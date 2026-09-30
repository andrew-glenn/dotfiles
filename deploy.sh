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

archlinux_stuff() {
  [ -f /etc/arch-release ] || return 0

  local xdg_config="${XDG_CONFIG_HOME:-$HOME/.config}"

  # -- packages needed by the i3 desktop configs in this repo --
  local pkgs=(
    # fonts
    ttf-hack-nerd          # Hack Nerd Font — used by urxvt, kitty, ghostty, i3
    # i3 desktop extras (beyond the base set in arch-bootstrap.sh)
    rofi                   # app launcher
    picom                  # compositor (transparency, fading)
    dunst                  # notification daemon
    feh                    # wallpaper setter
    dex                    # XDG autostart
    xautolock              # idle auto-lock
    brightnessctl          # laptop brightness keys
    network-manager-applet # nm-applet systray icon
    pulseaudio             # audio (pactl for volume keys)
    rxvt-unicode           # urxvt terminal
    # neovim
    neovim
    # zsh
    zsh
  )
  # Only install what isn't already present.
  local to_install=()
  for p in "${pkgs[@]}"; do
    pacman -Qi "$p" &>/dev/null || to_install+=("$p")
  done
  if [ ${#to_install[@]} -gt 0 ]; then
    echo "Installing: ${to_install[*]}"
    sudo pacman -S --needed --noconfirm "${to_install[@]}"
  fi

  # -- symlinks --
  # i3 window manager
  _conditionally_create_symlink "$DOTFILES/i3" "$xdg_config/i3"

  # i3status bar
  _conditionally_create_symlink "$DOTFILES/i3status" "$xdg_config/i3status"

  # rofi launcher
  _conditionally_create_symlink "$DOTFILES/rofi" "$xdg_config/rofi"

  # picom compositor
  _conditionally_create_symlink "$DOTFILES/picom" "$xdg_config/picom"

  # X11: .xinitrc and .Xresources
  _conditionally_create_symlink "$DOTFILES/xenv/.xinitrc" "$HOME/.xinitrc"
  _conditionally_create_symlink "$DOTFILES/xenv/.Xresources" "$HOME/.Xresources"

  # kitty terminal is handled by kitty_stuff(), which runs on both platforms

  # neovim
  _conditionally_create_symlink "$DOTFILES/neovim" "$xdg_config/nvim"
}

# Kitty is configured on both platforms, so this runs unconditionally. The
# repo holds one shared kitty.conf plus a hosts/ file per machine, wired up
# through two generated symlinks that are deliberately untracked.
kitty_stuff() {
  local xdg_config="${XDG_CONFIG_HOME:-$HOME/.config}"
  _conditionally_create_symlink "$DOTFILES/kitty" "$xdg_config/kitty"

  # Pick the per-host config: an exact short-hostname match wins, otherwise
  # fall back to the platform file. Written as a *relative* link so it stays
  # valid regardless of where the repo lives or which machine reads it.
  local short_host target
  short_host="$(hostname -s 2>/dev/null || uname -n)"
  short_host="${short_host%%.*}"
  if [ -f "$DOTFILES/kitty/hosts/${short_host}.conf" ]; then
    target="hosts/${short_host}.conf"
  elif [ "$(uname)" = "Darwin" ]; then
    target="hosts/darwin.conf"
  else
    target="hosts/linux.conf"
  fi
  ln -sfn "$target" "$DOTFILES/kitty/host-active.conf"
  echo "kitty host config -> ${target}"

  # colors-active.conf is generated the same way. Recreate it when missing or
  # dangling ([ -e ] is false for a broken link), which is the state a machine
  # ends up in after syncing a link that pointed at the other machine's paths.
  if [ ! -e "$DOTFILES/kitty/colors-active.conf" ]; then
    ln -sfn "colors-hacker.conf" "$DOTFILES/kitty/colors-active.conf"
    echo "kitty colors -> colors-hacker.conf (default)"
  fi
}

ssh_stuff() {
  mkdir -p -m 700 "$HOME/.ssh"
  _conditionally_create_symlink "$DOTFILES/ssh/rc" "$HOME/.ssh/rc"
}

vim_stuff() {
  _conditionally_create_symlink "$DOTFILES/vim/.vimrc" "$HOME/.vimrc"
}

zsh_stuff() {
  # powerlevel10k is vendored as a git submodule (zsh/powerlevel10k) and the
  # .zshrc sources it directly — no oh-my-zsh framework. Expose the submodule
  # under XDG_DATA_HOME instead of cloning a second copy into ~/.
  _conditionally_create_symlink "$DOTFILES/zsh/powerlevel10k" \
    "${XDG_DATA_HOME:-$HOME/.local/share}/powerlevel10k"

  _conditionally_create_symlink "$DOTFILES/zsh/.zshrc" "$HOME/.zshrc"
  _conditionally_create_symlink "$DOTFILES/zsh/.p10k.zsh" \
    "${XDG_CONFIG_HOME:-$HOME/.config}/p10k/p10k.zsh"
}

tmux_stuff() {
  _conditionally_create_symlink "$DOTFILES/tmux/tmux.conf" "$HOME/.tmux.conf"
  if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
  fi
}

lazygit_stuff() {
  # lazygit's config dir differs per platform, so ask the binary when it's
  # available and fall back to the documented defaults when it isn't.
  local config_dir=""
  if command -v lazygit >/dev/null 2>&1; then
    config_dir="$(lazygit --print-config-dir 2>/dev/null || true)"
  fi
  if [ -z "$config_dir" ]; then
    if [ "$(uname)" = "Darwin" ]; then
      config_dir="$HOME/Library/Application Support/lazygit"
    else
      config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/lazygit"
    fi
  fi
  _conditionally_create_symlink "$DOTFILES/lazygit/config.yml" \
    "$config_dir/config.yml"
}

main() {
  # Populate vendored submodules (powerlevel10k, tmux-menus, tmux-themepack).
  git -C "$DOTFILES" submodule update --init --recursive

  homebrew_stuff
  archlinux_stuff
  kitty_stuff
  ssh_stuff
  vim_stuff
  zsh_stuff
  tmux_stuff
  lazygit_stuff
}

# Only auto-run when executed directly, so the file can be sourced for testing.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
