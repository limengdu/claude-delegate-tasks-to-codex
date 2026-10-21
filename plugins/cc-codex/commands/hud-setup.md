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

3. Check the stable wrapper script at:

   ```text
   ~/.claude/cc-codex/codex-hud-wrapper.sh
   ```

   The cc-codex session-start hook writes this wrapper and the helpers in
   `~/.claude/cc-codex/bin` automatically. If the wrapper is missing, run the
   hook once:

   ```bash
   bash "$(ls -d "$HOME"/.claude/plugins/cache/cc-codex-marketplace/cc-codex/*/scripts/session-start-hook.sh | sort -V | tail -n 1)"
   ```

4. Append `--extra-cmd` with the stable wrapper path, and enable it with
   `CLAUDE_HUD_ALLOW_EXTRA_CMD=1` (claude-hud runs `--extra-cmd` only then):

   ```text
   CLAUDE_HUD_ALLOW_EXTRA_CMD=1 node /path/to/claude-hud/dist/index.js --extra-cmd "$HOME/.claude/cc-codex/codex-hud-wrapper.sh"
   ```

5. Set `"refreshInterval": 10` on the `statusLine` entry, so the Codex status
   keeps updating while Claude waits for a job.

6. If no `statusLine` is configured at all, tell the user they need
   claude-hud installed first:

   ```text
   /plugin install claude-hud@claude-hud
   /claude-hud:setup
   ```

7. If `--extra-cmd` is already present in the statusLine, ask the user if they
   want to replace it. Only one claude-hud `--extra-cmd` value is supported.

8. After updating, tell the user to restart Claude Code for it to take effect.
