// PROTOTYPE PLAYGROUND. Delete me. Not part of the tutorial.
//
// Every error below is deliberate. Hover each one with jury.nvim installed.
// The first hover after a save may show the generic hint; the second shows
// Jev's pick. `:Jury status` shows what it decided and why.

import { Context, Data, Effect, Layer } from "effect";

// ── errors (candidates for "which domain error") ──────────────────────────

class NotFound extends Data.TaggedError("NotFound")<{ id: number }> {}
class Timeout extends Data.TaggedError("Timeout")<{ afterMs: number }> {}
export class UserServiceError extends Data.TaggedError("UserServiceError")<{
  cause: unknown;
}> {}

// ── services and layers (candidates for "which layer") ─────────────────────

// Effect v4 idiom, copied from examples/reference/layers.ts.
class Logger extends Context.Service<
  Logger,
  {
    readonly log: (m: string) => Effect.Effect<void>;
  }
>()("proto/Logger") {}

class Greeter extends Context.Service<
  Greeter,
  {
    readonly greet: (n: string) => Effect.Effect<string>;
  }
>()("proto/Greeter") {}

class Database extends Context.Service<
  Database,
  {
    readonly find: (id: number) => Effect.Effect<string, NotFound>;
  }
>()("proto/Database") {}

export const LoggerLive = Layer.succeed(Logger, { log: (m) => Effect.log(m) });

export const GreeterLive = Layer.effect(
  Greeter,
  Effect.gen(function* () {
    const logger = yield* Logger;
    return {
      greet: (n: string) =>
        logger.log(`greeting ${n}`).pipe(Effect.as(`hello ${n}`)),
    };
  }),
);

export const DatabaseTest = Layer.succeed(Database, {
  find: (id) =>
    id === 1 ? Effect.succeed("alice") : Effect.fail(new NotFound({ id })),
});

export const AppLive = Layer.mergeAll(GreeterLive, DatabaseTest).pipe(
  Layer.provide(LoggerLive),
);

// ── ERROR 1: missing service at the boundary ──────────────────────────────
// `program` needs Greeter | Database. runPromise wants R = never.
// Expect Jev: layer AppLive, where = here.

const program = Effect.gen(function* () {
  const greeter = yield* Greeter;
  const db = yield* Database;
  const name = yield* db.find(1);
  return yield* greeter.greet(name);
});

export const main = Effect.runPromise(program);

// ── ERROR 2: unhandled error inside a service method ──────────────────────
// Declared to never fail, but db.find fails with NotFound.
// Expect Jev: fix = declare or map_error → UserServiceError.

export const getUserName = (
  id: number,
): Effect.Effect<string, never, Database> =>
  Effect.gen(function* () {
    const db = yield* Database;
    return yield* db.find(id);
  });

// ── ERROR 3: unhandled error at a request handler with an obvious fallback ─
// Expect Jev: fix = catch_tag with a fallback.

export const handler = (id: number): Effect.Effect<string, never, Database> =>
  Effect.gen(function* () {
    const db = yield* Database;
    const name = yield* db.find(id);
    return `user: ${name}`;
  });

// ── ERROR 4: two errors, boundary script ──────────────────────────────────
// Expect Jev: fix = or_die (script boundary) or catchTags.

const flaky = (
  id: number,
): Effect.Effect<string, NotFound | Timeout, Database> =>
  Effect.gen(function* () {
    const db = yield* Database;
    return yield* db.find(id);
  });

export const script: Effect.Effect<string, never, Database> = flaky(2);

// ── ERROR 5: a Layer whose RIn was never provided ─────────────────────────
// Expect Jev: layer LoggerLive, composed with Layer.provide inside.

export const GreeterStandalone: Layer.Layer<Greeter, never, never> = Layer.effect(
  Greeter,
  Effect.gen(function* () {
    const logger = yield* Logger;
    return { greet: (n: string) => logger.log(n).pipe(Effect.as(`hi ${n}`)) };
  }),
);

// ── ERROR 6: R widened to unknown by a helper that cast its R away ────────
// Expect Jev: widened at `fromRegistry`.

const registry: Record<string, unknown> = {};
const fromRegistry = (k: string) =>
  registry[k] as Effect.Effect<string, never, unknown>;
export const runRegistered = Effect.runPromise(
  Effect.gen(function* () {
    const home = yield* fromRegistry("home");
    return `home=${home}`;
  }),
);

// ── ERROR 7: E widened to unknown by an explicit annotation upstream ──────
// Expect Jev: widened at `loadUser`.

const loadUser = (id: number): Effect.Effect<string, unknown, never> =>
  Effect.succeed(`user-${id}`);
export const safeUser: Effect.Effect<string, never, never> = loadUser(1);

// ── ERROR 8: R widened to unknown by one member of a list ─────────────────
// Expect Jev: widened at `steps`.

const steps = [Effect.void, Effect.void as Effect.Effect<void, never, unknown>];
export const runSteps = Effect.runPromise(Effect.all(steps));
