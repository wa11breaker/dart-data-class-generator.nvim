if vim.g.loaded_dart_data_class_generator then
    return
end
vim.g.loaded_dart_data_class_generator = true

vim.api.nvim_create_user_command("DartDataClass", function(args)
    require("dart-data-class-generator").generate(args.args ~= "" and args.args or nil)
end, {
    nargs = "?",
    complete = function()
        return require("dart-data-class-generator.code_action").KINDS
    end,
    desc = "Generate data class members for the class under the cursor",
})
