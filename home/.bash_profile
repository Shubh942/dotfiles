#
# ~/.bash_profile
#

[[ -f ~/.bashrc ]] && . ~/.bashrc

. "$HOME/.local/bin/env"
. "$HOME/.cargo/env"
export PATH="$HOME/bin:$PATH"
