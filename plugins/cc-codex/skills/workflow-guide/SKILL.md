---
name: workflow-guide
description: Internal reference for the cc-codex delegation workflow. Do not invoke directly.
disable-model-invocation: true
user-invocable: false
---

# cc-codex Workflow Guide

This file is kept as a hidden reference. The active user-facing entrypoint is
the `commands/cc-codex.md` command. Use `commands/handoff.md` when Claude Code
already has enough conversation context and only needs to hand the work to
Codex.

## Roles

- Claude owns clarification, architecture, task shaping, review, and final
  acceptance.
- The handoff command skips new architecture discussion and only compacts the
  existing conversation context into an implementation brief.
- Codex owns repository inspection, code changes, test execution, bug fixes, and
  implementation verification.

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
