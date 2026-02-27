# helper functions
function update_path_if_exists(){
  echo "${PATH}" | grep -q -i "${1}" && return 
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
  export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init --path)"
  eval "$(pyenv init -)"
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

# Oh-my-zsh stuff
DISABLE_AUTO_UPDATE="true"
DISABLE_MAGIC_FUNCTIONS="true"
DISABLE_COMPFIX="true"
ZSH_THEME="powerlevel10k/powerlevel10k"
powerlevel10k_SHORTEN_DIR_LENGTH=2

# PATH updates, if path exists. 
update_path_if_exists /opt/homebrew/bin
update_path_if_exists /usr/local/bin
update_path_if_exists /opt/homebrew/opt/gnu-sed/libexec/gnubin
update_path_if_exists ${HOME}/Library/Python3.7/bin
update_path_if_exists ${HOME}/bin
update_path_if_exists ${HOME}/.cargo/bin
update_path_if_exists ${HOME}/.local/bin
update_path_if_exists ${HOME}/.toolbox/bin

# Source these files if they exists. 
source_if_exists ${HOME}/.oh-my-zsh/oh-my-zsh.sh
source_if_exists ${HOME}/.p10k.zsh
source_if_exists ${HOME}/bin/functions.sh
source_if_exists ${HOME}/.zshrc.local

# Niche conditional vars. 
[[ -L ${HOME}/.tmux.conf ]] && export DOTFILES_GIT_REPO=$(git -C ${$(readlink -f ${HOME}/.tmux.conf)%%tmux.conf} rev-parse --show-toplevel)

# Non-standard source logic. 
[[ -f ${HOME}/.local/bin/mise && ! -z ${DOTFILES_GIT_REPO} ]] &&  source ${DOTFILES_GIT_REPO}/zsh/mise-include.zsh

# Execute these scripts if they exist. 
exec_if_exists ${HOME}/bin/configure-ssh-agent.sh

# aliases
alias ll="ls -lah"
alias kcc="kiro-cli-chat"

# hooks
eval "$(direnv hook zsh)"

pyenv_if_exists
