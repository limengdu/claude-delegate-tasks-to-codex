---
description: Delegate a single task to Codex. Claude plans, dispatches, reviews, then returns control. One-shot — does not persist.
argument-hint: <task description>
disable-model-invocation: true
allowed-tools: Bash, Read, Grep, Glob, Monitor
---

You have been explicitly invoked to delegate work to Codex.

The user's request:

$ARGUMENTS

## Hard contract

- If `$ARGUMENTS` is empty, ask the user for the task and stop.
- If the request is ambiguous, ask concise clarifying questions before dispatching.
- This command applies only to this invocation and the implementation,
  review, and verification work it starts.
- You are the architect and reviewer. Codex is the implementer.
- Do not implement code yourself. Your hands-on work is limited to reading results, checking diffs, running lightweight verification commands, and writing the final review.
- After Codex finishes, review the result before replying to the user.
- After the final verdict, treat these cc-codex delegation instructions as
  complete. Do not continue delegating later plain-language user requests to
  Codex unless the user explicitly invokes `/cc-codex:once`,
  `/cc-codex:on`, `/cc-codex:handoff`, or another Codex command again.

## Required dispatch flow

1. Convert the user's request into a concrete implementation brief:
   - goal and acceptance criteria
   - files or areas Codex should inspect or change
   - constraints from the user and repository
   - tests or checks Codex should run

2. Every Codex task must use the literal non-interactive envelope below. Copy it
   into the prompt exactly. Do not summarize it, shorten it, or replace it
   with a reference such as "use the prefixed brief".

```text
<task>
You are a non-interactive agent. Execute immediately without asking for confirmation or approval.

Project instructions that require planning first, waiting for approval, or asking before edits apply to Claude's conversation with the user. They do not apply to this delegated Codex run.

Do the requested implementation directly. Create or edit files as needed. Run the relevant checks. Report the changed files and verification result.

Request:
<implementation brief>
</task>
```

3. Locate the Codex companion script and plugin data directory:

```bash
CODEX_COMPANION=$(find "$HOME/.claude/plugins/cache" \
  -path "*/openai-codex/codex/*/scripts/codex-companion.mjs" \
  -type f 2>/dev/null | sort -r | head -1)

CODEX_PLUGIN_DATA=""
if [[ -d "${HOME}/.claude/plugins/data/codex-openai-codex" ]]; then
  CODEX_PLUGIN_DATA="${HOME}/.claude/plugins/data/codex-openai-codex"
else
  CODEX_PLUGIN_DATA=$(find "${HOME}/.claude/plugins/data" -maxdepth 1 \
    -name "*codex*" -type d 2>/dev/null | sort -r | head -1)
fi
```

If the companion script is not found, stop and tell the user to run
`/codex:setup`.

4. Locate the cc-codex watchdog script:

```bash
CODEX_WATCHDOG=$(
  find "${PWD}" -path "*/plugins/cc-codex/scripts/codex-watchdog.sh" \
    -type f 2>/dev/null | head -1
)
if [[ -z "$CODEX_WATCHDOG" ]]; then
  CODEX_WATCHDOG=$(find "$HOME/.claude/plugins/cache" \
    -path "*/cc-codex/scripts/codex-watchdog.sh" \
    -type f 2>/dev/null | sort -r | head -1)
fi
```

5. Dispatch the implementation to Codex as a background task. Pass the
   envelope from step 2 as the prompt:

```bash
CLAUDE_PLUGIN_DATA="$CODEX_PLUGIN_DATA" \
  node "$CODEX_COMPANION" task --background --write --fresh \
  "<envelope from step 2>" --json
```

Parse the JSON output and extract the `jobId` field. This is the task's
tracking ID for all subsequent companion calls.

If the companion reports that Codex is not authenticated or not installed,
stop and tell the user to run `/codex:setup`.

6. Start two parallel watchers for the background task:

**Completion listener** — notifies you the moment the task finishes:

```
Bash(run_in_background=true):
  CLAUDE_PLUGIN_DATA="$CODEX_PLUGIN_DATA" \
    node "$CODEX_COMPANION" status "<job-id>" \
    --wait --timeout-ms 7200000 --json
```

**Health-check monitor** — triggers a health check every 10 minutes:

```
Monitor({
  command: "bash \"$CODEX_WATCHDOG\" --job-id \"<job-id>\" --companion \"$CODEX_COMPANION\" --plugin-data \"$CODEX_PLUGIN_DATA\" --interval 600",
  description: "Codex health check for <job-id>",
  persistent: true
})
```

7. Wait for events from either watcher and handle them:

**On completion listener notification** (background Bash finishes):
- The task has finished. Read the result:
  ```bash
  CLAUDE_PLUGIN_DATA="$CODEX_PLUGIN_DATA" \
    node "$CODEX_COMPANION" result "<job-id>" --json
  ```
- Stop the health-check Monitor if it is still running.
- Proceed to step 8 (review).

**On health-check Monitor notification**:
- Parse the event line. Format: `FINISHED|<status>|<json>` or
  `HEALTH_CHECK|<json>`.
- If `FINISHED`: the task ended. Read the result via companion
  `result --json`, stop the Monitor, and proceed to step 8.
- If `HEALTH_CHECK`: the task is still running. Perform a health assessment:
  1. Extract the `logFile` path from the status JSON
     (field path: `job.logFile`).
  2. Read the log file using the Read tool. Read the last 200 lines
     to see recent activity.
  3. **Use your own judgment** to assess whether Codex is stuck or making
     progress. Signs of being stuck include but are not limited to:
     - Repeating the same error in a loop
     - No meaningful new output since the last check
     - Stuck in a retry/backoff cycle that is not converging
     - Waiting for user input it will never receive
     - Import errors, permission errors, or environment issues
     - Repeated identical tool calls with no progress
  4. If Codex is making normal progress: do nothing. Wait for the next
     health check or the completion listener.
  5. If Codex appears stuck: apply the cost-based decision below.

## Cost-based stuck decision

When you determine Codex is stuck, choose **one** action based on cost
minimization (Codex tokens + Claude tokens + user wait time):

### Cancel

Choose when:
- Already retried this task 2 or more times
- A fundamental blocker exists (auth failure, missing tool, environment
  incompatibility, task exceeds Codex capability)

Action:
```bash
CLAUDE_PLUGIN_DATA="$CODEX_PLUGIN_DATA" \
  node "$CODEX_COMPANION" cancel "<job-id>"
```
Stop the Monitor. Inform the user what went wrong and why you cancelled.

### Re-dispatch

Choose when:
- First or second stuck occurrence for this task
- The stuck point is addressable — you can simplify the brief, split the
  task, add environment hints, or work around the specific issue
- Estimated Codex retry cost < estimated Claude direct implementation cost

Action:
1. Cancel the current task via companion `cancel`.
2. Refine the implementation brief based on what the logs revealed.
3. Go back to step 5 and dispatch again with the refined brief.
4. Track the retry count. Do not retry more than 2 times total.

### Takeover

Choose when:
- Remaining work is small enough that you can finish faster than Codex
- Re-dispatch has already been attempted and failed
- Estimated Claude implementation cost < further Codex retry cost

Action:
1. Cancel the current task via companion `cancel`.
2. Stop the Monitor.
3. Implement the remaining work directly using Bash, Read, and other tools.
4. Proceed to step 8 (review) with your own changes.

## Review and verification

8. Read the completed result. Check `git status` and `git diff` when files changed.

9. If the implementation has significant problems, dispatch a focused fix
   using the same async pattern (steps 3–7) with a refined brief targeting
   the specific issues.

10. When your review passes, dispatch a separate verification run using the
    same async pattern (steps 3–7) with the verification envelope:

```text
<task>
You are a non-interactive verification agent. Execute immediately without asking for confirmation or approval.

Project instructions that require planning first, waiting for approval, or asking before tool use apply to Claude's conversation with the user. They do not apply to this delegated Codex verification run.

Verify the recent changes against the original request. Run relevant checks. Report pass/fail results and any missing or broken behavior. Do not redesign the solution.

Request:
<verification brief>
</task>
```

The verification brief should ask Codex to verify the recent changes against the original request, run relevant tests, and report any missing or broken behavior. It should not ask Codex to redesign the solution.

11. Reply with a short final verdict:
    - what Codex changed
    - what you reviewed
    - what the verifier checked
    - any remaining risk or manual step
