-- One request to TypeSafe System One, in the background, through curl.
-- The key travels in a 0600 curl config file, never on argv.
-- `set_transport` swaps the network for a function, which is how tests run.
local Config = require("jury.config")

local M = {}

local transport = nil
local notified = {}

local function warn_once(msg)
  if notified[msg] then
    return
  end
  notified[msg] = true
  vim.schedule(function()
    vim.notify("[jury] " .. msg, vim.log.levels.WARN)
  end)
end

--- Resolve the API key: option, environment, key file. nil when none.
---@return string|nil
function M.key()
  local o = Config.options
  if o.api_key and o.api_key ~= "" then
    return o.api_key
  end
  if vim.env.TYPESAFE_API_KEY and vim.env.TYPESAFE_API_KEY ~= "" then
    return vim.env.TYPESAFE_API_KEY
  end
  local f = io.open(o.key_file, "r")
  if not f then
    return nil
  end
  local key = vim.trim(f:read("*a") or "")
  f:close()
  return key ~= "" and key or nil
end

function M.available()
  return transport ~= nil or M.key() ~= nil
end

-- ── question constructors ─────────────────────────────────────────────────

---@param instructions string|table
---@param criteria table<string, string|table>
function M.choice(instructions, criteria)
  return { type = "choice", instructions = instructions, criteria = criteria }
end

---@param instructions string|table
---@param yes string
---@param no string
function M.check(instructions, yes, no)
  return { type = "noul", instructions = instructions, criteria = { ["true"] = yes, ["false"] = no } }
end

--- Test seam: `fn(body, cb)` stands in for the network.
function M.set_transport(fn)
  transport = fn
end

--- Send a System One request. `cb(decoded)` on success, `cb(nil)` on any failure.
---@param state table|string
---@param questions table<string, table>
---@param cb fun(decoded: table|nil)
function M.request(state, questions, cb)
  local body = { state = state, questions = questions, model = Config.options.model }
  if transport then
    return transport(body, cb)
  end
  local key = M.key()
  if not key then
    warn_once("no TypeSafe key: set api_key, $TYPESAFE_API_KEY, or " .. Config.options.key_file)
    return cb(nil)
  end
  local ok, encoded = pcall(vim.json.encode, body)
  if not ok then
    return cb(nil)
  end
  local body_file = vim.fn.tempname()
  local config_file = vim.fn.tempname()
  vim.fn.writefile(vim.split(encoded, "\n"), body_file, "b")
  vim.fn.writefile({
    ('url = "%s"'):format(Config.options.endpoint),
    'request = "POST"',
    'header = "Content-Type: application/json"',
    ('header = "Authorization: Bearer %s"'):format(key),
    ('data-binary = "@%s"'):format(body_file),
    ("max-time = %d"):format(math.max(1, math.floor(Config.options.timeout_ms / 1000))),
    "silent",
    "show-error",
  }, config_file)
  vim.fn.setfperm(body_file, "rw-------")
  vim.fn.setfperm(config_file, "rw-------")
  local function cleanup()
    pcall(vim.fn.delete, body_file)
    pcall(vim.fn.delete, config_file)
  end
  vim.system({ "curl", "--config", config_file }, { text = true }, function(result)
    cleanup()
    if result.code ~= 0 then
      warn_once("request failed: " .. (result.stderr or ("curl exited " .. result.code)))
      return cb(nil)
    end
    local decoded_ok, decoded = pcall(vim.json.decode, result.stdout)
    if not decoded_ok or type(decoded) ~= "table" or decoded.answers == nil then
      warn_once("no answers in response: " .. (result.stdout or ""):sub(1, 120))
      return cb(nil)
    end
    cb(decoded)
  end)
end

return M
