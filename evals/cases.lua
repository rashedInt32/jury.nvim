-- Eval corpus: real tsc / @effect/language-service output for cases/playground.ts.
-- Captured with `tsc --noEmit --pretty false` on 2026-09-21 (effect 4.0.0-beta, TS 5).
-- `lnum` and `col` are 0-based, as vim.diagnostic wants them. `expect` maps a
-- question suffix to the accepted picks; `domain` is only checked when the
-- fix picked is map_error. Re-capture: see evals/README.md.
return {
  file = "cases/playground.ts",
  cases = {
    {
      lnum = 73,
      family = "services",
      title = "missing services at the boundary",
      expect = { layer = { "AppLive" }, where = { "here" } },
      diagnostics = {
        { col = 38, code = 2379, source = "typescript", message = "Argument of type 'Effect<string, NotFound, Greeter | Database>' is not assignable to parameter of type 'Effect<string, NotFound, never>' with 'exactOptionalPropertyTypes: true'. Consider adding 'undefined' to the types of the target's properties." },
      },
    },
    {
      lnum = 82,
      family = "errors",
      title = "unhandled error inside a service method",
      expect = { fix = { "declare", "map_error" }, domain = { "UserServiceError" } },
      diagnostics = {
        { col = 2, code = 1, source = "effect", message = "Missing 'NotFound' in the expected Effect errors." },
        { col = 2, code = 2375, source = "typescript", message = "Type 'Effect<string, NotFound, Database>' is not assignable to type 'Effect<string, never, Database>' with 'exactOptionalPropertyTypes: true'. Consider adding 'undefined' to the types of the target's properties." },
      },
    },
    {
      lnum = 91,
      family = "errors",
      title = "unhandled error in a request handler with an obvious fallback",
      expect = { fix = { "catch_tag" } },
      diagnostics = {
        { col = 2, code = 1, source = "effect", message = "Missing 'NotFound' in the expected Effect errors." },
        { col = 2, code = 2375, source = "typescript", message = "Type 'Effect<string, NotFound, Database>' is not assignable to type 'Effect<string, never, Database>' with 'exactOptionalPropertyTypes: true'. Consider adding 'undefined' to the types of the target's properties." },
      },
    },
    {
      lnum = 108,
      family = "errors",
      title = "two errors at a script boundary",
      expect = { fix = { "or_die", "catch_tag" } },
      diagnostics = {
        { col = 13, code = 2375, source = "typescript", message = "Type 'Effect<string, NotFound | Timeout, Database>' is not assignable to type 'Effect<string, never, Database>' with 'exactOptionalPropertyTypes: true'. Consider adding 'undefined' to the types of the target's properties." },
        { col = 13, code = 1, source = "effect", message = "Missing 'NotFound | Timeout' in the expected Effect errors." },
      },
    },
    {
      lnum = 113,
      family = "layer",
      title = "a Layer whose RIn was never provided",
      expect = { layer = { "LoggerLive" } },
      diagnostics = {
        { col = 13, code = 2375, source = "typescript", message = "Type 'Layer<Greeter, never, Logger>' is not assignable to type 'Layer<Greeter, never, never>' with 'exactOptionalPropertyTypes: true'. Consider adding 'undefined' to the types of the target's properties." },
        { col = 13, code = 38, source = "effect", message = "Missing 'Logger' in the expected Layer context." },
      },
    },
    {
      lnum = 128,
      family = "widened",
      title = "R widened by a helper that cast its R away",
      expect = { widened = { "fromRegistry" } },
      diagnostics = {
        { col = 2, code = 2379, source = "typescript", message = "Argument of type 'Effect<string, never, unknown>' is not assignable to parameter of type 'Effect<string, never, never>' with 'exactOptionalPropertyTypes: true'. Consider adding 'undefined' to the types of the target's properties." },
      },
    },
    {
      lnum = 139,
      family = "widened",
      title = "E widened by an explicit unknown annotation upstream",
      expect = { widened = { "loadUser" } },
      diagnostics = {
        { col = 13, code = 2375, source = "typescript", message = "Type 'Effect<string, unknown, never>' is not assignable to type 'Effect<string, never, never>' with 'exactOptionalPropertyTypes: true'. Consider adding 'undefined' to the types of the target's properties." },
        { col = 13, code = 1, source = "effect", message = "Missing 'unknown' in the expected Effect errors." },
      },
    },
    {
      lnum = 145,
      family = "widened",
      title = "R widened by one member of a list",
      expect = { widened = { "steps" } },
      diagnostics = {
        { col = 42, code = 2379, source = "typescript", message = "Argument of type 'Effect<void[], never, unknown>' is not assignable to parameter of type 'Effect<void[], never, never>' with 'exactOptionalPropertyTypes: true'. Consider adding 'undefined' to the types of the target's properties." },
      },
    },
  },
}
