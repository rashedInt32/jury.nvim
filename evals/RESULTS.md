# Eval results

Appended by `evals/run.lua`. Newest at the bottom.

## jev-latest — 2026-09-21 10:35

requests 1 · failed 0 · questions 12 · api 1075 ms · wall 1103 ms
accuracy 6/8 · mean confidence 0.80 · shown as concrete hint 6/8

| line | family | expected | got | ok | shown |
|---|---|---|---|---|---|
| 74 | services | layer∈{AppLive} where∈{here} | layer=AppLive 0.98, where=here 0.96 | ✔ | hint |
| 83 | errors | domain∈{UserServiceError} fix∈{declare,map_error} | domain=none 0.18, fix=declare 0.90 | ✔ | hint |
| 92 | errors | fix∈{catch_tag} | fix=declare 0.82 | ✖ | hint |
| 109 | errors | fix∈{or_die,catch_tag} | fix=declare 0.34 | ✖ | lean |
| 114 | layer | layer∈{LoggerLive} | layer=LoggerLive 0.97 | ✔ | hint |
| 129 | widened | widened∈{fromRegistry} | widened=fromRegistry 0.58 | ✔ | lean |
| 140 | widened | widened∈{loadUser} | widened=loadUser 0.91 | ✔ | hint |
| 146 | widened | widened∈{steps} | widened=steps 0.87 | ✔ | hint |

| family | accuracy | mean confidence |
|---|---|---|
| errors | 1/3 | 0.69 |
| layer | 1/1 | 0.97 |
| services | 1/1 | 0.97 |
| widened | 3/3 | 0.79 |

Rendered:
- L74 ⚡ Jev: .pipe(Effect.provide(AppLive))
- L83 ⚡ Jev: declare NotFound in this function's E channel; let the caller handle it
- L92 ⚡ Jev: declare NotFound in this function's E channel; let the caller handle it
- L109 ↳ jev unsure: fix declare 0.34 · mapError target none 0.45
- L114 ⚡ Jev: Layer.provide(LoggerLive) inside this layer
- L129 ↳ jev unsure: widened fromRegistry 0.58
- L140 ⚡ Jev: annotate loadUser (cases/playground.ts:138), where E widened
- L146 ⚡ Jev: annotate steps (cases/playground.ts:145), where R widened

## jev-preview — 2026-09-21 10:35

requests 1 · failed 0 · questions 12 · api 1001 ms · wall 1043 ms
accuracy 6/8 · mean confidence 0.80 · shown as concrete hint 6/8

| line | family | expected | got | ok | shown |
|---|---|---|---|---|---|
| 74 | services | layer∈{AppLive} where∈{here} | layer=AppLive 0.98, where=here 0.95 | ✔ | hint |
| 83 | errors | domain∈{UserServiceError} fix∈{declare,map_error} | domain=NotFound 0.25, fix=declare 0.91 | ✔ | hint |
| 92 | errors | fix∈{catch_tag} | fix=declare 0.84 | ✖ | hint |
| 109 | errors | fix∈{or_die,catch_tag} | fix=declare 0.38 | ✖ | lean |
| 114 | layer | layer∈{LoggerLive} | layer=LoggerLive 0.97 | ✔ | hint |
| 129 | widened | widened∈{fromRegistry} | widened=fromRegistry 0.55 | ✔ | lean |
| 140 | widened | widened∈{loadUser} | widened=loadUser 0.94 | ✔ | hint |
| 146 | widened | widened∈{steps} | widened=steps 0.86 | ✔ | hint |

| family | accuracy | mean confidence |
|---|---|---|
| errors | 1/3 | 0.71 |
| layer | 1/1 | 0.97 |
| services | 1/1 | 0.96 |
| widened | 3/3 | 0.78 |

Rendered:
- L74 ⚡ Jev: .pipe(Effect.provide(AppLive))
- L83 ⚡ Jev: declare NotFound in this function's E channel; let the caller handle it
- L92 ⚡ Jev: declare NotFound in this function's E channel; let the caller handle it
- L109 ↳ jev unsure: fix declare 0.38 · mapError target none 0.49
- L114 ⚡ Jev: Layer.provide(LoggerLive) inside this layer
- L129 ↳ jev unsure: widened fromRegistry 0.55
- L140 ⚡ Jev: annotate loadUser (cases/playground.ts:138), where E widened
- L146 ⚡ Jev: annotate steps (cases/playground.ts:145), where R widened

