-- Minimal in-process language server for Dart buffers: code actions only.
local code_action = require("dart-data-class-generator.code_action")

local M = {}

local NAME = "dart-data-class-generator"

local methods = {
    initialize = function()
        -- utf-8 positions match tree-sitter byte columns
        return { capabilities = { positionEncoding = "utf-8", codeActionProvider = true } }
    end,
    ["textDocument/codeAction"] = function(params)
        local pos = params.range.start
        local opts = require("dart-data-class-generator").opts
        return code_action.code_actions(vim.uri_to_bufnr(params.textDocument.uri), pos.line, pos.character, opts)
    end,
}

local function server(dispatchers)
    local closing, request_id = false, 0

    local function stop()
        if not closing then
            closing = true
            dispatchers.on_exit(0, 15)
        end
    end

    return {
        request = function(method, params, callback)
            request_id = request_id + 1
            vim.schedule(function()
                local ok, result = pcall(methods[method] or function() end, params)
                callback(not ok and { code = -32603, message = tostring(result) } or nil, ok and result or nil)
            end)
            return true, request_id
        end,
        notify = function(method)
            if method == "exit" then
                stop()
            end
            return true
        end,
        is_closing = function()
            return closing
        end,
        terminate = stop,
    }
end

local config = {
    name = NAME,
    cmd = server,
    commands = {
        [code_action.FORMAT_COMMAND] = function(_, ctx)
            code_action.format(ctx.bufnr)
        end,
    },
}

local function attach(bufnr)
    vim.lsp.start(config, {
        bufnr = bufnr,
        reuse_client = function(client)
            return client.name == NAME
        end,
    })
end

function M.setup()
    vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup(NAME, { clear = true }),
        pattern = "dart",
        callback = function(args)
            attach(args.buf)
        end,
    })

    -- Dart buffers opened before setup() ran.
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].filetype == "dart" then
            attach(bufnr)
        end
    end
end

return M
