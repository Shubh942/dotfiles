#!/bin/sh
# Extra zellij client for one Claude: attach to zellij session $1 and focus pane terminal_$2.
# Started inside a herdr tab created by herdr-zellij-state.sh so each Claude gets its own herdr pane.
# Usage: herdr-zj-view.sh <zellij-session> <zellij-pane-id>

session="$1"
pane="$2"
[ -n "$session" ] && [ -n "$pane" ] || exit 1

# zellij CLI actions apply to the client that last sent input, so make this client "active"
# with a no-op (lock mode on/off), then focus the Claude's pane in it.
(
  sleep 1.5
  "$HERDR_BIN_PATH" pane send-keys "$HERDR_PANE_ID" ctrl+g ctrl+g >/dev/null 2>&1
  sleep 0.4
  zellij -s "$session" action focus-pane-id "terminal_$pane" >/dev/null 2>&1
) &

HERDR_ZJ_VIEW=1 exec zellij attach "$session"
