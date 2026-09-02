# V2329A Origin Isle / SuperX root cause and fix — 2026-09-02

## Scope

Device under test:

- iQOO 12 Pro / V2329A / PD2329
- OriginOS 6 / Android 16
- observed fingerprint from the diagnostic build: `vivo/PD2329/PD2329:16/BP2A.250605.031.A3/compiler260820121504:user/release-keys`
- Origin Isle upstream baseline: `fvhde/origin-isle` v1.4.0
- Origin Isle package identity: `com.autonavi.minimap` (AMap spoof, intentionally used by upstream)

## Initial symptom

Origin Isle could read source notifications and correctly classify media notifications, but no SuperX / Origin Island card rendered on V2329A.

Observed examples before the fix:

- YouTube ReVanced: listener/log classification succeeded as media.
- Bilibili: listener/log classification succeeded as media.
- Built-in Sample cards all failed to render.

This ruled out a simple notification-listener or source-app recognition failure.

## Experiments that did NOT fix it

Two V2329A A/B builds were tested:

1. force `island.superx.forceShow = true` while keeping the media BUTTONS/WAVE path.
2. force-show plus BASE media template.

Neither rendered. Built-in Sample cards also failed, proving the failure was upstream of media-card formatting.

A dedicated diagnostic build (C) then confirmed:

- hidden SuperX APIs are present on this firmware;
- `setSuperXInfosSceneList(...)` returns normally through reflection;
- however scene state remained false after the call;
- `NAVIGATION`, `MOVIE`, `TAXI`, etc. all reported false;
- a minimal SuperX post did not survive as an active SuperX card.

## System-service finding

Publicly decompiled vivo notification-service code shows that the server-side setter is gated to system/phone callers. A normal third-party app can therefore invoke the Binder API without a reflection exception while the server silently ignores the requested change.

This explains why upstream's `grantScenes()` could log apparent success while the actual scene policy remained unchanged on this device.

## Decisive system state

`dumpsys notification` exposed the system-server SuperX policy directly.

Before the fix:

```text
appInfo com.autonavi.minimap
scene NAVIGATION switch false
scene TAXI switch false
```

Other built-in/system-supported packages showed true scenes, proving that SuperX itself was active on the device.

The vivo permission `com.vivo.notification.ISLAND_NOTI_SUPPORT` exists on this ROM with `protectionLevel=signature`, and `com.vivo.assistant` holds it as a system-UID app. However, this permission was not required for Origin Isle's normal third-party posting path once the NAVIGATION policy was enabled, so it is not the root cause of the failure.

## Root cause — VERIFIED

The real blocker on V2329A was the official vivo SuperX / Atomic Notification policy:

```text
com.autonavi.minimap / NAVIGATION = false
```

Because upstream Origin Isle uses `com.autonavi.minimap` and uses NAVIGATION as the practical carrier scene, every SuperX card was silently rejected while this system policy was disabled.

## Fix — VERIFIED, no root required

Open vivo Assistant's Atomic Notification settings:

```sh
am start -a com.vivo.assistant.atomicnotification.settings
```

Equivalent component:

```text
com.vivo.assistant/.settings.AtomicNotificationSettingsActivity
```

Enable the entry corresponding to `com.autonavi.minimap` / Origin Isle / AMap.

After enabling it, `dumpsys notification` changed to:

```text
appInfo com.autonavi.minimap
scene NAVIGATION switch true
scene TAXI switch false
```

No root, Shizuku, signature spoofing, or system-permission patch is required for the actual fix. Shizuku/rish was used only for diagnostics and to launch the settings activity conveniently.

## Validation after NAVIGATION=true

### Built-in Samples

PASS. Multiple built-in sample types rendered successfully at the same time, including navigation, call, music, working/progress and timer-style cards.

### Real applications

- Google Maps: PASS — navigation card renders on the island.
- YouTube / YouTube ReVanced: PASS — media card renders.
- Bilibili: PASS — media card renders.
- Real call / VoIP path: UNTESTED due lack of test condition at the time of closure.

Therefore the V2329A SuperX protocol and renderer are compatible with upstream Origin Isle v1.4.0 after the official NAVIGATION policy is enabled.

## Final disposition

The V2329A-specific media-template A/B variants and diagnostic C build were diagnostic only and are not needed for daily use.

Recommended daily state:

- return to official Origin Isle v1.4.0;
- confirm `NAVIGATION=true` in vivo Atomic Notification settings after reinstall, because uninstall/reinstall of `com.autonavi.minimap` may or may not preserve the system policy;
- keep the diagnostic branches/artifacts only as evidence and for regression debugging.

Official v1.4.0 APK SHA256:

```text
af5319c70069bed8eee7595c9f12324e5d9950281d8c22b9f3d6cf6ece8eba25
```

## Engineering note for upstream/future fork

A robust onboarding flow for vivo devices should check `getSceneStatus(packageName, "NAVIGATION")` and, when false, direct the user to the system Atomic Notification settings instead of assuming `setSuperXInfosSceneList()` successfully grants the scene.

This V2329A case demonstrates that package spoofing alone is insufficient when the system policy for the spoofed package exists but is disabled.
