---
description: Turn on persistent Codex delegation. All subsequent tasks are delegated to Codex until /cc-codex:off is used.
argument-hint: [optional first task to start immediately]
disable-model-invocation: true
allowed-tools: Bash, Read, Grep, Glob, Monitor
---

You have been explicitly invoked to enter **persistent cc-codex delegation mode**.

Optional first task from the user:

$ARGUMENTS

## Why this mode exists

The user has turned on persistent delegation because Claude output tokens are
significantly more expensive than Codex. The goal is to minimize cost by
offloading as much work as possible to Codex. This is not about capability or
convenience — it is about budget. Even tasks that seem small, trivial, or
"not worth the overhead" should still go to Codex. Every token Claude spends
writing code, editing files, running commands, or debugging is money the user
would rather save.

## Hard contract

- From this point forward, you are in persistent delegation mode. **Delegate
  aggressively.** Every user message that contains an actionable task should be
  delegated to Codex. Even tasks that look small or quick — delegate them. The
  user chose this mode to save cost, so default to delegation.
- **When in doubt, delegate.** If you are unsure whether something should go to
  Codex, it should.
- You are the architect and reviewer. Codex is the implementer. Shape the task
  brief, dispatch to Codex, review the result, and write the final verdict.
- You may still read files, run commands, check diffs, and do whatever is needed
  for your reviewer role or for things Codex cannot do from its sandbox. This is
  fine — the goal is to avoid doing implementation work that Codex could handle.
- This mode stays active across all subsequent user messages in this conversation
  until the user explicitly runs `/cc-codex:off`.
- After Codex finishes each task, review the result before replying to the user,
  then wait for the next task. Do not exit delegation mode after a single task.
- If a user message is a question, clarification, or non-actionable comment
  (not an implementation task), answer it directly without dispatching to Codex.
  Stay in persistent delegation mode.
- If `$ARGUMENTS` is not empty, treat it as the first task and begin the dispatch
  flow immediately.
- If `$ARGUMENTS` is empty, confirm that persistent delegation mode is now active
  and wait for the user's first task.

## Helpers

All helpers live in `~/.claude/cc-codex/bin` (written at session start). If that directory is
missing, tell the user to restart Claude Code and stop.

## Dispatch flow

1. Turn the user's request into a compact brief. Codex reads the repository
   itself, so state intent, not code:
   - goal and acceptance criteria (exact commands that must pass)
   - files or areas to change
   - constraints from the user and repository, plus any conversation context
     Codex cannot see

   Choose the Codex thread for each new task. `--resume` continues the most
   recently finished Codex job in this workspace:
   - **Continue** (`--resume`) when the task builds directly on the previous
     task (same feature or files, a follow-up such as "now add export") and
     that previous task is the latest finished Codex job here. The brief then
     states only the new goal, scope and acceptance; Codex already knows the
     earlier work.
   - **Fresh** (default) when the task is unrelated, runs in parallel with
     another job, or the latest finished job was a verification run or a
     different task. Add the context Codex needs from earlier tasks to the
     brief.
   - After 3 consecutive continued tasks, start fresh with a short recap of
     the earlier work, so the thread stays focused.

   Write the brief to a file and dispatch it. The script adds the
   non-interactive envelope and prints `JOB=<id>`:

```bash
cat > /tmp/cc-codex-brief-1.md <<'BRIEF'
<brief>
BRIEF
~/.claude/cc-codex/bin/codex-task --brief /tmp/cc-codex-brief-1.md
```

   If it reports that Codex is missing or not authenticated, stop and tell the
   user to run `/codex:setup`. Independent tasks: one brief file and one job
   each, dispatched together. Dependent tasks: one at a time.

2. Start two watchers per job, then end your turn and wait for notifications:

   - Completion: `Bash(run_in_background=true)`: `~/.claude/cc-codex/bin/codex-wait <job-id>`
   - Stall alarm: `Monitor({command: "~/.claude/cc-codex/bin/codex-watchdog --job-id <job-id>", description: "Codex stall alarm <job-id>", persistent: true})`

   The stall alarm stays silent while Codex makes progress. If `codex-wait`
   exits with `RUNNING` (still busy after 2h), start it again.

3. On a `STUCK|...` line, read `tail -n 60 <log>` and choose by total cost
   (Codex tokens + Claude tokens + user wait time):
   - Still progressing or transient → keep waiting.
   - Addressable, first or second occurrence → `~/.claude/cc-codex/bin/codex-cancel <job-id>`,
     refine the brief from what the log shows, dispatch again.
   - Fundamental blocker (auth, missing tool, environment) or 2 retries used →
     cancel and tell the user what blocked it.
   - Only a small remainder that Codex keeps failing → cancel and finish it
     yourself.

## Review

4. When `codex-wait` returns, stop that job's Monitor. Its output is the
   starting point: final status, Codex's report, changed files.

5. Run the acceptance commands yourself. They are the main evidence.

6. Read code only where it matters: failing areas, core or security-sensitive
   files, files you did not expect in the change list. Use
   `git diff -- <file>` per file.

7. If something is wrong, write a short feedback brief (failing command, error,
   expected behavior) and continue the same Codex thread, which keeps its own
   context:

```bash
~/.claude/cc-codex/bin/codex-task --brief /tmp/cc-codex-fix-1.md --resume
```

   Then repeat steps 2–6. `--resume` continues the latest finished task of
   this workspace and needs every other Codex task here to be finished; with
   parallel tasks still running, dispatch a fresh, self-contained fix brief
   instead. After 2 fix rounds without success, stop and report.

8. Independent verification: dispatch with `--kind verify` only when your
   acceptance commands cannot cover the change (for example: no runnable
   tests, behavior you cannot exercise, or risky areas such as auth, data
   migrations, broad refactors). Otherwise your passing checks are the
   verification.

9. Reply with a short verdict for this task:
   - what Codex changed
   - what you checked and the results
   - whether an independent verification ran and its result
   - any remaining risk or manual step

10. After the verdict, remain in persistent delegation mode. Wait for the next
    user message. Do not exit delegation mode until the user runs `/cc-codex:off`.
