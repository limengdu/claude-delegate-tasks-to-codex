#!/usr/bin/env bash
# codex-mode.sh — Record whether persistent delegation (/cc-codex:on) is active
# for the current Claude Code session.
# codex-mode.sh —— 记录当前 Claude Code 会话是否处于持久委派模式（/cc-codex:on）。
#
# Usage: codex-mode.sh on|off|status [session-id]
#   session-id defaults to $CLAUDE_CODE_SESSION_ID.
#
# State: one marker file per session in ~/.claude/cc-codex/on-sessions/.

set -u

MODE_DIR="${HOME}/.claude/cc-codex/on-sessions"
ACTION="${1:-}"
SESSION_ID="${2:-${CLAUDE_CODE_SESSION_ID:-}}"

[[ -n "$ACTION" ]] || { echo "Usage: codex-mode.sh on|off|status [session-id]" >&2; exit 2; }
[[ -n "$SESSION_ID" ]] || { echo "ERROR: no session id (CLAUDE_CODE_SESSION_ID is unset)." >&2; exit 1; }
[[ "$SESSION_ID" =~ ^[A-Za-z0-9_-]+$ ]] || { echo "ERROR: invalid session id." >&2; exit 1; }

MARKER="${MODE_DIR}/${SESSION_ID}"

case "$ACTION" in
  on)
    mkdir -p "$MODE_DIR" && date '+%Y-%m-%dT%H:%M:%S' > "$MARKER"
    echo "cc-codex persistent mode: on (session ${SESSION_ID})" ;;
  off)
    rm -f "$MARKER"
    echo "cc-codex persistent mode: off (session ${SESSION_ID})" ;;
  status)
    [[ -f "$MARKER" ]] && echo "on" || echo "off" ;;
  *)
    echo "ERROR: action must be on, off or status." >&2; exit 2 ;;
esac
