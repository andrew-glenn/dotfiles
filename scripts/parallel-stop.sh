#!/usr/bin/env bash
# Stop all Docker agent containers and kill the tmux session for a given title.
# Usage: ./parallel-stop.sh <title>

set -euo pipefail

_slugify() {
  local input="${1:?}"
  echo "${input//[^a-zA-Z0-9]/-}"
}

_stop_session() {
  local session="${1:?}"
  local slug="${2:?}"

  docker ps --filter "name=claude-${slug}-" --format "{{.Names}}" \
    | xargs -r docker stop

  tmux kill-session -t "${session}"
}

# ---

title="${1:?Usage: parallel-stop.sh <title>}"
session="[claude] ${title}"
slug="$(_slugify "${title}")"

_stop_session "${session}" "${slug}"
