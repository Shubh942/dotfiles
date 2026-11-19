#!/bin/sh
# Register Claudes that are already running inside zellij (inside herdr) with herdr, as if they
# had just started: gives each its own herdr pane/tab, reports its state, starts its title watcher.
# Use after installing/changing herdr-zellij-subagents.sh. Usage: herdr-zj-adopt.sh

HOOK="$(dirname "$0")/herdr-zellij-subagents.sh"

for pid in $(pgrep -x claude); do
  env="$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null)" || continue
  get() { printf '%s\n' "$env" | sed -n "s/^$1=//p" | head -n1; }
  [ -n "$(get ZELLIJ_SESSION_NAME)" ] && [ "$(get HERDR_ENV)" = 1 ] || continue

  info="$HOME/.claude/sessions/$pid.json"
  sid="$(jq -r '.sessionId // empty' "$info" 2>/dev/null)"
  status="$(jq -r '.status // "idle"' "$info" 2>/dev/null)"
  [ -n "$sid" ] || continue
  transcript="$(ls "$HOME"/.claude/projects/*/"$sid".jsonl 2>/dev/null | head -n1)"
  [ -n "$transcript" ] || transcript="$HOME/.claude/projects/$(readlink "/proc/$pid/cwd" | tr '/.' '--')/$sid.jsonl"

  echo "adopting claude pid=$pid zellij=$(get ZELLIJ_SESSION_NAME) pane=$(get ZELLIJ_PANE_ID) session=$sid"
  json="$(jq -nc --arg s "$sid" --arg t "$transcript" '{session_id:$s, transcript_path:$t}')"
  run() {
    printf '%s' "$json" | env -i HOME="$HOME" PATH="$PATH" XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-}" \
      ZELLIJ="$(get ZELLIJ)" ZELLIJ_SESSION_NAME="$(get ZELLIJ_SESSION_NAME)" ZELLIJ_PANE_ID="$(get ZELLIJ_PANE_ID)" \
      HERDR_ENV=1 HERDR_BIN_PATH="$(get HERDR_BIN_PATH)" HERDR_ZJ_CPID="$pid" \
      sh -c "cd '$(readlink "/proc/$pid/cwd")' 2>/dev/null; exec sh '$HOOK' '$1'"
  }
  run SessionStart
  [ "$status" = idle ] || { sleep 1; run UserPromptSubmit; }
  sleep 2   # let each claim its pane before the next one (first claims the main pane)
done
