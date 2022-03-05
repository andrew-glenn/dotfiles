# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

export PATH=$HOME/.toolbox/bin:$PATH
# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh
export TERM=xterm-256color
# Set name of the theme to load. Optionally, if you set this to "random"
# it'll load a random theme each time that oh-my-zsh is loaded.
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
#ZSH_THEME="robbyrussell"
ZSH_THEME="powerlevel9k/powerlevel9k"
# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion. Case
# sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git pyenv zsh-pyenv)

source $ZSH/oh-my-zsh.sh
export PATH=$PATH:/usr/local/bin:~/Library/Python/3.7/bin:~/bin
# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ssh
# export SSH_KEY_PATH="~/.ssh/rsa_id"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
POWERLEVEL9K_MODE="nerdfont-complete"
POWERLEVEL9K_DISABLE_RPROMPT=true
POWERLEVEL9K_PROMPT_ON_NEWLINE=false
# Set personal aliases, overriding those provided by oh-my-zsh libs,
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
alias ll="ls -lah"
alias cleardns="sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder"
alias ssh="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
alias mid="sudo plutil -convert xml1 /Library/Managed\ Preferences/andglenn/com.google.Chrome.plist && sudo sed -i -e "\"'4r /Users/andglenn/Documents/chrome.txt'\"" /Library/Managed\ Preferences/andglenn/com.google.Chrome.plist"
alias hardmid="sudo plutil -convert xml1 /Library/Managed\ Preferences/andglenn/com.google.Chrome.plist && sudo sed -i -e "\"'4r /Users/andglenn/Documents/chromeHard.txt'\"" /Library/Managed\ Preferences/andglenn/com.google.Chrome.plist"
#alias pip='pip3'
source /usr/local/bin/virtualenvwrapper.sh
source $ZSH/oh-my-zsh.sh
source ~/bin/functions.sh
#test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"
#POWERLEVEL9K_MODE='nerdfont-complete'
#POWERLEVEL9K_SHORTEN_DIR_LENGTH=2
#POWERLEVEL9K_SHORTEN_STRATEGY="truncate_middle"
#POWERLEVEL9K_CONTEXT_DEFAULT_BACKGROUND="000"
#POWERLEVEL9K_CONTEXT_DEFAULT_FOREGROUND="007"
#POWERLEVEL9K_DIR_HOME_BACKGROUND="001"
#POWERLEVEL9K_DIR_HOME_FOREGROUND="000"
#POWERLEVEL9K_DIR_HOME_SUBFOLDER_BACKGROUND="001"
#POWERLEVEL9K_DIR_HOME_SUBFOLDER_FOREGROUND="000"
#POWERLEVEL9K_NODE_VERSION_BACKGROUND="black"
#POWERLEVEL9K_NODE_VERSION_FOREGROUND="007"
#POWERLEVEL9K_NODE_VERSION_VISUAL_IDENTIFIER_COLOR="002"
#POWERLEVEL9K_LOAD_CRITICAL_BACKGROUND="black"
#POWERLEVEL9K_LOAD_WARNING_BACKGROUND="black"
#POWERLEVEL9K_LOAD_NORMAL_BACKGROUND="black"
#POWERLEVEL9K_LOAD_CRITICAL_FOREGROUND="007"
#POWERLEVEL9K_LOAD_WARNING_FOREGROUND="007"
#POWERLEVEL9K_LOAD_NORMAL_FOREGROUND="007"
#POWERLEVEL9K_LOAD_CRITICAL_VISUAL_IDENTIFIER_COLOR="red"
#POWERLEVEL9K_LOAD_WARNING_VISUAL_IDENTIFIER_COLOR="yellow"
#POWERLEVEL9K_LOAD_NORMAL_VISUAL_IDENTIFIER_COLOR="green"
#POWERLEVEL9K_TIME_BACKGROUND="black"
#POWERLEVEL9K_TIME_FOREGROUND="007"
#POWERLEVEL9K_TIME_FORMAT="%D{%H:%M} %F{003}\uF017"
#POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=('context' 'dir' 'vcs')
#POWERLEVEL9K_LEFT_SEGMENT_SEPARATOR=$'\uE0B0'
#POWERLEVEL9K_RIGHT_SEGMENT_SEPARATOR=$'\uE0B2'
#
POWERLEVEL9K_SHORTEN_DIR_LENGTH=2
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(dir virtualenv  vcs)
POWERLEVEL9K_VIRTUALENV_BACKGROUND='cyan'
source ~/powerlevel10k/powerlevel10k.zsh-theme
eval "$(rbenv init -)"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
