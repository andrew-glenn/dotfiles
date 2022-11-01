function zsh_stuff(){
  if [ ! -d  ~/.oh-my-zsh ]; then
    _download_and_exec_script https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh
  fi

  _conditionally_create_symlink ${PWD}/zsh/powerlevel10k ~/powerlevel10k

  test -L ~/.zshrc || rm ~/.zshrc
  _conditionally_create_symlink ${PWD}/zsh/.zshrc ~/.zshrc
  
  if [ ! -d ${ZSH_CUSTOM:~$HOME}~/.oh-my-zsh/themes/powerlevel10k ]; then
	  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
  fi
}

function tmux_stuff(){
  _conditionally_create_symlink ${PWD}/tmux/tmux.conf ~/.tmux.conf
}


function ssh_stuff(){
  if [ ! -d ~/.ssh/ ]; then
    mkdir ~/.ssh
  fi
  _conditionally_create_symlink ${PWD}/vim/.vimrc ~/.vimrc
  _conditionally_create_symlink ${PWD}/ssh/rc ~/.ssh/rc 
}

function _conditionally_create_symlink(){
  if [ ! -L ${2} ]; then
    ln -s ${1} ${2}
  fi
}

function _download_and_exec_script(){
  TF=$(mktemp)
  curl -fsSL ${1} > ${TF}
  chmod +x ${TF}
  ${TF}
}

function homebrew_stuff(){
  if [ ! -f /opt/homebrew/bin/brew ]; then 
   _download_and_exec_script  https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
  fi
  brew tap homebrew/cask-fonts && brew install --cask font-Hack-nerd-font
}

ssh_stuff
zsh_stuff
tmux_stuff
homebrew_stuff
