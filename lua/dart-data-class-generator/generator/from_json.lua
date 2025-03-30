local utils = require("dart-data-class-generator.utils")
local opts = require("dart-data-class-generator").opts

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
                value = variable.name .. "?.toJson()"
            else
                value = variable.name .. ".toJson()"
            end
        end

        table.insert(result, string.format("'%s': %s", variable.name, value))
    end

    return result
end

-- factory User.fromJson(Map<String, dynamic> json) {
--   return User(
--     name: json['name'],
--     email: json['email'],
--     preference: json['preference'],
--   );
-- }

---@param variables string[]
---@param class_name string
---@return string
local function get_from_json_template(class_name, variables)
    local map_list = table.concat(variables, ",\n    ")
    local template = [[
%s.fromJson(Map<String, dynamic> json) {
  return %s(
    %s
  );
}
]]
    return string.format(template, class_name, class_name, map_list)
end

---@param class_info ClassInfo
---@return string
M.generate_to_json = function(class_info, use_snake_case)
    print(opts.enable_auto_type_cast)
    local map = get_variable_map_list(class_info.variables)
    local to_json_template = get_from_json_template(
        class_info.name,
        map
    )

    return to_json_template
end

return M
