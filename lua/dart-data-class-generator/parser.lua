local ts = vim.treesitter

---@class ClassInfo
---@field bufnr number
---@field line_number number
---@field name string|nil
---@field variables VariableDeclaration[]

---@class VariableDeclaration
---@field type string|nil        -- Basic type (e.g., "int", "Map")
---@field type_full string|nil   -- Full type including generics (e.g., "Map<int, RequestModel>")
---@field is_nullable boolean    -- Whether the type is nullable
---@field vars string[]          -- Variable names, since dart support multiple variables in a single declaration

local M = {}

---@return ClassInfo|nil
M.get_class_info = function()
    local bufnr = vim.api.nvim_get_current_buf()
    local currentNode = ts.get_node()
    if not currentNode then return nil end
    local start_row, _ = currentNode:start()

    local parent_node = currentNode:parent()
    if not parent_node then return nil end

    local lang = "dart"
    local query_string = [[
    (declaration
      (function_type
        (nullable_type)? @is_nullable)? @funciton_type
      (type_identifier)? @type
      (type_arguments)? @type_args
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
            type_full = nil,
            is_nullable = false,
            vars = {},
        }
        ---@type string[]
        local current_variable_names = {}
        local type_arguments = nil

        for id, node in pairs(match) do
            local capture_name = query.captures[id]
            local node_text = vim.treesitter.get_node_text(node, 0)

            if capture_name == "type" then
                current_variable.type = node_text
            elseif capture_name == "is_nullable" then
                current_variable.is_nullable = true
            elseif capture_name == "variable" then
                table.insert(current_variable_names, node_text)
            elseif capture_name == "type_args" then
                type_arguments = node_text
            elseif capture_name == "funciton_type" then
                current_variable.type = "Function"
                current_variable.type_full = node_text
            end
        end

        -- Append generic type arguments (if present) to make the full type
        -- Example: "List<int>" or "Map<String, double>"
        if type_arguments then
            current_variable.type_full = string.format("%s%s", current_variable.type, type_arguments)
        end

        -- If the type is a nullable function, remove the trailing "?"
        -- from type_full since nullability is already tracked separately.
        if current_variable.type == "Function" and current_variable.is_nullable then
            if current_variable.type_full:sub(-1) == "?" then
                current_variable.type_full = current_variable.type_full:sub(1, -2)
            end
        end

        -- If type_full is not set, default it to the basic type.
        if current_variable.type_full == nil then
            current_variable.type_full = current_variable.type
        end


        if current_variable.type then
            current_variable.vars = current_variable_names
            table.insert(variables, current_variable)
        end
    end

    -- Sort, non-nullable first
    table.sort(variables, function(a, b)
        if a.is_nullable ~= b.is_nullable then
            return not a.is_nullable
        end
        return false
    end)

    class_info.variables = variables
    return class_info
end

return M
