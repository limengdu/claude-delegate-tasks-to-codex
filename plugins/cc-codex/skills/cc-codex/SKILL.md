---
name: cc-codex
description: Delegate heavy or mechanical coding work to OpenAI Codex agents, then review the results. This skill is DORMANT by default and must NEVER be used on your own initiative. Activate it ONLY when the user explicitly asks — either by typing the command "/cc-codex" or by saying in plain language that they want Codex to do the work (e.g. "use Codex to…", "let Codex handle…", "delegate this to Codex", "用 Codex 帮我做…", "让 Codex 来做…"). If the user has not explicitly invoked it, ignore this skill completely and work normally. Presence of tmux, project size, or task type are NOT triggers.
---

# cc-codex — Delegate to Codex, Then Review

You are the **planner and reviewer**. Codex agents are the **workers**. Codex
writes code; you decide what to delegate, then you check the result. The final
quality judgment is always yours.

## When to run (read first)

Run ONLY when the user explicitly asked, in one of these ways:
1. They typed `/cc-codex ...`
2. They said in plain language to use Codex — e.g. "use Codex to build X",
   "让 Codex 帮我做…"

Otherwise this skill stays dormant. Do not delegate, do not mention Codex.

## Where the scripts are

```bash
DISPATCH="${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh"
WAIT="${CLAUDE_PLUGIN_ROOT}/scripts/wait-done.sh"
[[ -x "$DISPATCH" ]] || echo "dispatch.sh missing — reinstall the plugin"
```

## Display is automatic (you don't manage it)

`dispatch.sh` checks for tmux by itself:
- Inside tmux → splits a pane so the user can watch the agent live.
- Not in tmux → runs the agent in the background, streaming to a log file.

Either way the task runs and you get the same log + done-marker to review.

## Step 1 — Decide what's worth delegating

| Good for Codex | Keep for yourself |
|---|---|
| Self-contained scripts / tools / modules | Architecture & design decisions |
| Boilerplate, codegen, repetitive refactors | Anything needing this conversation's context |
| Independent files that can run in parallel | Tightly coupled multi-step refactors |
| Broad read-only research across many files | The final review and sign-off (always yours) |

If delegating costs more than just doing it, say so and do it yourself.

## Step 2 — Show a short plan

```
Plan
────────────────────────────────────────
[run-1] Task A  → file(s): ...   sandbox: workspace-write
[run-2] Task B  → file(s): ...   sandbox: read-only
────────────────────────────────────────
```

Sandbox choice:
- `read-only` — research / audit. Agent cannot write.
- `workspace-write` — (default) agent edits files inside the working dir only.
- `danger-full-access` — avoid. Only if user explicitly insists; script warns.

## Step 3 — Dispatch (one --file per task; never inline task text)

Write a **detailed spec** per task — expand the user's brief request into full
requirements (what to build, which file(s), exact behavior, data format, edge
cases, how to verify). Then dispatch:

```bash
cat > /tmp/cc1.txt <<'TASK'
<full task A spec>
TASK
cat > /tmp/cc2.txt <<'TASK'
<full task B spec>
TASK

"$DISPATCH" --file /tmp/cc1.txt --id 1                     # workspace-write
"$DISPATCH" --file /tmp/cc2.txt --id 2 --sandbox read-only  # research
```

Independent tasks → dispatch all at once. Dependent tasks → one at a time.

## Step 4 — Wait (event-driven)

```bash
"$WAIT" 1     # blocks until run-1 finishes
"$WAIT" 2
```

For parallel runs, issue waits as separate background Bash calls so each
reports independently.

## Step 5 — REVIEW (your main job)

For each finished run:
1. **Read what changed** — `git diff`, or read the files / the log at
   `~/.cc-codex/runs/run-<id>.log`.
2. **Run real checks** — typecheck, linter, tests, or run the script.
   Deterministic tools beat asking another AI to review.
3. **Judge against intent** — edge cases, error handling, unrelated files
   touched, invented dependencies.
4. **Decide:** minor issue → fix yourself; substantial miss → sharpen prompt,
   re-dispatch; good → mark done.

Report:

```
Review
────────────────────────────────────────
✅ run-1  Task A — passes typecheck + tests, behavior correct
⚠️  run-2  Task B — works but missing input validation; I fixed it
❌ run-3  Task C — misread the spec; re-dispatching with clearer prompt
────────────────────────────────────────
```

## Monitoring

```bash
"$DISPATCH" --list                       # status of all runs
tail -n 80 ~/.cc-codex/runs/run-1.log     # peek at output
```

## Never do

- Never run without an explicit user invocation.
- Never gate on or refuse because of tmux.
- Never raise sandbox to `danger-full-access` on your own.
- Never skip the review.
- Never delegate work that needs this conversation's live context.
