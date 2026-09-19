-- The loop. Nothing here knows what a question means; sources do.
--
--   DiagnosticChanged ─debounce─▶ judge_buffer ─▶ for each source:
--     collect items ─▶ skip cached / in flight / duplicate signature
--     ─▶ one request ─▶ answers ─▶ source.finish(item) ─▶ cache entry
--
-- Consumers read the cache synchronously on hover. A miss renders whatever
-- the consumer renders on its own and schedules a judge for next time.
local Config = require("jury.config")
local Client = require("jury.client")

local uv = vim.uv or vim.loop

local M = {}

---@class JurySource
---@field name string
---@field filetypes table<string, boolean>
---@field collect fun(bufnr: integer): JuryItem[]
---@field state fun(bufnr: integer, items: JuryItem[], cb: fun(shared: table))
---@field questions fun(item: JuryItem, id: string, shared: table): table<string, table>|nil
---@field finish fun(item: JuryItem, id: string, answers: table, shared: table): table

---@class JuryItem
---@field key string      cache key this item serves
---@field sig string      duplicate signature: items with equal sig share one judgment
---@field keys? string[]  every cache key that ends up served by this judgment
---@field id? string

local state = {
  sources = {}, -- name -> JurySource
  cache = {}, -- key -> entry
  by_sig = {}, -- sig -> entry
  inflight = {}, -- key -> true
  timers = {}, -- bufnr -> timer
  last = {}, -- name -> { at, judged, latency_ms, answers }
  log = {}, -- recent batch lines for :Jury status
}

local function notify(msg, level)
  state.log[#state.log + 1] = os.date("%H:%M:%S ") .. msg
  if #state.log > 20 then
    table.remove(state.log, 1)
  end
  if Config.options.notify then
    vim.schedule(function()
      vim.notify("[jury] " .. msg, level or vim.log.levels.INFO)
    end)
  end
end

function M.register(source)
  state.sources[source.name] = source
end

function M.get(key)
  return state.cache[key]
end

function M.inflight(key)
  return state.inflight[key] == true
end

--- Judge every source's pending items for a buffer. One request per source.
function M.judge_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  if not Client.available() then
    return
  end
  for _, source in pairs(state.sources) do
    local ok, collected = pcall(source.collect, bufnr)
    if not ok then
      notify(source.name .. " collect failed: " .. tostring(collected), vim.log.levels.WARN)
      collected = {}
    end
    local items, seen = {}, {}
    for _, item in ipairs(collected) do
      if state.cache[item.key] == nil and not state.inflight[item.key] then
        if state.by_sig[item.sig] then
          state.cache[item.key] = state.by_sig[item.sig]
        elseif seen[item.sig] then
          table.insert(seen[item.sig].keys, item.key)
          state.inflight[item.key] = true
        else
          item.keys = { item.key }
          seen[item.sig] = item
          items[#items + 1] = item
        end
      end
    end
    if #items > 0 then
      M.run(source, bufnr, items)
    end
  end
end

function M.run(source, bufnr, items)
  source.state(bufnr, items, function(shared)
    vim.schedule(function()
      local questions, batch, count = {}, {}, 0
      for i, item in ipairs(items) do
        local id = "d" .. i
        local ok, q = pcall(source.questions, item, id, shared)
        if ok and q and next(q) then
          item.id = id
          batch[#batch + 1] = item
          for k, v in pairs(q) do
            questions[k] = v
            count = count + 1
          end
          for _, key in ipairs(item.keys) do
            state.inflight[key] = true
          end
        end
        if count >= 60 then
          break
        end
      end
      if #batch == 0 then
        return
      end
      local state_items = {}
      for _, item in ipairs(batch) do
        state_items[#state_items + 1] = item.state
      end
      local request_state = vim.tbl_extend("force", shared.state or {}, { items = state_items })
      local started = uv.hrtime()
      Client.request(request_state, questions, function(decoded)
        local latency = math.floor((uv.hrtime() - started) / 1e6)
        vim.schedule(function()
          for _, item in ipairs(batch) do
            for _, key in ipairs(item.keys) do
              state.inflight[key] = nil
            end
          end
          if not decoded then
            notify(("%s: request failed after %d ms"):format(source.name, latency), vim.log.levels.WARN)
            return
          end
          local concrete = 0
          for _, item in ipairs(batch) do
            local ok, entry = pcall(source.finish, item, item.id, decoded.answers, shared)
            if not ok then
              entry = { error = tostring(entry) }
            end
            entry = entry or {}
            entry.at = os.time()
            state.by_sig[item.sig] = entry
            for _, key in ipairs(item.keys) do
              state.cache[key] = entry
            end
            if entry.line or entry.index then
              concrete = concrete + 1
            end
          end
          state.last[source.name] = { at = os.date("%H:%M:%S"), judged = #batch, latency_ms = latency, answers = decoded.answers }
          notify(("%s: judged %d in %d ms, %d concrete"):format(source.name, #batch, latency, concrete))
          vim.api.nvim_exec_autocmds("User", { pattern = "JuryJudged", data = { source = source.name, bufnr = bufnr } })
        end)
      end)
    end)
  end)
end

--- Debounced judge for a buffer; waits out insert mode.
function M.schedule(bufnr)
  local t = state.timers[bufnr]
  if t then
    t:stop()
  else
    t = uv.new_timer()
    state.timers[bufnr] = t
  end
  t:start(Config.options.debounce_ms, 0, function()
    vim.schedule(function()
      if vim.fn.mode():sub(1, 1) == "i" then
        M.schedule(bufnr)
        return
      end
      M.judge_buffer(bufnr)
    end)
  end)
end

function M.attach()
  local group = vim.api.nvim_create_augroup("Jury", { clear = true })
  vim.api.nvim_create_autocmd("DiagnosticChanged", {
    group = group,
    callback = function(args)
      local ft = vim.bo[args.buf].filetype
      for _, source in pairs(state.sources) do
        if source.filetypes[ft] then
          M.schedule(args.buf)
          return
        end
      end
    end,
  })
end

function M.clear()
  state.cache, state.by_sig, state.inflight = {}, {}, {}
  require("jury.candidates").clear()
end

function M.status_lines()
  local lines = {}
  for name, last in pairs(state.last) do
    lines[#lines + 1] = ("%s: last batch %s, %d judged, %d ms"):format(name, last.at, last.judged, last.latency_ms)
    for id, a in pairs(last.answers or {}) do
      lines[#lines + 1] = ("  %-12s %s %.2f"):format(id, tostring(a.choice or a.noul), a.confidence or a.noul or 0)
    end
  end
  lines[#lines + 1] = ("cache: %d entries, %d in flight"):format(vim.tbl_count(state.cache), vim.tbl_count(state.inflight))
  for _, e in pairs(state.by_sig) do
    lines[#lines + 1] = "  " .. (e.line or e.lean or (e.index and ("overload " .. e.index)) or e.error or "no pick")
  end
  for _, l in ipairs(state.log) do
    lines[#lines + 1] = l
  end
  return lines
end

--- Test seam.
function M._state()
  return state
end

return M
