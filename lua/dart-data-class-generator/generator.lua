local parser = require("dart-data-class-generator.parser")
local utils = require("dart-data-class-generator.utils")

local constructor = require("dart-data-class-generator.generator.constructor")
local copy_with = require("dart-data-class-generator.generator.copy_with")
local to_json = require("dart-data-class-generator.generator.to_json")

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
    if not class_info then
        utils.notify("No class found")
        return
    end

    local line_number = utils.get_constructor_end_line_no()
    if not line_number then
        line_number = class_info.line_number
    end

    local result = to_json.generate_to_json(class_info)
    utils.write_widget(result, class_info.bufnr, line_number )
end

return M
