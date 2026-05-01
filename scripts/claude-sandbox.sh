#!/usr/bin/env bash
# Run Claude Code interactively inside a Docker container.
# If inside tmux, prompts for a window name first.
# Usage: claude-sandbox.sh [claude args...]

set -euo pipefail

IMAGE="claude-sandbox"
CONTAINER_PREFIX="claude-sandbox"

# --- tmux helpers

_ask_window_name() {
  local name
  read -rp "Window name: " name </dev/tty
  printf '%s' "${name}"
}

_rename_window() {
  local name="${1:?Usage: _rename_window <name>}"
  tmux rename-window "${name}"
}

# --- sandbox helpers

_ensure_image() {
  local dockerfile="${1:?}"
  if ! docker image inspect "${IMAGE}" &>/dev/null; then
    echo "Building ${IMAGE} image..."
    docker build -f "${dockerfile}" -t "${IMAGE}" "$(dirname "${dockerfile}")"
  fi
}

_container_name() {
  local dir="${1:?}"
  local base
  base="$(basename "${dir}")"
  echo "${CONTAINER_PREFIX}-${base//[^a-zA-Z0-9]/-}-$$"
}

_mount_cache() {
  local host_dir="${1:?}" container_dir="${2:?}"
  if [ -d "${host_dir}" ]; then
    volumes+=(-v "${host_dir}":"${container_dir}")
  fi
}

# --- main

if [ -n "${TMUX:-}" ]; then
  window_name=$(_ask_window_name)
  if [ -n "${window_name}" ]; then
    _rename_window "${window_name}"
  fi
fi


project_dir="$(pwd)"
repo_root="$(cd /home/ag/dev/me/active/claude/claude-docker-sandbox && pwd)"

_ensure_image "${repo_root}/Dockerfile.agent"

container_name="$(_container_name "${project_dir}")"

container_home="/home/sandboxuser"

volumes=(
  -v "${project_dir}":/workspace
  -v "${HOME}/.claude":"${container_home}/.claude"
)

# Forward top-level config file if present
[ -f "${HOME}/.claude.json" ] && volumes+=(-v "${HOME}/.claude.json":"${container_home}/.claude.json")

# Forward git config if present
[ -f "${HOME}/.gitconfig" ] && volumes+=(-v "${HOME}/.gitconfig":"${container_home}/.gitconfig":ro)
[ -d "${HOME}/.config/git" ] && volumes+=(-v "${HOME}/.config/git":"${container_home}/.config/git":ro)

# Forward SSH keys for git operations (read-only)
[ -d "${HOME}/.ssh" ] && volumes+=(-v "${HOME}/.ssh":"${container_home}/.ssh":ro)

# Persist common dev caches across runs
_mount_cache "${HOME}/.cache/go-build"  "${container_home}/.cache/go-build"
_mount_cache "${HOME}/go"               "${container_home}/go"
_mount_cache "${HOME}/.npm"             "${container_home}/.npm"
_mount_cache "${HOME}/.cache/pip"       "${container_home}/.cache/pip"
_mount_cache "${HOME}/.cargo"           "${container_home}/.cargo"
_mount_cache "${HOME}/.cache/yarn"      "${container_home}/.cache/yarn"

env_vars=()

# Forward API key — check common env var names
[ -n "${ANTHROPIC_API_KEY:-}" ] && env_vars+=(-e ANTHROPIC_API_KEY)
[ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] && env_vars+=(-e CLAUDE_CODE_OAUTH_TOKEN)
[ -n "${CLAUDE_CODE_USE_BEDROCK:-}" ] && env_vars+=(
  -e CLAUDE_CODE_USE_BEDROCK
  -e AWS_ACCESS_KEY_ID
  -e AWS_SECRET_ACCESS_KEY
  -e AWS_SESSION_TOKEN
  -e AWS_REGION
)
[ -n "${CLAUDE_CODE_USE_VERTEX:-}" ] && env_vars+=(
  -e CLAUDE_CODE_USE_VERTEX
  -e CLOUD_ML_REGION
  -e ANTHROPIC_VERTEX_PROJECT_ID
)

[ -t 0 ] && tty_flag="-it" || tty_flag="-i"

exec docker run --rm ${tty_flag} \
  --name "${container_name}" \
  --user "$(id -u):$(id -g)" \
  "${volumes[@]}" \
  ${env_vars[@]+"${env_vars[@]}"} \
  -e HOME="${container_home}" \
  -e TERM="${TERM:-xterm-256color}" \
  -w /workspace \
  "${IMAGE}" --dangerously-skip-permissions "$@"
