#!/usr/bin/env bash
# Run Claude Code interactively inside a Docker container.
# Same experience as local claude, just isolated.
# Usage: claude-sandbox.sh [claude args...]

set -euo pipefail

IMAGE="claude-sandbox"
CONTAINER_PREFIX="claude-sandbox"

# ---

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

# ---

project_dir="$(pwd)"
repo_root="$(cd /home/ag/dev/me/claude-docker-sandbox && pwd)"

_ensure_image "${repo_root}/Dockerfile.agent"

container_name="$(_container_name "${project_dir}")"

# Map volumes to a home dir that matches the local UID
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

env_vars=()

# Forward API key — check common env var names
[ -n "${ANTHROPIC_API_KEY:-}" ] && env_vars+=(-e ANTHROPIC_API_KEY)
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
  "${env_vars[@]}" \
  -e HOME="${container_home}" \
  -e TERM="${TERM:-xterm-256color}" \
  -w /workspace \
  "${IMAGE}" "$@"
