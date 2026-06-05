---
name: cc-codex
description: Delegate heavy or mechanical coding work to OpenAI Codex agents, then review the results. This skill is DORMANT by default and must NEVER be used on your own initiative. Activate it ONLY when the user explicitly asks for it — either by typing the command "/cc-codex" or by saying in plain language that they want Codex to do the work (e.g. "use Codex to…", "let Codex handle…", "delegate this to Codex", "用 Codex 帮我做…", "让 Codex 来做…"). If the user has not explicitly invoked it in one of those ways, ignore this skill completely and work normally — do not delegate, do not mention Codex. Presence of tmux, project size, or task type are NOT triggers.
---

# cc-codex — Delegate to Codex, Then Review

You are the **planner and reviewer**. Codex agents are the **workers**. Codex
writes code; you decide what to delegate, then you check the result. The final
quality judgment is always yours.

## When this skill is allowed to run (read first)

Run ONLY when the user explicitly invoked it, in one of these two ways:
1. They typed the command `/cc-codex ...`, OR
2. They said in plain language that they want Codex to do it — e.g. "use Codex
   to build X", "let Codex handle Y", "delegate this to Codex", "用 Codex 帮我写…",
   "让 Codex 去做…".

If neither happened, this skill stays dormant. Do not delegate, do not bring up
Codex, do not act on tmux being present or a task looking big. The user's
explicit request is the only trigger. (This is deliberate: the user wants their
normal Claude Code sessions untouched unless they ask for delegation.)

## Where the scripts are

The skill is installed globally, so the scripts are at a fixed path:

```bash
DISPATCH="$HOME/.claude/skills/cc-codex/scripts/dispatch.sh"
WAIT="$HOME/.claude/skills/cc-codex/scripts/wait-done.sh"
[[ -x "$DISPATCH" ]] || echo "dispatch.sh missing — reinstall the skill"
```

## Display is automatic (you don't manage it)

`dispatch.sh` checks for tmux by itself:
- Inside tmux → it opens a split pane so the user can watch the agent live.
- Not in tmux → it runs the agent in the background, streaming to a log file.

tmux is never a precondition. The task runs either way, and you get the same
log + done-marker to wait on and review.

## Step 1 — Decide what's worth delegating

Delegation has overhead (spawning the agent, it re-reading the code). Worth it
for **token-heavy or parallelizable** work; not for tiny edits.

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

Sandbox choice (controls what the agent may touch):
- `read-only` — research / audit. Agent cannot write anything.
- `workspace-write` — (default) agent edits files inside the working dir only.
- `danger-full-access` — avoid. Only if the user explicitly insists and accepts
  unrestricted filesystem access; the script warns before proceeding.

## Step 3 — Dispatch (one --file per task; never inline the task text)

Independent tasks → dispatch all, then wait on all:

```bash
cat > /tmp/cc1.txt <<'TASK'
<full task A: what to build, which file(s), exact behavior, data format, edge cases, how to verify>
TASK
cat > /tmp/cc2.txt <<'TASK'
<full task B>
TASK

"$DISPATCH" --file /tmp/cc1.txt --id 1                     # workspace-write (default)
"$DISPATCH" --file /tmp/cc2.txt --id 2 --sandbox read-only # research only
```

Dependent tasks → dispatch one, wait, verify, then the next.

A good task prompt = what to do + which file(s) + exact behavior + data format +
how to verify. Vague prompts produce vague work.

## Step 4 — Wait (event-driven)

```bash
"$WAIT" 1     # blocks until run-1 finishes
"$WAIT" 2
```

For parallel runs, issue the waits as separate background Bash calls so each
reports independently. A long wait means the agent is still working, not dead.
Don't poll by scraping screen text.

## Step 5 — REVIEW (your main job)

For each finished run, you personally:
1. Read what changed — `git diff`, or read the files / the log at
   `~/.cc-codex/runs/run-<id>.log`.
2. Run the real checks that exist — typecheck, linter, tests, or just run the
   script. Deterministic tools beat asking another agent to review.
3. Judge against intent, not just "does it run": edge cases, error handling, that
   it didn't touch unrelated files, that it didn't invent dependencies.
4. Decide: minor issue → fix it yourself; substantial miss → sharpen the prompt
   and re-dispatch; good → mark done.

Report per task:

```
Review
────────────────────────────────────────
✅ run-1  Task A — passes typecheck + tests, behavior correct
⚠️  run-2  Task B — works but missing input validation; I fixed it
❌ run-3  Task C — misread the spec; re-dispatching with a clearer prompt
────────────────────────────────────────
```

## Monitoring

```bash
"$DISPATCH" --list                       # status of all runs
tail -n 80 ~/.cc-codex/runs/run-1.log     # peek at a run's output
```

## Never do

- Never run without an explicit user invocation (`/cc-codex` or a plain-language
  "use Codex…").
- Never gate on or refuse because of tmux.
- Never raise sandbox to `danger-full-access` on your own.
- Never skip the review — delegation without review is unsupervised codegen.
- Never delegate work that needs this conversation's live context.
