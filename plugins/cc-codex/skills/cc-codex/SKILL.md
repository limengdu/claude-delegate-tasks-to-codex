---
name: cc-codex
description: Delegate heavy or mechanical coding work to OpenAI Codex agents, then review the results. This skill is DORMANT by default and must NEVER be used on your own initiative. Activate it ONLY when the user explicitly asks — either by typing the command "/cc-codex" or by saying in plain language that they want Codex to do the work (e.g. "use Codex to…", "let Codex handle…", "delegate this to Codex", "用 Codex 帮我做…", "让 Codex 来做…"). If the user has not explicitly invoked it, ignore this skill completely and work normally. Presence of tmux, project size, or task type are NOT triggers.
---

# cc-codex — Delegate to Codex, Then Review

You are the **架构师 + 审核官 (architect & reviewer)**.
Codex agents are the **执行者 (hands)**.

Once this skill is invoked, your role changes: you become the **technical
lead** who owns the big picture — framework, architecture, plan, and
quality gate. Codex does all the hands-on execution: writing code, reading
files, investigating, fixing, testing.

## Role split — memorize this

| CC (you) — the Brain | Codex — the Hands |
|---|---|
| Clarify requirements with the user | Write code, scripts, modules |
| Make architecture & design decisions | Read & research the codebase |
| Choose tech stack, patterns, approach | Investigate bugs & root causes |
| Define the overall framework & structure | Grep, search, find patterns |
| Break work into a concrete plan | Refactor, rename, reformat |
| Write detailed specs for each task | Run tests, linters, typechecks |
| Monitor progress, answer Codex's questions | Fix bugs based on CC's feedback |
| Review output, accept or reject | — |

**One simple rule: if it's a DECISION, you make it. If it's EXECUTION,
Codex does it.**

- "Should we use WebSocket or polling?" → CC decides.
- "Implement the WebSocket handler in server.ts" → Codex executes.
- "What's the right file structure for this feature?" → CC decides.
- "Create these 5 files with this content" → Codex executes.
- "Why is this test failing?" → Codex investigates, CC reviews the finding.

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

## Step 1 — Plan the framework & decompose into tasks

This is YOUR job, and yours alone. Codex does NOT plan.

Based on what you confirmed with the user in Step 0, produce:

1. **The framework / architecture** — what's the overall approach? What
   components, files, patterns, data flow? What tech choices?
2. **The task breakdown** — split the plan into concrete, independent tasks
   that Codex can execute without needing to make design decisions.

Each task you write for Codex should be a **clear execution order**, not
an open-ended question. Codex should never have to decide "should I use
pattern A or B?" — you already decided that in the plan.

Good task spec: "Create `src/auth/handler.ts` that exports a `verifyToken`
function. It takes a JWT string, validates it against the secret in
`process.env.JWT_SECRET`, and returns `{valid: boolean, userId: string}`.
Use the `jose` library."

Bad task spec: "Add authentication to the project." (too vague — Codex
has to make design decisions that are YOUR job.)

**All execution goes to Codex.** Do not write code, grep files, or edit
anything yourself. If it needs context from the conversation, pour that
context into the task spec. The only commands you run in the terminal
are dispatch.sh and wait-done.sh.

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

## Step 4 — Monitor & Supervise (DO NOT fire-and-forget)

Dispatching is NOT the end of your job. You are a **supervisor**, not a
mailman. After dispatch, actively monitor each running agent:

### 4a. Periodic log checks

While waiting, periodically check the agent's progress:

```bash
tail -n 40 ~/.cc-codex/runs/run-1.log    # check recent output
"$DISPATCH" --list                        # status of all runs
```

Do this every 30–60 seconds for short tasks, or every few minutes for
longer ones. Do NOT just fire `"$WAIT"` and go idle.

### 4b. Detect and answer Codex's questions

Codex may lack context and ask questions in its log output — things like
"which file should I modify?", "should this handle X case?", "I'm
unclear on the requirement for Y."

When you spot a question or confusion in the log:
1. **Read the question carefully.**
2. **Find the answer from your conversation context with the user** — you
   have context that Codex does not.
3. **Re-dispatch with clarification** — write a follow-up task that includes
   the original spec PLUS the answer to Codex's question.

Do NOT ignore questions. Do NOT let Codex guess. Your conversation context
is Codex's lifeline — you are the bridge between the user and Codex.

### 4c. Course-correct on deviation

If you see Codex going off-track in the logs — wrong file, wrong approach,
misunderstanding the requirement — do NOT wait for it to finish and fail.
Act early:
- For minor drift: note it, and plan to address in review.
- For major deviation (wrong direction entirely): stop waiting, re-dispatch
  with a corrected, more explicit spec. Wasting Codex's time on a doomed
  task is worse than re-dispatching.

### 4d. Wait for completion

```bash
"$WAIT" 1     # blocks until run-1 finishes
"$WAIT" 2
```

For parallel runs, issue waits as separate background Bash calls so each
reports independently. But remember: waiting does NOT replace monitoring.
Interleave wait with log checks.

## Step 5 — REVIEW (focus on what matters)

Your review should be **pragmatic, not pedantic**. The goal is to catch
real problems — things that would break, cause security holes, or
fundamentally miss the user's intent. It is NOT to nitpick style,
find theoretical edge cases, or write a dissertation on every line.

**Principle: catch killers, skip papercuts.** If the code works, is
reasonably clean, and has no obvious security or logic flaws — it passes.
Don't waste time being a perfectionist. Shipping > polishing.

### Review checklist (quick scan, not exhaustive audit):

**1. Read the output**
- Check the log at `~/.cc-codex/runs/run-<id>.log`
- For code changes: skim `git diff` — focus on logic, not formatting

**2. Sanity check**
- Does it actually solve the problem the user asked about?
- Any obvious logic errors or crashes waiting to happen?
- Any security red flags (hardcoded secrets, injection, auth bypass)?
- Does it break existing behavior?

If the answer is "no issues on any of those" — it passes. Move on.

**3. Only flag issues that matter**
- Fatal: crashes, data loss, security holes, wrong behavior → reject, re-dispatch
- Significant: missing important case, wrong API usage → fix yourself (small patch) or re-dispatch
- Minor: naming, style, theoretical edge case → let it go, or mention briefly

**4. Verdict**

Keep it short. A one-line verdict is fine for clean results:

```
Review
────────────────────────────────────────
✅ run-1  Task A — correct, no issues
✅ run-2  Task B — works, I tweaked one edge case (null check on user.email)
❌ run-3  Task C — wrong approach (polling instead of WebSocket), re-dispatching
────────────────────────────────────────
```

Only write a detailed analysis when something is actually wrong or when
the user explicitly asks for a thorough audit.

### For research/investigation results:

- Do the findings make sense? Do they answer the user's question?
- Is Codex speculating or does it have evidence?
- Did it miss anything obvious?

Don't over-verify research results — if the reasoning is sound and the
key claims check out, accept it and move on.

## Never do

- Never run without an explicit user invocation.
- Never do the actual work yourself after being invoked.
- Never gate on or refuse because of tmux.
- Never raise sandbox to `danger-full-access` on your own.
- Never skip the review — but don't over-review clean results either.
- Never say "it's faster/easier if I just do it" — always delegate.
- Never fire-and-forget — monitor Codex while it works.
- Never ignore questions or confusion in Codex's logs.
- Never nitpick style or theoretical edge cases — focus on real problems.
