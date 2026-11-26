local parser = require("dart-data-class-generator.parser")
local generator = require("dart-data-class-generator.generator")

local M = {}

M.FORMAT_COMMAND = "dart-data-class-generator.format"

-- What can be generated, and the members each one adds.
M.KINDS = { "constructor", "copyWith", "toJson", "fromJson", "equality" }
local kind_members = { equality = { "==", "hashCode" } }

-- Members in the order they're added to the class.
local MEMBERS = { "constructor", "copyWith", "toJson", "fromJson", "==", "hashCode" }

local generate = {
    constructor = generator.constructor,
    copyWith = generator.copy_with,
    toJson = generator.to_json,
    fromJson = generator.from_json,
    ["=="] = generator.equals,
    hashCode = generator.hash_code,
}

local actions = {
    { title = "Generate data class", kinds = M.KINDS },
    { title = "Generate constructor", kinds = { "constructor" } },
    { title = "Generate copyWith", kinds = { "copyWith" } },
    { title = "Generate toJson", kinds = { "toJson" } },
    { title = "Generate fromJson", kinds = { "fromJson" } },
    { title = "Generate == and hashCode", kinds = { "equality" } },
}

--- Indents every line after the first.
local function indent(code, prefix)
    return (code:gsub("\n([^\n])", "\n" .. prefix .. "%1"))
end

local function text_edit(sr, sc, er, ec, new_text)
    return {
        range = { start = { line = sr, character = sc }, ["end"] = { line = er, character = ec } },
        newText = new_text,
    }
end

local function is_flutter(bufnr)
    local root = vim.fs.root(bufnr, "pubspec.yaml")
    local file = root and io.open(vim.fs.joinpath(root, "pubspec.yaml"))
    if not file then
        return false
    end
    local pubspec = file:read("*a")
    file:close()
    return pubspec:match("sdk:%s*flutter") ~= nil
end

--- TextEdit adding `import '<path>';` after the file's other imports, unless
--- it's already there.
local function import_edit(bufnr, path)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local last
    for i, line in ipairs(lines) do
        if line:find(path, 1, true) and line:match("^import%s") then
            return nil
        elseif line:match("^import%s") or line:match("^library[%s;]") then
            last = i
        end
    end
    local import = "import '" .. path .. "';\n"
    if last then
        return text_edit(last, 0, last, 0, import)
    end
    return text_edit(0, 0, 0, 0, import .. "\n")
end

--- TextEdits that add `kinds` to `cls`, replacing members that already exist.
--- New constructors go at the top of the class body, other members at the end.
local function text_edits(bufnr, cls, kinds, opts)
    local edits, top, bottom = {}, {}, {}
    local wanted = {}
    for _, kind in ipairs(kinds) do
        for _, member in ipairs(kind_members[kind] or { kind }) do
            wanted[member] = true
        end
    end

    if wanted["=="] then
        opts = vim.tbl_extend("force", opts, { flutter = is_flutter(bufnr) })
        local path = generator.equality_import(cls, opts)
        local import = path and import_edit(bufnr, path)
        if import then
            table.insert(edits, import)
        end
    end

    for _, member in ipairs(MEMBERS) do
        if wanted[member] then
            local code = generate[member](cls, opts)
            local range = cls.members[member]
            if range then
                local line = vim.api.nvim_buf_get_lines(bufnr, range[1], range[1] + 1, true)[1]
                table.insert(edits, text_edit(range[1], range[2], range[3], range[4], indent(code, line:match("^%s*"))))
            else
                table.insert(member == "constructor" and top or bottom, cls.indent .. indent(code, cls.indent))
            end
        end
    end

    local open_row, open_col = cls.body:start()
    local close_row, close_col = cls.body:end_()
    close_col = close_col - 1
    -- Keep the closing brace's indentation when it's on its own line.
    local before_close = vim.api.nvim_buf_get_lines(bufnr, close_row, close_row + 1, true)[1]:sub(1, close_col)
    if before_close:match("^%s*$") and close_row > open_row then
        close_col = 0
    end

    local top_text = #top > 0 and "\n" .. table.concat(top, "\n\n") .. "\n" or ""
    local bottom_text = #bottom > 0 and "\n" .. table.concat(bottom, "\n\n") .. "\n" or ""
    if open_row == close_row and open_col + 1 == close_col then
        -- Empty `{}`: both go in the same place.
        top_text, bottom_text = top_text .. bottom_text, ""
    end
    if top_text ~= "" then
        table.insert(edits, text_edit(open_row, open_col + 1, open_row, open_col + 1, top_text))
    end
    if bottom_text ~= "" then
        table.insert(edits, text_edit(close_row, close_col, close_row, close_col, bottom_text))
    end
    return edits
end

local function workspace_edit(bufnr, edits)
    return { changes = { [vim.uri_from_bufnr(bufnr)] = edits } }
end

local function class_at(bufnr, row, col)
    local node = parser.class_at(bufnr, row, col)
    return node and parser.parse(bufnr, node)
end

--- LSP code actions for the class at (row, col). Widgets only get the
--- constructor, and State classes nothing.
function M.code_actions(bufnr, row, col, opts)
    local cls = class_at(bufnr, row, col)
    if not cls or cls.superclass == "State" then
        return {}
    end

    local result = {}
    for _, action in ipairs(cls.widget and { actions[2] } or actions) do
        table.insert(result, {
            title = action.title,
            kind = "refactor",
            edit = workspace_edit(bufnr, text_edits(bufnr, cls, action.kinds, opts)),
            command = { title = "Format", command = M.FORMAT_COMMAND },
        })
    end
    return result
end

function M.format(bufnr)
    if #vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/formatting" }) > 0 then
        pcall(vim.cmd.undojoin)
        vim.lsp.buf.format({ bufnr = bufnr, async = false })
    end
end

--- Adds `kinds` to the class under the cursor in the current window. Works
--- on any class, widgets included.
---@return boolean ok
function M.apply(kinds, opts)
    local bufnr = vim.api.nvim_get_current_buf()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local cls = class_at(bufnr, row - 1, col)
    if not cls then
        return false
    end
    vim.lsp.util.apply_text_edits(text_edits(bufnr, cls, kinds, opts), bufnr, "utf-8")
    M.format(bufnr)
    return true
end

return M
