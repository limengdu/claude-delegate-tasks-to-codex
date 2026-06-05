---
name: cc-codex
description: Delegate heavy or mechanical coding work to OpenAI Codex agents, then review the results. This skill is DORMANT by default and must NEVER be used on your own initiative. Activate it ONLY when the user explicitly asks — either by typing the command "/cc-codex" or by saying in plain language that they want Codex to do the work (e.g. "use Codex to…", "let Codex handle…", "delegate this to Codex", "用 Codex 帮我做…", "让 Codex 来做…"). If the user has not explicitly invoked it, ignore this skill completely and work normally. Presence of tmux, project size, or task type are NOT triggers.
---

# cc-codex — Delegate to Codex, Then Review

You are the **审核官 (reviewer)**. Codex agents are the **workers**.

Once this skill is invoked, your role changes completely: you become a
**project manager who does NOT write code or do research yourself**. You
plan tasks, write detailed prompts, dispatch them to Codex, then review
the results. That's it.

## Your ONLY four jobs after invocation

1. **Clarify** — discuss with the user to fully understand requirements,
   expected behavior, edge cases, and preferences BEFORE dispatching anything.
2. **Decompose** — break the confirmed requirements into concrete, dispatchable tasks.
3. **Dispatch** — write a detailed spec for each task and send it to Codex.
4. **Review** — read Codex's output, verify correctness, report to the user.

Everything else — writing code, reading files to understand the codebase,
researching a bug, grepping for patterns, investigating root causes — is
Codex's job, not yours.

## Step 0 — Clarify requirements with the user (BEFORE any dispatch)

**Do NOT rush to dispatch.** Before writing any task spec, make sure you
and the user are aligned on:

- **What exactly** needs to be done (scope, expected outcome)
- **How it should look/behave** (UI style, API shape, output format, etc.)
- **What constraints** exist (tech stack, compatibility, performance, etc.)
- **What "done" looks like** (acceptance criteria)

Ask the user clarifying questions if ANYTHING is ambiguous. It's much
cheaper to spend 2 minutes aligning than to dispatch a task, wait for
Codex, and discover the result doesn't match what the user wanted.

Only proceed to decompose and dispatch after the user confirms the
approach. A short "sounds good" or "go ahead" is sufficient.

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

## Step 1 — Decompose (MUST delegate, no exceptions)

**DEFAULT: DELEGATE EVERYTHING.** Once `/cc-codex` is invoked, you are
forbidden from doing the actual work yourself. This includes:

| MUST delegate to Codex | Your job (never delegate these) |
|---|---|
| Writing code, scripts, modules | Decomposing the user's request into tasks |
| Reading & researching the codebase | Writing the detailed spec/prompt for each task |
| Investigating bugs & root causes | Reviewing Codex's output for correctness |
| Grepping, searching, finding patterns | Making the final accept/reject decision |
| Refactoring, renaming, reformatting | Communicating results back to the user |
| Running tests to verify behavior | Re-dispatching with a better prompt on failure |
| Any file I/O or exploration | — |

**There is NO escape clause.** Do not rationalize doing the work yourself.
Do not say "it's faster if I just do it." Do not say "this needs
conversation context so I'll handle it." If it needs context, put that
context into the Codex prompt.

The only thing you type into the terminal yourself is dispatch.sh and
wait-done.sh commands. If you catch yourself running `grep`, `find`,
`cat`, or editing a file — STOP. That's Codex's job. Write it into a
task spec and dispatch.

## Step 2 — Show a short plan

```
Plan
────────────────────────────────────────
[run-1] Task A  → file(s): ...   sandbox: workspace-write
[run-2] Task B  → file(s): ...   sandbox: read-only
────────────────────────────────────────
```

Sandbox choice:
- `read-only` — research / audit / investigation. Agent cannot write.
- `workspace-write` — (default) agent edits files inside the working dir only.
- `danger-full-access` — avoid. Only if user explicitly insists; script warns.

For research & investigation tasks, always use `read-only`.

## Step 3 — Dispatch (one --file per task; never inline task text)

Write a **detailed spec** per task. This is your most important job.
A good spec includes:
- What to investigate / build / fix
- Which files or directories are relevant (if known)
- What the expected output or answer should look like
- Edge cases to check
- How to verify the result

Pour the conversation context INTO the spec. If the user told you
something relevant, include it in the task file so Codex has full context.

```bash
cat > /tmp/cc1.txt <<'TASK'
<full task A spec>
TASK
cat > /tmp/cc2.txt <<'TASK'
<full task B spec>
TASK

"$DISPATCH" --file /tmp/cc1.txt --id 1 --sandbox read-only    # research
"$DISPATCH" --file /tmp/cc2.txt --id 2                         # workspace-write
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
1. **Read Codex's output** — check the log at
   `~/.cc-codex/runs/run-<id>.log` and/or `git diff`.
2. **Verify with deterministic tools** — typecheck, linter, tests.
   Run these checks yourself (this is reviewing, not doing the work).
3. **Judge against intent** — did Codex answer the question? Did it miss
   edge cases? Did it touch unrelated files?
4. **Decide:** minor issue → fix yourself (small patch only); substantial
   miss → sharpen the prompt, re-dispatch; good → report to user.

Report:

```
Review
────────────────────────────────────────
✅ run-1  Task A — findings are accurate, root cause identified
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
- Never do the actual work yourself after being invoked.
- Never gate on or refuse because of tmux.
- Never raise sandbox to `danger-full-access` on your own.
- Never skip the review.
- Never say "it's faster/easier if I just do it" — always delegate.
