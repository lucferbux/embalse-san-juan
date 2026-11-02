#!/bin/bash
# Builds the signed Android App Bundle for Google Play. Bump versionCode in android/app/build.gradle.kts first:
# Play never accepts the same one twice. Nothing here uploads or publishes.
#
# The upload key lives outside the repo and its password in the macOS Keychain. Both are created on the first run.
# Google holds the key that signs what users install (Play App Signing), so a lost upload key can be replaced
# from Play Console.
set -euo pipefail

cd "$(dirname "$0")/.."
: "${JAVA_HOME:=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home}"
export JAVA_HOME
KEYSTORE="$HOME/.config/embalse-san-juan/upload.jks"
SERVICE="embalse-san-juan-upload-key"

if [ ! -f "$KEYSTORE" ]; then
    mkdir -p "$(dirname "$KEYSTORE")"
    security add-generic-password -a "$USER" -s "$SERVICE" -w "$(openssl rand -hex 32)"
    UPLOAD_KEYSTORE_PASSWORD="$(security find-generic-password -a "$USER" -s "$SERVICE" -w)" \
        "$JAVA_HOME/bin/keytool" -genkeypair -keystore "$KEYSTORE" -storetype PKCS12 -alias upload \
        -keyalg RSA -keysize 4096 -validity 10000 -dname "CN=lucferbux, C=ES" -storepass:env UPLOAD_KEYSTORE_PASSWORD
    chmod 600 "$KEYSTORE"
fi

export UPLOAD_KEYSTORE="$KEYSTORE"
UPLOAD_KEYSTORE_PASSWORD="$(security find-generic-password -a "$USER" -s "$SERVICE" -w)"
export UPLOAD_KEYSTORE_PASSWORD

cd android
./gradlew --quiet testDebugUnitTest bundleRelease
ls -lh app/build/outputs/bundle/release/app-release.aab
