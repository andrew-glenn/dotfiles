# Termcap stuff
export LESS_TERMCAP_mb=$'\e[1;32m'
export LESS_TERMCAP_md=$'\e[1;32m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_so=$'\e[01;33m'
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_us=$'\e[1;4;31m'

export DOTFILES_GIT_REPO=${HOME}/.config/dotfiles

# p10k instant prompt (must be first — before any console output)
if [[ -z "$SKIP_OMZ" ]]; then
  if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then 
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
  fi
fi

# helper functions

function update_path_if_exists(){
  [[ ":${PATH}:" == *":${1}:"* ]] && return
  [[ -d ${1} ]] && export PATH="${PATH}:${1}"
}

function source_if_exists(){
  [[ -f ${1} ]] && source ${1}
}

function exec_if_exists(){
  [[ -f ${1} ]] && ${1}
}

function pyenv_if_exists(){
  [[ -d "${HOME}/.pyenv" ]] || return
  export PYENV_ROOT="$HOME/.pyenv"
  export PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"
  pyenv() {
    unfunction pyenv
    eval "$(command pyenv init --path)"
    eval "$(command pyenv init -)"
    pyenv "$@"
  }
}

function tn() {
  local detach=true
  local cmd=""
  local name="$1"; shift

  while [[ "$1" == -* ]]; do
    case "$1" in
      -d) detach=false; shift ;;
      -c) shift; cmd="$1"; shift ;;
      *) shift ;;
    esac
  done

  local orig=""
  if [[ -n "$TMUX" ]]; then
    orig="$(tmux display-message -p '#S')"
  fi

  if [[ -n "$cmd" ]]; then
    local wrapped="$cmd"
    if [[ -n "$orig" ]]; then
      wrapped="$cmd; tmux switch-client -t $orig; tmux kill-session -t $name"
    fi
    tmux new-session -d -s "$name" "SKIP_OMZ=1 zsh -ic '${wrapped}'"
  else
    tmux new-session -d -s "$name"
  fi

  if [[ -n "$TMUX" ]]; then
    tmux switch-client -t "$name"
  elif $detach; then
    tmux attach-session -t "$name"
  fi
}

ta() {
  local s="${1:-main}"
  tmux attach -d -t "$s" 2>/dev/null || tmux new-session -s "$s"
}

kf() {
  local sel
  sel=$(command kfind --pick "${1:-.}") || return
  [ -n "$sel" ] && cd "$sel" && kcc
}

kfn() { command kfind note "$*"; }
kfp() { command kfind pin; }
kfu() { command kfind unpin; }

# Kiro
kag() {
  if [ "$PWD" = "$HOME" ]; then
    local tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/kiro-scratch.XXXXXX")
    (cd "$tmpdir" && command kiro-cli chat --agent AG "$@")
    KIRO_AGENT=AG ~/.kiro/hooks/extract-transcript.sh "$tmpdir"
    rm -rf "$tmpdir"
  else
    command kiro-cli chat --agent AG "$@"
    KIRO_AGENT=AG ~/.kiro/hooks/extract-transcript.sh "$PWD" &!
  fi
}

grb() {
  for d in */; do
    [ -d "$d.git/rebase-merge" ] || [ -d "$d.git/rebase-apply" ] && echo "$d"
  done
}

nuke() { ps aux | grep -i "$1" | grep -v grep | awk '{print $2}' | xargs kill -9; }


# Terminal / tool stuff
export TERM=xterm-256color
export MISE_SHELL=zsh
export EDITOR=nvim

# PATH updates
update_path_if_exists /opt/homebrew/bin
update_path_if_exists /usr/local/bin
update_path_if_exists /opt/homebrew/opt/gnu-sed/libexec/gnubin
update_path_if_exists ${HOME}/Library/Python3.7/bin
update_path_if_exists ${HOME}/bin
update_path_if_exists ${HOME}/.cargo/bin
update_path_if_exists ${HOME}/.local/bin
update_path_if_exists ${HOME}/.toolbox/bin

if [[ -d ${HOME}/dev/me ]]; then
  for dir in ${HOME}/dev/me/*/bin; do
    update_path_if_exists ${dir}
  done
fi

# Source p10k theme
if [[ -z "$SKIP_OMZ" ]]; then
  if [[ -f ${HOME}/powerlevel10k/powerlevel10k.zsh-theme ]]; then
    source ${HOME}/powerlevel10k/powerlevel10k.zsh-theme
  else
    source_if_exists ${HOME}/.oh-my-zsh/custom/themes/powerlevel10k/powerlevel10k.zsh-theme
  fi
  source_if_exists ${HOME}/.p10k.zsh
fi

source_if_exists ${HOME}/bin/functions.sh
source_if_exists ${HOME}/.zshrc.local

# Non-standard source logic
[[ -f ${HOME}/.local/bin/mise && -f ${DOTFILES_GIT_REPO}/zsh/mise-include.zsh ]] && source ${DOTFILES_GIT_REPO}/zsh/mise-include.zsh

# fzf integration
if command -v fzf &>/dev/null; then
  source <(fzf --zsh) 2>/dev/null || source_if_exists ~/.fzf.zsh
fi

# Execute these scripts if they exist
exec_if_exists ${HOME}/bin/configure-ssh-agent.sh

# conditional alias
if [[ -f ${DOTFILES_GIT_REPO}/scripts/claude-sandbox.sh ]]; then
  if [[ ! -f ${HOME}/.config/.no_claude_alias ]] ; then
    alias claude="${DOTFILES_GIT_REPO}/scripts/claude-sandbox.sh"
  fi
fi

# aliases
alias assistant="kiro-cli chat --agent assistant"
alias ll="lsd -la --group-directories-first"

# hooks
eval "$(direnv hook zsh)"

pyenv_if_exists

