#!/usr/bin/env bash
# dispatch.sh — Run ONE Codex task. tmux is OPTIONAL.
#
# The ONLY trigger for this whole system is you invoking the /cc-codex command.
# This script never decides whether to run based on the environment.
#
# tmux behavior (purely cosmetic / for visibility):
#   - If you happen to be inside tmux  -> split a pane so you can WATCH the agent.
#   - If you are NOT in tmux           -> run detached in the background, log to file.
# Either way the task runs. Never exits just because tmux is absent.
#
# Safe by default:
#   - sandbox=workspace-write (writes confined to --dir)
#   - danger-full-access only if you pass it explicitly (with a warning)
#   - non-interactive `codex exec` -> no approval prompts to auto-dismiss
#
# Usage:
#   dispatch.sh --file /tmp/task.txt [--id 2] [--sandbox read-only] [--dir /path] [--model NAME]
#   dispatch.sh --list

set -u

STATE_DIR="${CC_CODEX_STATE:-$HOME/.cc-codex/runs}"
mkdir -p "$STATE_DIR"

AGENT_ID=""
TASK_FILE_INPUT=""
SANDBOX="workspace-write"
WORKDIR_OVERRIDE=""
MODEL="${CC_CODEX_MODEL:-}"
LIST_MODE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)    TASK_FILE_INPUT="$2"; shift 2 ;;
    --id)      AGENT_ID="$2"; shift 2 ;;
    --sandbox) SANDBOX="$2"; shift 2 ;;
    --dir)     WORKDIR_OVERRIDE="$2"; shift 2 ;;
    --model)   MODEL="$2"; shift 2 ;;
    --list)    LIST_MODE=true; shift ;;
    *)         echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

# -- list mode --
if $LIST_MODE; then
  echo "Codex runs:"
  found=0
  for sf in "$STATE_DIR"/run-*.state; do
    [[ -f "$sf" ]] || continue
    found=1
    # shellcheck disable=SC1090
    ( source "$sf"; printf "  run-%s [%s] %s  %s\n" "${NUM:-?}" "${STATUS:-?}" "${MODE:-?}" "${TASK:-}" )
  done
  [[ $found -eq 0 ]] && echo "  (none)"
  exit 0
fi

# -- guards (only real prerequisites -- NOT environment gates) --
if ! command -v codex >/dev/null 2>&1; then
  echo "ERROR: codex CLI not found. Install: npm install -g @openai/codex (then codex --login)" >&2
  exit 1
fi
if [[ -z "$TASK_FILE_INPUT" || ! -f "$TASK_FILE_INPUT" ]]; then
  echo "ERROR: --file <path> required and must exist." >&2
  exit 1
fi

case "$SANDBOX" in
  read-only|workspace-write) ;;
  danger-full-access)
    echo "WARNING: danger-full-access grants UNRESTRICTED filesystem access." >&2
    echo "         Proceeding in 2s only because you asked explicitly..." >&2
    sleep 2 ;;
  *) echo "ERROR: invalid --sandbox '$SANDBOX'." >&2; exit 1 ;;
esac

WORKDIR="${WORKDIR_OVERRIDE:-$(pwd)}"

# -- assign run id --
if [[ -z "$AGENT_ID" ]]; then
  for n in 1 2 3 4 5 6 7 8; do
    sf="$STATE_DIR/run-${n}.state"
    if [[ ! -f "$sf" ]]; then AGENT_ID="$n"; break; fi
    st="$( ( source "$sf"; echo "${STATUS:-}" ) )"
    if [[ "$st" != "running" ]]; then AGENT_ID="$n"; break; fi
  done
  [[ -z "$AGENT_ID" ]] && { echo "ERROR: all run slots (1-8) busy." >&2; exit 1; }
fi

STATE_FILE="$STATE_DIR/run-${AGENT_ID}.state"
LOG_FILE="$STATE_DIR/run-${AGENT_ID}.log"
DONE_FILE="$STATE_DIR/run-${AGENT_ID}.done"
TASK_FILE="$STATE_DIR/run-${AGENT_ID}.task"
rm -f "$DONE_FILE" "$LOG_FILE"
cp "$TASK_FILE_INPUT" "$TASK_FILE"
: > "$LOG_FILE"

MODEL_ARGS=()
[[ -n "$MODEL" ]] && MODEL_ARGS=(-c "model=\"$MODEL\"")

# A small runner the agent executes; on exit it rewrites STATUS (portably) and
# writes the exit code to the .done marker. Used by both tmux and background paths.
RUNNER="$STATE_DIR/run-${AGENT_ID}.runner.sh"
{
  echo '#!/usr/bin/env bash'
  echo 'set -u'
  printf 'cd %q || exit 97\n' "$WORKDIR"
  printf 'codex exec --sandbox %q' "$SANDBOX"
  for a in "${MODEL_ARGS[@]}"; do printf ' %q' "$a"; done
  printf ' "$(cat %q)" 2>&1 | tee -a %q\n' "$TASK_FILE" "$LOG_FILE"
  echo 'code=${PIPESTATUS[0]}'
  printf 'tmpf=%q.tmp.$$\n' "$STATE_FILE"
  printf 'if [[ -f %q ]]; then\n' "$STATE_FILE"
  printf '  while IFS= read -r line; do [[ "$line" == STATUS=* ]] && echo "STATUS=\\"$([[ $code -eq 0 ]] && echo done || echo failed)\\"" || echo "$line"; done < %q > "$tmpf" && mv "$tmpf" %q\n' "$STATE_FILE" "$STATE_FILE"
  echo 'fi'
  printf 'echo "$code" > %q\n' "$DONE_FILE"
} > "$RUNNER"
chmod +x "$RUNNER"

# -- decide display mode: tmux if available, else background --
MODE="background"
if [[ -n "${TMUX:-}" ]] && command -v tmux >/dev/null 2>&1; then
  MODE="tmux"
fi

if [[ "$MODE" == "tmux" ]]; then
  ORIGIN_PANE="$(tmux display-message -p '#{pane_id}')"
  PANE_TITLE="cc-codex-${AGENT_ID}"
  WORKERS=$(tmux list-panes -F '#{pane_title}' 2>/dev/null | grep -c '^cc-codex-' || true)
  if [[ "$WORKERS" -eq 0 ]]; then
    tmux split-window -h -p 45
  else
    LAST=$(tmux list-panes -F '#{pane_id}:#{pane_title}' 2>/dev/null | grep ':cc-codex-' | tail -1 | cut -d: -f1)
    [[ -n "$LAST" ]] && tmux select-pane -t "$LAST"
    tmux split-window -v -p 50
  fi
  tmux select-pane -T "$PANE_TITLE"
  TARGET_PANE="$(tmux display-message -p '#{pane_id}')"
  tmux send-keys -t "$TARGET_PANE" "bash $(printf '%q' "$RUNNER")" Enter
  tmux select-pane -t "$ORIGIN_PANE"
else
  setsid bash "$RUNNER" >/dev/null 2>&1 < /dev/null &
fi

# -- write state (running) --
TASK_SAFE="$(head -c 60 "$TASK_FILE" | tr '"\\\n' "'  ")"
cat > "$STATE_FILE" <<EOF
NUM="${AGENT_ID}"
STATUS="running"
MODE="${MODE}"
SANDBOX="${SANDBOX}"
STARTED="$(date '+%H:%M:%S')"
WORKDIR="${WORKDIR}"
LOG="${LOG_FILE}"
TASK="${TASK_SAFE}"
EOF

echo "OK run-${AGENT_ID} launched (${MODE})"
echo "  task:    $(head -c 80 "$TASK_FILE" | tr '\n' ' ')"
echo "  sandbox: ${SANDBOX}"
echo "  dir:     ${WORKDIR}"
echo "  log:     ${LOG_FILE}"
[[ "$MODE" == "tmux" ]] && echo "  (running in a visible tmux pane -- you can watch it)"
echo "  wait:    wait-done.sh ${AGENT_ID}"
