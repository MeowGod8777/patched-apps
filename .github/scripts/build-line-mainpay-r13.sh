#!/usr/bin/env bash
set -euo pipefail

git clone --depth 1 --branch v3.10.0 https://github.com/andrewliang25/morphe-patches.git /tmp/morphe-patches

python3 - <<'PY'
from pathlib import Path
p=Path("/tmp/morphe-patches/extensions/extension/src/main/java/app/andrewliang/extension/LinePayRedirect.java")
s=p.read_text()
old = """            if (inner == null) {
                // Not a recognizable payment deep link (e.g. line://pay/main). Caller finishes.
                Log.i(TAG, "Pay intent on " + name(activity) + ": no reserve id, skipping redirect.");
                return;
            }
"""
new = """            if (inner == null) {
                // Device validation shows Wallet -> LINE Pay reaches PayLaunchActivity with
                // an unrecognized line://pay/... URI and no reserve id. Redirect that activity
                // class directly instead of guessing the exact URI shape.
                if (isPayLaunchActivity(activity)) {
                    if (openStandaloneMain(activity)) return;
                }
                Log.i(TAG, "Pay intent on " + name(activity) + ": no reserve id, skipping redirect.");
                return;
            }
"""
if old not in s:
    raise SystemExit("target redirect block not found")
s=s.replace(old,new,1)
marker = """    private static String firstNonNull(String a, String b) {
        return a != null ? a : b;
    }
"""
helper = """    private static boolean isPayLaunchActivity(Activity activity) {
        return activity != null &&
            "com.linecorp.line.pay.base.PayLaunchActivity".equals(activity.getClass().getName());
    }

    private static boolean openStandaloneMain(Activity activity) {
        if (activity == null) return false;
        try {
            // HMA now explicitly exposes com.linepaytw.upay to LINE. Launch the verified
            // standalone LINE Pay entry directly; the previous empty web wrapper
            // (https://web-tw-pay.line.me/R/iab?url=) could open LINE Pay into a blank page.
            Intent launch = new Intent(Intent.ACTION_MAIN);
            launch.addCategory(Intent.CATEGORY_LAUNCHER);
            launch.setClassName("com.linepaytw.upay", "com.linepaytw.upay.biz.main.LaunchActivity");
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            activity.startActivity(launch);
            Log.i(TAG, "Redirecting PayLaunchActivity to standalone LINE Pay launcher.");
            return true;
        } catch (Throwable t) {
            Log.w(TAG, "LINE Pay main redirect failed.", t);
            return false;
        }
    }

""" + marker
if marker not in s:
    raise SystemExit("helper marker not found")
s=s.replace(marker,helper,1)
p.write_text(s)
PY

pushd /tmp/morphe-patches >/dev/null
./gradlew clean :patches:buildAndroid --no-daemon
MPP=$(ls patches/build/libs/patches-*.mpp | grep -Ev '(sources|javadoc)' | head -n1)
cp "$MPP" /tmp/line-mainpay-custom.mpp
popd >/dev/null
sha256sum /tmp/line-mainpay-custom.mpp

python3 - <<'PY'
from pathlib import Path
p=Path("build.sh")
s=p.read_text()
needle='read -r patches_jar cli_jar <<<"$PREBUILTS"'
repl=needle+'\n\tif [ "$table_name" = "LINE-Andrew" ] && [ -n "${CUSTOM_LINE_MPP-}" ]; then patches_jar="$CUSTOM_LINE_MPP"; fi'
if needle not in s:
    raise SystemExit("build.sh hook point not found")
p.write_text(s.replace(needle,repl,1))
PY

cat >/tmp/line-config.toml <<'EOF'
enable-module-update = false
parallel-jobs = 1

[LINE-Andrew]
app-name = "LINE"
patches-source = "andrewliang25/morphe-patches"
cli-source = "MorpheApp/morphe-cli"
rv-brand = "Andrew"
build-mode = "module"
version = "26.14.0"
arch = "arm64-v8a"
include-stock = "auto"
excluded-patches = """\
  '[Chat] Hide Events button' \
  '[Chat] Hide LINE GIFT button' \
  '[Chat] Hide Transfer button' \
  '[Chat] Hide attach menu extra tools' \
  '[Chat] Hide calendar buttons' \
  '[Chat] Hide community button' \
  '[Chat] Keep chats unread' \
  '[Fix] Restore chat backup sign-in via MicroG-RE' \
  '[Fix] Restore location maps via MicroG-RE' \
  '[Fix] Restore push notifications' \
  '[General] Custom font' \
  '[Premium] Disable LINE Premium' \
  '[Tab] Hide Wallet tab' \
  """
archive-dlurl = "https://archive.org/download/andrews-apks/apks/jp.naver.line.android"
apkmirror-dlurl = "https://www.apkmirror.com/apk/line-corporation/line"
uptodown-dlurl = "https://line.en.uptodown.com/android"
EOF

export CUSTOM_LINE_MPP=/tmp/line-mainpay-custom.mpp
export NEXT_VER_CODE=18
export GITHUB_REPOSITORY=MeowGod8777/patched-apps
./build.sh /tmp/line-config.toml

ZIP=build/line-andrew-module-v26.14.0-arm64-v8a.zip
test -s "$ZIP"
sha256sum "$ZIP" | tee "$ZIP.sha256"

TAG=line-mainpay-r18
gh release delete "$TAG" --yes --cleanup-tag 2>/dev/null || true
gh release create "$TAG"   "$ZIP"   "$ZIP.sha256"   /tmp/line-mainpay-custom.mpp   --title "LINE 26.14 Andrew R18 / Andrew v3.10.0"   --notes "R18 refresh on Andrew morphe-patches v3.10.0, still targeting LINE 26.14.0. Preserves the device-validated direct standalone LINE Pay launcher fallback and the existing selected patch policy. Adds Andrew's Patch Setting and current upstream improvements such as the enhanced Hide Agent i and Keep unsent behavior. [General] Custom font remains excluded because this device uses the system font; [Premium] Disable LINE Premium remains excluded."
