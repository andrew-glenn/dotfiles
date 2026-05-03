# p10k instant prompt (must be first — before any console output)
[[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]] && \
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"

# helper functions
export DOTFILES_GIT_REPO=${HOME}/.config/dotfiles

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

# Termcap stuff
export LESS_TERMCAP_mb=$'\e[1;32m'
export LESS_TERMCAP_md=$'\e[1;32m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_so=$'\e[01;33m'
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_us=$'\e[1;4;31m'

# Terminal / tool stuff
export TERM=xterm-256color
export MISE_SHELL=zsh

# PATH updates, if path exists. 
update_path_if_exists /opt/homebrew/bin
update_path_if_exists /usr/local/bin
update_path_if_exists /opt/homebrew/opt/gnu-sed/libexec/gnubin
update_path_if_exists ${HOME}/Library/Python3.7/bin
update_path_if_exists ${HOME}/bin
update_path_if_exists ${HOME}/.cargo/bin
update_path_if_exists ${HOME}/.local/bin
update_path_if_exists ${HOME}/.toolbox/bin
## I'll fix this later
# if [[ -d ${HOME}/dev/me ]] && [[ -d ${HOME}/dev/me/active ]]; then 
#   for dir in ${HOME}/dev/me/active/*/bin; do
#     update_path_if_exists ${dir}
#   done
# fi

# Source p10k theme directly (no oh-my-zsh framework)
source_if_exists ${HOME}/.oh-my-zsh/custom/themes/powerlevel10k/powerlevel10k.zsh-theme
source_if_exists ${HOME}/.p10k.zsh
source_if_exists ${HOME}/bin/functions.sh
source_if_exists ${HOME}/.zshrc.local

# Niche conditional vars. 
[[ -L ${HOME}/.tmux.conf ]] && export DOTFILES_GIT_REPO=${DOTFILES_GIT_REPO:-$(git -C ${$(readlink -f ${HOME}/.tmux.conf)%%tmux.conf} rev-parse --show-toplevel)}

# Non-standard source logic. 
[[ -f ${HOME}/.local/bin/mise && -f ${DOTFILES_GIT_REPO}/zsh/mise-include.zsh ]] && source ${DOTFILES_GIT_REPO}/zsh/mise-include.zsh

# Execute these scripts if they exist. 
[ -r ${HOME}/bin/configure-ssh-agent.sh ] && source ${HOME}/bin/configure-ssh-agent.sh

# conditional alias
[[ -f ${DOTFILES_GIT_REPO}/scripts/claude-sandbox.sh && ! -e ${HOME}/.config/claude-local-only ]] && alias claude="${DOTFILES_GIT_REPO}/scripts/claude-sandbox.sh"
# aliases
alias ll="ls -lah"
# hooks
eval "$(direnv hook zsh)"

pyenv_if_exists

# Kiro: if launched from $HOME, cd to temp dir first (no session retention)
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
alias assistant="kiro-cli chat --agent assistant"

# Added by AIM CLI
export PATH="$HOME/.aim/mcp-servers:$PATH"
