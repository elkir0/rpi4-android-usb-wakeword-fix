#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
apex_path=${APEX_PATH:-"$project_dir/artifacts/com.android.hardware.audio.rpi-input-sync-rpi4.apex"}
apk_path=${ROUTE_APK_PATH:-"$project_dir/diagnostics/speech-test/app/build/outputs/apk/debug/app-debug.apk"}
dist_dir=${DIST_DIR:-"$project_dir/dist"}
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/rpi4-wakeword-release.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT

stock_apex_sha=27b5332e841f50e6b3435b5b512c86981443764e54a517262976bc98f0b587f3
validated_apex_sha=a8c735ede091b92770cb74162baaa826c69708a26d7fce0d59d62b082d989ccc
validated_stock_policy_sha=29d18b8e3ca51dc1f6e54fd39886a60e2372a9e1f610ae9d285311e312b732d5
validated_patched_policy_sha=bb1c738411bd04e612cd5b907fef7674e34b9f939456f4fc33430f9b2b8153a9

patched_policy="$project_dir/recovery/policy/usb_audio_policy_configuration.patched.xml"
stock_policy="$project_dir/recovery/policy/usb_audio_policy_configuration.stock.xml"
rc_file="$project_dir/diagnostics/audio-policy/usb-mic-runtime.rc"
runtime_file="$project_dir/diagnostics/audio-policy/usb-mic-runtime.sh"

sha256_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

normalize_tree_times() {
    find "$1" -exec touch -t 202605200000 {} +
}

require_file() {
    if [[ ! -s "$1" ]]; then
        printf 'Fichier requis absent ou vide: %s\n' "$1" >&2
        exit 1
    fi
}

require_hash() {
    local path=$1 expected=$2 actual
    actual=$(sha256_file "$path")
    if [[ "$actual" != "$expected" ]]; then
        printf 'SHA-256 inattendu pour %s\nAttendu: %s\nObtenu: %s\n' \
            "$path" "$expected" "$actual" >&2
        exit 1
    fi
}

for required in "$apex_path" "$apk_path" "$patched_policy" "$stock_policy" \
    "$rc_file" "$runtime_file"; do
    require_file "$required"
done

require_hash "$apex_path" "$validated_apex_sha"
require_hash "$stock_policy" "$validated_stock_policy_sha"
require_hash "$patched_policy" "$validated_patched_policy_sha"

patched_apex_sha=$(sha256_file "$apex_path")
patched_policy_sha=$(sha256_file "$patched_policy")
stock_policy_sha=$(sha256_file "$stock_policy")
rc_sha=$(sha256_file "$rc_file")
runtime_sha=$(sha256_file "$runtime_file")
apk_sha=$(sha256_file "$apk_path")

install_stage="$work_dir/install"
rollback_stage="$work_dir/rollback"
bundle_stage="$work_dir/bundle"
mkdir -p "$install_stage/META-INF/com/google/android" "$install_stage/payload" \
    "$rollback_stage/META-INF/com/google/android" "$rollback_stage/payload" \
    "$bundle_stage"

render_template() {
    sed \
        -e "s|@STOCK_APEX_SHA256@|$stock_apex_sha|g" \
        -e "s|@PATCHED_APEX_SHA256@|$patched_apex_sha|g" \
        -e "s|@STOCK_POLICY_SHA256@|$stock_policy_sha|g" \
        -e "s|@PATCHED_POLICY_SHA256@|$patched_policy_sha|g" \
        -e "s|@RC_SHA256@|$rc_sha|g" \
        -e "s|@RUNTIME_SHA256@|$runtime_sha|g" \
        -e "s|@APK_SHA256@|$apk_sha|g" \
        "$1" > "$2"
    if grep -q '@[A-Z_]*@' "$2"; then
        printf 'Placeholder non remplace dans %s\n' "$2" >&2
        exit 1
    fi
}

render_template \
    "$project_dir/recovery/install/META-INF/com/google/android/update-binary" \
    "$install_stage/META-INF/com/google/android/update-binary"
cp "$project_dir/recovery/install/META-INF/com/google/android/updater-script" \
    "$install_stage/META-INF/com/google/android/updater-script"
cp "$apex_path" "$install_stage/payload/com.android.hardware.audio.rpi.apex"
cp "$patched_policy" "$install_stage/payload/usb_audio_policy_configuration.xml"
cp "$rc_file" "$install_stage/payload/usb-mic-runtime.rc"
cp "$runtime_file" "$install_stage/payload/usb-mic-runtime.sh"
cp "$apk_path" "$install_stage/payload/usb-mic-route.apk"

render_template \
    "$project_dir/recovery/rollback/META-INF/com/google/android/update-binary" \
    "$rollback_stage/META-INF/com/google/android/update-binary"
cp "$project_dir/recovery/rollback/META-INF/com/google/android/updater-script" \
    "$rollback_stage/META-INF/com/google/android/updater-script"
cp "$stock_policy" \
    "$rollback_stage/payload/usb_audio_policy_configuration.stock.xml"

chmod 0755 "$install_stage/META-INF/com/google/android/update-binary" \
    "$rollback_stage/META-INF/com/google/android/update-binary"
normalize_tree_times "$install_stage"
normalize_tree_times "$rollback_stage"

rm -rf "$dist_dir"
mkdir -p "$dist_dir"

install_zip="$dist_dir/install-rpi4-android-usb-wakeword-fix.zip"
rollback_zip="$dist_dir/rollback-rpi4-android-usb-wakeword-fix.zip"
bundle_zip="$dist_dir/rpi4-android-usb-wakeword-fix-lineageos23.2-20260520-test1.zip"

(
    cd "$install_stage"
    zip -X -q -r "$install_zip" META-INF payload
)
(
    cd "$rollback_stage"
    zip -X -q -r "$rollback_zip" META-INF payload
)

unzip -tq "$install_zip" >/dev/null
unzip -tq "$rollback_zip" >/dev/null

for spec in \
    "payload/com.android.hardware.audio.rpi.apex:$patched_apex_sha" \
    "payload/usb_audio_policy_configuration.xml:$patched_policy_sha" \
    "payload/usb-mic-runtime.rc:$rc_sha" \
    "payload/usb-mic-runtime.sh:$runtime_sha" \
    "payload/usb-mic-route.apk:$apk_sha"; do
    member=${spec%%:*}
    expected=${spec##*:}
    actual=$(unzip -p "$install_zip" "$member" | \
        { if command -v sha256sum >/dev/null 2>&1; then sha256sum; else shasum -a 256; fi; } | \
        awk '{print $1}')
    [[ "$actual" == "$expected" ]] || {
        printf 'Payload invalide dans le ZIP: %s\n' "$member" >&2
        exit 1
    }
done

cp "$install_zip" "$rollback_zip" "$bundle_stage/"
cp "$project_dir/docs/COMPATIBILITE-RELEASE-FR.txt" "$bundle_stage/LISEZ-MOI-FR.txt"
cp "$project_dir/LICENSE" "$project_dir/NOTICE" "$bundle_stage/"
(
    cd "$bundle_stage"
    for file in install-rpi4-android-usb-wakeword-fix.zip \
        rollback-rpi4-android-usb-wakeword-fix.zip LISEZ-MOI-FR.txt LICENSE NOTICE; do
        printf '%s  %s\n' "$(sha256_file "$file")" "$file"
    done > PACKAGE-SHA256SUMS
    normalize_tree_times .
    zip -X -q -r "$bundle_zip" .
)
unzip -tq "$bundle_zip" >/dev/null

(
    cd "$dist_dir"
    for file in install-rpi4-android-usb-wakeword-fix.zip \
        rollback-rpi4-android-usb-wakeword-fix.zip \
        rpi4-android-usb-wakeword-fix-lineageos23.2-20260520-test1.zip; do
        printf '%s  %s\n' "$(sha256_file "$file")" "$file"
    done > SHA256SUMS
)

if unzip -l "$install_zip" | grep -q 'stock.*\.apex'; then
    printf 'ERREUR: un APEX stock semble present dans le package public.\n' >&2
    exit 1
fi

printf 'Release construite et verifiee dans %s\n' "$dist_dir"
cat "$dist_dir/SHA256SUMS"
