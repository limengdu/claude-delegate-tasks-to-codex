#!/usr/bin/env bash
# codex-hud.sh — Outputs Codex status as JSON for claude-hud's --extra-cmd.
# codex-hud.sh —— 为 claude-hud 的 --extra-cmd 输出 Codex 状态 JSON。
#
# Usage: --extra-cmd "/path/to/codex-hud.sh"

set -u

MAX_LABEL_LENGTH=50

# Find the official Codex companion script used by /codex:status.
# 查找 /codex:status 背后使用的官方 Codex companion 脚本。
find_codex_companion() {
  if [[ -n "${CC_CODEX_HUD_COMPANION:-}" && -f "${CC_CODEX_HUD_COMPANION}" ]]; then
    echo "${CC_CODEX_HUD_COMPANION}"
    return
  fi

  find "${HOME}/.claude/plugins/cache" \
    -path "*/openai-codex/codex/*/scripts/codex-companion.mjs" \
    -type f 2>/dev/null | sort -r | head -1
}

# Find the Codex plugin data directory that stores tracked jobs.
# 查找保存 Codex 任务状态的插件数据目录。
find_codex_plugin_data() {
  if [[ -n "${CLAUDE_PLUGIN_DATA:-}" && -d "${CLAUDE_PLUGIN_DATA}" ]]; then
    echo "${CLAUDE_PLUGIN_DATA}"
    return
  fi

  if [[ -d "${HOME}/.claude/plugins/data/codex-openai-codex" ]]; then
    echo "${HOME}/.claude/plugins/data/codex-openai-codex"
    return
  fi

  find "${HOME}/.claude/plugins/data" -maxdepth 1 -name "*codex*" -type d 2>/dev/null | sort -r | head -1
}

# Convert /codex:status --json data into a compact table-like HUD label.
# 将 /codex:status --json 数据压缩成类似状态表格的一行 HUD。
render_label() {
  STATUS_JSON_PAYLOAD="$1" python3 - "$MAX_LABEL_LENGTH" <<'PY'
import json
import os
import sys

max_length = int(sys.argv[1])

try:
    report = json.loads(os.environ.get("STATUS_JSON_PAYLOAD", ""))
except Exception:
    print(json.dumps({"label": "Codex: status unavailable"}))
    raise SystemExit(0)


def clean(value):
    return " ".join(str(value or "").split())


def first_non_empty(*values):
    for value in values:
        text = clean(value)
        if text:
            return text
    return ""


def shorten(text, limit):
    text = clean(text)
    if len(text) <= limit:
        return text
    if limit <= 1:
        return text[:limit]
    return text[: limit - 1].rstrip() + "…"


def join_fields(fields):
    return " | ".join(clean(field) for field in fields if clean(field))


def append_summary(base, summary):
    summary = clean(summary)
    if not summary:
        return base
    remaining = max_length - len(base) - 3
    if remaining >= 8:
        return f"{base} | {shorten(summary, remaining)}"
    return base


def active_job_label(job):
    kind = first_non_empty(job.get("kindLabel"), job.get("kind"), job.get("jobClass"), "job")
    status = first_non_empty(job.get("status"), "unknown")
    phase = clean(job.get("phase"))
    elapsed = first_non_empty(job.get("elapsed"), job.get("duration"))
    summary = clean(job.get("summary"))

    fields = ["Codex", f"{kind}/{status}", phase, elapsed]

    return shorten(append_summary(join_fields(fields), summary), max_length)


def finished_job_label(job, section):
    status = first_non_empty(job.get("status"), "unknown")
    duration = first_non_empty(job.get("duration"), job.get("elapsed"))
    summary = clean(job.get("summary"))
    base = join_fields(["Codex", section, status, duration])
    return shorten(append_summary(base, summary), max_length)


running = report.get("running") if isinstance(report.get("running"), list) else []
latest = report.get("latestFinished") if isinstance(report.get("latestFinished"), dict) else None
recent = report.get("recent") if isinstance(report.get("recent"), list) else []

if running:
    label = active_job_label(running[0])
elif latest:
    label = finished_job_label(latest, "latest")
elif recent:
    label = finished_job_label(recent[0], "recent")
else:
    runtime = clean((report.get("sessionRuntime") or {}).get("label"))
    suffix = runtime if runtime else "no jobs"
    gate = "gate:on" if report.get("needsReview") else "gate:off"
    label = shorten(join_fields(["Codex", "idle", suffix, gate]), max_length)

print(json.dumps({"label": label}))
PY
}

COMPANION=$(find_codex_companion)
[[ -n "$COMPANION" ]] || {
  printf '{"label":"Codex: status unavailable"}\n'
  exit 0
}

PLUGIN_DATA=$(find_codex_plugin_data)

if [[ -n "$PLUGIN_DATA" ]]; then
  STATUS_JSON=$(CLAUDE_PLUGIN_DATA="$PLUGIN_DATA" node "$COMPANION" status --json 2>/dev/null || true)
else
  STATUS_JSON=$(node "$COMPANION" status --json 2>/dev/null || true)
fi

if [[ -z "$STATUS_JSON" ]]; then
  printf '{"label":"Codex: status unavailable"}\n'
  exit 0
fi

render_label "$STATUS_JSON"
