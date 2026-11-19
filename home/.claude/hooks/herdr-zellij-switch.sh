#!/bin/sh
# One-time switch to the patched herdr (sub-agents): replace the running herdr server, point
# Claude's settings at the sub-agent hook, then register Claudes already running in zellij.
# Usage: herdr-zellij-switch.sh handoff|restart      Log: $XDG_RUNTIME_DIR/herdr-zellij-switch.log
set -u
mode="${1:-}"
log="${XDG_RUNTIME_DIR:-/tmp}/herdr-zellij-switch.log"
exec >>"$log" 2>&1
echo "=== $(date) mode=$mode"
unset HERDR_ENV HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID HERDR_CLIENT_SOCKET_PATH
H="$HOME/.local/bin/herdr"
hooks="$HOME/.claude/hooks"

case "$mode" in
  handoff) "$H" server live-handoff --import-exe "$H" || { echo "handoff FAILED; nothing else changed"; exit 1; } ;;
  restart) "$H" server stop; sleep 2 ;;  # the next `herdr` launch starts the new server
  *) echo "usage: $0 handoff|restart"; exit 2 ;;
esac

# Claude settings: old view-tab hook -> sub-agent hook (backup kept).
s="$HOME/.claude/settings.json"
cp "$s" "$s.bak-before-subagents"
jq '.hooks |= with_entries(.value |= map(.hooks |= map(
      if (.command | test("herdr-zellij-state\\.sh"))
      then .command |= sub("herdr-zellij-state\\.sh"; "herdr-zellij-subagents.sh") else . end)))' \
  "$s.bak-before-subagents" > "$s.tmp" && mv "$s.tmp" "$s"
echo "settings updated: $(grep -c herdr-zellij-subagents.sh "$s") hook entries"

# Close view tabs the old hook created and stop its watchers (state files list them).
for d in "${XDG_RUNTIME_DIR:-/tmp}"/herdr-zj/*/; do
  [ -d "$d" ] || continue
  for v in "$d"view-*; do
    [ -f "$v" ] || continue
    read -r _ vtab _ < "$v"; [ -n "$vtab" ] && "$H" tab close "$vtab"
  done
  for w in "$d"watch-*.pid; do [ -f "$w" ] && kill "$(cat "$w")" 2>/dev/null; done
  rm -f "$d"view-* "$d"main "$d"watch-*.pid
done

# Register Claudes already running in zellij with the new hook.
sed -i "s/herdr-zellij-state\\.sh/herdr-zellij-subagents.sh/" "$hooks/herdr-zj-adopt.sh"
sh "$hooks/herdr-zj-adopt.sh"
echo "done"
