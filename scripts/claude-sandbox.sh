#!/usr/bin/env bash
# Run Claude Code interactively inside a Docker container.
# If inside tmux and stdin is a tty, prompts for a window name first.
# Usage: claude-sandbox.sh [--rebuild] [claude args...]

set -euo pipefail

IMAGE="claude-sandbox"
CONTAINER_PREFIX="claude-sandbox"

# Resource limits — override via env, or set CLAUDE_SANDBOX_NO_LIMITS=1 to skip.
MEMORY="${CLAUDE_SANDBOX_MEMORY:-8g}"
CPUS="${CLAUDE_SANDBOX_CPUS:-3}"
PIDS_LIMIT="${CLAUDE_SANDBOX_PIDS_LIMIT:-4096}"
TMP_SIZE="${CLAUDE_SANDBOX_TMP_SIZE:-2g}"

# --- tmux helpers

_ask_window_name() {
  local name=""
  printf 'Window name: ' >/dev/tty
  read -r name </dev/tty || true
  printf '%s' "${name}"
}

_rename_window() {
  local name="${1:?Usage: _rename_window <name>}"
  tmux rename-window "${name}"
}

# --- sandbox helpers

_ensure_image() {
  local dockerfile="${1:?}" force_rebuild="${2:-0}"
  if [ "${force_rebuild}" = "1" ]; then
    echo "Rebuilding ${IMAGE} — run 'make rebuild' in ${repo_root} for full rebuild."
    (cd "${repo_root}" && make build)
    return
  fi
  if ! docker image inspect "${IMAGE}" &>/dev/null; then
    echo "Image ${IMAGE} not found. Run 'make build' in ${repo_root} first." >&2
    exit 1
  fi
}

_mount_cache() {
  local host_dir="${1:?}" container_dir="${2:?}"
  mkdir -p "${host_dir}"
  volumes+=(-v "${host_dir}":"${container_dir}")
}

# --- args

force_rebuild=0
if [ "${1:-}" = "--rebuild" ]; then
  force_rebuild=1
  shift
fi

# --- main

if [ -n "${TMUX:-}" ] && [ -t 0 ]; then
  window_name=$(_ask_window_name)
  if [ -n "${window_name}" ]; then
    _rename_window "${window_name}"
  fi
fi

project_dir="$(pwd)"
repo_root="$(cd /home/ag/dev/me/active/claude/claude-docker-sandbox && pwd)"

_ensure_image "${repo_root}/Dockerfile" "${force_rebuild}"

# Slug mirrors Claude's own ~/.claude/projects/ naming: / and . both become -.
host_project_slug="$(echo "${project_dir}" | sed 's|[/.]|-|g')"
host_project_dir="${HOME}/.claude/projects/${host_project_slug}"
mkdir -p "${host_project_dir}"

# One sandbox per host project dir. If you need a second shell into a running
# session, `docker exec -it <container_name> bash`.
container_name="${CONTAINER_PREFIX}${host_project_slug}"
if docker ps --format '{{.Names}}' | grep -Fxq "${container_name}"; then
  echo "Sandbox already running for this project: ${container_name}" >&2
  echo "Attach with: docker exec -it ${container_name} bash" >&2
  exit 1
fi

container_home="/home/node"

# Per-host-project namespace for ~/.claude/projects/<slug> so transcripts,
# memory, and project state don't collide across host projects (they all
# cd to /workspace inside the container, which would otherwise collapse
# every host project onto the same `-workspace` slug).
volumes=(
  -v "${project_dir}":/workspace
  -v "${HOME}/.claude":"${container_home}/.claude"
  -v "${host_project_dir}":"${container_home}/.claude/projects/-workspace"
)

# Plugins shared from host: outer RO so sandbox can't mutate installed_plugins.json,
# marketplaces, or plugin code; inner RW overlay on plugins/data because plugins
# (e.g. claude-mem) legitimately write observations there.
if [ -d "${HOME}/.claude/plugins" ]; then
  volumes+=(-v "${HOME}/.claude/plugins":"${container_home}/.claude/plugins":ro)
  [ -d "${HOME}/.claude/plugins/data" ] && \
    volumes+=(-v "${HOME}/.claude/plugins/data":"${container_home}/.claude/plugins/data")
fi

# claude-mem writes its database under ~/.claude-mem/ (outside ~/.claude).
[ -d "${HOME}/.claude-mem" ] && volumes+=(-v "${HOME}/.claude-mem":"${container_home}/.claude-mem")

# Top-level config — Claude writes to this on startup (project state, lastUsed),
# so RO mounts hang silently. Copy host file to a per-project scratch path and
# mount that RW. Host ~/.claude.json (incl. OAuth tokens) stays untouched;
# in-container mutations are discarded next run when the copy is refreshed.
if [ -f "${HOME}/.claude.json" ]; then
  claude_json_scratch="${HOME}/.cache/claude-sandbox/claude-json/${host_project_slug}.json"
  mkdir -p "$(dirname "${claude_json_scratch}")"
  cp "${HOME}/.claude.json" "${claude_json_scratch}"
  volumes+=(-v "${claude_json_scratch}":"${container_home}/.claude.json")
fi

# Git config — RO
[ -f "${HOME}/.gitconfig" ] && volumes+=(-v "${HOME}/.gitconfig":"${container_home}/.gitconfig":ro)
[ -d "${HOME}/.config/git" ] && volumes+=(-v "${HOME}/.config/git":"${container_home}/.config/git":ro)

# git_templates referenced by init.templatedir in the dotfiles git config.
git_templates="${HOME}/.config/dotfiles/git_templates"
[ -d "${git_templates}" ] && volumes+=(-v "${git_templates}":"${container_home}/.config/dotfiles/git_templates":ro)

# SSH — agent socket + known_hosts/config only. Private keys stay on host.
ssh_agent_target="/run/host-ssh-agent.sock"
ssh_auth_forwarded=0
if [ -n "${SSH_AUTH_SOCK:-}" ] && [ -S "${SSH_AUTH_SOCK}" ]; then
  volumes+=(-v "${SSH_AUTH_SOCK}":"${ssh_agent_target}")
  ssh_auth_forwarded=1
fi
[ -f "${HOME}/.ssh/known_hosts" ] && volumes+=(-v "${HOME}/.ssh/known_hosts":"${container_home}/.ssh/known_hosts":ro)
[ -f "${HOME}/.ssh/config" ]      && volumes+=(-v "${HOME}/.ssh/config":"${container_home}/.ssh/config":ro)

# Persist common dev caches across runs
_mount_cache "${HOME}/.cache/go-build"  "${container_home}/.cache/go-build"
_mount_cache "${HOME}/go"               "${container_home}/go"
_mount_cache "${HOME}/.npm"             "${container_home}/.npm"
_mount_cache "${HOME}/.cache/pip"       "${container_home}/.cache/pip"
_mount_cache "${HOME}/.cargo"           "${container_home}/.cargo"
_mount_cache "${HOME}/.cache/yarn"      "${container_home}/.cache/yarn"

# Per-project Python venv. Activate inside container with: . ~/.venv/bin/activate
_mount_cache "${HOME}/.cache/claude-sandbox/venvs/${host_project_slug}" \
             "${container_home}/.venv"

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

[ "${ssh_auth_forwarded}" = "1" ] && env_vars+=(-e "SSH_AUTH_SOCK=${ssh_agent_target}")

[ -t 0 ] && tty_flag="-it" || tty_flag="-i"

limit_args=()
if [ -z "${CLAUDE_SANDBOX_NO_LIMITS:-}" ]; then
  limit_args=(
    --memory "${MEMORY}"
    --cpus "${CPUS}"
    --pids-limit "${PIDS_LIMIT}"
    --tmpfs "/tmp:size=${TMP_SIZE}"
  )
fi

exec docker run --rm ${tty_flag} --init \
  --name "${container_name}" \
  --user "$(id -u):$(id -g)" \
  --security-opt no-new-privileges \
  ${limit_args[@]+"${limit_args[@]}"} \
  "${volumes[@]}" \
  ${env_vars[@]+"${env_vars[@]}"} \
  -e HOME="${container_home}" \
  -e TERM="${TERM:-xterm-256color}" \
  -w /workspace \
  --network=host \
  "${IMAGE}" --dangerously-skip-permissions "$@"
