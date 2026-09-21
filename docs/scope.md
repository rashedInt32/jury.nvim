# Scope: what jury judges, and what it leaves alone

jury asks Jev only when the answer is **not in the diagnostic** and the
candidates can be **enumerated by code**. Everything else stays exactly as
effect-error-pretty renders it. This file is the contract; `tests/spec.lua`
fails when effect-error-pretty gains a parsed kind that is not listed here.

## Judged

| kind | branch | question(s) | why a judge helps |
|---|---|---|---|
| `effect_mismatch` | R differs, real service names | which layer · where to provide | layers live in other files; the message names the service, not the layer |
| `effect_mismatch` | RIn differs on a `Layer` | which layer | one placement (`Layer.provide` inside), so no where-question |
| `effect_mismatch` | E differs, real error tags | which fix · which domain error | the right fix depends on where the code sits, not on the types |
| `effect_mismatch` | R or E is only `unknown`/`any` | which upstream definition widened | the message points nowhere; the enclosing code lists the suspects |
| `missing_context` | `effect` tag | which layer · where | language-service form of the first row |
| `missing_context` | `layer` tag | which layer | language-service form of the RIn row |
| `missing_errors` | real error tags | which fix · which domain error | language-service form of the E row |
| `missing_errors` | only `unknown` | which upstream definition widened | language-service form of the widened row |
| TS2769 overloads | two or more candidate reports | which report to explain | the parser must pick one; the wrong one hides the real diff |

## Not judged, on purpose

| kind | branch | reason |
|---|---|---|
| `effect_mismatch` | Scope-only | the fix is always `Effect.scoped`; nothing to choose |
| `effect_mismatch` | identical signatures | always two copies of a package; deterministic |
| `effect_mismatch` | only A differs | ordinary type work; no enumerable fix |
| `effect_mismatch` | more than one channel differs | the box shows the full tri-channel diff; a pick would hide half of it |
| `type_mismatch` | | plain TypeScript; the message already names both types |
| `missing_property` | | plain TypeScript; the message names the property |
| `unknown_property` | | TypeScript already ranks "did you mean" suggestions |
| `undefined` | | same as above |
| `module_not_found` | | check path or install types; deterministic |
| `export_not_found` | | TypeScript already ranks suggestions |
| `implicit_any` | | annotate the parameter; nothing to choose |
| `used_before_assigned` | | control flow, not a pick |
| `nullish` | | optional chaining or a null check; nothing to choose |
| `arg_count` | | the message states both counts |
| `const_assign` | | rename or use `let`; nothing to choose |
| `deprecated` | | the message names the replacement when one exists |
| `not_callable` | | plain TypeScript |

Rule of thumb for a new kind: if a careful reader could act on the box
without opening another file, it belongs in the second table.

## What a judged box shows

- **Concrete hint** (confidence at or above `min_confidence`): the pick,
  rendered through effect-error-pretty's own template, labelled with
  `label` (default `Jev`). The detail line under it is the chosen option's
  own "right when" clause plus the confidence.
- **Lean** (below the bar, or `none` picked): the generic hint stays and the
  lean is printed under it with the raw numbers.
- **Nothing**: no candidates in the workspace, no key, or a failed request.
  The box is identical to one rendered without jury installed.
