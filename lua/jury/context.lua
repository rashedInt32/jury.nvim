-- The code around a diagnostic: the innermost enclosing function by
-- treesitter, or a window of lines when no parser is available. Capped.
local Config = require("jury.config")

local M = {}

local WANTED = {
  function_declaration = true,
  arrow_function = true,
  method_definition = true,
  function_expression = true,
  generator_function_declaration = true,
  lexical_declaration = true,
  export_statement = true,
}

local function truncate(s, n)
  return #s <= n and s or (s:sub(1, n) .. "…")
end

---@param bufnr integer
---@param row integer 0-based
---@return string
function M.enclosing(bufnr, row)
  local max = Config.options.context_chars
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if ok and parser then
    local tree = parser:parse()[1]
    local node = tree and tree:root():named_descendant_for_range(row, 0, row, 0)
    while node do
      if WANTED[node:type()] then
        local text = vim.treesitter.get_node_text(node, bufnr)
        if #text <= max then
          return text
        end
      end
      node = node:parent()
    end
  end
  local from = math.max(0, row - 12)
  local lines = vim.api.nvim_buf_get_lines(bufnr, from, row + 12, false)
  return truncate(table.concat(lines, "\n"), max)
end

return M
