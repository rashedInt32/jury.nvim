# Performance

Output of `evals/perf.lua`. Stub API, so these are jury's own costs.

```
perf — 2026-09-21 10:36 — Darwin
float_format, cache miss, per box (13 boxes)                  0.372 ms
collect(bufnr): parse + treesitter context for every diagnostic    0.550 ms
rg layers, cold [evals, 1 ts files]                           8.477 ms
rg errors, cold [evals, 1 ts files]                           8.980 ms
rg definitions (widened), cold [evals, 1 ts files]            7.960 ms
rg layers, cold [packages, 1741 ts files]                    93.844 ms
rg errors, cold [packages, 1741 ts files]                    20.128 ms
rg definitions (widened), cold [packages, 1741 ts files]     19.878 ms
judge_buffer round trip, stub API, cold scans                25.770 ms
float_format, cache hit, per box (13 boxes)                   0.041 ms
judge_buffer, everything cached                               0.458 ms
```

API latency per batch is in RESULTS.md (about one second for twelve questions).
