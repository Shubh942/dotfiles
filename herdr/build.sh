#!/bin/sh
# Builds herdr v0.9.5 with zellij-slots.patch and installs it to ~/.local/bin/herdr.
# Needs cargo; downloads Zig 0.16.0 (herdr's build needs it) if it is not installed.
set -eu

here="$(cd "$(dirname "$0")" && pwd)"
src="$HOME/src/herdr"
zig_dir="$HOME/.local/share/zig-0.16.0"

if [ ! -d "$src/.git" ]; then
  git clone https://github.com/herdrdev/herdr.git "$src"
fi
cd "$src"
if ! git rev-parse -q --verify zellij-slots >/dev/null; then
  git checkout -b zellij-slots v0.9.5
  git am "$here/zellij-slots.patch"
fi
git checkout zellij-slots

zig="$(command -v zig || true)"
if [ -z "$zig" ] || ! "$zig" version | grep -q '^0\.16\.'; then
  if [ ! -x "$zig_dir/zig" ]; then
    mkdir -p "$zig_dir"
    curl -fsSL "https://ziglang.org/download/0.16.0/zig-$(uname -m)-linux-0.16.0.tar.xz" \
      | tar -xJ --strip-components=1 -C "$zig_dir"
  fi
  zig="$zig_dir/zig"
fi

ZIG="$zig" cargo build --release
mkdir -p "$HOME/.local/bin"
install -m755 target/release/herdr "$HOME/.local/bin/herdr"
"$HOME/.local/bin/herdr" --version
