#!/usr/bin/env bash
set -euo pipefail

git clone --depth 1 https://github.com/andrewliang25/morphe-patches.git /tmp/morphe-patches

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
                // Wallet -> LINE Pay home uses line://pay/main and has no reserve id.
                if (isMainPay(extraUri) || isMainPay(dataString)) {
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
helper = """    private static boolean isMainPay(String url) {
        if (url == null || url.isEmpty()) return false;
        return url.startsWith("line://pay/main") || url.contains("/pay/main");
    }

    private static boolean openStandaloneMain(Activity activity) {
        if (activity == null) return false;
        try {
            Intent launch = activity.getPackageManager().getLaunchIntentForPackage("com.linepaytw.upay");
            if (launch == null) {
                launch = new Intent(Intent.ACTION_MAIN);
                launch.addCategory(Intent.CATEGORY_LAUNCHER);
                launch.setPackage("com.linepaytw.upay");
            }
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            activity.startActivity(launch);
            Log.i(TAG, "Redirecting LINE Pay main to standalone app.");
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
./gradlew :patches:buildAndroid clean --no-daemon
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
  '[Tab] Hide Wallet tab' \
  """
archive-dlurl = "https://archive.org/download/andrews-apks/apks/jp.naver.line.android"
apkmirror-dlurl = "https://www.apkmirror.com/apk/line-corporation/line"
uptodown-dlurl = "https://line.en.uptodown.com/android"
EOF

export CUSTOM_LINE_MPP=/tmp/line-mainpay-custom.mpp
export NEXT_VER_CODE=13
export GITHUB_REPOSITORY=MeowGod8777/patched-apps
./build.sh /tmp/line-config.toml

ZIP=build/line-andrew-module-v26.14.0-arm64-v8a.zip
test -s "$ZIP"
sha256sum "$ZIP" | tee "$ZIP.sha256"

TAG=line-mainpay-r13
gh release delete "$TAG" --yes --cleanup-tag 2>/dev/null || true
gh release create "$TAG"   "$ZIP"   "$ZIP.sha256"   /tmp/line-mainpay-custom.mpp   --title "LINE 26.14 Andrew R13 main-pay redirect"   --notes "Same selected patch policy as Release 12, with Redirect LINE Pay extended so Wallet -> LINE Pay (line://pay/main) launches the standalone Taiwan LINE Pay app. Merchant reserveId redirect is unchanged."
