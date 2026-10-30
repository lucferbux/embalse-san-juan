#!/usr/bin/env bash
# PostToolUse: quick feedback on the area just edited. `make check` remains the full check.
set -uo pipefail

path="$(jq -r '.tool_input.file_path // ""' <<<"$(cat)")"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

case "$path" in
  "$root"/backend/src/*|"$root"/backend/test/*)
    if ! output="$(cd "$root/backend" && npm run -s typecheck 2>&1)"; then
      echo "$output" >&2
      exit 2
    fi
    ;;
  "$root"/contract/*)
    echo "Contract changed: update backend/src/domain/types.ts and the Swift models, then run make fixture." >&2
    exit 2
    ;;
  "$root"/ios/project.yml)
    echo "project.yml changed: run make generate." >&2
    ;;
esac
exit 0
