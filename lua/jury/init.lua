-- jury.nvim: calibrated picks for Neovim, judged by TypeSafe Jev.
--
-- Code enumerates the candidates, Jev picks one and says how sure it is,
-- a threshold decides whether that pick is shown. Judgments are prefetched
-- when diagnostics change and cached, so nothing on the hover path waits.
local Config = require("jury.config")
local Prefetch = require("jury.prefetch")

local M = {}

local registered = {}

---@param opts? JuryConfig
function M.setup(opts)
  Config.setup(opts)
  registered = {}
  if Config.options.sources["effect-error-pretty"] then
    local ok, err = require("jury.sources.effect_error_pretty").register()
    registered["effect-error-pretty"] = ok or err
  end
  Prefetch.attach()
  require("jury.commands").setup()
end

--- Register your own source. See `JurySource` in prefetch.lua.
function M.register_source(source)
  Prefetch.register(source)
  registered[source.name] = true
end

function M.judge(bufnr)
  Prefetch.judge_buffer(bufnr)
end

function M.clear()
  Prefetch.clear()
end

function M.status()
  local lines = { "sources:" }
  for name, v in pairs(registered) do
    lines[#lines + 1] = ("  %s: %s"):format(name, v == true and "registered" or tostring(v))
  end
  lines[#lines + 1] = "key: " .. (require("jury.client").available() and "available" or "missing")
  vim.list_extend(lines, Prefetch.status_lines())
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "jury" })
  return lines
end

return M
