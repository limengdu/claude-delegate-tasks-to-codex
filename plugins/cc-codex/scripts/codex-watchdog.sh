#!/usr/bin/env bash
# codex-watchdog.sh — Periodic health-check timer for a background Codex task.
# codex-watchdog.sh —— 后台 Codex 任务的定时健康检查脚本。
#
# Outputs one line per interval for the Monitor tool. Each line triggers Claude
# to read Codex logs and assess whether the task is stuck.
#
# Usage:
#   bash codex-watchdog.sh --job-id <id> [--companion <path>] [--plugin-data <dir>] [--interval <sec>]

set -u

INTERVAL=600
JOB_ID=""
COMPANION=""
PLUGIN_DATA=""

# ---------------------------------------------------------------------------
# Argument parsing
# 参数解析
# ---------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
  case "$1" in
    --job-id)      JOB_ID="$2";      shift 2 ;;
    --companion)   COMPANION="$2";   shift 2 ;;
    --plugin-data) PLUGIN_DATA="$2"; shift 2 ;;
    --interval)    INTERVAL="$2";    shift 2 ;;
    *)             shift ;;
  esac
done

# ---------------------------------------------------------------------------
# Resolve companion script path if not provided.
# 如果未指定 companion 路径，自动查找。
# ---------------------------------------------------------------------------

find_codex_companion() {
  if [[ -n "${CC_CODEX_HUD_COMPANION:-}" && -f "${CC_CODEX_HUD_COMPANION}" ]]; then
    echo "${CC_CODEX_HUD_COMPANION}"
    return
  fi

  find "${HOME}/.claude/plugins/cache" \
    -path "*/openai-codex/codex/*/scripts/codex-companion.mjs" \
    -type f 2>/dev/null | sort -r | head -1
}

# ---------------------------------------------------------------------------
# Resolve Codex plugin data directory if not provided.
# 如果未指定 plugin-data 路径，自动查找。
# ---------------------------------------------------------------------------

find_codex_plugin_data() {
  if [[ -d "${HOME}/.claude/plugins/data/codex-openai-codex" ]]; then
    echo "${HOME}/.claude/plugins/data/codex-openai-codex"
    return
  fi

  find "${HOME}/.claude/plugins/data" -maxdepth 1 -name "*codex*" -type d 2>/dev/null | sort -r | head -1
}

# ---------------------------------------------------------------------------
# Validate required arguments.
# 校验必要参数。
# ---------------------------------------------------------------------------

if [[ -z "$JOB_ID" ]]; then
  echo "ERROR|missing required --job-id"
  exit 1
fi

if [[ -z "$COMPANION" ]]; then
  COMPANION=$(find_codex_companion)
fi

if [[ -z "$COMPANION" || ! -f "$COMPANION" ]]; then
  echo "ERROR|codex companion script not found"
  exit 1
fi

if [[ -z "$PLUGIN_DATA" ]]; then
  PLUGIN_DATA=$(find_codex_plugin_data)
fi

# ---------------------------------------------------------------------------
# Main loop: sleep → check status → output event line.
# 主循环：休眠 → 检查状态 → 输出事件行。
# ---------------------------------------------------------------------------

while true; do
  sleep "$INTERVAL"

  if [[ -n "$PLUGIN_DATA" ]]; then
    STATUS_JSON=$(CLAUDE_PLUGIN_DATA="$PLUGIN_DATA" node "$COMPANION" status "$JOB_ID" --json 2>/dev/null || echo "")
  else
    STATUS_JSON=$(node "$COMPANION" status "$JOB_ID" --json 2>/dev/null || echo "")
  fi

  if [[ -z "$STATUS_JSON" ]]; then
    echo "HEALTH_CHECK|{\"error\":\"status check failed\",\"jobId\":\"$JOB_ID\"}"
    continue
  fi

  JOB_STATUS=$(echo "$STATUS_JSON" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    job = d.get('job', d)
    print(job.get('status', 'unknown'))
except Exception:
    print('unknown')
" 2>/dev/null || echo "unknown")

  case "$JOB_STATUS" in
    completed|failed|cancelled)
      echo "FINISHED|$JOB_STATUS|$STATUS_JSON"
      exit 0
      ;;
    *)
      echo "HEALTH_CHECK|$STATUS_JSON"
      ;;
  esac
done
