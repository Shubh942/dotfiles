# dotfiles

Terminal and desktop setup: alacritty, kitty, ghostty, wezterm, zellij, fish,
nushell, starship, nvim, niri, git, bash/zsh, btop, lazygit, micro, the Fedora
setup scripts, a patched herdr, and the Claude hooks that connect Claude
running in zellij to herdr.

Secrets stay out of this repo: fish loads them from `~/.ssh/api_keys.fish`.
`fish_variables` is per-machine and not tracked.

## New machine

```sh
git clone git@github.com:<you>/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

`install.sh` symlinks every file under `home/` into `$HOME` (anything already
there goes to `~/.dotfiles-backup/<time>/`), merges `claude/hooks.json` into
`~/.claude/settings.json`, and builds herdr if it is not installed. Rerun it
any time; it skips what is already linked.

Fonts for alacritty: `~/.config/alacritty/setup.sh`. zellij: `~/.config/zellij/setup.sh`.

## Making changes

Config files in `$HOME` are symlinks into this repo, so edit them in place and
commit here.

- New file to track: move it under `home/` at the same path, run `install.sh`.
- Claude hooks: edit `claude/hooks.json` (`$HOME` is filled in on install).
- herdr code: commit in `~/src/herdr` on `zellij-slots`, then run
  `herdr/update-patch.sh`. `herdr/build.sh` (or `install.sh --build-herdr`)
  rebuilds it.

## What the herdr patch adds

- Each Claude inside zellij shows as its own agent in herdr's sidebar.
- Working agents show a spinner instead of a dot.
- Switching zellij tabs highlights that Claude in herdr's agents list.
- After a reboot, herdr runs `herdr-zj-restore`, which rebuilds the zellij
  session with every Claude resumed (`~/.local/state/herdr-zj/` holds the list).
