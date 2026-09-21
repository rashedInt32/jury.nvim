-- Eval runner: judge evals/cases/playground.ts against the live API, once per
-- model, and report accuracy, confidence and latency per family.
--
--   nvim --headless -u tests/minimal_init.lua -c "luafile evals/run.lua"
--   JEV_MODELS=jev-latest,jev-preview   (default: both)
local root = vim.g.jury_test_root
assert(vim.g.jury_test_pretty, "effect-error-pretty.nvim checkout not found next to jury.nvim")
local evals = root .. "/evals"
local corpus = dofile(evals .. "/cases.lua")
vim.cmd.cd(evals)

local pretty = require("effect-error-pretty")
pretty.setup({ effect = true })
local jury = require("jury")
local Client = require("jury.client")
local Prefetch = require("jury.prefetch")
local Config = require("jury.config")
local Candidates = require("jury.candidates")
jury.setup({ notify = false, debounce_ms = 10 })

if not Client.available() then
  io.stderr:write("evals: TypeSafe is not configured; see evals/README.md\n")
  os.exit(2)
end

local models = vim.split(vim.env.JEV_MODELS or "jev-latest,jev-preview", ",", { trimempty = true })
local uv = vim.uv or vim.loop
local function ms(t0)
  return math.floor((uv.hrtime() - t0) / 1e6)
end

-- ── fixture ───────────────────────────────────────────────────────────────

vim.cmd.edit(evals .. "/" .. corpus.file)
local buf = vim.api.nvim_get_current_buf()
vim.bo[buf].filetype = "typescript"
local ns = vim.api.nvim_create_namespace("jury-evals")
local diags = {}
for _, c in ipairs(corpus.cases) do
  for _, d in ipairs(c.diagnostics) do
    diags[#diags + 1] = { lnum = c.lnum, col = d.col, severity = 1, source = d.source, code = d.code, message = d.message }
  end
end
vim.diagnostic.set(ns, buf, diags)

-- ── intercept the request to keep the wire bodies ─────────────────────────

local log = {}
local orig_request = Client.request
Client.request = function(state, questions, cb)
  local t0 = uv.hrtime()
  return orig_request(state, questions, function(decoded)
    log[#log + 1] = { state = state, questions = questions, decoded = decoded, ms = ms(t0) }
    cb(decoded)
  end)
end

-- Two sites can carry the same message (lines 83 and 92 do), so an item is
-- matched by its enclosing context, which is what the judge actually saw.
local Context = require("jury.context")
local context_of = {}
for _, c in ipairs(corpus.cases) do
  context_of[c.lnum] = Context.describe(buf, c.lnum).text
end
local function case_for(item)
  for _, c in ipairs(corpus.cases) do
    if context_of[c.lnum] == item.context then
      return c
    end
  end
  return nil
end

local function jev_line(lnum)
  for _, d in ipairs(vim.diagnostic.get(buf)) do
    if d.lnum == lnum then
      local box = pretty.float_format(d) or ""
      for line in box:gmatch("[^\n]+") do
        if line:find("⚡ " .. Config.options.label .. ":", 1, true) or line:find("↳", 1, true) then
          return (line:gsub("^│%s*", ""))
        end
      end
    end
  end
  return "(generic)"
end

-- ── one model ─────────────────────────────────────────────────────────────

local function run(model)
  Config.options.model = model
  jury.clear()
  log = {}
  local t0 = uv.hrtime()
  jury.judge(buf)
  vim.wait(120000, function()
    return #log >= 1 and vim.tbl_count(Prefetch._state().inflight) == 0
  end, 50)
  local wall = ms(t0)

  local got = {} -- lnum -> suffix -> { choice, confidence }
  local questions, failed = 0, 0
  for _, req in ipairs(log) do
    questions = questions + vim.tbl_count(req.questions)
    if not req.decoded then
      failed = failed + 1
    else
      for qid, a in pairs(req.decoded.answers or {}) do
        local idx, suffix = qid:match("^d(%d+)_(%w+)$")
        local item = idx and req.state.items[tonumber(idx)]
        local c = item and case_for(item)
        if c then
          got[c.lnum] = got[c.lnum] or {}
          got[c.lnum][suffix] = { choice = Candidates.name(a.choice) or tostring(a.choice), confidence = a.confidence or 0 }
        end
      end
    end
  end

  local rows, per = {}, {}
  local min = Config.options.min_confidence
  for _, c in ipairs(corpus.cases) do
    local g = got[c.lnum] or {}
    local ok, confs, parts = true, {}, {}
    for suffix, accepted in pairs(c.expect) do
      local a = g[suffix]
      local needed = suffix ~= "domain" or (g.fix and g.fix.choice == "map_error")
      if needed then
        if not a or not vim.tbl_contains(accepted, a.choice) then
          ok = false
        end
        if a then
          confs[#confs + 1] = a.confidence
        end
      end
      if a then
        parts[#parts + 1] = ("%s=%s %.2f"):format(suffix, a.choice, a.confidence)
      end
    end
    table.sort(parts)
    local primary = g[c.family == "widened" and "widened" or (c.family == "errors" and "fix" or "layer")]
    local shown = primary ~= nil and primary.confidence >= min and primary.choice ~= "none"
    local mean = 0
    for _, v in ipairs(confs) do
      mean = mean + v
    end
    mean = #confs > 0 and mean / #confs or 0
    rows[#rows + 1] = { c = c, ok = ok, shown = shown, mean = mean, got = table.concat(parts, ", "), line = jev_line(c.lnum) }
    per[c.family] = per[c.family] or { n = 0, ok = 0, conf = 0 }
    per[c.family].n = per[c.family].n + 1
    per[c.family].ok = per[c.family].ok + (ok and 1 or 0)
    per[c.family].conf = per[c.family].conf + mean
  end

  local out = {}
  local function w(s)
    out[#out + 1] = s
  end
  local total_ok, total_conf, total_shown = 0, 0, 0
  for _, r in ipairs(rows) do
    total_ok = total_ok + (r.ok and 1 or 0)
    total_conf = total_conf + r.mean
    total_shown = total_shown + (r.shown and 1 or 0)
  end
  w(("## %s — %s"):format(model, os.date("%Y-%m-%d %H:%M")))
  w("")
  w(("requests %d · failed %d · questions %d · api %d ms · wall %d ms"):format(#log, failed, questions, log[1] and log[1].ms or 0, wall))
  w(("accuracy %d/%d · mean confidence %.2f · shown as concrete hint %d/%d"):format(total_ok, #rows, #rows > 0 and total_conf / #rows or 0, total_shown, #rows))
  w("")
  w("| line | family | expected | got | ok | shown |")
  w("|---|---|---|---|---|---|")
  for _, r in ipairs(rows) do
    local exp = {}
    for suffix, accepted in pairs(r.c.expect) do
      exp[#exp + 1] = suffix .. "∈{" .. table.concat(accepted, ",") .. "}"
    end
    table.sort(exp)
    w(("| %d | %s | %s | %s | %s | %s |"):format(r.c.lnum + 1, r.c.family, table.concat(exp, " "), r.got, r.ok and "✔" or "✖", r.shown and "hint" or "lean"))
  end
  w("")
  w("| family | accuracy | mean confidence |")
  w("|---|---|---|")
  local fams = vim.tbl_keys(per)
  table.sort(fams)
  for _, f in ipairs(fams) do
    w(("| %s | %d/%d | %.2f |"):format(f, per[f].ok, per[f].n, per[f].conf / per[f].n))
  end
  w("")
  w("Rendered:")
  for _, r in ipairs(rows) do
    w(("- L%d %s"):format(r.c.lnum + 1, r.line))
  end
  w("")
  return table.concat(out, "\n")
end

local report = {}
for _, model in ipairs(models) do
  report[#report + 1] = run(vim.trim(model))
end
local text = table.concat(report, "\n")
io.stdout:write(text .. "\n")
local f = assert(io.open(evals .. "/RESULTS.md", "a"))
f:write(text .. "\n")
f:close()
os.exit(0)
