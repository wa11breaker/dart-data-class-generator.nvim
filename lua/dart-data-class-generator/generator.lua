local parser = require("dart-data-class-generator.parser")
local utils = require("dart-data-class-generator.utils")

local M = {}

M.generate_constructor = function()
    local class_info = parser.get_class_info()
    if not class_info then return end

    local function generate_parameter_list(variables)
        local params = {}
        for _, vars in ipairs(variables) do
            for _, var in ipairs(vars.vars) do
                local prefix = vars.is_nullable and "" or "required "
                table.insert(params, prefix .. "this." .. var)
            end
        end
        return table.concat(params, ",\n") .. ","
    end

    local template = string.format("%s ({", class_info.name) .. "\n%s\n});\n\n"
    local result = string.format(
        template,
        generate_parameter_list(class_info.variables)
    )

    utils.write_widget(result, class_info.bufnr, class_info.line_number)
end

M.generate_copy_with = function()
    local class_info = parser.get_class_info()
    if not class_info then return end

    local start_line = utils.get_constructor_end_line_no()
    if not start_line then
        start_line = class_info.line_number
    end

    ---@param variables VariableDeclaration[]
    local function generate_parameter_list(variables)
        local params = {}
        for _, vars in ipairs(variables) do
            for _, var in ipairs(vars.vars) do
                table.insert(params, vars.type_full .. "? " .. var)
            end
        end
        return table.concat(params, ",\n") .. ","
    end

    ---@param variables VariableDeclaration[]
    local function generate_constructor_args(variables)
        local args = {}
        for _, vars in ipairs(variables) do
            for _, var in ipairs(vars.vars) do
                table.insert(args, var .. ": " .. var .. " ?? this." .. var)
            end
        end
        return table.concat(args, ",\n") .. ","
    end

    local template = utils.join_lines(
        string.format("%s copyWith({", class_info.name),
        "%s", -- parameters
        "}) {",
        string.format("  return %s(", class_info.name),
        "%s", -- arguments
        "  );",
        "}\n\n"
    )
    local result = string.format(
        template,
        generate_parameter_list(class_info.variables),
        generate_constructor_args(class_info.variables)
    )

    utils.write_widget(result, class_info.bufnr, start_line)
end

M.generate_from_json = function()
    local class_info = parser.get_class_info()
    if not class_info then return end

    local start_line = utils.get_constructor_end_line_no()
    if not start_line then
        start_line = class_info.line_number
    end

    ---@param variables VariableDeclaration[]
    ---@return string
    local function generate_parameter_list(variables)
        ---@type string[]
        local result = {}

        for _, variable in ipairs(variables) do
            for _, var in ipairs(variable.vars) do
                local is_nullable = variable.is_nullable
                local nullable_suffix = is_nullable and "?" or ""
                local value = string.format("json['%s'] as %s%s", var, variable.type_full, nullable_suffix)

                table.insert(result, string.format("%s: %s", var, value))
            end
        end

        return table.concat(result, ",\n")
    end

    local template = string.format(
        [[
        factory %s.fromJson(Map<String, dynamic> json) {
          return %s(
            %s,
          );
        }

        ]],
        class_info.name,
        class_info.name,
        generate_parameter_list(class_info.variables)
    )
    local result = string.format(
        template,
        generate_parameter_list(class_info.variables)
    )
    utils.write_widget(result, class_info.bufnr, start_line)
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
