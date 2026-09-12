#!/usr/bin/env bash
set -euo pipefail

apk="${1:?Pass the packaged APK path}"
test -f "$apk"
test -n "${ANDROID_KEYSTORE_BASE64:-}"
test -n "${ANDROID_KEYSTORE_PASSWORD:-}"
test -n "${ANDROID_KEY_ALIAS:-}"
test -n "${ANDROID_KEY_PASSWORD:-}"
test -n "${RUNNER_TEMP:-}"
test -n "${ANDROID_HOME:-}"

keystore="$RUNNER_TEMP/gomoku-release.jks"
signed="$RUNNER_TEMP/gomoku-release-signed.apk"
trap 'rm -f "$keystore" "$signed" "$signed.idsig"' EXIT
umask 077
printf '%s' "$ANDROID_KEYSTORE_BASE64" | base64 --decode > "$keystore"
build_tools="$(find "$ANDROID_HOME/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n 1)"
test -x "$build_tools/apksigner"
"$build_tools/zipalign" -c -P 16 4 "$apk"
"$build_tools/apksigner" sign \
  --ks "$keystore" \
  --ks-key-alias "$ANDROID_KEY_ALIAS" \
  --ks-pass env:ANDROID_KEYSTORE_PASSWORD \
  --key-pass env:ANDROID_KEY_PASSWORD \
  --out "$signed" "$apk"
"$build_tools/zipalign" -c -P 16 4 "$signed"
"$build_tools/apksigner" verify --verbose --print-certs "$signed" | tee "$(dirname "$apk")/android-signature.txt"
grep -F 'Signer #1 certificate SHA-256 digest: c5bbb8806b7034dbc4ab65652c3f89839f057d782df31ece4e8125f5792e5333' "$(dirname "$apk")/android-signature.txt"
badging="$("$build_tools/aapt2" dump badging "$signed")"
version="$(sed -n 's/^version: \([^+]*\)+.*/\1/p' apps/gomoku_app/pubspec.yaml | tr -d '\r')"
build="$(sed -n 's/^version: [^+]*+\([0-9]*\).*/\1/p' apps/gomoku_app/pubspec.yaml | tr -d '\r')"
grep -F "package: name='com.xqd922.gomoku'" <<< "$badging"
grep -F "versionCode='$build'" <<< "$badging"
grep -F "versionName='$version'" <<< "$badging"
test "$build" -gt 3000
cp "$signed" "$apk"
echo 'Release APK signature, package identity, version and alignment verified.'
