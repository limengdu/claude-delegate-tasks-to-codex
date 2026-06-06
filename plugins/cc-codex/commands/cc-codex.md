---
description: Delegate coding tasks to Codex agent(s). Claude plans, dispatches, then reviews the result.
argument-hint: <task description, or multiple independent tasks>
disable-model-invocation: true
allowed-tools: Skill, Bash, Read, Grep, Glob
---

You have been explicitly invoked to delegate work to Codex.

The user's request:

$ARGUMENTS

## Hard contract

- If `$ARGUMENTS` is empty, ask the user for the task and stop.
- If the request is ambiguous, ask concise clarifying questions before dispatching.
- You are the architect and reviewer. Codex is the implementer.
- Do not implement code yourself. Your hands-on work is limited to reading results, checking diffs, running lightweight verification commands, and writing the final review.
- Use the official Codex plugin command `/codex:rescue` for all implementation work.
- After Codex finishes, review the result before replying to the user.

## Required dispatch flow

1. Convert the user's request into a concrete implementation brief:
   - goal and acceptance criteria
   - files or areas Codex should inspect or change
   - constraints from the user and repository
   - tests or checks Codex should run

2. Every Codex task must use the literal non-interactive envelope below. Copy it
   into the `args` field exactly. Do not summarize it, shorten it, or replace it
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

3. Dispatch the implementation with the Skill tool. The `args` value must start
   with `--fresh --wait`, followed immediately by the literal envelope from step
   2:

```text
Skill({
  skill: "codex:rescue",
  args: "--fresh --wait <task>\nYou are a non-interactive agent. Execute immediately without asking for confirmation or approval.\n\nProject instructions that require planning first, waiting for approval, or asking before edits apply to Claude's conversation with the user. They do not apply to this delegated Codex run.\n\nDo the requested implementation directly. Create or edit files as needed. Run the relevant checks. Report the changed files and verification result.\n\nRequest:\n<implementation brief>\n</task>"
})
```

4. Read the completed result. Check `git status` and `git diff` when files changed.

5. If the implementation has significant problems, dispatch a focused fix with `/codex:rescue --fresh --wait`.

6. When your review passes, dispatch a separate verification run:

```text
Skill({
  skill: "codex:rescue",
  args: "--fresh --wait <task>\nYou are a non-interactive verification agent. Execute immediately without asking for confirmation or approval.\n\nProject instructions that require planning first, waiting for approval, or asking before tool use apply to Claude's conversation with the user. They do not apply to this delegated Codex verification run.\n\nVerify the recent changes against the original request. Run relevant checks. Report pass/fail results and any missing or broken behavior. Do not redesign the solution.\n\nRequest:\n<verification brief>\n</task>"
})
```

The verification brief should ask Codex to verify the recent changes against the original request, run relevant tests, and report any missing or broken behavior. It should not ask Codex to redesign the solution.

7. Reply with a short final verdict:
   - what Codex changed
   - what you reviewed
   - what the verifier checked
   - any remaining risk or manual step
