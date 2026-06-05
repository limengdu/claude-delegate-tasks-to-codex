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

## Step 5 — REVIEW (critical analysis, not rubber-stamping)

You are the last line of defense. Codex is a capable worker, but it makes
mistakes, takes shortcuts, and sometimes produces code that looks correct
but isn't. **Your job is to catch what Codex missed.**

**Do NOT assume Codex's output is correct.** Approach every result with
healthy skepticism. A review that says "looks good" without evidence is
a failed review.

### For EVERY finished run, perform ALL of these checks:

**1. Read the full output**
- Check the log at `~/.cc-codex/runs/run-<id>.log`
- For code changes: read `git diff` carefully, line by line

**2. Correctness analysis**
- Does the code/finding actually solve the original problem?
- Are there logical errors, off-by-one bugs, race conditions?
- Are edge cases handled (empty input, null, overflow, concurrency)?
- Did Codex make assumptions that conflict with the user's requirements?

**3. Risk assessment**
- Security: injection, XSS, auth bypass, secret exposure, unsafe deserialization?
- Performance: O(n²) where O(n) is possible? Memory leaks? Unbounded growth?
- Reliability: unhandled errors? Silent failures? Missing retries for network calls?
- Compatibility: does it break existing behavior? API contract changes?

**4. Code quality check**
- Does it follow the project's existing patterns and conventions?
- Are there unnecessary dependencies or over-engineering?
- Is the naming clear? Would a new developer understand it?

**5. Run deterministic verification**
- Typecheck, linter, tests — run them yourself (this IS reviewing, not doing work).
- If tests don't exist for the change, flag this in your report.

**6. Verdict — with reasoning**

For each run, provide a structured report. NEVER just say "looks good."
Always explain WHY you accept or reject:

```
Review
────────────────────────────────────────
✅ run-1  Task A — root cause correctly identified
   Analysis: Codex found the issue in auth.ts:42 where the token
   expiry check uses < instead of <=. Verified by reading the spec.
   Risk: none, isolated one-line fix.

⚠️  run-2  Task B — works but has issues I fixed
   Analysis: core logic correct, but missing null check on user.email
   which would crash on guest accounts. I patched it (3 lines).
   Risk: low after fix.

❌ run-3  Task C — rejected, re-dispatching
   Analysis: Codex used setTimeout polling instead of WebSocket as
   specified. Wrong approach entirely — likely misread the spec.
   Action: re-dispatching with explicit "MUST use WebSocket" constraint.
────────────────────────────────────────
```

### If the review is for research/investigation:

- Are the findings factually correct? Cross-check key claims.
- Are conclusions well-supported, or is Codex speculating?
- Did Codex miss obvious areas to investigate?
- Are there alternative explanations Codex didn't consider?

## Never do

- Never run without an explicit user invocation.
- Never do the actual work yourself after being invoked.
- Never gate on or refuse because of tmux.
- Never raise sandbox to `danger-full-access` on your own.
- Never skip the review or rubber-stamp Codex's output.
- Never say "it's faster/easier if I just do it" — always delegate.
- Never fire-and-forget — monitor Codex while it works.
- Never ignore questions or confusion in Codex's logs.
- Never accept code without a risk/bug analysis — "looks good" is not a review.
