# iQOO 12 Pro / YT Music c0 V3 — pre-delivery static rejection

Date: 2026-09-03 (+08:00)

## Build inspected

Workflow run: `33766038877`

Artifact: `9897571771`

APK produced by CI but **NOT approved for device delivery**:

`YouTube_Music_9.15.51_Luna_VIVO_C0_SELECTION_TIME_V3.apk`

APK SHA256:

`fc14096a36accbd3011828ea64895af30775b8e5646f45404fcc5e8e75bdb2db`

The mechanical validation chain passed (rebuild, 16K alignment, signer, v2/v3 signature, package/version, static markers), but a post-build control-flow audit found incomplete timing-injection coverage.

## Exact issue

Original `Lii;->m(MediaMetadataCompat)` has this control flow:

```smali
iget-object v0, p1, MediaMetadataCompat->c:MediaMetadata
if-nez v0, :cond_c

# only when framework MediaMetadata is not yet materialized:
new MediaMetadata$Builder
...
build
iput-object ..., p1, MediaMetadataCompat->c

:cond_c
iget-object p1, p1, MediaMetadataCompat->c
...
MediaSession.setMetadata(p1)
```

The first V3 patch inserted the Vivo support-event block immediately **before** the `:cond_c` label.

That means:

- fall-through path where `MediaMetadataCompat.c` was initially null: injection executes;
- branch path where `MediaMetadataCompat.c` was already non-null: `if-nez ... :cond_c` jumps directly to the label and bypasses the injection.

Therefore the intended invariant:

`every non-null metadata update -> add vivomusicmix.media.metadata.support_event = 0x10`

was not guaranteed.

## Classification

This is not a protocol failure and not an Apktool/smali encoding failure.

It is a **static control-flow placement bug in the first V3 timing patch**.

The selection bridge itself passed static/rebuild validation, but the APK is rejected as a combined V3 candidate because the timing half is not guaranteed to run.

## Fix

Move the support-event injection to immediately **after** the `:cond_c` label and before the original `iget-object p1, ...->c`.

Both paths then converge at `:cond_c` and execute the same injection:

```text
prebuilt framework metadata -> :cond_c -> injection
newly built framework metadata -> fall through :cond_c -> injection
```

Rebuild and repeat the complete validation chain before device delivery.
