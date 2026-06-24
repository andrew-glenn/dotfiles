#!/usr/bin/env bash
# Install CLI tools from GitHub releases to ~/bin.
# Usage: ./install-tools.sh

set -euo pipefail

DEST="${HOME}/bin"
ARCH=$(uname -m)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

case "$ARCH" in
  x86_64)
    ARCH_ALT="amd64"
    ARCH_RUST="x86_64-unknown-linux-musl"
    ARCH_RUST_GNU="x86_64-unknown-linux-musl"
    ;;
  aarch64)
    ARCH_ALT="arm64"
    ARCH_RUST="aarch64-unknown-linux-musl"
    ARCH_RUST_GNU="aarch64-unknown-linux-gnu"
    ;;
  *)
    echo "Unsupported arch: $ARCH" >&2
    exit 1
    ;;
esac

# Tool definitions. Keys are binary names.
# REPO: GitHub owner/repo
# URL:  download URL template ({v} = version)
# BIN:  path to binary inside tarball ({v} = version), empty = direct download
declare -A REPO URL BIN

REPO[fzf]="junegunn/fzf"
URL[fzf]="https://github.com/junegunn/fzf/releases/download/v{v}/fzf-{v}-linux_${ARCH_ALT}.tar.gz"

REPO[fd]="sharkdp/fd"
URL[fd]="https://github.com/sharkdp/fd/releases/download/v{v}/fd-v{v}-${ARCH_RUST}.tar.gz"
BIN[fd]="fd-v{v}-${ARCH_RUST}/fd"

REPO[bat]="sharkdp/bat"
URL[bat]="https://github.com/sharkdp/bat/releases/download/v{v}/bat-v{v}-${ARCH_RUST}.tar.gz"
BIN[bat]="bat-v{v}-${ARCH_RUST}/bat"

REPO[rg]="BurntSushi/ripgrep"
URL[rg]="https://github.com/BurntSushi/ripgrep/releases/download/{v}/ripgrep-{v}-${ARCH_RUST_GNU}.tar.gz"
BIN[rg]="ripgrep-{v}-${ARCH_RUST_GNU}/rg"

REPO[direnv]="direnv/direnv"
URL[direnv]="https://github.com/direnv/direnv/releases/download/v{v}/direnv.linux-${ARCH_ALT}"

REPO[yq]="mikefarah/yq"
URL[yq]="https://github.com/mikefarah/yq/releases/download/v{v}/yq_linux_${ARCH_ALT}"

REPO[zoxide]="ajeetdsouza/zoxide"
URL[zoxide]="https://github.com/ajeetdsouza/zoxide/releases/download/v{v}/zoxide-{v}-${ARCH_RUST}.tar.gz"

REPO[delta]="dandavison/delta"
URL[delta]="https://github.com/dandavison/delta/releases/download/{v}/delta-{v}-${ARCH_RUST_GNU}.tar.gz"
BIN[delta]="delta-{v}-${ARCH_RUST_GNU}/delta"

REPO[tmux]="mjakob-gh/build-static-tmux"
URL[tmux]="https://github.com/mjakob-gh/build-static-tmux/releases/download/v{v}/tmux.linux-${ARCH_ALT}.stripped.gz"

# Install order
TOOLS=(fzf fd bat rg direnv yq zoxide delta tmux)

# ---

_fetch() { curl -fsSL "$1" -o "$2"; }

_latest() {
  local repo="${1:?}"
  curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
    | grep -Po '"tag_name":\s*"\K[^"]+' | sed 's/^v//'
}

_install_tar() {
  local name="${1:?}" url="${2:?}" bin_path="${3:-${name}}"

  _fetch "${url}" "$TMP/${name}.tar.gz"
  tar -xzf "$TMP/${name}.tar.gz" -C "$TMP"
  install -m 755 "$TMP/${bin_path}" "$DEST/${name}"
}

_install_bin() {
  local name="${1:?}" url="${2:?}"
  _fetch "${url}" "$DEST/${name}"
  chmod +x "$DEST/${name}"
}

_install_gz() {
  local name="${1:?}" url="${2:?}"
  _fetch "${url}" "$TMP/${name}.gz"
  gunzip -f "$TMP/${name}.gz"
  install -m 755 "$TMP/${name}" "$DEST/${name}"
}

# ---

mkdir -p "$DEST"
echo "Installing to $DEST (arch: $ARCH)"

for name in "${TOOLS[@]}"; do
  v=$(_latest "${REPO[$name]}")
  url="${URL[$name]//\{v\}/${v}}"
  bin_path="${BIN[$name]:-}"
  bin_path="${bin_path//\{v\}/${v}}"

  echo "-> ${name} (${v})"

  if [ -n "${bin_path}" ]; then
    _install_tar "${name}" "${url}" "${bin_path}"
  elif [[ "${url}" == *.tar.gz ]]; then
    _install_tar "${name}" "${url}"
  elif [[ "${url}" == *.gz ]]; then
    _install_gz "${name}" "${url}"
  else
    _install_bin "${name}" "${url}"
  fi
done

# ---

echo ""
echo "Done. Installed:"
for name in "${TOOLS[@]}"; do
  printf "  %-10s %s\n" "$name" "$("$DEST/$name" --version 2>&1 | head -1)"
done
