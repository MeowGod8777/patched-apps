# iQOO 12 Pro battery ledger — MacroDroid context v2

Status: **target context design; supersedes legacy `home_wifi / out_4g` semantics**

This design begins only after the Scene screenshot ingestion contract was finalized. MacroDroid remains an environmental-context source only; it does not capture Scene battery metrics.

## 1. Objective

Maintain a low-cost, append-only network-context timeline that can be intersected with Scene session intervals.

Final network states:

```text
home_wifi
other_wifi
mobile
unknown
```

A periodic heartbeat is retained so ingestion can distinguish “no state change” from “MacroDroid was not reliably observing the device”.

## 2. Why `out_4g` is retired

Legacy pilot logic used:

```text
leave all home SSIDs -> out_4g
```

That implication is invalid:

```text
not home Wi-Fi != mobile data
```

Examples that must not become `mobile` merely because the home SSID is absent:

- another Wi-Fi network
- no data connection
- Wi-Fi transition/reassociation
- MacroDroid temporarily missing connectivity information

Existing historical `out_4g` rows remain preserved as legacy observations but are semantically normalized to `unknown` unless independent evidence confirms mobile transport.

## 3. Classifier precedence

All network-related triggers call one shared classifier/action block.

Classifier order:

```text
1. Wi-Fi connected AND SSID is a configured home SSID -> home_wifi
2. Wi-Fi connected to any other SSID                  -> other_wifi
3. Wi-Fi disconnected AND data connectivity available -> mobile
4. otherwise                                           -> unknown
```

The Wi-Fi branches must run before the mobile branch.

`mobile` means MacroDroid reports data connectivity available while Wi-Fi is disconnected. It does not mean “mobile data toggle is enabled” and it is not inferred from cellular signal/service alone.

## 4. Home SSID set

Current confirmed home SSID from the pilot timeline:

```text
DaFengLi_5G
```

If additional home SSIDs are used later, add them to the same home set. Do not encode unrelated trusted Wi-Fi as home; those belong to `other_wifi`.

## 5. Trigger set

Use one context-classification macro/action block called conceptually:

```text
Battery Context Classify v2
```

Invoke it from these triggers:

1. Wi-Fi State Change -> Connected to any network
2. Wi-Fi State Change -> Disconnected from any network
3. Data Connectivity Change -> Data Available
4. Data Connectivity Change -> No Connection
5. Regular Interval -> every 1 hour
6. device/MacroDroid startup trigger if available/reliable on the device

The hourly trigger is a coverage heartbeat, not a polling requirement for network state accuracy. Network changes are primarily captured by event triggers.

## 6. Debounce

Wi-Fi handoff can produce brief disconnected states before the next transport is ready.

For connectivity-change triggers, wait approximately **5 seconds** before classification. Then classify the current state once.

Do not retain the legacy 30-second rule that directly labels departure as `out_4g`.

If the user later observes noisy duplicate transitions, deduplicate identical consecutive states during ingestion rather than adding long delays that could miss short real transitions.

## 7. Event file

Target device file:

```text
/sdcard/SceneBattery/context_events_v2.csv
```

Header:

```csv
epoch_s,event_type,state,ssid,source
```

Rows:

```text
<epoch>,transition,home_wifi,DaFengLi_5G,macrodroid_v2
<epoch>,transition,mobile,,macrodroid_v2
<epoch>,heartbeat,mobile,,macrodroid_v2
```

`epoch_s` must be a real Unix epoch value, not a literal placeholder such as `<目前日期時間>`.

## 8. Append behavior

### Transition trigger

After classification:

- append a `transition` row only if the newly classified state differs from the last known v2 state;
- update the local/global last-state variable.

### Heartbeat trigger

Every hour:

- re-run the same classifier;
- append one `heartbeat` row even if state is unchanged.

This provides an explicit observation/coverage signal.

### Startup

On first run or after MacroDroid/device restart:

- classify immediately;
- append a `startup` row;
- initialize the last-state variable.

## 9. SSID handling

When Wi-Fi is connected, retain the current SSID in the event row.

Expected examples:

```text
home_wifi  -> DaFengLi_5G
other_wifi -> actual current SSID
mobile     -> empty SSID
unknown    -> empty unless a diagnostically useful value exists
```

If Android/MacroDroid cannot expose the SSID reliably at a particular event, do not guess it.

## 10. Coverage interpretation

A state transition remains valid until another transition changes it, but session context quality also depends on heartbeat coverage.

Recommended ingestion quality labels:

- `confirmed`: transitions bracket the interval and heartbeats show normal coverage
- `partial`: some usable event overlap exists but heartbeat/interval coverage has gaps
- `unknown`: no reliable v2 observation coverage for the relevant interval

Exact heartbeat-gap thresholds can be tuned after several days of natural use. Do not overfit them before real v2 data exists.

## 11. Session classification

Once a Scene session has a usable wall interval, intersect it with v2 network events.

Possible derived session network labels:

- `home_wifi` — essentially all sufficiently observed session interval is home Wi-Fi
- `mobile` — essentially all sufficiently observed interval is mobile
- `other_wifi` — essentially all sufficiently observed interval is other Wi-Fi
- `mixed` — materially spans multiple confirmed transports
- `unknown` — observation coverage is insufficient

Do not force a dominant state when meaningful mixed use occurred.

Exact dominance/mixed thresholds should be based on interval coverage after v2 data exists; do not invent a threshold before enough natural-use sessions are available.

## 12. Legacy migration

Existing pilot file:

```text
/sdcard/SceneBattery/network_timeline_md.csv
```

and canonical `context_timeline.csv` are preserved.

Migration rule:

```text
legacy home_wifi -> home_wifi
legacy out_4g    -> unknown unless independently confirmed as mobile
invalid placeholder timestamps remain invalid
```

Do not rewrite the legacy pilot file in place.

## 13. No Shizuku dependency

The v2 classifier should use MacroDroid's native Wi-Fi state/SSID and data-connectivity facilities rather than Shizuku shell commands.

Reasons:

- context collection should survive ordinary use with minimal dependencies;
- Shizuku lifecycle should not determine whether environmental coverage exists;
- no shell output parsing is required for this four-state model.

Shizuku remains available for other device tasks but is not part of this context timeline contract.

## 14. Validation period

After enabling v2, use it naturally for several days before changing thresholds or adding navigation automation.

Validation checks:

- home Wi-Fi transitions resolve to `home_wifi`
- another Wi-Fi resolves to `other_wifi`
- Wi-Fi off/disconnected with usable mobile data resolves to `mobile`
- airplane/no-data periods resolve to `unknown`
- hourly heartbeat continues while the phone is naturally idle/in use
- no impossible rapid flip-flop dominates the log

Only after this base network timeline is stable should navigation `on/off` events be added.
