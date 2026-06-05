#!/usr/bin/env bash
# hud.sh — Live dashboard for Codex task progress.
# Replaces wait-done.sh as the primary monitoring tool.
# Shows all tasks, refreshes every 3s, exits when all tasks finish.
#
# Usage:
#   hud.sh              # watch all runs
#   hud.sh 1 3 5        # watch specific run IDs only
#   hud.sh --once       # print once and exit (no loop)

set -u

STATE_DIR="${CC_CODEX_STATE:-$HOME/.cc-codex/runs}"
REFRESH=3
ONCE=false
WATCH_IDS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --once) ONCE=true; shift ;;
    *)      WATCH_IDS+=("$1"); shift ;;
  esac
done

# -- helpers --

elapsed_since() {
  local started="$1"
  local now_s; now_s=$(date '+%s')
  local start_s; start_s=$(date -j -f '%H:%M:%S' "$started" '+%s' 2>/dev/null || echo "$now_s")
  # Handle day rollover
  if [[ "$start_s" -gt "$now_s" ]]; then
    start_s=$((start_s - 86400))
  fi
  local diff=$((now_s - start_s))
  local m=$((diff / 60))
  local s=$((diff % 60))
  printf '%dm%02ds' "$m" "$s"
}

status_icon() {
  case "$1" in
    running) printf '\033[33m⚙  running\033[0m' ;;
    done)    printf '\033[32m✅ done   \033[0m' ;;
    failed)  printf '\033[31m❌ failed \033[0m' ;;
    *)       printf '\033[90m?  %-7s\033[0m' "$1" ;;
  esac
}

truncate_str() {
  local s="$1" max="$2"
  if [[ ${#s} -gt $max ]]; then
    echo "${s:0:$((max-3))}..."
  else
    echo "$s"
  fi
}

last_log_line() {
  local logfile="$1"
  [[ -f "$logfile" ]] || return
  local line
  line=$(tail -n 5 "$logfile" 2>/dev/null | grep -v '^$' | tail -n 1)
  [[ -n "$line" ]] && truncate_str "$line" 50
}

# -- collect state files to watch --

get_state_files() {
  if [[ ${#WATCH_IDS[@]} -gt 0 ]]; then
    for id in "${WATCH_IDS[@]}"; do
      local sf="$STATE_DIR/run-${id}.state"
      [[ -f "$sf" ]] && echo "$sf"
    done
  else
    for sf in "$STATE_DIR"/run-*.state; do
      [[ -f "$sf" ]] && echo "$sf"
    done
  fi
}

# -- render one frame --

render() {
  local width=56
  local bar
  bar=$(printf '━%.0s' $(seq 1 $width))

  printf '\033[2J\033[H'
  printf '\033[1m cc-codex HUD\033[0m%*s\033[90m%s\033[0m\n' \
    $((width - 22)) "" "$(date '+%H:%M:%S')"
  echo "$bar"

  local total=0 running=0 done_count=0 failed=0
  local has_running=false

  while IFS= read -r sf; do
    [[ -f "$sf" ]] || continue
    local NUM="" STATUS="" STARTED="" TASK="" LOG="" SANDBOX="" MODE=""
    # shellcheck disable=SC1090
    source "$sf"
    total=$((total + 1))

    local elapsed="—"
    [[ -n "$STARTED" ]] && elapsed=$(elapsed_since "$STARTED")

    local icon
    icon=$(status_icon "$STATUS")

    local task_display
    task_display=$(truncate_str "${TASK:-<no description>}" 30)

    printf ' \033[1m#%s\033[0m  %s  \033[90m%6s\033[0m  %s\n' \
      "$NUM" "$icon" "$elapsed" "$task_display"

    if [[ "$STATUS" == "running" ]]; then
      has_running=true
      running=$((running + 1))
      local activity
      activity=$(last_log_line "${LOG:-}")
      if [[ -n "$activity" ]]; then
        printf '     \033[90m└─ %s\033[0m\n' "$activity"
      fi
    elif [[ "$STATUS" == "done" ]]; then
      done_count=$((done_count + 1))
    elif [[ "$STATUS" == "failed" ]]; then
      failed=$((failed + 1))
    fi
  done < <(get_state_files | sort)

  echo "$bar"

  if [[ $total -eq 0 ]]; then
    printf ' \033[90mNo tasks found.\033[0m\n'
  else
    printf ' Total: \033[1m%d\033[0m' "$total"
    [[ $running -gt 0 ]] && printf '  |  Running: \033[33m%d\033[0m' "$running"
    [[ $done_count -gt 0 ]] && printf '  |  Done: \033[32m%d\033[0m' "$done_count"
    [[ $failed -gt 0 ]] && printf '  |  Failed: \033[31m%d\033[0m' "$failed"
    printf '\n'
  fi

  if $has_running; then
    printf ' \033[90mRefreshing every %ds... (Ctrl-C to detach)\033[0m\n' "$REFRESH"
    return 0
  else
    if [[ $total -gt 0 ]]; then
      printf '\n \033[1mAll tasks finished.\033[0m\n'
    fi
    return 1
  fi
}

# -- main loop --

if $ONCE; then
  render
  exit 0
fi

while true; do
  if ! render; then
    break
  fi
  sleep "$REFRESH"
done
