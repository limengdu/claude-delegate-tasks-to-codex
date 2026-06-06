---
description: Configure the Codex status HUD line (requires claude-hud plugin)
disable-model-invocation: true
allowed-tools: Bash, Read, Edit, AskUserQuestion
---

Set up the Codex HUD status line that shows Codex task progress in the
claude-hud statusline. It only appears when Codex jobs are running.

## What to do

1. Find the user's current `statusLine` setting in their Claude Code settings.
   Check these files in order:
   - `~/.claude/settings.json` (user settings)
   - `.claude/settings.json` (project settings)
   - `~/.claude/settings.local.json` (local settings)

2. The `statusLine` value should be a command string that runs claude-hud.
   It looks something like:

   ```text
   node /path/to/claude-hud/dist/index.js
   ```

3. Create a stable wrapper script at:

   ```text
   ~/.claude/cc-codex/codex-hud-wrapper.sh
   ```

   The wrapper should locate the current cc-codex HUD script each time it runs,
   then execute it. It should support both local development with `--plugin-dir`
   and normal installed plugins from Claude Code's plugin cache. This avoids
   writing a versioned cache path into `statusLine`.

   ```bash
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
   ```

4. Append `--extra-cmd` with the stable wrapper path:

   ```text
   node /path/to/claude-hud/dist/index.js --extra-cmd "$HOME/.claude/cc-codex/codex-hud-wrapper.sh"
   ```

5. If no `statusLine` is configured at all, tell the user they need
   claude-hud installed first:

   ```text
   /plugin install claude-hud@claude-hud
   /claude-hud:setup
   ```

6. If `--extra-cmd` is already present in the statusLine, ask the user if they
   want to replace it. Only one claude-hud `--extra-cmd` value is supported.

7. After updating, tell the user to restart Claude Code for it to take effect.
