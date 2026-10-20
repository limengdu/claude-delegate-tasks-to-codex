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
- Do not implement code yourself. Your hands-on work is limited to reading results, checking diffs, running the acceptance commands, and writing the final review.
- After Codex finishes, review the result before replying to the user.
- After the final verdict, treat these cc-codex delegation instructions as
  complete. Do not continue delegating later plain-language user requests to
  Codex unless the user explicitly invokes `/cc-codex:once`,
  `/cc-codex:on`, `/cc-codex:handoff`, or another Codex command again.

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

9. Reply with a short final verdict:
   - what Codex changed
   - what you checked and the results
   - whether an independent verification ran and its result
   - any remaining risk or manual step
