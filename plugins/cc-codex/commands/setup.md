---
description: Install and verify cc-codex dependencies, Codex setup, and HUD integration.
argument-hint: [--enable-review-gate|--disable-review-gate]
disable-model-invocation: true
allowed-tools: Bash, Read, Edit, AskUserQuestion
---

You have been explicitly invoked to set up cc-codex and its required tools.

Optional setup arguments:

$ARGUMENTS

## Goal

Run a practical setup flow that gets the user ready to use:

- the official Codex CLI
- the official `codex@openai-codex` Claude Code plugin
- the `claude-hud@claude-hud` Claude Code plugin
- the cc-codex HUD wrapper
- the current cc-codex plugin

## Required setup flow

1. Check whether `claude` is available:

   ```bash
   command -v claude
   ```

   If it is missing, stop and tell the user Claude Code CLI is required.

2. Check whether `codex` is available:

   ```bash
   command -v codex
   codex --version
   ```

   If `codex --version` fails, check for a broken shell alias or shadowed
   binary before deciding Codex is missing:

   ```bash
   which -a codex 2>/dev/null
   type codex 2>/dev/null
   npm list -g @openai/codex 2>/dev/null | head -5
   ```

   If `type codex` shows an alias but `which -a codex` also lists a real
   executable path, run that executable directly with `--version`. Treat Codex
   CLI as ready if the direct executable works, and include a final warning
   telling the user which alias should be cleaned up.

   If `codex` is missing, check whether `npm` is available:

   ```bash
   command -v npm
   ```

   If npm is available, use `AskUserQuestion` exactly once to ask whether to
   install Codex CLI globally. Put `Install Codex (Recommended)` first and
   `Skip for now` second. If the user chooses install, run:

   ```bash
   npm install -g @openai/codex
   ```

   Then rerun:

   ```bash
   codex --version
   ```

   If npm is unavailable or the user skips installation, keep going but mark
   Codex CLI as not ready in the final report.

3. Check installed Claude Code plugins:

   ```bash
   claude plugin list
   claude plugin marketplace list
   ```

4. Ensure the official Codex plugin marketplace and plugin are installed.
   If the marketplace list does not include `openai-codex`, run:

   ```bash
   claude plugin marketplace add openai/codex-plugin-cc
   ```

   If the plugin list does not include `codex@openai-codex`, run:

   ```bash
   claude plugin install codex@openai-codex
   ```

5. Ensure the claude-hud marketplace and plugin are installed.
   If the marketplace list does not include `claude-hud`, run:

   ```bash
   claude plugin marketplace add jarrodwatts/claude-hud
   ```

   If the plugin list does not include `claude-hud@claude-hud`, run:

   ```bash
   claude plugin install claude-hud@claude-hud
   ```

6. Ensure cc-codex itself is installed.
   If the marketplace list does not include `cc-codex-marketplace`, run:

   ```bash
   claude plugin marketplace add limengdu/claude-delegate-tasks-to-codex
   ```

   If the plugin list does not include `cc-codex@cc-codex-marketplace`, run:

   ```bash
   claude plugin install cc-codex@cc-codex-marketplace
   ```

7. Run the official Codex setup check through the installed companion script.
   Locate the newest companion:

   ```bash
   find "$HOME/.claude/plugins/cache" -path "*/openai-codex/codex/*/scripts/codex-companion.mjs" -type f 2>/dev/null | sort -r | head -1
   ```

   Then run:

   ```bash
   node "<companion-path>" setup --json $ARGUMENTS
   ```

   Preserve any login guidance from the setup result, especially guidance to
   run `codex login`.

8. Configure the HUD wrapper at:

   ```text
   ~/.claude/cc-codex/codex-hud-wrapper.sh
   ```

   The wrapper should locate the current cc-codex HUD script each time it runs,
   then execute it. It should support both local development with `--plugin-dir`
   and normal installed plugins from Claude Code's plugin cache.

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

   Make it executable:

   ```bash
   chmod +x "$HOME/.claude/cc-codex/codex-hud-wrapper.sh"
   ```

9. Configure the Claude Code `statusLine` setting.
   Use structured JSON editing, not string concatenation. Before modifying
   user settings, create a timestamped backup of the target settings file.

   Check these files in order:

   - `~/.claude/settings.json`
   - `.claude/settings.json`
   - `~/.claude/settings.local.json`

   If no `statusLine` exists, create one in `~/.claude/settings.json` for
   claude-hud. On macOS and Linux, generate the command by finding the installed
   claude-hud plugin and a runtime:

   ```bash
   command -v bun 2>/dev/null || command -v node 2>/dev/null
   ls -d "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/plugins/cache/*/claude-hud/*/ 2>/dev/null | awk -F/ '{ print $(NF-1) "\t" $(0) }' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+[[:space:]]' | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1 | cut -f2-
   ```

   If the runtime is `bun`, use `src/index.ts` and add `--env-file /dev/null`.
   If the runtime is `node`, use `dist/index.js`.

   The generated macOS/Linux command should dynamically find the latest
   claude-hud plugin version each time it runs. For `node`, use:

   ```text
   bash -c 'cols=$(stty size </dev/tty 2>/dev/null | awk '"'"'{print $2}'"'"'); export COLUMNS=$(( ${cols:-120} > 4 ? ${cols:-120} - 4 : 1 )); plugin_dir=$(ls -d "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/plugins/cache/*/claude-hud/*/ 2>/dev/null | awk -F/ '"'"'{ print $(NF-1) "\t" $(0) }'"'"' | grep -E '"'"'^[0-9]+\.[0-9]+\.[0-9]+[[:space:]]'"'"' | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1 | cut -f2-); exec "<runtime-path>" "${plugin_dir}dist/index.js"'
   ```

   For `bun`, use the same command shape but execute:

   ```text
   "<runtime-path>" --env-file /dev/null "${plugin_dir}src/index.ts"
   ```

   If the platform is Windows or the runtime/plugin path cannot be detected,
   stop the statusLine creation step and tell the user to run `/claude-hud:setup`
   after restarting Claude Code, then rerun `/cc-codex:setup`.

   If a `statusLine` command exists and it already has the cc-codex wrapper,
   leave it unchanged.

   If a `statusLine` command exists without `--extra-cmd`, append:

   ```text
   --extra-cmd "$HOME/.claude/cc-codex/codex-hud-wrapper.sh"
   ```

   If a `statusLine` command exists with a different `--extra-cmd`, use
   `AskUserQuestion` to ask whether to replace it. Only one claude-hud
   `--extra-cmd` value is supported.

10. Verify:

   ```bash
   bash -n "$HOME/.claude/cc-codex/codex-hud-wrapper.sh"
   "$HOME/.claude/cc-codex/codex-hud-wrapper.sh"
   claude plugin details codex
   claude plugin details claude-hud
   claude plugin details cc-codex
   ```

11. Final report:

   Reply with a compact checklist:

   - Claude CLI
   - Codex CLI
   - official Codex plugin
   - claude-hud plugin
   - cc-codex plugin
   - Codex setup result
   - HUD wrapper
   - statusLine
   - whether restart is required

   If anything could not be automated, list the exact command the user should
   run next.
