-- Latency of every path jury adds to the editor, measured on the eval fixture.
--
--   nvim --headless -u tests/minimal_init.lua -c "luafile evals/perf.lua"
--   JURY_PERF_CWD=/path/to/big/workspace   (default: this repo's parent dir)
--
-- No network: the transport is a stub that answers instantly, so the numbers
-- are jury's own cost. API latency is reported by evals/run.lua.
local root = vim.g.jury_test_root
assert(vim.g.jury_test_pretty, "effect-error-pretty.nvim checkout not found next to jury.nvim")
local evals = root .. "/evals"
local corpus = dofile(evals .. "/cases.lua")
local uv = vim.uv or vim.loop

local pretty = require("effect-error-pretty")
pretty.setup({ effect = true })
local jury = require("jury")
local Client = require("jury.client")
local Prefetch = require("jury.prefetch")
local Candidates = require("jury.candidates")
local Source = require("jury.sources.effect_error_pretty")
jury.setup({ notify = false, debounce_ms = 10 })

Client.set_transport(function(body, cb)
  local answers = {}
  for id, q in pairs(body.questions) do
    local first = next(q.criteria)
    answers[id] = { type = "choice", choice = first, confidence = 0.9 }
  end
  vim.schedule(function()
    cb({ answers = answers, model = "stub" })
  end)
end)

vim.cmd.cd(evals)
vim.cmd.edit(evals .. "/" .. corpus.file)
local buf = vim.api.nvim_get_current_buf()
vim.bo[buf].filetype = "typescript"
local ns = vim.api.nvim_create_namespace("jury-perf")
local diags = {}
for _, c in ipairs(corpus.cases) do
  for _, d in ipairs(c.diagnostics) do
    diags[#diags + 1] = { lnum = c.lnum, col = d.col, severity = 1, source = d.source, code = d.code, message = d.message }
  end
end
vim.diagnostic.set(ns, buf, diags)
local all = vim.diagnostic.get(buf)

local function bench(n, fn)
  local t0 = uv.hrtime()
  for _ = 1, n do
    fn()
  end
  return (uv.hrtime() - t0) / 1e6 / n
end

local lines = {}
local function report(label, value)
  lines[#lines + 1] = ("%-58s %8.3f ms"):format(label, value)
end

-- 1. Hover path before any judgment: format = parse + context + cache miss.
report(("float_format, cache miss, per box (%d boxes)"):format(#all), bench(20, function()
  for _, d in ipairs(all) do
    pretty.float_format(d)
  end
end) / #all)

-- 2. Collect: what DiagnosticChanged costs before any request is sent.
report("collect(bufnr): parse + treesitter context for every diagnostic", bench(20, function()
  Source.collect(buf)
end))

-- 3. Workspace scans, cold (cache cleared each time).
local function scan_ms(spec, cwd)
  Candidates.clear()
  local done = false
  local t0 = uv.hrtime()
  Candidates.scan(spec, cwd, function()
    done = true
  end)
  vim.wait(10000, function()
    return done
  end, 1)
  return (uv.hrtime() - t0) / 1e6
end
local LAYERS = { id = "layers", re = [[const (\w+)(?:\s*:\s*Layer<[^=]*)?\s*=\s*(?:Layer\.|\w+\.pipe\(\s*Layer\.|Layer\.\w+\()]], name = "const (%w+)" }
local ERRORS = { id = "errors", re = [[class (\w+) extends (?:Data|Schema)\.TaggedError]], name = "class (%w+)" }
local DEFS = { id = "defs", re = [[\b(?:const|let|var|function|class)\s+(fromRegistry|steps|loadUser|runSteps|registry)\b]], name = "const (%w+)" }
for _, cwd in ipairs({ evals, vim.env.JURY_PERF_CWD or vim.fn.fnamemodify(root, ":h") }) do
  local files = tonumber(vim.fn.system({ "sh", "-c", "rg --files -g '*.ts' -g '*.tsx' -g '!node_modules' -g '!dist' " .. vim.fn.shellescape(cwd) .. " | wc -l" })) or -1
  local tag = ("[%s, %d ts files]"):format(vim.fn.fnamemodify(cwd, ":t"), files)
  report("rg layers, cold " .. tag, scan_ms(LAYERS, cwd))
  report("rg errors, cold " .. tag, scan_ms(ERRORS, cwd))
  report("rg definitions (widened), cold " .. tag, scan_ms(DEFS, cwd))
end

-- 4. Whole judge round trip with an instant transport: collect + scans +
--    questions + finish. What the user pays after the debounce, minus the API.
jury.clear()
local t0 = uv.hrtime()
jury.judge(buf)
vim.wait(10000, function()
  return vim.tbl_count(Prefetch._state().inflight) == 0 and vim.tbl_count(Prefetch._state().cache) > 0
end, 1)
report("judge_buffer round trip, stub API, cold scans", (uv.hrtime() - t0) / 1e6)

-- 5. Hover path after judgment: the synchronous resolver on a warm cache.
report(("float_format, cache hit, per box (%d boxes)"):format(#all), bench(50, function()
  for _, d in ipairs(all) do
    pretty.float_format(d)
  end
end) / #all)

-- 6. Re-judge with everything cached: what every later DiagnosticChanged costs.
report("judge_buffer, everything cached", bench(20, function()
  jury.judge(buf)
end))

io.stdout:write(("perf — %s — %s\n"):format(os.date("%Y-%m-%d %H:%M"), uv.os_uname().sysname))
io.stdout:write(table.concat(lines, "\n") .. "\n")
os.exit(0)
