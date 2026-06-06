---
description: Turn off cc-codex delegation for the current Claude Code conversation.
argument-hint: [optional note]
disable-model-invocation: true
---

You have been explicitly invoked to turn off cc-codex delegation for the
current Claude Code conversation.

Optional note from the user:

$ARGUMENTS

## Hard contract

- Treat all earlier cc-codex delegation instructions as completed and inactive.
- From this point forward, handle later user requests directly in Claude Code by
  default.
- Do not delegate to Codex, call `/codex:rescue`, or use Codex implementation
  skills unless the user explicitly invokes `/cc-codex:cc-codex`,
  `/cc-codex:handoff`, or another Codex command again.
- If a Codex job is already running, this command does not cancel that external
  job. It only changes how future user requests in this conversation should be
  handled.
- Reply briefly that cc-codex delegation is off for this conversation.
