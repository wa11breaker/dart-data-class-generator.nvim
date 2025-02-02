local ts = vim.treesitter

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

M.get_constructor_end_line_no = function()
    -- Get the current node under the cursor
    local current_node = ts.get_node()
    if not current_node then return nil end

    local parent_node = current_node:parent()
    if not parent_node then return nil end

    local lang = "dart"
    local bufnr = vim.api.nvim_get_current_buf()
    local query_string = [[(constructor_signature) @constructor]]

    local query = ts.query.parse(lang, query_string)
    for _, match, _ in query:iter_matches(parent_node, bufnr, 0, -1) do
        local node = match[1]
        if node then
            ---@diagnostic disable-next-line: undefined-field
            local _, _, end_row, _ = node:range()
            return end_row + 1
        end
    end

    return nil
end


M.is_valid_node = function(node)
    if not node then return false end
    local current = node:type()
    local parent = node:parent():type()

    return current == "identifier" and parent == "class_definition"
end

return M
