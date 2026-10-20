#!/usr/bin/env bash
# codex-watchdog.sh — Stall detector for a background Codex task.
# codex-watchdog.sh —— 后台 Codex 任务的卡死检测脚本。
#
# Polls the job quietly and prints a line for the Monitor tool only when the
# task looks stuck. Exits silently when the job ends (codex-wait.sh reports it).
#
# Output lines:
#   STUCK|no log output for <sec>s|log=<path>
#   STUCK|repeated error x<count>: <line>|log=<path>
#   ERROR|<message>
#
# Usage:
#   bash codex-watchdog.sh --job-id <id> [--interval <sec>] [--stall <sec>] [--repeat <count>]
#     --interval  poll period, default 60
#     --stall     seconds without new log output before reporting, default 900
#     --repeat    occurrences of the same error line in the last 80 log lines, default 8

set -u
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

INTERVAL=60
STALL=900
REPEAT=8
JOB_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --job-id)   JOB_ID="$2";   shift 2 ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    --stall)    STALL="$2";    shift 2 ;;
    --repeat)   REPEAT="$2";   shift 2 ;;
    *)          shift 2 ;;
  esac
done

[[ -n "$JOB_ID" ]] || { echo "ERROR|missing required --job-id"; exit 1; }

COMPANION="$(cc_find_companion)"
[[ -n "$COMPANION" ]] || { echo "ERROR|codex companion script not found"; exit 1; }
export CLAUDE_PLUGIN_DATA="$(cc_plugin_data)"

last_size=-1
last_change=$(date +%s)
stall_reported=0
reported_errors=""
status_failures=0

while true; do
  sleep "$INTERVAL"

  # One line: "<status>\t<logFile>"
  # 一行输出：「状态\t日志路径」
  INFO="$(node "$COMPANION" status "$JOB_ID" --json 2>/dev/null | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    job = d.get("job") or d
    print(job.get("status", "unknown") + "\t" + str(job.get("logFile") or ""))
except Exception:
    pass
')"

  if [[ -z "$INFO" ]]; then
    status_failures=$((status_failures + 1))
    if [[ $status_failures -eq 3 ]]; then
      echo "ERROR|status check failed 3 times for job ${JOB_ID}"
    fi
    continue
  fi
  status_failures=0

  JOB_STATUS="${INFO%%$'\t'*}"
  LOG_FILE="${INFO#*$'\t'}"

  case "$JOB_STATUS" in
    queued|running) ;;
    *) exit 0 ;;
  esac

  [[ -n "$LOG_FILE" && -f "$LOG_FILE" ]] || continue
  now=$(date +%s)

  # Stall: the log has not grown for STALL seconds.
  # 卡住：日志超过 STALL 秒没有新增内容。
  size=$(wc -c < "$LOG_FILE")
  if [[ "$size" -ne "$last_size" ]]; then
    last_size=$size
    last_change=$now
    stall_reported=0
  elif [[ $stall_reported -eq 0 && $((now - last_change)) -ge $STALL ]]; then
    echo "STUCK|no log output for $((now - last_change))s|log=${LOG_FILE}"
    stall_reported=1
  fi

  # Loop: the same error line repeats REPEAT+ times in the recent log; each distinct line is reported once.
  # 死循环：同一条错误在最近日志里重复 REPEAT 次以上；每条不同的错误只报告一次。
  top="$(tail -n 80 "$LOG_FILE" | grep -iE 'error|fail|exception|denied|retry' \
    | sort | uniq -c | sort -rn | head -n 1)"
  if [[ -n "$top" ]]; then
    count=$(echo "$top" | awk '{print $1}')
    line="$(echo "$top" | sed -E 's/^ *[0-9]+ //' | cut -c1-160)"
    if [[ "$count" -ge "$REPEAT" && "$reported_errors" != *"$line"* ]]; then
      echo "STUCK|repeated error x${count}: ${line}|log=${LOG_FILE}"
      reported_errors="${reported_errors}"$'\n'"${line}"
    fi
  fi
done
