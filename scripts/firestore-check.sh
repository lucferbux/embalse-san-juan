#!/bin/bash
# Checks the published data and the access rules from outside, with no credentials.
set -uo pipefail

BASE='https://firestore.googleapis.com/v1/projects/embalse-san-juan/databases/(default)/documents'
failed=0
expect() {
    local label="$1" want="$2" got="$3"
    if [ "$got" = "$want" ]; then echo "ok    $label ($got)"; else echo "FAIL  $label: expected $want, got $got"; failed=1; fi
}
status() { curl -s -o /dev/null -w '%{http_code}' "$@"; }

expect "public/snapshot can be read" 200 "$(status "$BASE/public/snapshot")"
expect "public/history can be read" 200 "$(status "$BASE/public/history")"
expect "readings can't be read" 403 "$(status "$BASE/readings/2026-10-30")"
expect "meta can't be read" 403 "$(status "$BASE/meta/miteco")"
expect "public/snapshot can't be written" 403 "$(status -X PATCH -H 'Content-Type: application/json' -d '{"fields":{}}' "$BASE/public/snapshot")"
expect "public/snapshot can't be deleted" 403 "$(status -X DELETE "$BASE/public/snapshot")"
expect "new documents can't be created" 403 "$(status -X PATCH -H 'Content-Type: application/json' -d '{"fields":{}}' "$BASE/public/other")"

# Firestore documents are limited to 1 MiB.
size="$(curl -s "$BASE/public/history" | wc -c | tr -d ' ')"
if [ "$size" -lt 1000000 ]; then echo "ok    public/history is $size bytes"; else echo "FAIL  public/history is $size bytes"; failed=1; fi

age="$(curl -s "$BASE/public/snapshot" | jq -r '.fields.payload.stringValue | fromjson | .generatedAt | fromdate | now - . | floor')"
if [ "$age" -lt 10800 ]; then echo "ok    snapshot is $age s old"; else echo "FAIL  snapshot is $age s old: is the hourly job running?"; failed=1; fi
exit "$failed"
