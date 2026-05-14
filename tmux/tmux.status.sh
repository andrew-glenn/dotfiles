#!/usr/bin/env bash
# Status-bar helpers. Each sub-command prints a tmux-format-ready snippet
# (may include #[fg=...] tags) to stdout.
#
# Usage: tmux.status.sh <battery|utc|ssh>

set -eu

_battery() {
  local bat=/sys/class/power_supply/BAT0
  [ -r "${bat}/capacity" ] || { printf 'NOBAT'; return; }

  local status pct color label
  status=$(cat "${bat}/status")
  pct=$(cat "${bat}/capacity")

  if [ "${status}" = "Charging" ]; then
    color=220; label=CHG
  elif [ "${pct}" -lt 20 ]; then
    color=196; label=BAT
  elif [ "${pct}" -lt 50 ]; then
    color=208; label=BAT
  else
    color=94; label=BAT
  fi

  printf '#[fg=colour%s]%s %s%%' "${color}" "${label}" "${pct}"
}

# ---

_utc() {
  date -u +'%H:%M:%S'
}

# ---

# Walk descendants of $1 and print the first ssh-host argument we find.
# Quiet if no ssh in the tree. Used to render an SSH badge in the status bar.
_ssh() {
  local root=${1:?Usage: ssh <pane_pid>}
  local queue=("${root}") pid

  while [ ${#queue[@]} -gt 0 ]; do
    pid=${queue[0]}; queue=("${queue[@]:1}")
    [ -r "/proc/${pid}/comm" ] || continue

    if [ "$(cat "/proc/${pid}/comm" 2>/dev/null)" = "ssh" ]; then
      # cmdline is NUL-separated. Last non-flag argv is the destination.
      local host
      host=$(tr '\0' '\n' < "/proc/${pid}/cmdline" \
        | awk 'NR>1 && $0 !~ /^-/ {h=$0} END {print h}')
      [ -n "${host}" ] && { printf '#[fg=colour208,bold]SSH#[fg=colour94] %s' "${host}"; return; }
    fi

    local children
    children=$(cat "/proc/${pid}/task/${pid}/children" 2>/dev/null || true)
    [ -n "${children}" ] && queue+=(${children})
  done
}

# ---

cmd=${1:-}
case "${cmd}" in
  battery) _battery ;;
  utc)     _utc ;;
  ssh)     _ssh "${2:-}" ;;
  *)       printf 'Usage: %s <battery|utc|ssh>\n' "$0" >&2; exit 1 ;;
esac
