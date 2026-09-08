# iQOO 12 Pro battery ledger — MacroDroid context v2.5

Status: **production candidate with a known transition-coverage gap discovered during natural use on 2026-09-08**. Supersedes legacy `home_wifi / out_4g` semantics and earlier v2.1–v2.4 test candidates, but the 2026-09-06..08 raw batch is **not yet safe for wholesale canonical promotion**.

MacroDroid is an environmental-context source only. It does not capture or redefine Scene battery metrics.

## 1. Purpose

Maintain a low-cost append-only network-context timeline that can be intersected with Scene session intervals.

Runtime network states:

```text
home_wifi
other_wifi
mobile
offline
```

`unknown` is reserved for canonical ingestion / coverage quality when recorded evidence is insufficient; it is not the normal v2.5 classifier fallback.

A periodic heartbeat is retained so ingestion can distinguish “no state change” from “MacroDroid was not reliably observing the device”.

## 2. Why legacy `out_4g` is retired

Legacy pilot logic used:

```text
leave all home SSIDs -> out_4g
```

That implication is invalid:

```text
not home Wi-Fi != mobile data
```

Another Wi-Fi, an offline phone, a transition/reassociation window, or missing observation must not be relabelled as mobile.

Existing historical `out_4g` rows remain preserved but canonicalize to `unknown` unless independent evidence confirms mobile transport.

## 3. v2.5 classifier

After network-related triggers, wait approximately 5 seconds, run MacroDroid Connectivity Check into boolean `ctx_online`, then classify in this order:

```text
1. Wi-Fi connected AND SSID is in explicit home set -> home_wifi
2. Wi-Fi connected to any other SSID               -> other_wifi
3. no Wi-Fi AND ctx_online = true                   -> mobile
4. no Wi-Fi AND ctx_online = false                  -> offline
```

Wi-Fi branches must run before the mobile branch.

`mobile` therefore means no Wi-Fi is active and a usable data path is actually reachable. It is not inferred from “left home Wi-Fi”.

`offline` is an explicit observed state and is the expected classification when the user turns off Wi-Fi and mobile data before sleep.

## 4. Confirmed home SSIDs

Confirmed on 2026-09-05:

```text
DaFengLi
DaFengLi_5G
An's 3F TP LINK 256B 2.4G
An's 3F TP LINK 256B 5G
```

All four classify as `home_wifi`.

Saved networks such as `2F` and `AS-3f` are not automatically home unless separately confirmed later.

## 5. Triggers in the imported v2.5 macro

The current imported macro uses:

1. WiFi State Change -> connected to any network
2. WiFi State Change -> disconnected from any network
3. Data Connectivity Change -> Data Available
4. Data Connectivity Change -> No Connection
5. Regular Interval -> every 1 hour

The current production candidate does not require a separate Shizuku routine for classification.

## 6. Event file

Device path:

```text
/sdcard/SceneBattery/context_events_v2.csv
```

Intended header:

```csv
epoch_ms,event_type,state,ssid,source
```

The first natural-use file uploaded on 2026-09-08 was **headerless** because the file already existed before the one-time header seeding command; canonical ingestion must therefore parse this source as five positional fields rather than assuming the first row is a header.

Examples:

```text
<epoch_ms>,transition,home_wifi,DaFengLi_5G,macrodroid_v2
<epoch_ms>,transition,other_wifi,<ssid>,macrodroid_v2
<epoch_ms>,transition,mobile,,macrodroid_v2
<epoch_ms>,transition,offline,,macrodroid_v2
<epoch_ms>,heartbeat,home_wifi,DaFengLi_5G,macrodroid_v2
```

## 7. Deduplication

Connectivity changes can fire several MacroDroid triggers for one final network state.

v2.5 builds a key from:

```text
state + SSID
```

and stores the last retained key in a persistent global string variable:

```text
battery_ctx_last_key
```

All transient classifier values remain local variables.

For transition-trigger runs:

- append only when current `state + SSID` differs from `battery_ctx_last_key`
- after writing, update `battery_ctx_last_key`

For hourly heartbeat:

- always append one heartbeat row
- refresh the same persisted key

The global scope is intentional: local variables do not reliably retain the previous key across independent macro invocations.

Canonical ingestion remains duplicate-tolerant because earlier candidates and occasional concurrent invocations can still produce near-simultaneous duplicate transition rows.

## 8. Acceptance validation completed on 2026-09-05

Observed on-device results verified:

- four-home-SSID classifier correction applied
- `An's 3F TP LINK 256B 5G` -> `home_wifi`
- explicit no-network condition -> `offline`
- `offline -> home_wifi` transition
- hourly heartbeat output
- repeated manual execution at unchanged state produces no new transition after the persistent global dedupe key is populated

`mobile` was not deliberately forced during final v2.5 acceptance.

## 9. Natural-use validation finding — 2026-09-08

The first multi-day raw batch covers `2026-09-05T22:52:49.910+08:00` through `2026-09-08T11:03:47.107+08:00`.

The batch itself shows many plausible `home_wifi` / `offline` heartbeats and transitions, but Scene screenshots captured during ordinary use expose an important coverage failure:

- `2026-09-08 03:49:21`: Scene screenshot visibly shows a Wi-Fi status icon and substantial network-app use, while MacroDroid carries `offline` across the surrounding overnight observations and records no matching Wi-Fi transition.
- `2026-09-08 08:03:16`: Scene screenshot visibly shows a Wi-Fi status icon; MacroDroid heartbeat at `08:02:25.015` says `offline`, and no Wi-Fi transition appears around the capture.
- `2026-09-08 11:25:01`: screenshot is consistent with MacroDroid (`home_wifi / DaFengLi_5G` transition at `10:35:54.234`, heartbeat at `11:03:47.107`).

The first two cases do **not** prove that the classifier branch itself always returns the wrong state; Wi-Fi could have been enabled after an `offline` heartbeat. They do prove that **short Wi-Fi-on periods can be absent from the event timeline**, which is sufficient to invalidate unconditional session-context joining from the raw file.

Therefore:

- do not bulk-promote the 2026-09-06..08 raw batch into `canonical/context_events.csv`
- preserve the raw batch unchanged under `generated/2026-09-08/`
- treat affected session context as `unknown` when screenshot/context evidence conflicts or transition coverage is missing
- capture-instant `home_wifi` may still be used when a recent transition/heartbeat and screenshot status agree, but it must not be promoted to full-session context without a reconciled Scene interval

## 10. Historical test rows

Earlier v2 test candidates produced useful implementation evidence but are not authoritative classifier semantics:

- v2.1 initially labelled `An's 3F TP LINK 256B 5G` as `other_wifi` because the explicit home set was incomplete
- v2.2/v2.3 produced duplicate transition rows because dedupe state was not persistent across invocations

Do not rewrite the raw device CSV. Canonical ingestion may normalize known home SSIDs and suppress redundant identical transition representations while retaining provenance.

## 11. Context joining

Scene session intervals are intersected only with **validated** canonical context observations.

Session-level derived labels remain:

```text
home_wifi
mobile
other_wifi
offline
mixed
unknown
```

Do not force a dominant label when materially mixed use occurred. `unknown` means insufficient reliable context coverage, not a fifth runtime network transport state.

History-only Scene intervals may have bounded start/end uncertainty; joins must respect the History quantization bounds documented in `SCREENSHOT_INGESTION_V1.md`.

## 12. Next MacroDroid change criterion

v2.5 should no longer be described as “fully frozen”. The next change must specifically address missed short active-use Wi-Fi periods without turning the system into high-frequency polling.

A low-cost recovery trigger such as **screen-on / device-unlocked classification** is a candidate because it can re-sample context when the user actually begins active use, even if an Android background Wi-Fi transition broadcast was missed. Do not implement additional polling merely to hide this problem; validate the smallest recovery trigger against natural-use data.

`mobile` and `other_wifi` still require natural-use validation after the coverage fix.

## 13. Legacy preservation

Keep existing legacy sources unchanged:

```text
/sdcard/SceneBattery/network_timeline_md.csv
canonical/context_timeline.csv
canonical/context_events.csv
```

Legacy normalization remains conservative:

```text
legacy home_wifi -> home_wifi
legacy out_4g    -> unknown
```

The old pilot file is archival evidence and must not be rewritten in place.
