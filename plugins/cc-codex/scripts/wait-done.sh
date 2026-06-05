#!/usr/bin/env bash
# wait-done.sh — Block until a Codex run finishes. Works the same whether the
# run is in a tmux pane or detached in the background.
#
# Usage: wait-done.sh <run-id> [max-seconds]
#   max-seconds: safety cap, default 3600. 0 = wait forever.

set -u
STATE_DIR="${CC_CODEX_STATE:-$HOME/.cc-codex/runs}"

ID="${1:-}"
MAX="${2:-3600}"
[[ -z "$ID" ]] && { echo "Usage: wait-done.sh <run-id> [max-seconds]" >&2; exit 2; }

DONE_FILE="$STATE_DIR/run-${ID}.done"
STATE_FILE="$STATE_DIR/run-${ID}.state"

elapsed=0
while [[ ! -f "$DONE_FILE" ]]; do
  sleep 1
  elapsed=$((elapsed + 1))
  if [[ "$MAX" -gt 0 && "$elapsed" -ge "$MAX" ]]; then
    echo "TIMEOUT after ${MAX}s (run may still be working)" >&2
    exit 124
  fi
done

CODE="$(cat "$DONE_FILE" 2>/dev/null || echo '?')"
STATUS="$( [[ -f "$STATE_FILE" ]] && ( source "$STATE_FILE"; echo "${STATUS:-unknown}" ) || echo unknown )"
echo "run-${ID} finished: ${STATUS} (exit ${CODE})"
[[ "$STATUS" == "failed" ]] && exit 1
exit 0
