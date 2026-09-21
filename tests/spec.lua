-- Test suite. Plain asserts, one process, fake transport, no network.
local root = vim.g.jury_test_root
assert(vim.g.jury_test_pretty, "effect-error-pretty.nvim checkout not found next to jury.nvim")

local failures, passed = {}, 0
local function it(name, fn)
  local ok, err = xpcall(fn, debug.traceback)
  if ok then
    passed = passed + 1
    io.stdout:write("✔ " .. name .. "\n")
  else
    failures[#failures + 1] = name .. "\n" .. tostring(err)
    io.stdout:write("✖ " .. name .. "\n")
  end
end
local function eq(a, b, msg)
  if not vim.deep_equal(a, b) then
    error((msg or "not equal") .. "\n  actual:   " .. vim.inspect(a) .. "\n  expected: " .. vim.inspect(b), 2)
  end
end
local function truthy(v, msg)
  if not v then
    error(msg or "expected truthy", 2)
  end
end
local function has(s, needle)
  if not s or not s:find(needle, 1, true) then
    error(("expected %q in %q"):format(needle, tostring(s)), 2)
  end
end
local function lacks(s, needle)
  if s and s:find(needle, 1, true) then
    error(("did not expect %q in %q"):format(needle, s), 2)
  end
end
local function write(path, s)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local f = assert(io.open(path, "w"))
  f:write(s)
  f:close()
end

-- A throwaway workspace with layers and error classes for the candidate scan.
local ws = vim.fn.fnamemodify(vim.fn.tempname(), ":p"):gsub("/$", "")
write(ws .. "/layers.ts", table.concat({
  'import { Layer } from "effect"',
  "export const LoggerLive = Layer.succeed(Logger, {})",
  "export const AppLive = Layer.mergeAll(GreeterLive, DatabaseTest).pipe(Layer.provide(LoggerLive))",
}, "\n") .. "\n")
write(ws .. "/other/layers.ts", 'export const AppLive = Layer.succeed(Other, {})\n')
write(ws .. "/errors.ts", table.concat({
  'class NotFound extends Data.TaggedError("NotFound")<{ id: number }> {}',
  'export class UserServiceError extends Data.TaggedError("UserServiceError")<{ cause: unknown }> {}',
}, "\n") .. "\n")
write(ws .. "/app.ts", table.concat({
  "const program = Effect.gen(function* () { return 1 })",
  "export const main = Effect.runPromise(program)",
  "export const getUserName = (id: number): Effect.Effect<string, never, Database> =>",
  "  Effect.gen(function* () { const db = yield* Database; return yield* db.find(id) })",
  "export const handler = (id: number): Effect.Effect<string, never, Database> =>",
  "  Effect.gen(function* () { const db = yield* Database; return `user: ${yield* db.find(id)}` })",
  "Effect.runFork(Effect.forkScoped(job))",
  "export const GreeterLive: Layer.Layer<Greeter, never, never> = Layer.effect(Greeter, make)",
  "const registry: Record<string, unknown> = {}",
  "const fromRegistry = (k: string) => registry[k] as Effect.Effect<string, never, unknown>",
  "export const runRegistered = Effect.runPromise(Effect.gen(function* () { return yield* fromRegistry(\"home\") }))",
}, "\n") .. "\n")
vim.cmd.cd(ws)

local pretty = require("effect-error-pretty")
pretty.setup({ effect = true })
local jury = require("jury")
local Client = require("jury.client")
local Prefetch = require("jury.prefetch")

local requests = {}
local plan = {}
Client.set_transport(function(body, cb)
  requests[#requests + 1] = body
  local answers = {}
  for id, q in pairs(body.questions) do
    local p = plan[id:match("_(%w+)$")] or {}
    local choice = p.choice
    if type(choice) == "function" then
      choice = choice(q.criteria)
    end
    if not choice or q.criteria[choice] == nil then
      choice = next(q.criteria)
    end
    answers[id] = { type = "choice", choice = choice, confidence = p.confidence or 0.9, probabilities = {} }
  end
  vim.schedule(function()
    cb({ answers = answers, model = "fake" })
  end)
end)

jury.setup({ notify = false, debounce_ms = 20 })

vim.cmd.edit(ws .. "/app.ts")
local buf = vim.api.nvim_get_current_buf()
vim.bo[buf].filetype = "typescript"
local ns = vim.api.nvim_create_namespace("jury-spec")

local SUFFIX = " with 'exactOptionalPropertyTypes: true'. Consider adding 'undefined' to the types of the target's properties."
local NO_OVERLOAD = table.concat({
  "No overload matches this call.",
  "  Overload 1 of 2, '(options?: { readonly teardown?: Teardown | undefined; } | undefined): <E, A>(effect: Effect<A, E, never>) => void', gave the following error.",
  "    Type 'Effect<Fiber<never, never>, never, Scope>' has no properties in common with type '{ readonly teardown?: Teardown | undefined; }'.",
  "  Overload 2 of 2, '(effect: Effect<Fiber<never, never>, never, never>, options?: undefined): void', gave the following error.",
  "    Argument of type 'Effect<Fiber<never, never>, never, Scope>' is not assignable to parameter of type 'Effect<Fiber<never, never>, never, never>'.",
  "      Type 'Scope' is not assignable to type 'never'.",
}, "\n")
local diags = {
  { lnum = 1, col = 38, severity = 1, source = "typescript", code = 2379, message = "Argument of type 'Effect<string, NotFound, Greeter | Database>' is not assignable to parameter of type 'Effect<string, NotFound, never>'" .. SUFFIX },
  { lnum = 1, col = 38, severity = 1, source = "effect", code = 1, message = "This Effect requires a service that is missing from the expected Effect context: `Greeter | Database`." },
  { lnum = 3, col = 2, severity = 1, source = "typescript", code = 2375, message = "Type 'Effect<string, NotFound, Database>' is not assignable to type 'Effect<string, never, Database>'" .. SUFFIX },
  { lnum = 5, col = 2, severity = 1, source = "effect", code = 1, message = "Missing 'NotFound' in the expected Effect errors." },
  { lnum = 6, col = 0, severity = 1, source = "typescript", code = 2769, message = NO_OVERLOAD },
  { lnum = 7, col = 13, severity = 1, source = "effect", code = 1, message = "Missing 'Logger' in the expected Layer context." },
  { lnum = 10, col = 47, severity = 1, source = "typescript", code = 2379, message = "Argument of type 'Effect<string, never, unknown>' is not assignable to parameter of type 'Effect<string, never, never>'" .. SUFFIX },
}

local function box(i)
  return pretty.float_format(vim.diagnostic.get(buf)[i])
end

it("candidate scan finds layers and errors with unique sorted keys", function()
  local Candidates = require("jury.candidates")
  local got
  Candidates.scan({ id = "layers", re = [[const (\w+)\s*=\s*Layer\.]], name = "const (%w+)" }, ws, function(list)
    got = list
  end)
  vim.wait(3000, function()
    return got ~= nil
  end, 20)
  local keys = {}
  for _, l in ipairs(got) do
    keys[#keys + 1] = l.key
  end
  eq(keys, { "LoggerLive@layers.ts", "AppLive@layers.ts", "AppLive@other/layers.ts" })
  eq(Candidates.name("AppLive@layers.ts"), "AppLive")
end)

it("before any judgment the boxes render the generic hints", function()
  vim.diagnostic.set(ns, buf, diags)
  has(box(1), "⚡ Hint: .pipe(Effect.provide(SomeLayer))")
  has(box(3), "⚡ Hint: .pipe(Effect.catchTags({...})) or Effect.orDie")
  has(box(7), "R Not Inferred")
  has(box(7), "⚡ Hint: annotate the effect to find where R widened")
end)

it("one batch judges every family, dedupes the duplicate line, and steers the overload parse", function()
  plan = {
    layer = { choice = "AppLive@layers.ts", confidence = 0.97 },
    where = { choice = "here", confidence = 0.8 },
    fix = { choice = "declare", confidence = 0.92 },
    domain = { choice = "UserServiceError@errors.ts", confidence = 0.95 },
    overload = { choice = "2", confidence = 0.9 },
    widened = { choice = "fromRegistry@app.ts", confidence = 0.81 },
  }
  requests = {}
  jury.judge(buf)
  vim.wait(5000, function()
    local b = box(1)
    return b and b:find("⚡ Jev:", 1, true) ~= nil and box(5):find("Type Mismatch", 1, true) ~= nil
  end, 20)
  eq(#requests, 1, "one request for the whole buffer")
  -- 6 hint diagnostics collapse to 5 signatures (line 1 twice), plus the overload.
  eq(#requests[1].state.items, 6)
  local qcount = vim.tbl_count(requests[1].questions)
  eq(qcount, 2 + 2 + 2 + 1 + 1 + 1, "layer+where, fix+domain, fix+domain, overload, layer only, widened")
  local wide = requests[1].state.items[6]
  eq(wide.family, "widened")
  eq(wide.channel, "R")
  truthy(vim.tbl_contains(wide.suspects, "fromRegistry"), "the helper is a suspect")
  truthy(not vim.tbl_contains(wide.suspects, "Effect"), "the Effect namespace is not a suspect")
  local wq = requests[1].questions["d6_widened"]
  truthy(wq and wq.criteria["fromRegistry@app.ts"], "options are the suspects' workspace definitions")
  truthy(wq and wq.criteria["runRegistered@app.ts"])
  truthy(wq and not wq.criteria["registry@app.ts"], "definitions the context never mentions are not offered")
  truthy(wq and not wq.criteria["main@app.ts"])
  has(box(7), "⚡ Jev: annotate fromRegistry (app.ts:10), where R widened")
  has(box(7), "↳ const fromRegistry = (k: string) => registry[k] as Effect.Effect<string,", "the definition's own line is the reason")
  has(box(7), "… · 0.81")
  lacks(box(7), "annotate the effect to find where")
  has(box(6), "Missing RIn")
  has(box(6), "⚡ Jev: Layer.provide(AppLive) inside this layer", "a Layer's RIn gets the layer template, no where question")
  has(box(6), "↳ a Layer's RIn is satisfied inside it · 0.97")
  lacks(box(6), "Layer.merge")
  local first = requests[1].state.items[1]
  eq(first.file, "app.ts", "relative file path travels with the item")
  eq(first.exported, true, "`export const main` is exported")
  eq(first.holder, "effect")
  has(box(1), "⚡ Jev: .pipe(Effect.provide(AppLive))")
  has(box(1), "↳ this expression is the program boundary · 0.97", "the detail line is the chosen option's own reason")
  has(box(2), "⚡ Jev: .pipe(Effect.provide(AppLive))", "duplicate diagnostic shares the answer")
  has(box(3), "⚡ Jev: declare NotFound in this function's E channel; let the caller handle it")
  has(box(3), "↳ an inner step; its caller is better placed to decide · 0.92")
  has(box(4), "⚡ Jev: declare NotFound")
  has(box(5), "Type Mismatch", "overload picker steered the parse to report 2")
  lacks(box(1), "SomeLayer")
end)

it("two judges during one workspace scan send one request", function()
  jury.clear()
  requests = {}
  jury.judge(buf) -- starts the async candidate scan
  jury.judge(buf) -- fires while that scan is still running
  vim.wait(5000, function()
    return #requests >= 1 and vim.tbl_count(Prefetch._state().inflight) == 0
  end, 20)
  vim.wait(200)
  eq(#requests, 1, "the second judge must see the first batch in flight")
end)

it("a re-judge sends nothing when everything is cached", function()
  requests = {}
  jury.judge(buf)
  vim.wait(200)
  eq(#requests, 0)
end)

it("below the bar the generic hint stays and a lean is shown", function()
  jury.clear()
  plan.fix = { choice = "catch_tag", confidence = 0.31 }
  plan.domain = { choice = "UserServiceError@errors.ts", confidence = 0.9 }
  jury.judge(buf)
  vim.wait(5000, function()
    local b = box(3)
    return b and b:find("↳ jev unsure", 1, true) ~= nil
  end, 20)
  has(box(3), "⚡ Hint: .pipe(Effect.catchTags({...})) or Effect.orDie")
  has(box(3), "↳ jev unsure: fix catch_tag 0.31 · mapError target UserServiceError 0.90")
end)

it("a none answer on the layer becomes a lean, not a hint", function()
  jury.clear()
  plan.layer = { choice = "none", confidence = 0.5 }
  jury.judge(buf)
  vim.wait(5000, function()
    local b = box(1)
    return b and b:find("↳ jev unsure", 1, true) ~= nil
  end, 20)
  has(box(1), "⚡ Hint: .pipe(Effect.provide(SomeLayer))")
  has(box(1), "↳ jev unsure: layer none 0.50")
end)

it("the DiagnosticChanged loop judges on its own after a debounce", function()
  jury.clear()
  plan.layer = { choice = "AppLive@layers.ts", confidence = 0.99 }
  requests = {}
  vim.diagnostic.set(ns, buf, diags) -- fires DiagnosticChanged
  vim.wait(5000, function()
    return #requests >= 1
  end, 20)
  eq(#requests, 1)
end)

it("docs/scope.md names every parsed kind effect-error-pretty knows", function()
  local parse_src = table.concat(vim.fn.readfile(vim.g.jury_test_pretty .. "/lua/effect-error-pretty/parse.lua"), "\n")
  local scope = table.concat(vim.fn.readfile(root .. "/docs/scope.md"), "\n")
  local missing = {}
  for kind in parse_src:gmatch('kind = "([%w_]+)"') do
    if not scope:find("`" .. kind .. "`", 1, true) then
      missing[#missing + 1] = kind
    end
  end
  eq(missing, {}, "kinds without a scope decision")
end)

it("status reports the source and the last batch", function()
  local saved = vim.notify
  vim.notify = function() end
  local lines = table.concat(jury.status(), "\n")
  vim.notify = saved
  has(lines, "effect-error-pretty: registered")
  has(lines, "last batch")
end)

it("without a key and without a transport, judging is a no-op", function()
  Client.set_transport(nil)
  require("jury.config").options.key_file = "/nonexistent/jury-key"
  require("jury.config").options.api_key = nil
  local saved_env = vim.env.TYPESAFE_API_KEY
  vim.env.TYPESAFE_API_KEY = nil
  jury.clear()
  requests = {}
  jury.judge(buf)
  vim.wait(200)
  eq(vim.tbl_count(Prefetch._state().inflight), 0)
  has(box(1), "SomeLayer")
  vim.env.TYPESAFE_API_KEY = saved_env
end)

io.stdout:write(("\n%d passed, %d failed\n"):format(passed, #failures))
for _, f in ipairs(failures) do
  io.stdout:write("\n" .. f .. "\n")
end
os.exit(#failures == 0 and 0 or 1)
