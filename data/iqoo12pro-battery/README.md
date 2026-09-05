# iQOO 12 Pro Battery Ledger

Long-term natural-usage battery ledger for iQOO 12 Pro / V2329A using Scene (`com.omarea.vtools`) battery statistics.

## Measurement model

- This is **not** a fixed-workload laboratory benchmark.
- Scene `理论续航` / theoretical runtime is treated as a **workload-normalized endurance indicator**, not pure screen-on time.
- Scene `已使用` is not assumed to equal pure SOT.
- A discharge session does not need to start at 100% or end at 0%.
- Charging / Scene-stat reset forms a hard session boundary.
- Network changes form analysis segments inside a discharge session.

## Primary scene classes

- `home_wifi`: connected through one of the user's home Wi-Fi networks.
- `out_4g`: cellular-use segment outside the home-Wi-Fi context; malls, restaurants and ordinary outdoor use are intentionally grouped together.
- `unknown`: fallback only when transport/context cannot be determined reliably.

`navigation` is a modifier rather than a third top-level scene class.

## Data layers

- `baseline.csv`: confirmed historical records supplied by the user before automation.
- `raw/`: immutable automated snapshots. Multiple snapshots may belong to the same discharge session.
- Future generated session/segment ledgers must deduplicate / merge raw snapshots without deleting raw evidence.

## Duplicate/session rule

Do not deduplicate on average watts alone. Consider timestamp/history date, Scene `已使用`, theoretical runtime, battery level, app-duration distribution and monotonic progression. A later snapshot with longer `已使用` and mostly-continuing app counters is normally the same session, not a new record.
