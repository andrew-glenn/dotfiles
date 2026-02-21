#!/usr/bin/env bash
# Spawn parallel Claude agents in tmux, one Docker container each.
# Usage: ./parallel-run.sh [-t] <title>
#   -t  Use tiled panes in a single window (default: separate windows)

set -euo pipefail

_slugify() {
  local input="${1:?}"
  echo "${input//[^a-zA-Z0-9]/-}"
}

_send_agent() {
  local session="${1:?}"
  local target="${2:?}"
  local slug="${3:?}"
  local project_dir="${4:?}"
  local name="${5:?}"
  local prompt="${6:?}"

  tmux send-keys -t "${target}" \
    "docker run --rm -it --name \"claude-${slug}-${name}\" \
      --user \"$(id -u):$(id -g)\" \
      -v \"${project_dir}\":/workspace \
      -e HOME=/home/sandboxuser \
      claude-agent \"${prompt}\"" Enter
}

_spawn_windows() {
  local session="${1:?}"
  local slug="${2:?}"
  local project_dir="${3:?}"
  shift 3

  tmux new-session -d -s "${session}" -n "orchestrator"

  for agent in "$@"; do
    local name="${agent%%|*}"
    local prompt="${agent##*|}"

    tmux new-window -t "${session}" -n "${name}"
    _send_agent "${session}" "${session}:${name}" "${slug}" "${project_dir}" "${name}" "${prompt}"
  done
}

_spawn_tiled() {
  local session="${1:?}"
  local slug="${2:?}"
  local project_dir="${3:?}"
  shift 3

  tmux new-session -d -s "${session}"

  local pane=0
  for agent in "$@"; do
    local name="${agent%%|*}"
    local prompt="${agent##*|}"

    if [ "${pane}" -gt 0 ]; then
      if [ $(( pane % 2 )) -eq 1 ]; then
        tmux split-window -h -t "${session}"
      else
        tmux split-window -v -t "${session}:0.$(( pane - 1 ))"
      fi
      tmux select-layout -t "${session}" tiled
    fi

    _send_agent "${session}" "${session}:0.${pane}" "${slug}" "${project_dir}" "${name}" "${prompt}"
    pane=$(( pane + 1 ))
  done
}

# ---

tiled=0
while [ $# -gt 0 ]; do
  case "$1" in
    -t|--tiled)
      tiled=1
      shift
      ;;
    *)
      break
      ;;
  esac
done

title="${1:?Usage: parallel-run.sh [-t] <title>}"
session="[claude] ${title}"
slug="$(_slugify "${title}")"
project_dir="$(pwd)"

agents=(
  "reviewer|Review code changes in src/ for bugs and style issues"
  "tester|Write tests for any untested functions in src/"
  "docs|Update docs/README.md to reflect recent changes"
)

if [ "${tiled}" -eq 1 ]; then
  _spawn_tiled "${session}" "${slug}" "${project_dir}" "${agents[@]}"
else
  _spawn_windows "${session}" "${slug}" "${project_dir}" "${agents[@]}"
fi

tmux attach-session -t "${session}"
