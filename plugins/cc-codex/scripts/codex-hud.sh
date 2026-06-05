#!/usr/bin/env bash
# codex-hud.sh — Outputs Codex job status as JSON for claude-hud's --extra-cmd.
# When Codex jobs are running: {"label": "Codex: 2 running (1m30s)"}
# When no jobs are running: outputs nothing (claude-hud hides the line).
#
# Usage: --extra-cmd "/path/to/codex-hud.sh"

set -u

# Find the Codex plugin's state directory (codex-plugin-cc stores jobs here)
find_state_dir() {
  local base="${HOME}/.claude/plugins/data"
  local dir
  # codex-openai-codex is the standard data dir name
  dir=$(find "$base" -maxdepth 1 -name "codex-openai-codex" -type d 2>/dev/null | head -1)
  if [[ -n "$dir" ]]; then
    echo "$dir"
    return
  fi
  # Fallback: any codex-related data dir
  dir=$(find "$base" -maxdepth 1 -name "*codex*" -type d 2>/dev/null | head -1)
  [[ -n "$dir" ]] && echo "$dir"
}

STATE_BASE=$(find_state_dir)
[[ -z "$STATE_BASE" ]] && exit 0

# Scan all workspace state dirs for job files
running=0
completed=0
failed=0
earliest_start=""

while IFS= read -r job_file; do
  [[ -f "$job_file" ]] || continue

  status=$(python3 -c "
import json, sys
try:
    d = json.load(open('$job_file'))
    print(d.get('status', ''))
except:
    pass
" 2>/dev/null)

  case "$status" in
    running|queued)
      running=$((running + 1))
      start=$(python3 -c "
import json
try:
    d = json.load(open('$job_file'))
    print(d.get('startedAt', d.get('createdAt', '')))
except:
    pass
" 2>/dev/null)
      if [[ -n "$start" && ( -z "$earliest_start" || "$start" < "$earliest_start" ) ]]; then
        earliest_start="$start"
      fi
      ;;
    completed) completed=$((completed + 1)) ;;
    failed|cancelled) failed=$((failed + 1)) ;;
  esac
done < <(find "$STATE_BASE" -path "*/jobs/*.json" -type f 2>/dev/null | sort -r | head -10)

# No running jobs → output nothing (claude-hud hides the line)
[[ $running -eq 0 ]] && exit 0

# Calculate elapsed time
elapsed=""
if [[ -n "$earliest_start" ]]; then
  start_epoch=$(date -j -f '%Y-%m-%dT%H:%M:%S' "${earliest_start%%.*}" '+%s' 2>/dev/null || \
                date -d "${earliest_start}" '+%s' 2>/dev/null || echo "")
  if [[ -n "$start_epoch" ]]; then
    now_epoch=$(date '+%s')
    diff=$((now_epoch - start_epoch))
    if [[ $diff -ge 0 ]]; then
      m=$((diff / 60))
      s=$((diff % 60))
      elapsed=" ${m}m${s}s"
    fi
  fi
fi

# Build label
parts="$running running"
[[ $completed -gt 0 ]] && parts="$parts, $completed done"
[[ $failed -gt 0 ]] && parts="$parts, $failed failed"

label="Codex: ${parts}${elapsed}"

# Output JSON for claude-hud
printf '{"label":"%s"}\n' "$label"
