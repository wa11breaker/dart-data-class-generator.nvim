local ts = vim.treesitter

local M = {}

M.join_lines = function(...)
    local lines = { ... }
    return table.concat(lines, "\n")
end

---@param snippet string
---@param bufnr number
---@param line_number number
M.write_widget = function(snippet, bufnr, line_number)
    local data = vim.split(snippet, "\n", { plain = true })
    -- TODO: line_number + 1 will throw error if the class is empty
    vim.api.nvim_buf_set_text(
        bufnr,
        line_number + 1, 0,
        line_number + 1, 0,
        data
    )
    -- vim.cmd("undojoin")
    vim.lsp.buf.format({ async = false, bufnr = bufnr, })
end

M.get_constructor_end_line_no = function()
    local current_node = ts.get_node()
    if not current_node then return nil end

    local parent_node = current_node:parent()
    if not parent_node then return nil end

    local lang = "dart"
    local bufnr = vim.api.nvim_get_current_buf()
    local query_string = [[(constructor_signature) @constructor]]

    local query = ts.query.parse(lang, query_string)

    for _, match, _ in query:iter_matches(parent_node, bufnr, nil, nil, { all = false }) do
        local node = match[1]
        if node then
            ---@diagnostic disable-next-line: undefined-field
            local _, _, end_row, _ = node:range()
            return end_row + 1
        end
    end

    return nil
end


M.is_valid_node = function(node)
    if not node then return false end
    local current = node:type()
    local parent = node:parent():type()

    return current == "identifier" and parent == "class_definition"
end

-- Check if a type is a custom class (not a built-in type)
---@param type_name string
---@return boolean
M.is_custom_class = function(type_name)
    if not type_name then
        return false
    end

    -- List of Dart built-in types
    local built_in_types = {
        "int", "double", "String", "bool", "num",
        "List", "Map", "Set", "Iterable", "Future",
        "Stream", "dynamic", "void", "Object", "Function"
    }

    -- Check if type is in the built-in types list
    for _, built_in_type in ipairs(built_in_types) do
        if type_name == built_in_type then
            return false
        end
    end

    -- Check first character - custom classes typically start with uppercase
    local first_char = string.sub(type_name, 1, 1)
    if first_char == string.upper(first_char) then
        return true
    end

    return false
end

return M
