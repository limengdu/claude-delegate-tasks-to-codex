#!/usr/bin/env bash
# on-mode-restore.sh — SessionStart hook (matcher: compact). When the compacted
# session has persistent delegation on, re-inject the /cc-codex:on instructions
# as additional context.
# on-mode-restore.sh —— SessionStart 钩子（匹配 compact）。被压缩的会话若处于持久委派模式，
# 就把 /cc-codex:on 的说明作为附加上下文重新注入。

set -u

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ON_COMMAND="${SCRIPTS_DIR}/../commands/on.md"
MODE_DIR="${HOME}/.claude/cc-codex/on-sessions"

# Drop markers of sessions untouched for 30 days.
# 清理 30 天未更新的会话标记。
find "$MODE_DIR" -type f -mtime +30 -delete 2>/dev/null

HOOK_INPUT="$(cat)"
SESSION_ID="$(printf '%s' "$HOOK_INPUT" | python3 -c '
import json, sys
try:
    print(json.load(sys.stdin).get("session_id", ""))
except Exception:
    pass
')"

[[ "$SESSION_ID" =~ ^[A-Za-z0-9_-]+$ ]] || exit 0
[[ -f "${MODE_DIR}/${SESSION_ID}" && -f "$ON_COMMAND" ]] || exit 0
touch "${MODE_DIR}/${SESSION_ID}"

python3 - "$ON_COMMAND" <<'PY'
import json, re, sys

text = open(sys.argv[1], encoding="utf-8").read()
# Body without frontmatter and without the first-task argument block.
# 去掉 frontmatter 和「首个任务」参数段后的正文。
body = re.sub(r"\A---\n.*?\n---\n", "", text, flags=re.S)
body = re.sub(r"Optional first task from the user:\s*\$ARGUMENTS\s*", "", body)
body = body.replace("`$ARGUMENTS`", "the first-task argument of the original /cc-codex:on call")

context = (
    "cc-codex persistent delegation mode (/cc-codex:on) is still ACTIVE for this "
    "conversation; the context was compacted, so its instructions are restored "
    "below. Keep following them until the user runs /cc-codex:off. Do not re-run "
    "`codex-mode on`.\n\n" + body
)
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": context,
    }
}))
PY
