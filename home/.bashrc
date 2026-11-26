# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Load starship prompt if starship is installed
if [ -x /usr/bin/starship ]; then
	__main() {
		local major="${BASH_VERSINFO[0]}"
		local minor="${BASH_VERSINFO[1]}"

		if ((major > 4)) || { ((major == 4)) && ((minor >= 1)); }; then
			source <("/usr/bin/starship" init bash --print-full-init)
		else
			source /dev/stdin <<<"$("/usr/bin/starship" init bash --print-full-init)"
		fi
	}
	__main
	unset -f __main
fi

# Advanced command-not-found hook
if [[ -f /usr/share/doc/find-the-command/ftc.bash ]]; then
  source /usr/share/doc/find-the-command/ftc.bash
fi


## Useful aliases

# Replace ls with eza
if [[ -x /usr/bin/eza ]]; then
  alias ls='eza -al --color=always --group-directories-first --icons'     # preferred listing
  alias la='eza -a --color=always --group-directories-first --icons'      # all files and dirs
  alias ll='eza -l --color=always --group-directories-first --icons'      # long format
  alias lt='eza -aT --color=always --group-directories-first --icons'     # tree listing
  alias l.='eza -ald --color=always --group-directories-first --icons .*' # show only dotfiles
fi
# Enable bash completion
if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
fi


# Replace some more things with better alternatives
if [ -x /usr/bin/bat ]; then
  alias cat='bat --style header --style snip --style changes --style header'
fi

[ ! -x /usr/bin/yay ] && [ -x /usr/bin/paru ] && alias yay='paru'

# Common use
alias grubup="sudo update-grub"
alias fixpacman="sudo rm /var/lib/pacman/db.lck"
alias tarnow='tar -acf '
alias untar='tar -zxvf '
alias wget='wget -c '
alias rmpkg="sudo pacman -Rdd"
alias psmem='ps auxf | sort -nr -k 4'
alias psmem10='ps auxf | sort -nr -k 4 | head -10'
alias upd='/usr/bin/garuda-update'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
alias grep='ugrep --color=auto'
alias fgrep='ugrep -F --color=auto'
alias egrep='ugrep -E --color=auto'
alias hw='hwinfo --short'                          # Hardware Info
alias big="expac -H M '%m\t%n' | sort -h | nl"     # Sort installed packages according to size in MB (expac must be installed)
alias gitpkg='pacman -Q | grep -i "\-git" | wc -l' # List amount of -git packages
alias ip='ip -color'

# Get fastest mirrors
alias mirror="sudo reflector -f 30 -l 30 --number 10 --verbose --save /etc/pacman.d/mirrorlist"
alias mirrord="sudo reflector --latest 50 --number 20 --sort delay --save /etc/pacman.d/mirrorlist"
alias mirrors="sudo reflector --latest 50 --number 20 --sort score --save /etc/pacman.d/mirrorlist"
alias mirrora="sudo reflector --latest 50 --number 20 --sort age --save /etc/pacman.d/mirrorlist"

# Help people new to Arch
alias apt='man pacman'
alias apt-get='man pacman'
alias please='sudo'
alias tb='nc termbin.com 9999'
alias helpme='cht.sh --shell'
alias pacdiff='sudo -H DIFFPROG=meld pacdiff'

# Cleanup orphaned packages
alias cleanup='sudo pacman -Rns $(pacman -Qtdq)'

# Get the error messages from journalctl
alias jctl="journalctl -p 3 -xb"

# Recent installed packages
alias rip="expac --timefmt='%Y-%m-%d %T' '%l\t%n %v' | sort | tail -200 | nl"
export PATH="$PATH:/devtools/bin"
export PATH="$PATH:/home/shubh/shubh/documentation/repos/monorepo/devtools/bin"
export PATH="$PATH:/documentation/repos/monorepo/devtools/bin"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
export USE_BAZEL_VERSION=8.7.0

export GOPROXY=off
export GOPROXY=https://proxy.golang.org,direct
export GOPROXY=https://proxy.golang.org,direct
export PATH=$PATH:$HOME/go/bin
export PATH=$PATH:$HOME/go/bin

. "$HOME/.local/bin/env"
source $HOME/.local/bin/env
. "$HOME/.cargo/env"
export PATH="$PATH:/opt/flutter/bin"
export PATH="$PATH:/opt/flutter/bin"
export PATH="$PATH:/opt/flutter/bin"

# opencode
export PATH=/home/shubh/.opencode/bin:$PATH

# neww — spin up a fresh scratch worktree from the bare monorepo
# Usage: neww [optional-label]
# Creates branch scratch/YYYYMMDD-HHMMSS-RANDOM and checks it out
# as a sibling worktree, then cd's into it.
neww() {
    local bare_repo="/home/shubh/Documents/repos/monorepo"
    local worktrees_dir="/home/shubh/Documents/repos"
    local rand
    rand=$(cat /dev/urandom | tr -dc 'a-z0-9' | head -c 6 2>/dev/null)
    local ts
    ts=$(date +%Y%m%d-%H%M%S)
    local label="${1:-scratch}"
    local branch="scratch/${ts}-${rand}"
    local dir="${worktrees_dir}/${label}-${ts}-${rand}"
    echo "Creating worktree: $dir  (branch: $branch)"
    git -C "$bare_repo" worktree add -b "$branch" "$dir" master
    cd "$dir" || return 1
    echo "Done. You are now in $dir"
}
export PATH="$HOME/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$PATH:$(go env GOPATH)/bin"

# Every herdr tab runs zellij; herdr marks shells it types a restore command into with HERDR_RESUMING.
if [ "${HERDR_ENV:-}" = 1 ] && [ -z "${ZELLIJ:-}" ] && [ -z "${HERDR_RESUMING:-}" ] && command -v zellij >/dev/null; then
  zellij
fi
