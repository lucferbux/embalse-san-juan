#!/usr/bin/env bash
# PreToolUse: blocks writing service account keys into the project.
set -euo pipefail

input="$(cat)"
path="$(jq -r '.tool_input.file_path // ""' <<<"$input")"
content="$(jq -r '(.tool_input.content // "") + (.tool_input.new_string // "")' <<<"$input")"

if [[ "$path" =~ (service-account|firebase-adminsdk).*\.json$ ]]; then
  echo "Blocked: $path looks like a service account key. It belongs only in the GitHub secret." >&2
  exit 2
fi
if grep -qE 'BEGIN (RSA )?PRIVATE KEY' <<<"$content" && [[ "$path" != *guard-secrets.sh ]]; then
  echo "Blocked: this content contains a private key." >&2
  exit 2
fi
