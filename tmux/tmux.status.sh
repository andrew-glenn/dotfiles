#!/usr/bin/env bash
# Status-bar helpers. Each sub-command prints a tmux-format-ready snippet
# (may include #[fg=...] tags) to stdout.
#
# Usage: tmux.status.sh <battery|utc>

set -eu

_battery() {
  local bat=/sys/class/power_supply/BAT0
  [ -r "${bat}/capacity" ] || { printf 'NOBAT'; return; }

  local status pct color label
  status=$(cat "${bat}/status")
  pct=$(cat "${bat}/capacity")

  if [ "${status}" = "Charging" ]; then
    color=118; label=CHG
  elif [ "${pct}" -lt 20 ]; then
    color=198; label=BAT
  elif [ "${pct}" -lt 50 ]; then
    color=208; label=BAT
  else
    color=46;  label=BAT
  fi

  printf '#[fg=colour%s,bold]%s %s%%' "${color}" "${label}" "${pct}"
}

# ---

_utc() {
  date -u +'%H:%M:%S'
}

# ---

cmd=${1:-}
case "${cmd}" in
  battery) _battery ;;
  utc)     _utc ;;
  *)       printf 'Usage: %s <battery|utc>\n' "$0" >&2; exit 1 ;;
esac
