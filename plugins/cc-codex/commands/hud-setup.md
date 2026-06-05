---
description: Configure the Codex status HUD line (requires claude-hud plugin)
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
   ```
   node /path/to/claude-hud/dist/index.js
   ```

3. Append `--extra-cmd` with the path to the codex-hud script:
   ```
   node /path/to/claude-hud/dist/index.js --extra-cmd "${CLAUDE_PLUGIN_ROOT}/scripts/codex-hud.sh"
   ```

   Replace `${CLAUDE_PLUGIN_ROOT}` with the actual resolved path to this
   plugin's root. Find it by running:
   ```bash
   find ~/.claude/plugins/cache -path "*/cc-codex/scripts/codex-hud.sh" 2>/dev/null
   ```
   Then use the directory two levels up from `scripts/codex-hud.sh`.

4. If no `statusLine` is configured at all, tell the user they need
   claude-hud installed first: `/plugin install claude-hud` then
   `/claude-hud:setup`.

5. If `--extra-cmd` is already present in the statusLine, ask the user
   if they want to replace it (only one extra-cmd is supported).

6. After updating, tell the user to restart Claude Code for it to take effect.
