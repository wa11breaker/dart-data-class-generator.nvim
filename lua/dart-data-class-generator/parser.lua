-- Reads a Dart class from the buffer with tree-sitter.

local M = {}

-- Declaration children that aren't part of a field's type.
local not_type = {
    final_builtin = true,
    const_builtin = true,
    inferred_type = true,
    initialized_identifier_list = true,
}

local function text(bufnr, node)
    return vim.treesitter.get_node_text(node, bufnr)
end

local function children(node, type)
    local list = {}
    for child in node:iter_children() do
        if child:named() and (not type or child:type() == type) then
            table.insert(list, child)
        end
    end
    return list
end

--- Range of a class member, including its body and trailing `;`, and its
--- annotations if `annotations` is set.
local function member_range(bufnr, node, annotations)
    local sr, sc, er, ec = node:range()
    local prev = node:prev_named_sibling()
    while annotations and prev and prev:type() == "annotation" do
        sr, sc = prev:start()
        prev = prev:prev_named_sibling()
    end
    local next = node:next_named_sibling()
    if next and next:type() == "function_body" then
        _, _, er, ec = next:range()
    end
    local line = vim.api.nvim_buf_get_lines(bufnr, er, er + 1, true)[1]
    if line:sub(ec + 1, ec + 1) == ";" then
        ec = ec + 1
    end
    return { sr, sc, er, ec }
end

local function identifiers(bufnr, node)
    local names = {}
    for _, id in ipairs(children(node, "identifier")) do
        table.insert(names, text(bufnr, id))
    end
    return names
end

--- Instance fields of a `declaration`, or nil if it isn't one. Static fields
--- and fields with an initializer are left out: the constructor can't set them.
local function fields(bufnr, decl)
    local list_node = children(decl, "initialized_identifier_list")[1]
    if not list_node or text(bufnr, decl):match("^static%f[^%w_]") then
        return nil
    end

    local type_nodes = vim.tbl_filter(function(child)
        return not not_type[child:type()]
    end, children(decl))
    local type = "dynamic"
    if #type_nodes > 0 then
        local sr, sc = type_nodes[1]:start()
        local er, ec = type_nodes[#type_nodes]:end_()
        type = table.concat(vim.api.nvim_buf_get_text(bufnr, sr, sc, er, ec, {}), " ")
    end

    local final = #children(decl, "final_builtin") > 0
    local result = {}
    for _, id in ipairs(children(list_node, "initialized_identifier")) do
        if id:named_child_count() == 1 then
            table.insert(result, { name = text(bufnr, id:named_child(0)), type = type, final = final })
        end
    end
    return result
end

--- The generated member (constructor, copyWith, toJson, fromJson, ==,
--- hashCode) a class body child declares, if any.
local function member_kind(bufnr, node, class_name)
    local sig = node:named_child(0)
    if not sig then
        return nil
    end
    local type, names = sig:type(), identifiers(bufnr, sig)

    if node:type() == "declaration"
        and (type == "constructor_signature" or type == "constant_constructor_signature")
        and #names == 1 and names[1] == class_name then
        return "constructor", type == "constant_constructor_signature"
    end
    if node:type() == "method_signature" then
        if type == "function_signature" and (names[1] == "copyWith" or names[1] == "toJson") then
            return names[1]
        end
        if type == "factory_constructor_signature" and names[1] == class_name and names[2] == "fromJson" then
            return "fromJson"
        end
        if type == "getter_signature" and names[1] == "hashCode" then
            return "hashCode"
        end
        local operator = type == "operator_signature" and children(sig, "binary_operator")[1]
        if operator and text(bufnr, operator) == "==" then
            return "=="
        end
    end
end

--- The class around (row, col), unless the position is inside a method body.
function M.class_at(bufnr, row, col)
    local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "dart")
    if not ok or not parser then
        return nil
    end
    parser:parse()

    local node = parser:named_node_for_range({ row, col, row, col })
    while node do
        local type = node:type()
        if type == "function_body" then
            return nil
        elseif type == "class_definition" then
            return node
        end
        node = node:parent()
    end
end

---@return table|nil cls { name, type_params, superclass, widget, fields, const, members, body, indent }
function M.parse(bufnr, class_node)
    local cls = { type_params = {}, fields = {}, members = {}, const = false }

    for child in class_node:iter_children() do
        local type = child:type()
        if type == "identifier" and not cls.name then
            cls.name = text(bufnr, child)
        elseif type == "type_parameters" then
            for _, param in ipairs(children(child, "type_parameter")) do
                table.insert(cls.type_params, text(bufnr, param:named_child(0)))
            end
        elseif type == "superclass" then
            local base = children(child, "type_identifier")[1]
            cls.superclass = base and text(bufnr, base)
            -- Name-based: tree-sitter can't see what a custom base class extends.
            cls.widget = cls.superclass ~= nil and cls.superclass:match("Widget$") ~= nil
        elseif type == "class_body" then
            cls.body = child
        end
    end
    if not (cls.name and cls.body) then
        return nil
    end

    for _, node in ipairs(children(cls.body)) do
        if not cls.indent then
            local row, col = node:start()
            local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, true)[1]
            local indent = line:match("^%s*")
            if #indent == col and col > 0 then
                cls.indent = indent
            end
        end

        local kind, const = member_kind(bufnr, node, cls.name)
        if kind then
            -- The generated == and hashCode come with their @override.
            local annotations = kind == "==" or kind == "hashCode"
            cls.members[kind] = cls.members[kind] or member_range(bufnr, node, annotations)
            cls.const = cls.const or const or false
        elseif node:type() == "declaration" then
            vim.list_extend(cls.fields, fields(bufnr, node) or {})
        end
    end
    cls.indent = cls.indent or "  "

    return cls
end

return M
