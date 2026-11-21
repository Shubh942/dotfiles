#!/bin/sh
# Report Claude Code state to herdr when Claude runs inside zellij nested in a herdr pane.
# herdr's native detection can't see through zellij (the pane's foreground process is
# the zellij client), but HERDR_* env vars propagate into zellij, so we report directly.
#
# herdr shows one agent per herdr pane, so every Claude needs its own herdr pane:
#   - the first Claude in a zellij session reports to the herdr pane the session is attached in
#   - each additional Claude gets a herdr tab running a second zellij client focused on it
#     (herdr-zj-view.sh); the tab is closed again when that Claude exits
# Usage: herdr-zellij-state.sh <hook-event>   (hook JSON on stdin)

[ -n "${ZELLIJ:-}" ] || exit 0
[ "${HERDR_ENV:-}" = "1" ] || exit 0
[ -n "${HERDR_BIN_PATH:-}" ] && [ -n "${ZELLIJ_SESSION_NAME:-}" ] && [ -n "${ZELLIJ_PANE_ID:-}" ] || exit 0

H="$HERDR_BIN_PATH"
# Installing a new herdr renames the old binary, and processes started before keep its path.
[ -x "${H%/*}/herdr" ] && H="${H%/*}/herdr"
VIEW_SCRIPT="$(dirname "$0")/herdr-zj-view.sh"
state_dir="${XDG_RUNTIME_DIR:-/tmp}/herdr-zj/$ZELLIJ_SESSION_NAME"
mkdir -p "$state_dir" 2>/dev/null || exit 0

event="${1:-}"
input="$(cat 2>/dev/null || true)"
session_id="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)"
ntype="$(printf '%s' "$input" | jq -r '.notification_type // empty' 2>/dev/null)"
transcript="$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)"

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

# The Claude process this hook belongs to (identity for pane ownership).
cpid="${HERDR_ZJ_CPID:-$$}"   # HERDR_ZJ_CPID: set by herdr-zj-adopt.sh for already-running Claudes
while [ "$cpid" -gt 1 ] && [ "$(cat /proc/$cpid/comm 2>/dev/null)" != claude ]; do
  cpid="$(awk '{print $4}' /proc/$cpid/stat 2>/dev/null || echo 1)"
done
[ "$cpid" -gt 1 ] || exit 0

# /rename name (custom-title), else Claude's auto title (ai-title).
session_title() {
  grep -E '"type":"(custom|ai)-title"' "$1" 2>/dev/null | tail -n 200 \
    | jq -rs '(map(select(.type=="custom-title"))|last|.customTitle) // (map(select(.type=="ai-title"))|last|.aiTitle) // empty' 2>/dev/null
}

# herdr pane of the user's own zellij client for this session (view clients excluded).
# Found by following the zellij server's unix sockets to client pids and reading their env.
main_pane() {
  srv="$(pgrep -f "zellij --server .*/${ZELLIJ_SESSION_NAME}\$" | head -n1)"
  [ -n "$srv" ] || return 1
  for zc in $(ss -xpn 2>/dev/null | awk -v srv="pid=$srv," '
      { users[$6]=$9; peer[$6]=$8 }
      END { for (i in users) if (index(users[i], srv)) { p=peer[i];
              if ((p in users) && !index(users[p], srv)) print users[p] } }' \
      | grep -o 'pid=[0-9]*' | cut -d= -f2 | sort -u); do
    env="$(tr '\0' '\n' < "/proc/$zc/environ" 2>/dev/null)"
    printf '%s\n' "$env" | grep -qx 'HERDR_ZJ_VIEW=1' && continue
    p="$(printf '%s\n' "$env" | sed -n 's/^HERDR_PANE_ID=//p')"
    [ -n "$p" ] && { echo "$p"; return 0; }
  done
  return 1
}

# herdr pane this Claude reports to; creates a view tab if it has none. Serialized per session.
# $1 = create (allow creating a view tab) | lookup
target_pane() {
  (
    flock -w 10 9 || exit 1
    view="$state_dir/view-$ZELLIJ_PANE_ID"
    if [ -f "$view" ]; then
      read -r vpane vtab vpid < "$view"
      if [ "$vpid" = "$cpid" ] && "$H" pane get "$vpane" >/dev/null 2>&1; then
        echo "$vpane"; exit 0
      fi
      [ "$vpid" = "$cpid" ] || rm -f "$view"   # left over from an earlier Claude in this zellij pane
    fi
    main="$(main_pane)" || exit 1
    mpid="$(cat "$state_dir/main" 2>/dev/null)"
    if [ -z "$mpid" ] || [ "$mpid" = "$cpid" ] || ! kill -0 "$mpid" 2>/dev/null; then
      echo "$cpid" > "$state_dir/main"
      echo "$main"; exit 0
    fi
    [ "$1" = create ] || exit 1
    ws="$("$H" pane get "$main" 2>/dev/null | jq -r '.result.pane.workspace_id // empty')"
    [ -n "$ws" ] || exit 1
    label="${title:-claude}"
    out="$("$H" tab create --workspace "$ws" --label "$label" --no-focus --cwd "$PWD" 2>/dev/null)" || exit 1
    vpane="$(printf '%s' "$out" | jq -r '.result.root_pane.pane_id // empty')"
    vtab="$(printf '%s' "$out" | jq -r '.result.tab.tab_id // empty')"
    [ -n "$vpane" ] || exit 1
    "$H" pane send-text "$vpane" "exec sh '$VIEW_SCRIPT' '$ZELLIJ_SESSION_NAME' '$ZELLIJ_PANE_ID'
" >/dev/null 2>&1
    echo "$vpane $vtab $cpid" > "$view"
    echo "$vpane"
  ) 9>"$state_dir/lock"
}

report_title() { # $1 pane, $2 title
  [ -n "$2" ] || return 0
  timeout 3 "$H" pane report-metadata "$1" --source zellij-claude-title --agent claude \
    --title "$2" --display-agent "$2" >/dev/null 2>&1 || return 1
  if [ -f "$state_dir/view-$ZELLIJ_PANE_ID" ]; then
    read -r _ vtab _ < "$state_dir/view-$ZELLIJ_PANE_ID"
    [ -n "$vtab" ] && timeout 3 "$H" tab rename "$vtab" "$2" >/dev/null 2>&1
  fi
  return 0
}

title=""
[ -f "$transcript" ] && title="$(session_title "$transcript")"
seq="$(date +%s%N)"
src=zellij-claude

# Everything below talks to herdr; run it in the background so Claude is never slowed down.
(
  if [ "$state" = release ]; then
    pane="$(target_pane lookup)" || pane=""
    [ -n "$pane" ] && timeout 3 "$H" pane release-agent "$pane" --source "$src" --agent claude --seq "$seq"
    (
      flock -w 10 9
      view="$state_dir/view-$ZELLIJ_PANE_ID"
      if [ -f "$view" ]; then
        read -r _ vtab vpid < "$view"
        [ "$vpid" = "$cpid" ] && { [ -n "$vtab" ] && "$H" tab close "$vtab"; rm -f "$view"; }
      fi
      [ "$(cat "$state_dir/main" 2>/dev/null)" = "$cpid" ] && rm -f "$state_dir/main"
    ) 9>"$state_dir/lock"
    exit 0
  fi

  pane="$(target_pane create)" || exit 0
  [ -n "$pane" ] || exit 0
  set -- pane report-agent "$pane" --source "$src" --agent claude --state "$state" --seq "$seq"
  [ -n "$session_id" ] && set -- "$@" --agent-session-id "$session_id"
  timeout 3 "$H" "$@"
  report_title "$pane" "$title"

  # /rename fires no hook, so SessionStart spawns a watcher that pushes title changes to
  # herdr until this Claude exits.
  if [ "$event" = SessionStart ] && [ -n "$transcript" ]; then
    pidfile="$state_dir/watch-$cpid.pid"
    if ! { [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; }; then
      sh -c 'echo $PPID' > "$pidfile"
      last="$title"
      while kill -0 "$cpid" 2>/dev/null; do
        sleep 2
        t="$(session_title "$transcript")"
        if [ -n "$t" ] && [ "$t" != "$last" ] && p="$(target_pane lookup)" && [ -n "$p" ]; then
          report_title "$p" "$t" && last="$t"
        fi
      done
      rm -f "$pidfile"
    fi
  fi
) </dev/null >/dev/null 2>&1 &
exit 0
