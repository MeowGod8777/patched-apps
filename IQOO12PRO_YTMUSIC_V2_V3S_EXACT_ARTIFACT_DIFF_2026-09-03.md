# iQOO 12 Pro / YT Music — exact V2 vs V3S artifact diff — 2026-09-03

## Why this diff was required
V3S was intended to be V2 + a selection-only `onPlayFromMediaId()` hook, with the V3/V3R1 metadata-time patch completely removed. Runtime nevertheless regressed song-title/time presentation while playlist rendering survived and selection still did not work.

Therefore we compared the exact APK artifacts that were installed/tested rather than inferring from patch scripts.

## Exact artifacts
V2 runtime-PASS base candidate:
- workflow run: `33762673544`
- artifact: `9896185089`
- APK SHA256: `639a99a109ea853eda2c53238626d4caab45b410dccfe968cd3f04685d151715`

V3S runtime-regression candidate:
- workflow run: `33767682476`
- artifact: `9898283280`
- APK SHA256: `1cdeea400e6b2d8233ecaca15864c2397736ba82f888311995a9a9a75c2e3645`

Diff workflow:
- workflow: `Analyze YT Music V2 vs V3S artifact diff`
- run: `33772725746`
- artifact: `9900329810`

## ZIP-entry byte comparison
Both APKs contain the exact same entry set. Only four common entries differ: the three `META-INF` signature files and `classes5.dex`.

No AndroidManifest/resource/native-library/other DEX content differs.

## Full Apktool decode diff
After decoding both exact APKs with Apktool 3.0.3, the only real executable source difference is `smali_classes5/id.smali`.

`apktool.yml` differs only in source APK filename; original META-INF differs only because the classes5.dex digest/signature differs.

### Exact code delta
V2 `id.onPlayFromMediaId(String, Bundle)` is stock.

V3S changed only this method by:
- increasing `.locals 1 -> .locals 3`
- adding `vivo_qid_` prefix detection
- parsing the suffix as `long`
- calling `Lid;->onSkipToQueueItem(J)V`
- returning early

All other decoded files are byte-identical.

## Conclusion
The V3S title/time regression cannot be attributed to a different base, manifest, resource set, `ii.smali`, c0 queue bridge, or metadata patch. The only executable delta is modification of callback class `id.smali`.

Therefore **do not patch `id.onPlayFromMediaId()` again**. Treat this callback class as a fragile runtime boundary.

Move selection downstream while keeping the proven V2 `id.smali` byte-identical:

`stock V2 id.onPlayFromMediaId(mediaId, extras)`
→ existing `Lie.g(mediaId, extras)`
→ patch `Lie.g()` only for `vivo_qid_`
→ parse queueId
→ invoke existing `Lie.t(queueId)`

This preserves the V2 callback class and its runtime behavior while reusing YT Music's own queue-selection delegate.

## Time-display direction
Do not reintroduce `vivomusicmix.media.metadata.support_event` mutation in `ii.m()`.
Before another time fix, statically verify the exact Vivo `c0` consumer for initial duration/position and any cooperation-specific metadata/event keys. Keep time repair separate from YT Music's callback/metadata publication path until the consumer contract is proven.
