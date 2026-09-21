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

local function exported_above(node)
  while node do
    if node:type() == "export_statement" then
      return true
    end
    node = node:parent()
  end
  return false
end

---@class JuryContext
---@field text string      the enclosing function or a window of lines
---@field exported boolean whether that code is exported from the module
---@field file string      buffer path relative to the cwd

--- The code around a diagnostic and two facts a judge cannot see in the
--- text alone: is it exported, and where does the file live.
---@param bufnr integer
---@param row integer 0-based
---@return JuryContext
function M.describe(bufnr, row)
  local max = Config.options.context_chars
  local file = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":.")
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if ok and parser then
    local tree = parser:parse()[1]
    local node = tree and tree:root():named_descendant_for_range(row, 0, row, 0)
    while node do
      if WANTED[node:type()] then
        local text = vim.treesitter.get_node_text(node, bufnr)
        if #text <= max then
          return { text = text, exported = exported_above(node), file = file }
        end
      end
      node = node:parent()
    end
  end
  local from = math.max(0, row - 12)
  local lines = vim.api.nvim_buf_get_lines(bufnr, from, row + 12, false)
  local exported = (lines[row - from + 1] or ""):match("^%s*export%s") ~= nil
  return { text = truncate(table.concat(lines, "\n"), max), exported = exported, file = file }
end

---@param bufnr integer
---@param row integer 0-based
---@return string
function M.enclosing(bufnr, row)
  return M.describe(bufnr, row).text
end

return M
