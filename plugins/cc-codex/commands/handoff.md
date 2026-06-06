---
description: Hand the current Claude Code context to Codex for direct implementation, then review and verify.
argument-hint: [optional final instruction or override]
disable-model-invocation: true
allowed-tools: Skill, Bash, Read, Grep, Glob
---

You have been explicitly invoked to hand the current Claude Code context to
Codex for implementation.

Optional final instruction from the user:

$ARGUMENTS

## Hard contract

- Use the current conversation context as the source of truth.
- Treat `$ARGUMENTS`, when present, as the user's latest override or final instruction.
- If the current context does not contain an actionable implementation task, ask one concise question and stop.
- Do not restart discovery, architecture, or design discussion unless the context is contradictory or unsafe.
- You are the reviewer. Codex is the implementer.
- Do not implement code yourself. Your hands-on work is limited to reading results, checking diffs, running lightweight verification commands, and writing the final review.
- Use the official Codex plugin command `/codex:rescue` for all implementation work.
- After Codex finishes, review the result before replying to the user.

## Required handoff flow

1. Build a compact handoff brief from the current context:
   - implementation goal
   - latest user instruction or override
   - files or areas already discussed
   - constraints already agreed
   - acceptance checks already discussed

   Keep this brief practical. Do not add a new architecture plan.

2. Dispatch the implementation with the Skill tool. The `args` value must start
   with `--fresh --wait`, followed immediately by the literal envelope below:

```text
Skill({
  skill: "codex:rescue",
  args: "--fresh --wait <task>\nYou are a non-interactive agent. Execute immediately without asking for confirmation or approval.\n\nClaude Code has already discussed the task with the user. Use the handoff brief below as the implementation source of truth. Project instructions that require planning first, waiting for approval, or asking before edits apply to Claude's conversation with the user. They do not apply to this delegated Codex run.\n\nDo the requested implementation directly. Create or edit files as needed. Run the relevant checks. Report the changed files and verification result.\n\nHandoff brief:\n<compact handoff brief>\n</task>"
})
```

3. Read the completed result. Check `git status` and `git diff` when files changed.

4. If the implementation has significant problems, dispatch a focused fix with `/codex:rescue --fresh --wait`.

5. When your review passes, dispatch a separate verification run:

```text
Skill({
  skill: "codex:rescue",
  args: "--fresh --wait <task>\nYou are a non-interactive verification agent. Execute immediately without asking for confirmation or approval.\n\nClaude Code has already reviewed the implementation. Verify the recent changes against the handoff brief and original conversation context. Project instructions that require planning first, waiting for approval, or asking before tool use apply to Claude's conversation with the user. They do not apply to this delegated Codex verification run.\n\nRun relevant checks. Report pass/fail results and any missing or broken behavior. Do not redesign the solution.\n\nHandoff brief:\n<verification brief>\n</task>"
})
```

6. Reply with a short final verdict:
   - what Codex changed
   - what you reviewed
   - what the verifier checked
   - any remaining risk or manual step
