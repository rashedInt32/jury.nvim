-- Workspace candidates: names a judgment may pick from, found by ripgrep and
-- cached per cwd. Keys are `name@file`, sorted, so a pick is unambiguous and
-- the option order is the same on every run. Code enumerates; the model
-- only ever selects from what is listed here.
local Config = require("jury.config")

local M = {}

local cache = {} -- cwd .. "\n" .. id -> { list, at }
local pending = {} -- same key -> callbacks waiting on one running rg

--- Run one scan. `spec.re` is a ripgrep regex; `spec.name` is a Lua pattern
--- that pulls the identifier out of the matched line.
---@param spec { id: string, re: string, name: string, globs?: string[] }
---@param cwd string
---@param cb fun(list: table[])
function M.scan(spec, cwd, cb)
  local key = cwd .. "\n" .. spec.id
  local hit = cache[key]
  if hit and (os.time() - hit.at) < Config.options.candidate_ttl then
    return cb(hit.list)
  end
  if pending[key] then
    table.insert(pending[key], cb)
    return
  end
  pending[key] = { cb }
  local args = { "rg", "--no-heading", "--line-number", "--color", "never", "-g", "!node_modules", "-g", "!dist" }
  for _, g in ipairs(spec.globs or { "*.ts", "*.tsx" }) do
    args[#args + 1] = "-g"
    args[#args + 1] = g
  end
  args[#args + 1] = "-e"
  args[#args + 1] = spec.re
  args[#args + 1] = cwd
  vim.system(args, { text = true }, function(res)
    local list = {}
    for line in (res.stdout or ""):gmatch("[^\n]+") do
      local file, lnum, text = line:match("^(.-):(%d+):(.*)$")
      if file then
        local name = text:match(spec.name)
        if name then
          local rel = file:sub(1, #cwd) == cwd and file:sub(#cwd + 2) or file
          list[#list + 1] = { name = name, file = rel, line = tonumber(lnum), text = vim.trim(text) }
        end
      end
    end
    table.sort(list, function(a, b)
      if a.file ~= b.file then
        return a.file < b.file
      end
      return a.line < b.line
    end)
    for _, item in ipairs(list) do
      item.key = item.name .. "@" .. item.file
    end
    cache[key] = { list = list, at = os.time() }
    local waiting = pending[key] or {}
    pending[key] = nil
    for _, waiter in ipairs(waiting) do
      waiter(list)
    end
  end)
end

--- Strip the `@file` suffix from a picked key.
function M.name(key)
  return key and (key:gsub("@.*$", "")) or nil
end

-- Pending scans are left alone: a running rg still calls its waiters back.
function M.clear()
  cache = {}
end

function M.all()
  return cache
end

return M
