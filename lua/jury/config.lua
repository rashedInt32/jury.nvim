local M = {}

---@class JuryConfig
---@field api_key? string          TypeSafe key. Falls back to $TYPESAFE_API_KEY, then key_file.
---@field key_file string          0600 file holding the key.
---@field model string
---@field endpoint string
---@field timeout_ms integer
---@field min_confidence number    below this a pick is reported as a lean, not a hint
---@field debounce_ms integer      wait after DiagnosticChanged before judging
---@field context_chars integer    cap on the enclosing-function text sent as state
---@field candidate_ttl integer    seconds a workspace scan stays fresh
---@field notify boolean           one line per batch
---@field label string             printed instead of "Hint" on a concrete line
---@field sources table<string, boolean>  which adapters to register
M.defaults = {
  api_key = nil,
  key_file = vim.fn.expand("~/.config/typesafe/key"),
  model = "jev-latest",
  endpoint = "https://api.typesafe.ai/v1/systemone",
  timeout_ms = 8000,
  min_confidence = 0.6,
  debounce_ms = 500,
  context_chars = 1500,
  candidate_ttl = 30,
  notify = true,
  label = "Jev",
  sources = { ["effect-error-pretty"] = true },
}

---@type JuryConfig
M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  return M.options
end

return M
