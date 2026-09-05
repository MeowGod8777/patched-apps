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

All network-related triggers use one shared classification routine.

Before the final branch, run MacroDroid **Connectivity Check** and store the result in a boolean such as `ctx_online`. This asks whether a data connection is currently usable and avoids using the mobile-data toggle or cellular service registration as a proxy for transport.

Classifier order:

```text
1. Wi-Fi connected AND SSID is a configured home SSID -> home_wifi
2. Wi-Fi connected to any other SSID                  -> other_wifi
3. Wi-Fi disconnected AND ctx_online = true           -> mobile
4. otherwise                                           -> unknown
```

The Wi-Fi branches must run before the mobile branch.

`mobile` therefore means: no Wi-Fi connection is active, but MacroDroid's connectivity check reports usable data connectivity. It does not mean “mobile data toggle is enabled” and it is not inferred from cellular signal/service alone.

## 4. Home SSID set

Current confirmed home SSID from the pilot timeline:

```text
DaFengLi_5G
```

If additional home SSIDs are used later, add them to the same home set. Do not encode unrelated trusted Wi-Fi as home; those belong to `other_wifi`.

## 5. Trigger set

Use one context-classification routine called conceptually:

```text
Battery Context Classify v2
```

Invoke it from these triggers:

1. Wi-Fi State Change -> Connected to any network
2. Wi-Fi State Change -> Disconnected from any network
3. Data Connectivity Change -> Data Available
4. Data Connectivity Change -> No Connection
5. Regular Interval -> every 1 hour
6. MacroDroid Initialised and/or Device Boot if reliable on the device

The hourly trigger is a coverage heartbeat, not a polling requirement for network state accuracy. Network changes are primarily captured by event triggers.

## 6. Debounce

Wi-Fi handoff can produce brief disconnected states before the next transport is ready.

For connectivity-change triggers, wait approximately **5 seconds** before running Connectivity Check and classifying the current state once.

Do not retain the legacy 30-second rule that directly labels departure as `out_4g`.

If the user later observes noisy duplicate transitions, deduplicate identical consecutive states during ingestion rather than adding long delays that could miss short real transitions.

## 7. Event file

Target device file:

```text
/sdcard/SceneBattery/context_events_v2.csv
```

Header:

```csv
epoch_ms,event_type,state,ssid,source
```

Use MacroDroid's native current system-time-in-milliseconds magic text (`{system_time_ms}`) directly. No shell `date` command is required.

Rows conceptually look like:

```text
<epoch_ms>,transition,home_wifi,DaFengLi_5G,macrodroid_v2
<epoch_ms>,transition,mobile,,macrodroid_v2
<epoch_ms>,heartbeat,mobile,,macrodroid_v2
```

The epoch field must contain a real numeric Unix epoch in milliseconds, never a literal placeholder such as `<目前日期時間>`.

## 8. Append behavior

### Transition triggers

After classification:

- append a `transition` row when the network-trigger macro runs;
- duplicate identical states are acceptable and may be deduplicated during ingestion;
- if a reliable last-state variable is already in use, identical consecutive transitions may optionally be suppressed, but correctness is preferred over clever suppression.

### Heartbeat trigger

Every hour:

- run the same Connectivity Check + classifier;
- append one `heartbeat` row even if state is unchanged.

This provides an explicit observation/coverage signal.

### Startup

On first run or after MacroDroid/device restart:

- classify immediately;
- append a `startup` row.

## 9. SSID handling

When Wi-Fi is connected, retain MacroDroid's current Wi-Fi SSID magic text in the event row.

Expected examples:

```text
home_wifi  -> DaFengLi_5G
other_wifi -> actual current SSID
mobile     -> empty SSID
unknown    -> empty unless a diagnostically useful value exists
```

If Android/MacroDroid cannot expose the SSID reliably at a particular event, do not guess it.

## 10. File-writing method

Use MacroDroid's native **Write to File** action in append mode. The action supports append/prepend/overwrite directly, so routine context logging does not require a shell script.

The existing `/sdcard/SceneBattery/` location may be retained. Create the CSV header once during setup; subsequent macros append data rows only.

## 11. Coverage interpretation

A state transition remains valid until another transition changes it, but session context quality also depends on heartbeat coverage.

Recommended ingestion quality labels:

- `confirmed`: transitions bracket the interval and heartbeats show normal coverage
- `partial`: some usable event overlap exists but heartbeat/interval coverage has gaps
- `unknown`: no reliable v2 observation coverage for the relevant interval

Exact heartbeat-gap thresholds can be tuned after several days of natural use. Do not overfit them before real v2 data exists.

## 12. Session classification

Once a Scene session has a usable wall interval, intersect it with v2 network events.

Possible derived session network labels:

- `home_wifi` — essentially all sufficiently observed session interval is home Wi-Fi
- `mobile` — essentially all sufficiently observed interval is mobile
- `other_wifi` — essentially all sufficiently observed interval is other Wi-Fi
- `mixed` — materially spans multiple confirmed transports
- `unknown` — observation coverage is insufficient

Do not force a dominant state when meaningful mixed use occurred.

Exact dominance/mixed thresholds should be based on interval coverage after v2 data exists; do not invent a threshold before enough natural-use sessions are available.

## 13. Legacy migration

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

## 14. No Shizuku dependency

The v2 classifier uses MacroDroid's native Wi-Fi state/SSID, Connectivity Check, system-time magic text, and Write to File facilities rather than Shizuku shell commands.

Reasons:

- context collection should survive ordinary use with minimal dependencies;
- Shizuku lifecycle should not determine whether environmental coverage exists;
- no shell output parsing is required for this four-state model.

Shizuku remains available for other device tasks but is not part of this context timeline contract.

## 15. Validation period

After enabling v2, use it naturally for several days before changing thresholds or adding navigation automation.

Validation checks:

- home Wi-Fi transitions resolve to `home_wifi`
- another Wi-Fi resolves to `other_wifi`
- Wi-Fi off/disconnected with usable mobile data resolves to `mobile`
- airplane/no-data periods resolve to `unknown`
- hourly heartbeat continues while the phone is naturally idle/in use
- no impossible rapid flip-flop dominates the log

Only after this base network timeline is stable should navigation `on/off` events be added.
