#!/bin/sh
# Links everything under home/ into $HOME, merges the Claude hooks, and
# builds the patched herdr if it is missing.
# Usage: ./install.sh [--build-herdr]
set -eu

repo="$(cd "$(dirname "$0")" && pwd)"
backup="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

# Each file is a symlink into the repo, so edits land here ready to commit.
# Whatever was there before is moved to $backup.
(cd "$repo/home" && find . -type f) | while read -r rel; do
  rel="${rel#./}"
  src="$repo/home/$rel"
  dst="$HOME/$rel"
  [ "$(readlink "$dst" 2>/dev/null)" = "$src" ] && continue
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mkdir -p "$(dirname "$backup/$rel")"
    mv "$dst" "$backup/$rel"
  fi
  ln -s "$src" "$dst"
  echo "linked $rel"
done

# settings.json also holds per-machine settings, so only its hooks are managed.
settings="$HOME/.claude/settings.json"
[ -f "$settings" ] || echo '{}' > "$settings"
hooks="$(sed "s|\\\$HOME|$HOME|g" "$repo/claude/hooks.json")"
printf '%s' "$hooks" | jq -s '.[0] * .[1]' "$settings" - > "$settings.tmp"
mv "$settings.tmp" "$settings"
echo "merged Claude hooks into $settings"

if [ "${1:-}" = --build-herdr ] || ! command -v herdr >/dev/null 2>&1; then
  "$repo/herdr/build.sh"
fi

[ -d "$backup" ] && echo "previous files saved in $backup"
echo done
