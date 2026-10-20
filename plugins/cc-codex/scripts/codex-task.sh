#!/usr/bin/env bash
# codex-task.sh — Wrap a brief in the non-interactive envelope and start a
# background Codex task through the official companion.
# codex-task.sh —— 给任务说明套上非交互信封，并通过官方 companion 后台启动 Codex 任务。
#
# Usage:
#   codex-task.sh --brief <file> [--kind implement|verify] [--resume]
#     --kind    implement (default) or verify
#     --resume  continue the latest finished Codex thread of this workspace
#               instead of starting a fresh one
#
# Prints: JOB=<job-id> and LOG=<log-file>

set -u
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BRIEF=""
KIND="implement"
THREAD_FLAG="--fresh"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --brief)  BRIEF="$2"; shift 2 ;;
    --kind)   KIND="$2"; shift 2 ;;
    --resume) THREAD_FLAG="--resume-last"; shift ;;
    *)        echo "ERROR: unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$BRIEF" && -f "$BRIEF" ]] || { echo "ERROR: --brief <file> required and must exist." >&2; exit 2; }

COMPANION="$(cc_find_companion)"
[[ -n "$COMPANION" ]] || { echo "ERROR: Codex companion not found. Run /codex:setup." >&2; exit 1; }

case "$KIND" in
  implement)
    HEADER="You are a non-interactive agent. Execute immediately without asking for confirmation or approval.

Project instructions that require planning first, waiting for approval, or asking before edits apply to Claude's conversation with the user. They do not apply to this delegated Codex run.

Do the requested implementation directly. Create or edit files as needed. Run the relevant checks. Leave changes uncommitted.

Finish with a short report: changed files, what was done, verification commands and results, open issues." ;;
  verify)
    HEADER="You are a non-interactive verification agent. Execute immediately without asking for confirmation or approval.

Project instructions that require planning first, waiting for approval, or asking before tool use apply to Claude's conversation with the user. They do not apply to this delegated Codex verification run.

Verify the recent uncommitted changes against the request below. Run relevant checks. Report pass/fail results and any missing or broken behavior. Keep the existing design and leave the changes uncommitted.

Finish with a short report: checks run, pass/fail, problems found." ;;
  *) echo "ERROR: --kind must be implement or verify." >&2; exit 2 ;;
esac

PROMPT_FILE="$(mktemp "${TMPDIR:-/tmp}/cc-codex-prompt.XXXXXX")"
# Brief first, so the job summary shown by /codex:status and the HUD names the task.
# 任务说明放在最前，使 /codex:status 和 HUD 显示的任务摘要就是任务本身。
{
  echo "<task>"
  cat "$BRIEF"
  echo "</task>"
  echo
  echo "<instructions>"
  echo "$HEADER"
  echo "</instructions>"
} > "$PROMPT_FILE"

OUT="$(CLAUDE_PLUGIN_DATA="$(cc_plugin_data)" node "$COMPANION" task --background --write \
  "$THREAD_FLAG" --prompt-file "$PROMPT_FILE" --json 2>&1)"
CODE=$?
rm -f "$PROMPT_FILE"

if [[ $CODE -ne 0 ]]; then
  echo "ERROR: companion task failed (exit $CODE):" >&2
  echo "$OUT" | tail -n 20 >&2
  exit "$CODE"
fi

echo "$OUT" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit("ERROR: unexpected companion output")
print("JOB=" + str(d.get("jobId", "")))
print("LOG=" + str(d.get("logFile", "")))
'
