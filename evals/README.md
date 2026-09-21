# evals

Real diagnostics, real API, real numbers. Not part of `tests/`: this talks
to TypeSafe and needs the same setup jury itself uses (see the main README).

```sh
nvim --headless -u tests/minimal_init.lua -c "luafile evals/run.lua"
JEV_MODELS=jev-preview nvim --headless -u tests/minimal_init.lua -c "luafile evals/run.lua"
```

- `cases/playground.ts` is a copy of the tutorial playground with three
  widened cases and one Layer case appended. Every error in it is deliberate.
- `cases.lua` holds the tsc / language-service output for that file and the
  accepted pick per question. `lnum` and `col` are 0-based.
- `run.lua` opens the fixture, sets the diagnostics, judges once per model,
  prints a report and appends it to `RESULTS.md`.

Re-capture after editing the fixture: copy it into a project that has
`effect` and `@effect/language-service` installed, run
`tsc --noEmit --pretty false`, and paste the lines for that file into
`cases.lua`. Strip the trailing `effect(...)` tag and set `source = "effect"`
on those lines.

The report is information, not a gate. A gate comes after the numbers have
settled over a few runs.
