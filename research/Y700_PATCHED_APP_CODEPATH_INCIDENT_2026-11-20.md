# Y700 patched-app package-code incident — 2026-11-20

## Summary

After a Y700 ColorOS 16 WFD experiment used a runtime SurfaceFlinger restart, a later audit showed a fresh kernel boot and two patched-app package-code anomalies.

This file exists to preserve app-data recovery rules. It is not proof that Morphe/RVHC itself caused the reboot or package loss.

## LINE 26.11.0

The physical stock `/data/app` code path disappeared while PackageManager metadata and app-private data survived.

Preserved state:

```text
package jp.naver.line.android
versionCode 261100124
versionName 26.11.0
appId 10353
uid u0_a353
CE inode 53745
DE inode 53742
private data ≈153M
signing lineage retained in packages.xml
```

Recovery used Release 8 stock splits only; the module ZIP was NOT reflashed.

Release 8:

```text
line-andrew-module-v26.11.0-arm64-v8a.zip
SHA256 a8251c364988bf27c14c42f4de725e80fc0cff5a92a3bdad9c8da67b14a59892
```

Stock split hashes:

```text
base.apk
3dad00933c2f3071565efb9b533187cd6c37c779ea92c8989e53dfe095680077

split_config.arm64_v8a.apk
b73f4c6ae72a715abdde71cf7296c6af8ab90284b4840496f3cbe2028ca7d694

split_config.xxhdpi.apk
b4e93ead10f9613b2ef11fd8775f5d577a259bc029ecdc082586b8bdc96594f9

split_config.xxxhdpi.apk
d6e05dbbf3ed831bde9834675b51b05861397514d486c863f61b05cb02ba26ad
```

Safe recovery:

```text
backup CE/DE + packages.xml first
copy stock splits to /data/local/tmp
pm install-create --user 0 -i com.android.vending -r
pm install-write ...
pm install-commit
STOP on any INSTALL_FAILED_*
NEVER uninstall as fallback
```

Result: original appId/UID/inodes/data remained and a new valid `/data/app` code path was created.

Current Y700 Andrew payload:

```text
/data/adb/rvhc/line-andrew-arm64.apk
SHA256 8e65e24b06827d533309acea681e3f06b867e9cf8e84363fbf8444904bedd19a
```

Module Action then restored the bind mount successfully.

## YouTube Music 9.15.51

The same audit found:

```text
package com.google.android.apps.youtube.music
version 9.15.51
versionCode 91551240
uid u0_a405
PackageSetting present
installed=true
physical recorded /data/app codePath absent
CE data ≈121M
DE data ≈1.1M
module description = Needs reflash: App not installed
```

The patched payload survived:

```text
SHA256 baefd91ef026e162ecec50533c9a3646a07b4e9d47251a5887ac9034b5946f3d
```

Existing build provenance:

```text
workflow Build YT Music Y700 generic root
run 33836401680
commit 95f40ea271b2e810cc1c38096e1de1cd32165167
artifact 9923436810
module youtube-music-revanced-module-v9.15.51-arm64-v8a.zip
module SHA256 4d50b64fc48089ede0c8a2089948ead181980069ad485fdf2b56018d274579c0
```

Status on 2026-11-20: **data-preservation recovery pending**.

Do not blindly flash the module. Restore the exact stock package/splits with replace-only PackageInstaller semantics first, then re-establish the patched bind mount.

## General preservation rule for root-module apps

When a root module reports "App not installed" after a crash/reboot but `dumpsys package` and `/data/user/0/<pkg>` still exist:

1. stop before uninstalling;
2. save CE/DE data and decoded PackageManager metadata;
3. confirm appId/UID/version/signing lineage;
4. recover the exact stock split set;
5. perform replace-only install;
6. verify UID/inodes/data are unchanged;
7. only then restore the patched payload mount.

Do not use module installers that contain automatic uninstall fallback during rescue.


## 2026-11-20 post-recovery launch crash: exact `libelements.so` failure

After the stock 9.15.51 package was reconstructed with replace-only PackageInstaller semantics:

```text
source stock APK SHA256
a003ac2e673c2979b2268e5acfbfd74f88b93c4b75af5c7d604b3c7fb92768a4

appId remained 10405
CE inode remained 439750
DE inode remained 301907
versionCode remained 91551240
versionName remained 9.15.51
new /data/app codePath created
```

The existing Y700 ReVanced payload was then re-bound:

```text
payload SHA256
baefd91ef026e162ecec50533c9a3646a07b4e9d47251a5887ac9034b5946f3d

module Action:
* Enabled successfully

master base hash after mount:
baefd91ef026e162ecec50533c9a3646a07b4e9d47251a5887ac9034b5946f3d
```

Launch then crashed repeatedly with:

```text
Process: com.google.android.apps.youtube.music
java.lang.UnsatisfiedLinkError:
dlopen failed: library "libelements.so" not found

at java.lang.System.loadLibrary(...)
at jay.<clinit>(...)
```

This exactly matches a known upstream root/mount YouTube Music failure class documented by MorpheApp. Upstream issue #474 found the same `libelements.so` crash and reported that excluding `Spoof video streams` fixed the root/mount launch; the upstream maintainer noted that `Spoof video streams` was only needed for MicroG users.

The Y700 2026-09-04 build log confirms this payload did include:

```text
Applied: Spoof video streams
```

even though module mode explicitly excluded `GmsCore support`.

Important unresolved contradiction:

- the same historical payload hash `baefd91e...` had previously run on this Y700 before the package-code incident;
- therefore the current crash must not yet be simplified to "the payload is inherently broken";
- next check is whether the reconstructed stock install differs in native-library extraction/materialization under `/data/app/.../lib/arm64`, especially presence/absence of `libelements.so`.

Current status: **stock package identity/data preserved; ReVanced mount restored; launch blocked by exact native-library failure; no reboot/uninstall/clear-data performed.**


## Native-lib root cause pinned from original module installer

The original 2026-09-04 module source resolves the post-recovery launch failure directly.

In module build mode, `utils.sh` deliberately strips all native libraries from the APK before patching:

```sh
if [ "$build_mode" = module ]; then
    zip -d "$stock_apk_to_patch" "lib/*" >/dev/null 2>&1 || :
fi
```

The resulting patched payload therefore intentionally contains no `lib/arm64-v8a/*.so`.

The original module `customize.sh` compensates during installation by materializing the stock native libraries into the installed package code path:

```sh
BASEPATHLIB=${BASEPATH}/lib/${ARCH}
unzip -o -j "$MODPATH/stock/base.apk" "lib/${ARCH_LIB}/*" -d "$BASEPATHLIB"
set_perm_recursive "${BASEPATH}/lib" 1000 1000 755 755 u:object_r:apk_data_file:s0
```

Post-recovery observation:

```text
stock APK:
  lib/arm64-v8a/libelements.so present
  lib/arm64-v8a/libelements2.so present
  libcronet and libgoogle3 present

patched payload:
  no native libs by design

reconstructed /data/app/.../lib:
  empty
```

Therefore the current `libelements.so not found` crash is explained by the preservation recovery reproducing PackageInstaller replacement but not the original module installer's native-lib extraction stage.

This supersedes the earlier tentative hypothesis that `Spoof video streams` alone made the historical payload intrinsically unusable. The exact same payload previously worked because the required stock native libraries had been materialized by the original module installer.

Next repair scope is minimal: restore the stock arm64 native libraries into `/data/app/.../lib/arm64` with the same ownership/mode/SELinux context as `customize.sh`; do not uninstall, clear data, reboot, or rebuild yet.
