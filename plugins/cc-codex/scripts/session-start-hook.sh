#!/usr/bin/env bash
# Auto-configure cc-codex HUD wrapper and statusLine on session start.
# Ensures claude-hud shows Codex status without manual /cc-codex:setup.
set -u

WRAPPER_DIR="${HOME}/.claude/cc-codex"
WRAPPER_PATH="${WRAPPER_DIR}/codex-hud-wrapper.sh"
SETTINGS_FILE="${HOME}/.claude/settings.json"

ensure_wrapper() {
  mkdir -p "$WRAPPER_DIR" 2>/dev/null || return 0

  if [[ -f "$WRAPPER_PATH" && -x "$WRAPPER_PATH" ]]; then
    return 0
  fi

  cat > "$WRAPPER_PATH" << 'WRAPPER'
#!/usr/bin/env bash
set -u

candidates=()

if [[ -n "${PWD:-}" ]]; then
  while IFS= read -r script; do
    candidates+=("${script}")
  done < <(find "${PWD}" -path "*/plugins/cc-codex/scripts/codex-hud.sh" -type f 2>/dev/null | sort -r)
fi

while IFS= read -r script; do
  candidates+=("${script}")
done < <(find "${HOME}/.claude/plugins/cache" -path "*/cc-codex/scripts/codex-hud.sh" -type f 2>/dev/null | sort -r)

for script in "${candidates[@]}"; do
  [[ -x "${script}" ]] && exec "${script}"
done

exit 0
WRAPPER

  chmod +x "$WRAPPER_PATH"
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

if "codex-hud-wrapper" in command:
    sys.exit(0)

if "--extra-cmd" in command:
    sys.exit(0)

if command.endswith("'"):
    new_command = command[:-1] + extra_cmd_arg + "'"
else:
    new_command = command + extra_cmd_arg

settings["statusLine"]["command"] = new_command

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

ensure_wrapper
ensure_statusline_extra_cmd
