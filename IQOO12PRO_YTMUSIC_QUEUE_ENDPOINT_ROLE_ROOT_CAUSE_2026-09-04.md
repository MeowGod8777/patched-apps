# iQOO 12 Pro / OriginOS 6 — YouTube Music queue endpoint role root cause

Date: 2026-09-04

## Input identity

- Exact validated Luna base SHA256: `0b1b61ad6bd87dacc88517adf19c1115085d529e63847d50d587476efa4ce307`
- Static workflow: `Inspect YT Music queue endpoint roles`
- Run: `33825568884`
- Artifact: `9919823013`
- Artifact digest: `sha256:637b82000489c348c2d5a0c56ce3e235db9f1f480622e9570b6be945821468ba`
- Runtime trace checkpoint: `IQOO12PRO_YTMUSIC_V4N_TRACE_RUNTIME_RESULT_2026-09-04.md`
- Async result-contract checkpoint: `IQOO12PRO_YTMUSIC_ASYNC_INSPECTION_RESULT_2026-09-04.md`

## Root cause

**VERIFIED: V4/V4N encoded the wrong queue-item endpoint role.**

The previous V4N architecture used:

`Lnoq.o() -> Lboht -> Llgl.d(Lboht) -> Vivo MediaItem.mediaId`

Static RE had previously proven that `Lnoq.o()` is a pure getter and that `Llgl.d()` is a valid stock native-mediaId encoder. That was insufficient: purity and encodability did not establish that `o()` is the endpoint representing “play this queue item”.

The exact stock queue model now proves it is not.

## Exact queue contracts

`Lnoq` inherits several independent contracts:

- `Lazcf.n() -> Lazmi`
- `Lazck.o() -> Lboht`
- `Lazcj.p() -> Lboht`
- queue id through `m() -> long`

`Lnox` / `Lnpa` back these with distinct `Lbxxg` fields:

- `n()` builds `Lazmi` from `Lbxxg.l : Lboht`
- `o()` returns `Lbxxg.q : Lboht`
- `p()` returns `Lbxxg.r : Lboht`

Therefore `l`, `q`, and `r` are three different endpoint roles, not interchangeable representations of one playable endpoint.

## VERIFIED semantic evidence

### 1. `n()` is the stock queue-selection/playable representation

The exact stock `Llag` implementation of `onSkipToQueueItem(long)`:

1. locates the requested `Lnoq` by queue id;
2. calculates the target queue partition/index;
3. when a direct queue state transition is required, obtains the selected item with:

`invoke-interface {item}, Lnoq;->n()Lazmi;`

4. constructs:

`new Lazzm(Lazzl.e, selectedLazmi)`

5. dispatches it to the player/controller through:

`Lbacc.d(Lazzm)`

6. returns the canonical success result `Lkym.a`.

Thus stock queue selection itself uses `Lnoq.n() / Lazmi`, not `Lnoq.o()`.

`Lazmi.b` is the `Lboht` supplied when the `Lazmi` is constructed; for `Lnox.n()` this is exactly `Lbxxg.l`.

### 2. `o()` is a queue-management DELETE endpoint

The exact stock implementation `Loip.d(Lazck, boolean)` calls:

`Lazck.o() -> Lboht`

and, when non-null, dispatches that endpoint through the queue-management interface `Lazci.b(...)` with an operation callback explicitly labelled:

`"DELETE"`

The only direct `Lnoq.o()` call in the queue subsystem also appears in `Lnyo` around queue-item removal/cleanup before calling `Lazcl.d(...)`.

This is incompatible with treating `o()` as the canonical “play this row” endpoint.

### 3. `p()` is another independent queue-management endpoint

`Loip.a(Lazcj)` calls:

`Lazcj.p() -> Lboht`

then sends it through `Laoeb.c(endpoint, map)` with `local_queue_item_uid` metadata.

It is therefore also a distinct operation endpoint and is not the stock direct queue-selection path.

## Why this explains the V4N runtime trace

V4N returned an ID derived from `Lnoq.o()`.

That ID was structurally valid, so the runtime trace correctly showed:

`Vivo row click -> Llag.g -> Laveu.b -> Llbg.a -> Llbg.o`

without decode errors.

But the endpoint had the wrong semantic role. A syntactically valid queue-management endpoint can be encoded/decoded and dispatched without representing the requested track transition.

This resolves the previous apparent contradiction: transport and callback routing were working; the selected row payload was wrong.

## Superseded runtime probe

The newly added V4N result-code probe remains useful as a diagnostic tool but is **not the next priority**. The endpoint-role mismatch is already a stronger, exact-stock root cause than caller/Bundle speculation.

Do not ask the device to run another result-code probe before correcting the endpoint role.

## Next implementation gate

The next candidate must start from the V2 runtime-stable regression control and preserve its metadata/session behavior.

For every real queue `Lnoq` item, derive the native media ID from the playable queue item:

`Lnoq.n() -> Lazmi -> Lazmi.b : Lboht -> Llgl.d(Lboht)`

and expose that ID only as the Vivo current-list `MediaItem.mediaId`.

Requirements:

- no `Lid` modification;
- no queueId parser / `onSkipToQueueItem` bridge;
- no `Lii.m()` timing patch;
- no `Lnoq.o()` or `Lnoq.p()` selection ID;
- preserve V2 title/artist/artwork/current-session behavior;
- retain a render-only fallback ID only if playable `n()/Lazmi.b` is unavailable;
- validate exact base, signer, v2/v3 signature, 16K zipalign, 21 stored arm64 libraries, package/version, manifest and hard regression guards before device delivery.

This candidate is the first post-trace functional correction justified by a VERIFIED root cause, rather than another speculative selection mechanism.
