local M = {}

---@param variables VariableDeclaration[]
---@return string[]
local function get_parameter_list(variables)
    local params = {}
    for _, var in ipairs(variables) do
        local prefix = var.is_nullable and "" or "required "
        table.insert(params, prefix .. "this." .. var.name)
    end

    if #params == 0 then
        return {}
    end

    return params
end

---@param class_name string
---@param parameters string[]
---@return string
local function get_constructor_template(class_name, parameters)
    if #parameters == 0 then
        return string.format("%s();", class_name)
    end

    local parameter_string = table.concat(parameters, ",\n  ") .. ","
    return string.format([[%s({
  %s
});]], class_name, parameter_string)
end


---@param class_info ClassInfo
M.generate_constructor = function(class_info)
    local parameters = get_parameter_list(class_info.variables)
    local constructor = get_constructor_template(class_info.name, parameters)

    if #parameters == 0 then
        return constructor
    end
    return constructor .. "\n\n"  -- Add a newline to separate the constructor from the class body
end

M._get_parameter_list = get_parameter_list
M._get_constructor_template = get_constructor_template
return M
