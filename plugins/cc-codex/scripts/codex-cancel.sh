#!/usr/bin/env bash
# codex-cancel.sh — Cancel a background Codex job.
# codex-cancel.sh —— 取消一个后台 Codex 任务。
#
# Usage: codex-cancel.sh <job-id>

set -u
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

JOB_ID="${1:-}"
[[ -n "$JOB_ID" ]] || { echo "Usage: codex-cancel.sh <job-id>" >&2; exit 2; }

COMPANION="$(cc_find_companion)"
[[ -n "$COMPANION" ]] || { echo "ERROR: Codex companion not found. Run /codex:setup." >&2; exit 1; }

CLAUDE_PLUGIN_DATA="$(cc_plugin_data)" node "$COMPANION" cancel "$JOB_ID"
