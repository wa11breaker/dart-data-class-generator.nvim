local parser = require("dart-data-class-generator.parser")
local utils = require("dart-data-class-generator.utils")

local M = {}

---@param variables VariableDeclaration[]
---@return string[]
local function generate_parameter_list(variables)
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

---@param class_info ClassInfo
---@return string
M.generate_constructor = function(class_info)
    local paramaters = generate_parameter_list(class_info.variables)
    local paramater_string = table.concat(paramaters, ",\n") .. ","

    local template = string.format([[
    %s ({
    %s
    });

]], class_info.name, paramaters)

    local result = string.format(template, paramater_string)
    return result
end

M._generate_parameter_list = generate_parameter_list
return M
