#!/usr/bin/env bash
# install.sh — Install cc-codex as a GLOBAL Claude Code skill.
#
# One install, every project. The skill lives at ~/.claude/skills/cc-codex and
# stays dormant until you explicitly invoke it (type /cc-codex, or say "use
# Codex to ..."). Nothing else triggers it.

set -e
GREEN="\033[32m"; YELLOW="\033[33m"; BOLD="\033[1m"; RESET="\033[0m"
ok(){ printf "${GREEN}OK${RESET} %s\n" "$*"; }
note(){ printf "${YELLOW}!!${RESET} %s\n" "$*"; }
hd(){ printf "\n${BOLD}%s${RESET}\n" "$*"; }

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME/.claude/skills/cc-codex"

hd "Installing cc-codex skill (global)"

mkdir -p "$HOME/.claude/skills"
rm -rf "$DEST"
cp -R "$SRC_DIR/cc-codex" "$DEST"
chmod +x "$DEST"/scripts/*.sh
ok "Skill installed to $DEST"
ok "Available in ALL your projects — no per-project setup."

hd "Checking what you need"
chk(){ command -v "$1" >/dev/null 2>&1 && ok "$1 found" || note "$1 missing → $2"; }
chk codex "npm install -g @openai/codex   (then run: codex --login)   [required]"
chk claude "npm install -g @anthropic-ai/claude-code   [required]"
chk tmux  "optional — only enables a live split-view; everything works without it"

hd "Done. How to use it"
cat <<EOF

  Just open Claude Code in any project and either:

    /cc-codex  write a log-cleanup script in ./tools
        — or, in plain language —
    "use Codex to write a log-cleanup script in ./tools"

  Claude plans the work, hands it to Codex, waits, then reviews the result
  (runs tests, reads the diff) and reports back.

  Any other time, the skill stays asleep — your normal Claude Code is unchanged.
EOF
