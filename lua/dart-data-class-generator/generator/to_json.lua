local utils = require("dart-data-class-generator.utils")

local M = {}

---@param variables VariableDeclaration[]
---@return string
local function get_variable_map_list(variables)
    ---@type string[]
    local result = {}

    for _, variable in ipairs(variables) do
        local value = variable.name
        local is_nullable = variable.is_nullable

        if (utils.is_custom_class(variable.type)) then
            if is_nullable then
                value = variable.name .. "?.toJson()"
            else
                value = variable.name .. ".toJson()"
            end
        end

        table.insert(result, string.format("'%s': %s", variable.name, value))
    end

    return table.concat(result, ",\n")
end

---@param variables VariableDeclaration[]
---@return string
local function get_to_json_template(variables)
    local map = get_variable_map_list(variables)
    return string.format(
        [[
Map<String, dynamic> toJson() {
  return {
    %s,
  };
}
]],
        map
    )
end

---@param class_info ClassInfo
---@return string
M.generate_to_json = function(class_info)
    local to_json_template = get_to_json_template(class_info.variables)
    return to_json_template
end

return M
