local M = {}

M.join_lines = function(...)
    local lines = { ... }
    return table.concat(lines, "\n")
end

---@param snippet string
---@param bufnr number
---@param line_number number
M.write_widget = function(snippet, bufnr, line_number)
    local data = vim.split(snippet, "\n", { plain = true })
    vim.api.nvim_buf_set_text(
        bufnr,
        line_number + 1, 0,
        line_number + 1, 0,
        data
    )
    -- vim.cmd("undojoin")
    vim.lsp.buf.format({ async = false, bufnr = bufnr, })
end


M.is_valid_node = function(node)
    if not node then return false end
    local current = node:type()
    local parent = node:parent():type()

    return current == "identifier" and parent == "class_definition"
end

return M
