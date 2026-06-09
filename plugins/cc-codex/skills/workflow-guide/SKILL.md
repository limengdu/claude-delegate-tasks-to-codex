---
name: workflow-guide
description: Internal reference for the cc-codex delegation workflow. Do not invoke directly.
disable-model-invocation: true
user-invocable: false
---

# cc-codex Workflow Guide

This file is kept as a hidden reference. The active user-facing entrypoints are:

- `commands/once.md` — single-task delegation (one dispatch, then done).
- `commands/on.md` — persistent delegation mode (all tasks go to Codex until
  `/cc-codex:off`).
- `commands/handoff.md` — lightweight handoff when Claude Code already has enough
  conversation context.

## Roles

- Claude owns clarification, architecture, task shaping, review, and final
  acceptance.
- The handoff command skips new architecture discussion and only compacts the
  existing conversation context into an implementation brief.
- Codex owns repository inspection, code changes, test execution, bug fixes, and
  implementation verification.
- `/cc-codex:once` instructions are invocation-scoped. After a final verdict,
  later plain-language user requests should stay in Claude Code unless the user
  explicitly invokes a cc-codex or Codex command again.
- `/cc-codex:on` instructions are session-scoped. All subsequent tasks are
  delegated to Codex until the user runs `/cc-codex:off`.

## Dispatch

Use the official Codex plugin through `/codex:rescue --fresh --wait`.

Every delegated task must start with the non-interactive envelope from
`commands/cc-codex.md` so Codex does the work directly instead of waiting for a
separate approval step.

## Review

After Codex returns, Claude should inspect the reported result and local diff,
then either accept it, dispatch a focused fix, or report a clear blocker.

When the implementation review passes, Claude should run one separate Codex
verification pass before giving the final user-facing verdict.
