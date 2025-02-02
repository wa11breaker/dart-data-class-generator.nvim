local null_ls = require("null-ls")
local ts = vim.treesitter

local utils = require("dart-data-class-generator.utils")
local generator = require("dart-data-class-generator.generator")

local M = {}
M.opts = {}

local defaults = {
    enable_code_actions = true,
}

local function setup_code_actions()
    null_ls.setup()
    null_ls.register({
        name = "data-class-generator",
        method = null_ls.methods.CODE_ACTION,
        filetypes = { "dart" },
        generator = {
            fn = function(_)
                local out = {}
                local node = ts.get_node()

                print("node", node)
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

function M.setup(options)
    M.opts = vim.tbl_deep_extend("force", {}, defaults, options or {})
    if M.opts.enable_code_actions then
        setup_code_actions()
    end
end

return M
