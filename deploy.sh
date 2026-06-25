#!/usr/bin/env bash
set -euo pipefail

# Absolute path to this repo, independent of the caller's CWD.
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Symlink $1 -> $2. Idempotent: leaves an existing symlink alone, backs up a
# real file/dir to *.bak before linking, and creates parent dirs as needed.
_conditionally_create_symlink() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ]; then
    return 0
  fi
  if [ -e "$dst" ]; then
    mv "$dst" "${dst}.bak"
    echo "backed up existing ${dst} -> ${dst}.bak"
  fi
  ln -s "$src" "$dst"
}

# Download a script to a temp file and execute it, forwarding any extra args.
# `set -e` aborts if the download fails; the temp file is always cleaned up.
_download_and_exec_script() {
  local url="$1"; shift
  local tf
  tf="$(mktemp)"
  trap 'rm -f "$tf"' RETURN
  curl -fsSL "$url" > "$tf"
  chmod +x "$tf"
  "$tf" "$@"
}

homebrew_stuff() {
  [ "$(uname)" = "Darwin" ] || return 0

  if [ ! -x /opt/homebrew/bin/brew ]; then
    NONINTERACTIVE=1 _download_and_exec_script \
      https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
    { echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"'; } >> "$HOME/.zprofile"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  brew install --cask font-hack-nerd-font
}

ssh_stuff() {
  mkdir -p -m 700 "$HOME/.ssh"
  _conditionally_create_symlink "$DOTFILES/ssh/rc" "$HOME/.ssh/rc"
}

vim_stuff() {
  _conditionally_create_symlink "$DOTFILES/vim/.vimrc" "$HOME/.vimrc"
}

zsh_stuff() {
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    # --unattended: don't chsh or exec zsh, which would hijack this script.
    _download_and_exec_script \
      https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh --unattended
  fi

  local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  if [ ! -d "$zsh_custom/themes/powerlevel10k" ]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
      "$zsh_custom/themes/powerlevel10k"
  fi

  _conditionally_create_symlink "$DOTFILES/zsh/.zshrc" "$HOME/.zshrc"
}

tmux_stuff() {
  _conditionally_create_symlink "$DOTFILES/tmux/tmux.conf" "$HOME/.tmux.conf"
  if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
  fi
}

main() {
  homebrew_stuff
  ssh_stuff
  vim_stuff
  zsh_stuff
  tmux_stuff
}

# Only auto-run when executed directly, so the file can be sourced for testing.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
