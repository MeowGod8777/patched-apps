# iQOO 12 Pro battery ledger — MacroDroid context v2

Status: **target context design; externally capability-checked on 2026-09-05; supersedes legacy `home_wifi / out_4g` semantics**

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

## 3. Capability check against current MacroDroid documentation

The following v2 assumptions were checked against the MacroDroid Wiki on 2026-09-05:

- **Connectivity Check** exists, checks internet connectivity, stores the result in a boolean variable, and by default blocks later actions until the check completes.
- **Data Connectivity Change** exists with `Data Available` / `No Connection`; its connected state means either Wi-Fi or mobile data is connected.
- **WiFi State Change** supports connected/disconnected and `Any Network`.
- **Regular Interval** supports hourly triggering.
- **MacroDroid Initialised** fires after MacroDroid has fully initialized.
- magic text **`{system_time_ms}`** returns Unix epoch milliseconds.
- magic text **`{ssid}`** exposes the current Wi-Fi SSID when Android/MacroDroid permissions permit it.
- **Write to File** supports append/prepend/overwrite.

Reference pages:

- https://macrodroidforum.com/wiki/index.php/Action:_Connectivity_Check
- https://macrodroidforum.com/wiki/index.php/Trigger:_Data_Connectivity_Change
- https://macrodroidforum.com/wiki/index.php/Trigger:_Wifi_State_Change
- https://macrodroidforum.com/wiki/index.php/Trigger:_Regular_Interval
- https://macrodroidforum.com/wiki/index.php/Trigger:_MacroDroid_Initialised
- https://macrodroidforum.com/wiki/index.php/Magic_text
- https://macrodroidforum.com/wiki/index.php/Action:_Write_to_File
- https://macrodroidforum.com/wiki/index.php/Helper_App

Important: `Data Connectivity Change` alone does **not** distinguish Wi-Fi from mobile; it only says that at least one usable data transport appeared/disappeared. The shared classifier below remains necessary.

## 4. Android 16 / helper and permission requirement

This design has **no Shizuku dependency**, but that does not mean “no helper/permission dependency”.

On modern Android, MacroDroid documents Wi-Fi connection/SSID functionality as requiring location-related access, and some Wi-Fi features may require the MacroDroid Connectivity Helper. For this Android 16 device, treat the following as setup prerequisites for reliable Wi-Fi/SSID classification:

- MacroDroid location permission appropriate for background Wi-Fi observation
- Android Location service enabled where required by the platform
- MacroDroid excluded from aggressive battery/background restriction as needed for reliable observation
- MacroDroid Connectivity Helper installed/configured if the current device does not reliably expose Wi-Fi connection/SSID state to MacroDroid without it

Do not install or add the helper merely for shell access; it is relevant only to MacroDroid connectivity/SSID observation.

If `{ssid}` or Wi-Fi connected/disconnected status remains unavailable even after legitimate permissions/helper setup, classify conservatively as `unknown` rather than guessing.

## 5. Classifier precedence

All network-related triggers use one shared classification routine.

Before the final branch, run MacroDroid **Connectivity Check** and store the result in a boolean such as:

```text
ctx_online
```

Classifier order:

```text
1. Wi-Fi connected AND SSID is a configured home SSID -> home_wifi
2. Wi-Fi connected to any other known SSID            -> other_wifi
3. Wi-Fi disconnected AND ctx_online = true           -> mobile
4. otherwise                                           -> unknown
```

The Wi-Fi branches must run before the mobile branch.

`mobile` therefore means: no Wi-Fi connection is active, but MacroDroid's connectivity check reports usable data connectivity. It does not mean “mobile data toggle is enabled” and it is not inferred from cellular registration/signal alone.

If Wi-Fi is reported connected but SSID cannot be determined reliably, prefer `unknown` unless another trustworthy MacroDroid state distinguishes it. Do not label an unidentified connected Wi-Fi as `other_wifi` solely because it is not equal to the home SSID.

## 6. Home SSID set

Confirmed home SSIDs on 2026-09-05:

```text
DaFengLi
DaFengLi_5G
An's 3F TP LINK 256B 2.4G
An's 3F TP LINK 256B 5G
```

All four classify as `home_wifi`.

Other saved networks visible on the device are **not** automatically home merely because they are saved. In particular, `2F` and `AS-3f` remain outside the home set unless separately confirmed by the user.

If additional home SSIDs are confirmed later, add them to this same explicit set. Unrelated trusted Wi-Fi remains `other_wifi`.

## 7. Trigger set

Use one context-classification routine called conceptually:

```text
Battery Context Classify v2
```

Invoke it from:

1. WiFi State Change -> Connected to Network -> Any Network
2. WiFi State Change -> Disconnected from Network -> Any Network
3. Data Connectivity Change -> Data Available
4. Data Connectivity Change -> No Connection
5. Regular Interval -> every 1 hour
6. MacroDroid Initialised

Why both Wi-Fi and Data triggers:

- Wi-Fi -> mobile can remain globally “data available”; the Wi-Fi disconnect trigger catches the transport handoff.
- mobile -> Wi-Fi is caught by Wi-Fi connect.
- mobile data appearing/disappearing while Wi-Fi is absent is caught by Data Connectivity Change.
- the hourly run supplies coverage evidence rather than primary transition detection.

## 8. Debounce

Connectivity handoffs can briefly expose an intermediate disconnected state.

For Wi-Fi/Data connectivity-change triggers:

```text
wait ~5 seconds
run Connectivity Check
classify current state once
```

Do not retain the legacy 30-second rule that directly labels departure as `out_4g`.

Natural-use testing showed that multiple connectivity triggers can fire for the same final state. The generated v2.2+ candidate therefore tracks `state + SSID` and suppresses identical transition rows while keeping hourly heartbeat rows unconditional. Ingestion must still tolerate duplicate historical/legacy rows because earlier versions did not suppress them.

## 9. Event file

Target device file:

```text
/sdcard/SceneBattery/context_events_v2.csv
```

Header:

```csv
epoch_ms,event_type,state,ssid,source
```

Use MacroDroid native magic text:

```text
{system_time_ms}
```

No shell `date` command is required.

Rows conceptually:

```text
<epoch_ms>,transition,home_wifi,DaFengLi_5G,macrodroid_v2
<epoch_ms>,transition,home_wifi,An's 3F TP LINK 256B 5G,macrodroid_v2
<epoch_ms>,transition,mobile,,macrodroid_v2
<epoch_ms>,heartbeat,mobile,,macrodroid_v2
<epoch_ms>,startup,unknown,,macrodroid_v2
```

The epoch field must contain a real numeric Unix epoch in milliseconds, never a literal placeholder such as `<目前日期時間>`.

## 10. Append behavior

### Transition-trigger runs

After classification:

- build a transition identity from `state + SSID`
- append a `transition` row only when that identity differs from the last retained transition identity
- update the stored last identity after a successful write
- ingestion remains duplicate-tolerant because earlier candidate versions could emit redundant identical rows

### Heartbeat

Every hour:

- run Connectivity Check + the same classifier
- append one `heartbeat` row even if state is unchanged

This supplies explicit observation coverage.

### Startup

On MacroDroid Initialised:

- classify immediately
- append a `startup` row

## 11. SSID handling

When Wi-Fi is connected and the SSID is available, retain `{ssid}`.

Expected:

```text
home_wifi  -> one of the four confirmed home SSIDs
other_wifi -> actual current SSID
mobile     -> empty
unknown    -> empty or a diagnostic value if it explains uncertainty
```

If Android/MacroDroid cannot expose SSID reliably, do not guess it.

## 12. File writing

Use MacroDroid native **Write to File** in append mode.

Target directory may remain:

```text
/sdcard/SceneBattery/
```

Create the CSV header once during setup; subsequent executions append rows only. Routine context collection needs no shell script.

## 13. Coverage interpretation

A transition state remains effective until a later transition changes it, but session context quality also depends on heartbeat coverage.

Initial quality vocabulary:

- `confirmed`: usable transitions plus normal heartbeat coverage across the relevant interval
- `partial`: usable overlap exists but coverage has gaps
- `unknown`: no reliable v2 coverage

Do not hard-code heartbeat-gap/dominance thresholds before several days of natural v2 data exist.

## 14. Session classification

Intersect Scene session intervals with v2 observations.

Derived labels:

- `home_wifi`
- `mobile`
- `other_wifi`
- `mixed`
- `unknown`

Do not force a dominant state when materially mixed use occurred. Exact mixed/dominance thresholds should be calibrated from real v2 data rather than invented in advance.

History-only session intervals may have bounded start/end uncertainty per `SCREENSHOT_INGESTION_V1.md`; context joining must respect those bounds instead of pretending the interval is exact.

## 15. Legacy migration

Preserve:

```text
/sdcard/SceneBattery/network_timeline_md.csv
canonical/context_timeline.csv
canonical/context_events.csv
```

Current canonical migration already maps valid legacy states conservatively:

```text
legacy home_wifi -> home_wifi
legacy out_4g    -> unknown
```

Invalid placeholder-timestamp rows remain preserved in the legacy source rather than being promoted to valid canonical observations.

Do not rewrite the legacy pilot file in place.

## 16. Dependency statement

The v2 design intentionally avoids Shizuku/shell parsing. It uses MacroDroid's own connectivity actions/triggers/magic text and native file append.

Possible dependency on **MacroDroid Connectivity Helper + location permissions/services** for reliable Android 16 Wi-Fi/SSID observation is acceptable and is separate from Shizuku.

This keeps the battery-context timeline independent from Shizuku lifecycle while respecting Android's current connectivity-observation restrictions.

## 17. Validation period

After enabling v2, use naturally for several days before tuning thresholds or adding navigation automation.

Check:

- all four confirmed home SSIDs -> `home_wifi`
- another known Wi-Fi -> `other_wifi`
- Wi-Fi absent + usable mobile connectivity -> `mobile`
- airplane/no-data -> `unknown`
- hourly heartbeat survives ordinary idle/use
- SSID remains available often enough for classification
- no impossible rapid flip-flop dominates the file

Only after this base network timeline is stable should navigation `on/off` events be added.
