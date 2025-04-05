local utils = require("dart-data-class-generator.utils")

local M = {}

---@param variables VariableDeclaration[]
---@return string[]
local function get_variable_map_list(variables)
    ---@type string[]
    local result = {}

    for _, variable in ipairs(variables) do
        local value = variable.name
        local is_nullable = variable.is_nullable

        if (utils.is_custom_class(variable.type)) then
            if is_nullable then
                value = variable.type_full .. '?.fromJson(json[\'' .. variable.name .. '\'])'
            else
                value = variable.type_full .. '.fromJson(json[\'' .. variable.name .. '\'])'
            end
        else
            value = 'json[\'' .. variable.name .. '\']' .. ' as ' .. variable.type
            if is_nullable then
                value = value .. '?'
            end
        end

        table.insert(result, string.format("%s: %s", variable.name, value))
    end

    return result
end

---@param variables string[]
---@param class_name string
---@return string
local function get_from_json_template(class_name, variables)
    local map_list = table.concat(variables, ",\n    ")
    local template = [[
factory %s.fromJson(Map<String, dynamic> json) {
  return %s(
    %s,
  );
}
]]
    return string.format(template, class_name, class_name, map_list)
end

---@param class_info ClassInfo
---@return string
M.generate_from_json = function(class_info)
    local map = get_variable_map_list(class_info.variables)
    local to_json_template = get_from_json_template(
        class_info.name,
        map
    )

    return to_json_template
end

return M
