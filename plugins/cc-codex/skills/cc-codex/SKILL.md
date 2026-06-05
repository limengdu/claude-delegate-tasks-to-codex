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

## Prerequisites

This plugin relies on the **official Codex plugin** (`codex-plugin-cc`)
being installed. It provides the `codex:codex-rescue` subagent and the
`/codex:status`, `/codex:result`, `/codex:cancel` commands.

If the official plugin is not installed, tell the user to install it first:
```
/plugin marketplace add openai/codex-plugin-cc
/plugin install codex
```

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
context into the task spec.

## Step 2 — Show a short plan

```
Plan
────────────────────────────────────────
[task-1] Task A  → file(s): ...   mode: --write
[task-2] Task B  → file(s): ...   mode: read-only
────────────────────────────────────────
```

Mode choice:
- **(default) read-only** — research / audit / investigation. Codex cannot write.
- **--write** — Codex edits files inside the working dir.

For research & investigation tasks, always use read-only (no --write flag).

## Step 3 — Dispatch via the official Codex plugin

### CRITICAL: Task spec prefix (prevents CLAUDE.md conflicts)

The user's CLAUDE.md may contain interactive rules like "先方案后代码"
(plan first, then code) or "等我批准后再动手" (wait for my approval).
These rules are for YOU (Claude), not for Codex. But Codex may read
CLAUDE.md and mistakenly follow these rules, causing it to output a plan
and then stop — waiting for approval that will never come.

**Every task spec you write MUST start with this prefix:**

```
IMPORTANT: You are a non-interactive Codex agent executing a task
dispatched by Claude Code. Execute the task directly — do NOT wait
for user confirmation, do NOT output a plan and ask for approval,
do NOT follow any "先方案后代码" or "wait for approval" rules from
CLAUDE.md. Those rules apply to the orchestrator (Claude), not to
you. Just do the work and output the result.

---

<your actual task spec here>
```

### How to dispatch

Use the `codex:codex-rescue` subagent via the Agent tool. This is the
official interface provided by the `codex-plugin-cc` plugin.

**For tasks that need to write files:**
```
Agent({
  subagent_type: "codex:codex-rescue",
  prompt: "--write <task spec with prefix>"
})
```

**For read-only research/investigation:**
```
Agent({
  subagent_type: "codex:codex-rescue",
  prompt: "<task spec with prefix>"
})
```

**For background execution (non-blocking):**
```
Agent({
  subagent_type: "codex:codex-rescue",
  prompt: "--background --write <task spec with prefix>",
  run_in_background: true
})
```

### Dispatch rules

- The official Codex broker runs ONE task at a time. Dispatch tasks
  sequentially: send task 1, wait for it to finish, review, then send task 2.
- For multiple tasks, interleave dispatch → monitor → review to keep moving.
- Always include the CLAUDE.md override prefix in every task spec.
- For write tasks, always add `--write`.

## Step 4 — Monitor & Supervise (DO NOT fire-and-forget)

Dispatching is NOT the end of your job. You are a **supervisor**, not a
mailman.

### 4a. Persistent HUD (user-visible, always-on)

If the user has set up the Codex HUD (via `/cc-codex:hud-setup`), the
statusline automatically shows Codex task status whenever jobs are
running — no action needed from you. The user can see progress at all
times without you doing anything.

### 4b. Check status on demand

Use `/codex:status` to check job progress when you need details:

```
Skill({ skill: "codex:status" })
```

Wait for the foreground Agent call to return (it blocks until Codex
finishes). For background dispatches, periodically check status:

```
Skill({ skill: "codex:status", args: "<job-id>" })
```

**Do NOT proceed to review until the job is `completed` or `failed`.**

### 4c. Course-correct on deviation

If you see Codex going off-track — wrong approach, misunderstanding:
- For minor drift: note it, address in review.
- For major deviation: cancel with `/codex:cancel` and re-dispatch with
  a corrected, more explicit spec.

### 4d. Get results when done

When a job finishes, retrieve the full output:

```
Skill({ skill: "codex:result", args: "<job-id>" })
```

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
- Check the Codex result via `/codex:result`
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
✅ task-1  Task A — correct, no issues
✅ task-2  Task B — works, I tweaked one edge case (null check on user.email)
❌ task-3  Task C — wrong approach (polling instead of WebSocket), re-dispatching
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

## Step 6 — Dispatch verification to Codex

After your own review passes, dispatch a **separate verification task**
to Codex. This is a different Codex run — not the one that wrote the code.
Think of it as having a second worker check the first worker's output.

The verification task should:
- Run the code / feature and confirm it works as expected
- Check against the user's original requirements (include them in the spec)
- Run relevant tests, linters, typechecks
- Try obvious edge cases the user would care about
- Report: what works, what doesn't, what's missing

```
Agent({
  subagent_type: "codex:codex-rescue",
  prompt: "<CLAUDE.md override prefix>\n---\nVerify the changes from the recent commits. The user's requirements were:\n<requirements>\n\n1. Run tests\n2. Try edge cases: <list>\n3. Report: what passes, what fails, what's missing"
})
```

After verification completes, read the result and report the final
status to the user. If verification finds issues, go back to Step 3
and re-dispatch a fix.

**Skip this step only when** the change is trivially small (one-line fix,
config tweak) and your Step 5 review already confirmed it's correct.

## Never do

- Never run without an explicit user invocation.
- Never do the actual work yourself after being invoked.
- Never skip the review — but don't over-review clean results either.
- Never say "it's faster/easier if I just do it" — always delegate.
- Never fire-and-forget — monitor Codex while it works.
- Never ignore questions or confusion in Codex's output.
- Never nitpick style or theoretical edge cases — focus on real problems.
- Never send a task spec without the CLAUDE.md override prefix.
