local parser = require("dart-data-class-generator.parser")
local utils = require("dart-data-class-generator.utils")
local constructor = require("dart-data-class-generator.generator.constructor")
local copy_with = require("dart-data-class-generator.generator.copy_with")

local M = {}

M.generate_constructor = function()
    local class_info = parser.get_class_info()
    if not class_info then
        utils.notify("No class found")
        return
    end

    local result = constructor.generate_constructor(class_info)
    utils.write_widget(result, class_info.bufnr, class_info.line_number)
end

M.generate_copy_with = function()
    local class_info = parser.get_class_info()
    if not class_info then
        utils.notify("No class found")
        return
    end

    -- create copy_with method below constructor preferably
    local line_number = utils.get_constructor_end_line_no()
    if not line_number then
        line_number = class_info.line_number
    end

    local result = copy_with.generate_copy_with(class_info)
    utils.write_widget(result, class_info.bufnr, line_number)
end

M.generate_to_json = function()
    local class_info = parser.get_class_info()
    if not class_info then return end

    local start_line = utils.get_constructor_end_line_no()
    if not start_line then
        start_line = class_info.line_number
    end

    ---@param variables VariableDeclaration[]
    ---@return string
    local function generate_map(variables)
        ---@type string[]
        local result = {}

        for _, variable in ipairs(variables) do
            for _, var in ipairs(variable.vars) do
                local value = var
                local is_nullable = variable.is_nullable

                if (utils.is_custom_class(variable.type)) then
                    if is_nullable then
                        value = var .. "?.toJson()"
                    else
                        value = var .. ".toJson()"
                    end
                end

                table.insert(result, string.format("'%s': %s", var, value))
            end
        end

        return table.concat(result, ",\n")
    end

    local template = string.format(
        [[
        Map<String, dynamic> toJson() {
          return {
            %s,
          };
        }

        ]],
        generate_map(class_info.variables)
    )

    local result = string.format(
        template,
        generate_map(class_info.variables)
    )
    utils.write_widget(result, class_info.bufnr, start_line)
end

return M
