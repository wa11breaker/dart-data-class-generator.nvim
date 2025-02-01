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

    utils.write_widget(result, class_info)
end

M.generate_copy_with = function()
    local class_info = parser.get_class_info()
    if not class_info then return end

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

    utils.write_widget(result, class_info)
end

return M
