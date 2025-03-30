local M = {}

---@param variables VariableDeclaration[]
---@return string[]
local function get_parameter_list(variables)
    local params = {}
    for _, var in ipairs(variables) do
        table.insert(params, var.type_full .. "? " .. var.name)
    end

    return params
end

---@param variables VariableDeclaration[]
---@return string[]
local function get_constructor_parameters(variables)
    local args = {}
    for _, var in ipairs(variables) do
        table.insert(args, var.name .. ": " .. var.name .. " ?? this." .. var.name)
    end

    return args
end

---@param class_name string
---@param parameter_list string[]
---@param constructor_parameters string[]
---@return string
local function get_copywith_template(class_name, parameter_list, constructor_parameters)
    if #parameter_list == 0 then
        return string.format("%s copyWith() => %s();", class_name, class_name)
    end

    local parameter_list_string = table.concat(parameter_list, ",\n  ") .. ","
    local constructor_parameters_string = table.concat(constructor_parameters, ",\n    ") .. ","


    local template = [[
%s copyWith({
  %s
}) {
  return %s(
    %s
  );
}
]]

    return string.format(
        template, class_name, parameter_list_string,
        class_name, constructor_parameters_string
    )
end

---@param class_info ClassInfo
---@return string
M.generate_copy_with = function(class_info)
    local parameter_list = get_parameter_list(class_info.variables)
    local constructor_parameters = get_constructor_parameters(class_info.variables)
    local copy_with = get_copywith_template(class_info.name, parameter_list, constructor_parameters)

    return copy_with
end

M._get_parameter_list = get_parameter_list
M._get_constructor_parameters = get_constructor_parameters
M._get_copywith_template = get_copywith_template
return M
