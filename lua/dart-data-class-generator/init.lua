---@class ClassInfo
---@field bufnr number
---@field line_number number
---@field name string|nil
---@field variables VariableDeclaration[]

---@class VariableDeclaration
---@field type string|nil
---@field is_nullable boolean
---@field vars string[]

local null_ls = require("null-ls")
local ts = vim.treesitter


local function is_valid_node(node)
    if not node then return false end

    return node:type() == "identifier" or node:type() == "type_identifier"
end

---@return ClassInfo|nil
local function get_class_info()
    local bufnr = vim.api.nvim_get_current_buf()

    local currentNode = ts.get_node()
    if not currentNode then return nil end
    local start_row, _ = currentNode:start()

    local parent_node = currentNode:parent()
    if not parent_node then return nil end

    local parser = ts.get_parser()
    local lang = parser:lang()
    local query_string = [[
    (declaration
            (type_identifier) @type
            (nullable_type)? @is_nullable
            (initialized_identifier_list
                (initialized_identifier
                    (identifier) @variable)))
    ]]

    ---@type ClassInfo
    local class_info = {
        bufnr = bufnr,
        line_number = start_row,
        name = vim.treesitter.get_node_text(currentNode, 0),
        variables = {},
    }

    ---@type VariableDeclaration[]
    local variables = {}

    local query = ts.query.parse(lang, query_string)
    for _, match, _ in query:iter_matches(parent_node, 0) do
        ---@type VariableDeclaration
        local current_variable = {
            type = nil,
            is_nullable = false,
            vars = {},
        }
        ---@type string[]
        local current_variable_names = {}

        for id, node in pairs(match) do
            local capture_name = query.captures[id]
            local node_text = vim.treesitter.get_node_text(node, 0)

            if capture_name == "type" then
                current_variable.type = node_text
            elseif capture_name == "is_nullable" then
                current_variable.is_nullable = true
            elseif capture_name == "variable" then
                table.insert(current_variable_names, node_text)
            end
        end

        if current_variable.type then
            current_variable.vars = current_variable_names
            table.insert(variables, current_variable)
        end
    end

    -- Sort variables by is_nullable
    table.sort(variables, function(a, b)
        if a.is_nullable ~= b.is_nullable then
            return not a.is_nullable
        end
        return false
    end)

    class_info.variables = variables
    return class_info
end

---@param snippet string
---@param class_info ClassInfo
local write_widget = function(snippet, class_info)
    local lines = vim.split(snippet, "\n", { plain = true })
    vim.api.nvim_buf_set_text(class_info.bufnr, class_info.line_number + 1, 0, class_info.line_number + 1, 0, lines)
    -- vim.cmd("undojoin")
    vim.lsp.buf.format({ async = false, bufnr = class_info.bufnr, })
end

local function generate_constructor()
    local class_info = get_class_info()
    if not class_info then return end

    local constructor_table = {
        string.format("%s ({", class_info.name),
    }

    for _, variables in ipairs(class_info.variables) do
        for _, variable in ipairs(variables.vars) do
            if variables.is_nullable then -- Optional variable
                table.insert(constructor_table, string.format("  this.%s,", variable))
            else                          -- Required variable
                table.insert(constructor_table, string.format("  required this.%s,", variable))
            end
        end
    end

    table.insert(constructor_table, "});\n")
    write_widget(table.concat(constructor_table, "\n"), class_info)
end

local M = {}

function M.setup()
    null_ls.register({
        name = "flutter-bloc",
        method = null_ls.methods.CODE_ACTION,
        filetypes = { "dart" },
        generator = {
            fn = function(_)
                local out = {}
                local node = ts.get_node()

                if is_valid_node(node) then
                    table.insert(out, {
                        title  = "Generate Constructor",
                        action = generate_constructor,
                    })
                end

                return out
            end

        }
    })
end

M.setup()

return M
