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
update_path_if_exists ${HOME}/Library/Python3.7/bin
update_path_if_exists ${HOME}/bin
update_path_if_exists ${HOME}/.cargo/bin
update_path_if_exists ${HOME}/.local/bin
update_path_if_exists ${HOME}/.toolbox/bin

# Source these files if they exists. 
source_if_exists ${HOME}/.oh-my-zsh/oh-my-zsh.sh
source_if_exists ${HOME}/bin/functions.sh
source_if_exists ${HOME}/.zshrc.local
source_if_exists ${HOME}/.p10k.zsh

# Non-standard source logic. 
[[ -f ${HOME}/.local/bin/mise ]] &&  source ${DOTFILES_GIT_REPO}/zsh/mise-include.zsh

# Niche conditional vars. 
[[ -L ${HOME}/.tmux.conf ]] && export DOTFILES_GIT_REPO=$(git -C ${$(readlink -f ${HOME}/.tmux.conf)%%tmux.conf} rev-parse --show-toplevel)

# Execute these scripts if they exist. 
exec_if_exists ${HOME}/bin/configure-ssh-agent.sh

# aliases
alias ll="ls -lah"
alias kcc="kiro-cli-chat"

# hooks
eval "$(direnv hook zsh)"
