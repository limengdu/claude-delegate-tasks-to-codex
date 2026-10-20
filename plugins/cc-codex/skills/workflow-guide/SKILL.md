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

Helpers in `~/.claude/cc-codex/bin` (written by the session-start hook):

- `codex-task --brief <file> [--kind verify] [--resume]` wraps the brief in the
  non-interactive envelope and starts a background job through the official
  companion.
- `codex-wait <job-id>` blocks until the job ends and prints a compact report:
  status, Codex's final message, changed files.
- `codex-watchdog --job-id <id>` stays silent while Codex progresses and prints
  `STUCK|...` only when the log stalls or an error repeats.
- `codex-cancel <job-id>` cancels a job.

## Review

Claude starts from the `codex-wait` report, runs the acceptance commands, and
reads code only where it matters. Fixes go back to the same Codex thread with
`codex-task --resume`. A separate Codex verification run (`--kind verify`) is
used when the acceptance commands cannot cover the change.
