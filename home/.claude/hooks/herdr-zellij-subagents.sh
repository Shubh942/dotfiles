#!/bin/sh
# Report Claude Code running inside zellij (nested in a herdr pane) to herdr as a sub-agent.
# Needs the patched herdr (~/src/herdr, branch zellij-slots) with `herdr pane report-sub-agent`.
#
# Every Claude is its own herdr agent: slot = its zellij pane id, reported on the herdr pane that
# shows the zellij session. Selecting the agent in herdr focuses that pane and runs
# `zellij action focus-pane-id` so zellij switches to that Claude.
# Usage: herdr-zellij-subagents.sh <hook-event>   (hook JSON on stdin)

[ -n "${ZELLIJ:-}" ] || exit 0
[ "${HERDR_ENV:-}" = "1" ] || exit 0
[ -n "${HERDR_BIN_PATH:-}" ] && [ -n "${ZELLIJ_SESSION_NAME:-}" ] && [ -n "${ZELLIJ_PANE_ID:-}" ] || exit 0

H="$HERDR_BIN_PATH"
# Installing a new herdr renames the old binary, and processes started before keep its path.
[ -x "${H%/*}/herdr" ] && H="${H%/*}/herdr"
state_dir="${XDG_RUNTIME_DIR:-/tmp}/herdr-zj/$ZELLIJ_SESSION_NAME"
mkdir -p "$state_dir" 2>/dev/null || exit 0
slot="$ZELLIJ_PANE_ID"

event="${1:-}"
input="$(cat 2>/dev/null || true)"
ntype="$(printf '%s' "$input" | jq -r '.notification_type // empty' 2>/dev/null)"
transcript="$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)"
session_id="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
end_reason="$(printf '%s' "$input" | jq -r '.reason // empty' 2>/dev/null)"

case "$event" in
  SessionStart|Stop) state=idle ;;
  UserPromptSubmit|PreToolUse|PostToolUse) state=working ;;
  PermissionRequest) state=blocked ;;
  Notification)
    case "$ntype" in
      permission_prompt|elicitation_dialog) state=blocked ;;
      idle_prompt) state=idle ;;
      *) exit 0 ;;
    esac ;;
  SessionEnd) state=release ;;
  *) exit 0 ;;
esac

# The Claude process this hook belongs to. HERDR_ZJ_CPID: set by herdr-zj-adopt.sh.
cpid="${HERDR_ZJ_CPID:-$$}"
while [ "$cpid" -gt 1 ] && [ "$(cat /proc/$cpid/comm 2>/dev/null)" != claude ]; do
  cpid="$(awk '{print $4}' /proc/$cpid/stat 2>/dev/null || echo 1)"
done
[ "$cpid" -gt 1 ] || exit 0

# /rename name (custom-title), else Claude's auto title (ai-title).
session_title() {
  grep -E '"type":"(custom|ai)-title"' "$1" 2>/dev/null | tail -n 200 \
    | jq -rs '(map(select(.type=="custom-title"))|last|.customTitle) // (map(select(.type=="ai-title"))|last|.aiTitle) // empty' 2>/dev/null
}

# herdr pane of the zellij client attached to this session: follow the zellij server's unix
# sockets to client pids and read HERDR_PANE_ID from their environment.
herdr_pane() {
  srv="$(pgrep -f "zellij --server .*/${ZELLIJ_SESSION_NAME}\$" | head -n1)"
  [ -n "$srv" ] || return 1
  for zc in $(ss -xpn 2>/dev/null | awk -v srv="pid=$srv," '
      { users[$6]=$9; peer[$6]=$8 }
      END { for (i in users) if (index(users[i], srv)) { p=peer[i];
              if ((p in users) && !index(users[p], srv)) print users[p] } }' \
      | grep -o 'pid=[0-9]*' | cut -d= -f2 | sort -u); do
    p="$(tr '\0' '\n' < "/proc/$zc/environ" 2>/dev/null | sed -n 's/^HERDR_PANE_ID=//p')"
    [ -n "$p" ] && { echo "$p"; return 0; }
  done
  return 1
}

report() { # $1 state; reports to the current herdr pane, moving the slot if the pane changed
  pane="$(herdr_pane)" || return 1
  last_pane="$(cat "$state_dir/pane-$slot" 2>/dev/null)"
  if [ -n "$last_pane" ] && [ "$last_pane" != "$pane" ]; then
    timeout 3 "$H" pane release-sub-agent "$last_pane" --slot "$slot" >/dev/null 2>&1
  fi
  echo "$pane" > "$state_dir/pane-$slot"
  echo "$1" > "$state_dir/state-$slot"
  save_for_restore
  set -- pane report-sub-agent "$pane" --slot "$slot" --source zellij-claude --agent claude \
    --state "$1" --seq "$(date +%s%N)" --pane-resume "herdr-zj-restore $ZELLIJ_SESSION_NAME"
  [ -n "$title" ] && set -- "$@" --title "$title" --display-agent "$title"
  timeout 3 "$H" "$@" -- zellij -s "$ZELLIJ_SESSION_NAME" action focus-pane-id "terminal_$slot" \
    >/dev/null 2>&1
}

# Durable copy (survives reboot, unlike $state_dir) that herdr-zj-restore rebuilds from.
saved_dir="${XDG_STATE_HOME:-$HOME/.local/state}/herdr-zj/$ZELLIJ_SESSION_NAME"
save_for_restore() {
  [ -n "$session_id" ] || return 0
  mkdir -p "$saved_dir" || return 0
  tr '\0' '\n' < "/proc/$cpid/cmdline" 2>/dev/null \
    | jq -R . | jq -s --arg id "$session_id" --arg cwd "$cwd" --arg title "$title" \
      '{session_id: $id, cwd: $cwd, title: $title, argv: .}' > "$saved_dir/$slot.json.tmp" \
    && mv "$saved_dir/$slot.json.tmp" "$saved_dir/$slot.json"
}

# Forget a Claude only when it was quit on purpose; a shutdown or crash keeps it for restore.
forget_for_restore() {
  case "$end_reason" in
    other|"") [ "$(systemctl is-system-running 2>/dev/null)" = stopping ] && return 0 ;;
  esac
  rm -f "$saved_dir/$slot.json"
}

release() {
  pane="$(cat "$state_dir/pane-$slot" 2>/dev/null)"
  [ -n "$pane" ] && timeout 3 "$H" pane release-sub-agent "$pane" --slot "$slot" \
    --seq "$(date +%s%N)" >/dev/null 2>&1
  rm -f "$state_dir/pane-$slot" "$state_dir/state-$slot"
}

# One watcher per zellij session: when zellij focus moves to a Claude pane (tab switch, pane
# focus), mark that Claude focused in herdr's agents list. --focused skips the focus command,
# so herdr does not bounce the switch back to zellij.
focus_watch() {
  lock="$state_dir/focus-watch.lock"
  if ! mkdir "$lock" 2>/dev/null; then
    kill -0 "$(cat "$lock/pid" 2>/dev/null)" 2>/dev/null && return 0
    rm -rf "$lock"; mkdir "$lock" 2>/dev/null || return 0
  fi
  sh -c 'echo $PPID' > "$lock/pid"
  last=""
  while ls "$state_dir"/state-* >/dev/null 2>&1; do
    focused="$(zellij -s "$ZELLIJ_SESSION_NAME" action list-clients 2>/dev/null \
      | awk 'NR==2 {print $2}')" || break
    [ -n "$focused" ] || break
    s="${focused#terminal_}"
    if [ "$s" != "$last" ] && [ -f "$state_dir/state-$s" ] && [ -f "$state_dir/pane-$s" ]; then
      timeout 3 "$H" pane report-sub-agent "$(cat "$state_dir/pane-$s")" --slot "$s" \
        --source zellij-claude --agent claude --state "$(cat "$state_dir/state-$s")" \
        --seq "$(date +%s%N)" --focused >/dev/null 2>&1
    fi
    last="$s"
    sleep 0.4
  done
  rm -rf "$lock"
}
[ "$state" != release ] && (focus_watch) </dev/null >/dev/null 2>&1 &

title=""
[ -f "$transcript" ] && title="$(session_title "$transcript")"

# Talk to herdr in the background so Claude is never slowed down.
(
  if [ "$state" = release ]; then
    forget_for_restore
    release
    exit 0
  fi
  report "$state"

  # /rename fires no hook, so SessionStart spawns a watcher that pushes title changes until this
  # Claude exits, then releases the slot (covers crashes where SessionEnd never runs).
  if [ "$event" = SessionStart ] && [ -n "$transcript" ]; then
    pidfile="$state_dir/watch-$cpid.pid"
    if ! { [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; }; then
      sh -c 'echo $PPID' > "$pidfile"
      last="$title"
      while kill -0 "$cpid" 2>/dev/null; do
        sleep 2
        t="$(session_title "$transcript")"
        if [ -n "$t" ] && [ "$t" != "$last" ]; then
          title="$t"
          report "$(cat "$state_dir/state-$slot" 2>/dev/null || echo idle)" && last="$t"
        fi
      done
      [ -f "$state_dir/pane-$slot" ] && release
      rm -f "$pidfile"
    fi
  fi
) </dev/null >/dev/null 2>&1 &
exit 0
