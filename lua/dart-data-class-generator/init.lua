local code_action = require("dart-data-class-generator.code_action")

local M = {}

local defaults = {
    enable_code_actions = true,
    use_snake_case = false, -- JSON keys in snake_case: `createdAt` -> 'created_at'
}

M.opts = vim.deepcopy(defaults)

local function notify(msg, level)
    vim.notify(msg, level or vim.log.levels.INFO, { title = "dart-data-class-generator" })
end

--- Each call is merged into the options of earlier calls, so a project's
--- .nvim.lua only needs the options it changes.
function M.setup(options)
    M.opts = vim.tbl_deep_extend("force", M.opts, options or {})
    if M.opts.enable_code_actions then
        require("dart-data-class-generator.lsp").setup()
    end
end

--- Adds members to the class under the cursor.
---@param kind? string "constructor", "copyWith", "toJson", "fromJson", or nil for all of them
function M.generate(kind)
    if kind and not vim.tbl_contains(code_action.KINDS, kind) then
        notify("Unknown member '" .. kind .. "'", vim.log.levels.ERROR)
        return
    end
    if not code_action.apply(kind and { kind } or code_action.KINDS, M.opts) then
        notify("No class under the cursor", vim.log.levels.WARN)
    end
end

return M
