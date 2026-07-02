#!/usr/bin/env bash
# deploy.sh — Idempotent dotfiles bootstrap.
# Usage: ./deploy.sh [--dry-run]
#
# Safe to re-run. Existing symlinks are skipped. Existing regular files
# at target locations are backed up to *.bak-dotfiles before linking.
#
# Dependencies installed:
#   macOS: Homebrew, Hack Nerd Font, direnv, neovim (brew)
#   Linux: install-tools.sh (fzf, fd, bat, rg, direnv, yq, zoxide, delta, tmux)
#   Both:  oh-my-zsh, powerlevel10k (into omz custom themes), tmux TPM, git submodules

set -euo pipefail

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"
DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_info()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
_ok()    { printf '\033[1;32m✓\033[0m  %s\n' "$*"; }
_skip()  { printf '\033[1;33m→\033[0m  %s (skipped)\n' "$*"; }
_warn()  { printf '\033[1;33m⚠\033[0m  %s\n' "$*" >&2; }
_err()   { printf '\033[1;31m✗\033[0m  %s\n' "$*" >&2; }

_link() {
  # _link <source> <target>
  # Idempotent symlink creation. Backs up regular files, skips if already correct.
  local src="${1:?}" dst="${2:?}"

  if [[ -L "$dst" ]]; then
    local existing
    existing="$(readlink "$dst")"
    if [[ "$existing" == "$src" ]]; then
      _skip "$dst → $src"
      return 0
    fi
    # Wrong target — remove stale symlink
    $DRY_RUN || rm "$dst"
  elif [[ -e "$dst" ]]; then
    _warn "Backing up existing $dst → ${dst}.bak-dotfiles"
    $DRY_RUN || mv "$dst" "${dst}.bak-dotfiles"
  fi

  local dir
  dir="$(dirname "$dst")"
  [[ -d "$dir" ]] || { $DRY_RUN || mkdir -p "$dir"; }

  if $DRY_RUN; then
    _info "[dry-run] ln -s $src $dst"
  else
    ln -s "$src" "$dst"
    _ok "$dst → $src"
  fi
}

_download_and_exec() {
  local url="${1:?}"
  local tmp
  tmp="$(mktemp)"
  curl -fsSL "$url" -o "$tmp"
  chmod +x "$tmp"
  "$tmp"
  rm -f "$tmp"
}

_command_exists() { command -v "${1:?}" &>/dev/null; }

# ---------------------------------------------------------------------------
# Phase 1: Git Submodules
# ---------------------------------------------------------------------------

_info "Initializing git submodules..."
if $DRY_RUN; then
  _info "[dry-run] git submodule update --init --recursive"
else
  git -C "$DOTFILES" submodule update --init --recursive
  _ok "Submodules initialized"
fi

# ---------------------------------------------------------------------------
# Phase 2: Homebrew (macOS only)
# ---------------------------------------------------------------------------

install_homebrew() {
  [[ "$OS" != "Darwin" ]] && return 0

  if ! _command_exists brew; then
    _info "Installing Homebrew..."
    if $DRY_RUN; then
      _info "[dry-run] install homebrew"
    else
      _download_and_exec "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
      # Ensure brew is on PATH for remainder of this script
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
  else
    _skip "Homebrew already installed"
  fi
}

install_macos_packages() {
  [[ "$OS" != "Darwin" ]] && return 0
  _command_exists brew || return 0

  _info "Installing macOS packages via Homebrew..."

  local packages=(neovim direnv)
  local casks=(font-hack-nerd-font)

  for pkg in "${packages[@]}"; do
    if brew list "$pkg" &>/dev/null; then
      _skip "brew: $pkg"
    elif $DRY_RUN; then
      _info "[dry-run] brew install $pkg"
    else
      brew install "$pkg"
      _ok "brew: $pkg"
    fi
  done

  for cask in "${casks[@]}"; do
    if brew list --cask "$cask" &>/dev/null; then
      _skip "cask: $cask"
    elif $DRY_RUN; then
      _info "[dry-run] brew install --cask $cask"
    else
      brew install --cask "$cask"
      _ok "cask: $cask"
    fi
  done
}

# ---------------------------------------------------------------------------
# Phase 3: Linux tools (install-tools.sh)
# ---------------------------------------------------------------------------

install_linux_tools() {
  [[ "$OS" != "Linux" ]] && return 0

  _info "Installing Linux CLI tools..."
  if $DRY_RUN; then
    _info "[dry-run] ${DOTFILES}/scripts/install-tools.sh"
  else
    "${DOTFILES}/scripts/install-tools.sh"
    _ok "Linux tools installed"
  fi
}

install_linux_fonts() {
  [[ "$OS" != "Linux" ]] && return 0

  local font_dir="${HOME}/.local/share/fonts"
  _info "Installing fonts to $font_dir..."

  if $DRY_RUN; then
    _info "[dry-run] copy fonts → $font_dir"
  else
    mkdir -p "$font_dir"
    cp -r "${DOTFILES}/fonts/"* "$font_dir/" 2>/dev/null || true
    if _command_exists fc-cache; then
      fc-cache -f "$font_dir"
    fi
    _ok "Fonts installed"
  fi
}

# ---------------------------------------------------------------------------
# Phase 4: oh-my-zsh + powerlevel10k
# ---------------------------------------------------------------------------

install_omz() {
  if [[ -d "${HOME}/.oh-my-zsh" ]]; then
    _skip "oh-my-zsh already installed"
  elif $DRY_RUN; then
    _info "[dry-run] install oh-my-zsh"
  else
    _info "Installing oh-my-zsh..."
    # RUNZSH=no prevents the installer from switching shell immediately
    RUNZSH=no KEEP_ZSHRC=yes \
      sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    _ok "oh-my-zsh installed"
  fi
}

install_p10k() {
  local target="${HOME}/.oh-my-zsh/custom/themes/powerlevel10k"

  if [[ -d "$target" ]]; then
    _skip "p10k theme already in oh-my-zsh"
    return 0
  fi

  # Link the submodule copy into oh-my-zsh's custom themes dir
  _info "Linking powerlevel10k into oh-my-zsh custom themes..."
  if $DRY_RUN; then
    _info "[dry-run] ln -s ${DOTFILES}/zsh/powerlevel10k $target"
  else
    mkdir -p "$(dirname "$target")"
    ln -s "${DOTFILES}/zsh/powerlevel10k" "$target"
    _ok "p10k linked → $target"
  fi
}

# ---------------------------------------------------------------------------
# Phase 6: Symlinks
# ---------------------------------------------------------------------------

create_symlinks() {
  _info "Creating symlinks..."

  # Ensure directories exist
  $DRY_RUN || mkdir -p "${HOME}/.ssh" "${HOME}/.config" "${HOME}/.config/p10k" "${HOME}/.local/share" "${HOME}/bin"

  # Shell
  _link "${DOTFILES}/zsh/.zshrc"        "${HOME}/.zshrc"
  _link "${DOTFILES}/zsh/.p10k.zsh"     "${HOME}/.p10k.zsh"

  # XDG paths referenced by .zshrc
  _link "${DOTFILES}/zsh/powerlevel10k" "${HOME}/.local/share/powerlevel10k"
  _link "${HOME}/.p10k.zsh"            "${HOME}/.config/p10k/p10k.zsh"

  # Tmux
  _link "${DOTFILES}/tmux/tmux.conf"    "${HOME}/.tmux.conf"

  # Vim
  _link "${DOTFILES}/vim/.vimrc"        "${HOME}/.vimrc"

  # SSH
  _link "${DOTFILES}/ssh/rc"            "${HOME}/.ssh/rc"

  # Neovim (directory symlink → ~/.config/nvim)
  _link "${DOTFILES}/neovim"            "${HOME}/.config/nvim"

  # Ghostty (directory symlink → ~/.config/ghostty)
  _link "${DOTFILES}/ghostty"           "${HOME}/.config/ghostty"

  # yamllint
  _link "${DOTFILES}/yamllint"          "${HOME}/.config/yamllint"

  # ptpython
  _link "${DOTFILES}/ptpython"          "${HOME}/.config/ptpython"

  # Git templates
  git config --global init.templateDir "${DOTFILES}/git_templates"
  _ok "git templateDir → ${DOTFILES}/git_templates"
}

# ---------------------------------------------------------------------------
# Phase 7: Linux-only extras (i3, picom, rofi, xenv)
# ---------------------------------------------------------------------------

create_linux_symlinks() {
  [[ "$OS" != "Linux" ]] && return 0

  _info "Creating Linux-specific symlinks..."
  $DRY_RUN || mkdir -p "${HOME}/.config"

  # Only link these if the directories exist in dotfiles (they do)
  _link "${DOTFILES}/i3"        "${HOME}/.config/i3"
  _link "${DOTFILES}/i3status"  "${HOME}/.config/i3status"
  _link "${DOTFILES}/rofi"      "${HOME}/.config/rofi"
  _link "${DOTFILES}/picom"     "${HOME}/.config/picom"

  # Xresources
  _link "${DOTFILES}/xenv/.Xresources" "${HOME}/.Xresources"
  _link "${DOTFILES}/xenv/.xinitrc"    "${HOME}/.xinitrc"
}

# ---------------------------------------------------------------------------
# Phase 8: Verify
# ---------------------------------------------------------------------------

verify() {
  _info "Verifying installation..."
  local warnings=0

  if ! _command_exists zsh; then
    _warn "zsh not found — install it manually"
    ((warnings++))
  fi

  if ! _command_exists direnv; then
    _warn "direnv not found — .zshrc expects it"
    ((warnings++))
  fi

  if ! _command_exists nvim; then
    _warn "neovim not found"
    ((warnings++))
  fi

  if [[ ! -d "${HOME}/.oh-my-zsh" ]]; then
    _warn "oh-my-zsh directory missing"
    ((warnings++))
  fi

  if [[ $warnings -eq 0 ]]; then
    _ok "All checks passed"
  else
    _warn "$warnings warning(s) — see above"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  _info "Deploying dotfiles from: $DOTFILES"
  _info "OS: $OS"
  $DRY_RUN && _info "*** DRY RUN — no changes will be made ***"
  echo

  install_homebrew
  install_macos_packages
  install_linux_tools
  install_linux_fonts
  install_omz
  install_p10k
  create_symlinks
  create_linux_symlinks
  verify

  echo
  _ok "Deploy complete."
}

main "$@"
