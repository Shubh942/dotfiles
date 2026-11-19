#!/bin/sh
# After committing herdr changes in ~/src/herdr (branch zellij-slots),
# run this to refresh zellij-slots.patch, then commit the dotfiles repo.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
git -C "$HOME/src/herdr" format-patch v0.9.5..zellij-slots --stdout > "$here/zellij-slots.patch"
echo "updated $here/zellij-slots.patch"
