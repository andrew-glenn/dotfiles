#!/usr/bin/env bash
#
# battery.sh — emit battery percentage + charging indicator
#
# Usage:
#   battery.sh          → "87% ⚡" or "87% 🔋" (or just "87%")
#   battery.sh --export → prints TMUX_BATTERY="..." for eval
#   battery.sh --env    → reads from TMUX_BATTERY env var (for remote tmux)
#
# The idea: local machine runs --export, SSH forwards TMUX_BATTERY,
# remote tmux calls --env to display it.

_get_battery() {
  local pct=""
  local charging=""

  # Linux — /sys/class/power_supply
  if [ -d /sys/class/power_supply/BAT0 ]; then
    pct=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null)
    local status
    status=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null)
    [ "${status}" = "Charging" ] && charging="1"
  elif [ -d /sys/class/power_supply/BAT1 ]; then
    pct=$(cat /sys/class/power_supply/BAT1/capacity 2>/dev/null)
    local status
    status=$(cat /sys/class/power_supply/BAT1/status 2>/dev/null)
    [ "${status}" = "Charging" ] && charging="1"
  # macOS — pmset
  elif command -v pmset >/dev/null 2>&1; then
    local pmset_out
    pmset_out=$(pmset -g batt 2>/dev/null)
    pct=$(echo "${pmset_out}" | grep -oE '[0-9]+%' | head -1 | tr -d '%')
    echo "${pmset_out}" | grep -q 'AC Power' && charging="1"
  fi

  [ -z "${pct}" ] && return 1

  local icon
  if [ -n "${charging}" ]; then
    icon="+"
  elif [ "${pct}" -le 20 ]; then
    icon="!"
  else
    icon=""
  fi

  echo "${pct}%${icon}"
}

_format_env() {
  local val=""
  # Try tmux global env first (set by battery-push.sh on remote),
  # then fall back to shell env.
  val=$(tmux show-environment -g TMUX_BATTERY 2>/dev/null | sed 's/^TMUX_BATTERY=//')
  [ -z "${val}" ] && val="${TMUX_BATTERY:-}"
  [ -n "${val}" ] && echo "${val}"
}

# ---

case "${1:-}" in
  --export)
    val=$(_get_battery) && echo "TMUX_BATTERY=\"${val}\""
    ;;
  --env)
    _format_env
    ;;
  *)
    _get_battery
    ;;
esac
