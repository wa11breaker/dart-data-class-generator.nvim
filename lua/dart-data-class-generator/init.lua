local null_ls = require("null-ls")
local ts = vim.treesitter

local utils = require("dart-data-class-generator.utils")
local generator = require("dart-data-class-generator.generator")

local M = {}

function M.setup()
    null_ls.register({
        name = "flutter-bloc",
        method = null_ls.methods.CODE_ACTION,
        filetypes = { "dart" },
        generator = {
            fn = function(_)
                local out = {}
                local node = ts.get_node()

                if utils.is_valid_node(node) then
                    table.insert(out, {
                        title  = "Generate Constructor",
                        action = generator.generate_constructor,
                    })

                    table.insert(out, {
                        title  = "Generate copyWith",
                        action = generator.generate_copy_with
                    })
                end

                return out
            end

        }
    })
end

return M
