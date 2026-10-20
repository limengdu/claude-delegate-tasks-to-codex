#!/usr/bin/env bash
# codex-wait.sh — Block until a Codex job ends, then print a compact report:
# final status, Codex's final message (capped) and the working-tree changes.
# codex-wait.sh —— 等待 Codex 任务结束，然后输出精简报告：最终状态、Codex 最终回复（限长）、工作区改动。
#
# Usage: codex-wait.sh <job-id> [timeout-ms]
#   timeout-ms: default 7200000 (2h). Exit 3 if the job is still running then.
#   CC_CODEX_RESULT_MAX: max bytes of the result to print, default 4000.

set -u
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

JOB_ID="${1:-}"
TIMEOUT_MS="${2:-7200000}"
RESULT_MAX="${CC_CODEX_RESULT_MAX:-4000}"
[[ -n "$JOB_ID" ]] || { echo "Usage: codex-wait.sh <job-id> [timeout-ms]" >&2; exit 2; }

COMPANION="$(cc_find_companion)"
[[ -n "$COMPANION" ]] || { echo "ERROR: Codex companion not found. Run /codex:setup." >&2; exit 1; }
export CLAUDE_PLUGIN_DATA="$(cc_plugin_data)"

STATUS="$(node "$COMPANION" status "$JOB_ID" --wait --timeout-ms "$TIMEOUT_MS" --json 2>/dev/null \
  | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    print((d.get("job") or d).get("status", "unknown"))
except Exception:
    print("unknown")
')"

case "$STATUS" in
  queued|running)
    echo "RUNNING job=${JOB_ID} (wait timed out; run codex-wait.sh again)"
    exit 3 ;;
esac

echo "job ${JOB_ID} finished: ${STATUS}"

echo "--- result ---"
RESULT="$(node "$COMPANION" result "$JOB_ID" 2>&1)"
printf '%s\n' "$RESULT" | head -c "$RESULT_MAX"
echo
SIZE=${#RESULT}
[[ "$SIZE" -gt "$RESULT_MAX" ]] && echo "[truncated at ${RESULT_MAX}/${SIZE} chars; full: node <companion> result ${JOB_ID}]"

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "--- changes (git status / diff --stat; includes edits made before this job) ---"
  git status --short | head -n 40
  git diff --stat | tail -n 1
fi

[[ "$STATUS" == "completed" ]] || exit 1
exit 0
