#!/usr/bin/env bash
# Session-start setup for cc-codex:
#   1. Write launchers in ~/.claude/cc-codex/bin that point at this plugin's scripts.
#   2. Write the HUD wrapper and add it to claude-hud's statusLine --extra-cmd.
# 会话启动时配置 cc-codex：
#   1. 在 ~/.claude/cc-codex/bin 写入指向本插件脚本的启动器。
#   2. 写入 HUD 包装脚本，并加入 claude-hud 状态栏的 --extra-cmd。
set -u

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER_DIR="${HOME}/.claude/cc-codex"
BIN_DIR="${WRAPPER_DIR}/bin"
WRAPPER_PATH="${WRAPPER_DIR}/codex-hud-wrapper.sh"
SETTINGS_FILE="${HOME}/.claude/settings.json"

# Write a launcher script <name> that execs <target> with all arguments.
# 写入启动器 <name>，带全部参数执行 <target>。
write_launcher() {
  local path="$1" target="$2"
  printf '#!/usr/bin/env bash\nexec bash %q "$@"\n' "$target" > "${path}.tmp.$$" \
    && chmod +x "${path}.tmp.$$" && mv "${path}.tmp.$$" "$path"
}

ensure_launchers() {
  mkdir -p "$BIN_DIR" 2>/dev/null || return 0
  write_launcher "${BIN_DIR}/codex-task"     "${SCRIPTS_DIR}/codex-task.sh"
  write_launcher "${BIN_DIR}/codex-wait"     "${SCRIPTS_DIR}/codex-wait.sh"
  write_launcher "${BIN_DIR}/codex-watchdog" "${SCRIPTS_DIR}/codex-watchdog.sh"
  write_launcher "${BIN_DIR}/codex-cancel"   "${SCRIPTS_DIR}/codex-cancel.sh"
  write_launcher "$WRAPPER_PATH"             "${SCRIPTS_DIR}/codex-hud.sh"
}

ensure_statusline_extra_cmd() {
  [[ -f "$SETTINGS_FILE" ]] || return 0

  python3 - "$SETTINGS_FILE" << 'PYTHON'
import json
import sys
import shutil
import tempfile
import os

settings_file = sys.argv[1]
wrapper_ref = '$HOME/.claude/cc-codex/codex-hud-wrapper.sh'
extra_cmd_arg = ' --extra-cmd "' + wrapper_ref + '"'

try:
    with open(settings_file, "r") as f:
        settings = json.load(f)
except Exception:
    sys.exit(0)

status_line = settings.get("statusLine")
if not status_line or not isinstance(status_line, dict):
    sys.exit(0)

command = status_line.get("command", "")
if not command:
    sys.exit(0)

new_command = command

# Attach the wrapper when no other --extra-cmd is configured.
# 未配置其他 --extra-cmd 时接上包装脚本。
if "codex-hud-wrapper" not in new_command and "--extra-cmd" not in new_command:
    if new_command.endswith("'"):
        new_command = new_command[:-1] + extra_cmd_arg + "'"
    else:
        new_command = new_command + extra_cmd_arg

# claude-hud runs --extra-cmd only with CLAUDE_HUD_ALLOW_EXTRA_CMD enabled.
# claude-hud 只有在开启 CLAUDE_HUD_ALLOW_EXTRA_CMD 时才执行 --extra-cmd。
if "codex-hud-wrapper" in new_command and "CLAUDE_HUD_ALLOW_EXTRA_CMD" not in new_command:
    new_command = "CLAUDE_HUD_ALLOW_EXTRA_CMD=1 " + new_command

# Claude Code re-renders the status line only on events unless refreshInterval
# (seconds) is set; a periodic refresh keeps the Codex timer moving while idle.
# Claude Code 默认只在有事件时刷新状态栏，设置 refreshInterval（秒）后才会定时刷新，Codex 计时才能走动。
refresh = status_line.get("refreshInterval")
new_refresh = refresh if isinstance(refresh, (int, float)) and refresh > 0 else 10

if new_command == command and new_refresh == refresh:
    sys.exit(0)

settings["statusLine"]["command"] = new_command
settings["statusLine"]["refreshInterval"] = new_refresh

backup = settings_file + ".bak"
try:
    shutil.copy2(settings_file, backup)
except Exception:
    pass

tmp_dir = os.path.dirname(settings_file)
fd, tmp_path = tempfile.mkstemp(dir=tmp_dir, suffix=".tmp")
try:
    with os.fdopen(fd, "w") as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp_path, settings_file)
except Exception:
    try:
        os.unlink(tmp_path)
    except Exception:
        pass
    sys.exit(0)
PYTHON
}

ensure_launchers
ensure_statusline_extra_cmd
