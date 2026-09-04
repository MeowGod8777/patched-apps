# iQOO 12 Pro / OriginOS 6 — YouTube Music playFromMediaId async inspection result

Date: 2026-09-04

## Input identity

- Exact validated Luna base SHA256: `0b1b61ad6bd87dacc88517adf19c1115085d529e63847d50d587476efa4ce307`
- Inspection workflow: `Inspect YT Music playFromMediaId async completion`
- Run: `33824986696`
- Artifact: `9919610097`
- Artifact digest: `sha256:bcb555fa0ad2cabd09903cb2e8ee5e0ec05b8d64975038d82aa9b36a9cf652f1`
- Preceding runtime trace result: `IQOO12PRO_YTMUSIC_V4N_TRACE_RUNTIME_RESULT_2026-09-04.md`

## VERIFIED static findings

### 1. `Llbg.o()` preprocessing cannot silently terminate the request before `Llbg.i()`

`Llbg.o(Lckob, Lboht, Bundle)` optionally preprocesses the endpoint through a `ListenableFuture`.

Its two completion continuations are:

- `Llax` — success continuation. It casts the future result to `Lboht`, calls `Llbg.i(resultEndpoint, bundle)`, then publishes the returned `Lbupb` into the `Lckob` result object.
- `Llaw` — failure continuation. It ignores the preprocessing throwable, falls back to the original `Lboht`, calls `Llbg.i(originalEndpoint, bundle)`, then publishes the returned `Lbupb` into the same `Lckob` result object.

Therefore the asynchronous preprocessing branch itself does not explain the silent no-switch result. Both success and failure converge on `Llbg.i()`.

### 2. `Llbg.i()` returns an explicit playback result object

The return type is `Lbupb`. `Lkym` constructs the canonical result values:

- `Lkym.a`: `c=false`, `d=0`
- `Lkym.b`: `c=true`, `d=1`
- `Lkym.c`: `c=true`, `d=3`
- `Lkym.d`: `c=true`, `d=4`
- `Lkym.e`: `c=false`, `d=2`
- `Lkym.f`: `c=false`, `d=11`

For the `Llbg.i()` path relevant here, observed returns are primarily `a/b/c/d`.

`Lkym.b(Lbupb)` returns true only when `c == false && d == 0`, i.e. `Lkym.a`.

### 3. `Llag.x()` confirms the boolean/code semantics

The async `Lckob` result is observed by `Llag.g()` through `Lkzx`, which forwards the `Lbupb` to:

`Llag.x(Llkq, "onPlayFromMediaId()", Lbupb)`.

`Llag.x()` maps `onPlayFromMediaId()` to `Lbuns.b` and formats the result as:

- `c == false` -> `SUCCESS`
- `c == true` -> `ERROR`

with `Lbupb.d` as the error/result code.

Thus the next runtime boundary is not another playback callback guess. It is the exact `Lbupb { c, d }` returned by `Llbg.i()` for the Vivo row press.

### 4. `Llbg.i()` contains concrete early failure gates

Relevant exact-base branches include:

- null / structurally invalid endpoint (`Lomt.i(endpoint) == false`) -> `Lkym.b` (`ERROR`, code 1)
- an endpoint capability/environment gate involving `Lavtj.v()` -> `Lkym.c` (`ERROR`, code 3)
- entitlement / UI-mode / keyguard / route-state branches -> `Lkym.d` (`ERROR`, code 4)
- normal accepted playback paths -> `Lkym.a` (`SUCCESS`, code 0)

The current V4N trace proved only that `Llbg.o()` was entered and returned synchronously; it did not observe this later result object.

### 5. The Bundle is normalized before `Llbg.o()`

In `Llag.g()`:

1. `Llag.w(bundle, true)` resolves caller package/source into `Llkq`.
2. `Llai.b(Llkq.d, bundle)` ensures a non-null bundle and writes `skip_entitlement_check` according to the resolved source.
3. That normalized bundle is passed into `Llbg.o()` and then unchanged into `Llbg.i()` through either `Llax` or `Llaw`.

Therefore caller/source classification can materially change `Llbg.i()` behavior even when the native media ID and endpoint are correct.

## Eliminated hypotheses

The following are no longer primary candidates:

- Vivo row click not reaching YT Music;
- wrong `Lid`/MediaSession callback routing;
- native media ID transport corruption;
- `Laveu.b()` rejection;
- `Llbg.a()` returning null;
- `Llbg.o()` not being called;
- preprocessing future failure silently swallowing the request.

## Next runtime probe gate

A single observation-only result-code probe is justified if no existing log exposes `Llag.x()` result.

It must preserve V4N behavior and add only side-effect-free logging for:

1. `Llag.x()` action + `Lbupb.c` + `Lbupb.d`;
2. resolved caller/source from `Llkq`;
3. normalized Bundle facts relevant to `Llbg.i()` (`skip_entitlement_check`, `EXTRA_START_PAUSED`, legacy stream type, Vivo current-list marker);
4. optionally `Lomt.i(endpoint)` at the decoded endpoint boundary.

Decision gate:

- code 1 -> endpoint is non-null but structurally invalid for `Llbg.i()`; compare intended `Lnoq.o()` endpoint extensions with decoded endpoint extensions.
- code 3 -> identify the exact `Lavtj.v()` / endpoint extension gate.
- code 4 -> focus on caller/source entitlement or UI/route-state gate and Bundle/source classification.
- code 0 with no actual switch -> playback command is accepted by `Llbg.i()` but the downstream player/session transition is not occurring; trace `Lbacc/Lbacw/Lnyo` state publication rather than changing selection transport.

No timing-display patch is to be mixed into this probe.