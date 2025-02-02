local M = {}

M.join_lines = function(...)
    local lines = { ... }
    return table.concat(lines, "\n")
end

---@param snippet string
---@param class_info ClassInfo
M.write_widget = function(snippet, class_info)
    local lines = vim.split(snippet, "\n", { plain = true })
    vim.api.nvim_buf_set_text(class_info.bufnr,
        class_info.line_number + 1, 0,
        class_info.line_number + 1, 0, lines
    )
    -- vim.cmd("undojoin")
    vim.lsp.buf.format({ async = false, bufnr = class_info.bufnr, })
end


M.is_valid_node = function(node)
    if not node then return false end

    local parent = node:parent()
    return node:type() == "identifier" and parent:type() == "class_definition"
end

return M
