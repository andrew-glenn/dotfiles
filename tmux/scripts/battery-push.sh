#!/usr/bin/env bash
#
# battery-push.sh — push local battery to all remote tmux sessions
#
# Runs locally from tmux status-right via #(). Self-throttles to avoid
# hammering SSH on every status-interval. Finds active SSH control
# sockets and pushes TMUX_BATTERY into remote tmux env.

set -u

_script_dir="$(cd "$(dirname "$0")" && pwd)"
_battery_val=""
_lock="/tmp/.tmux-battery-push.lock"
_throttle=60

_should_run() {
  [ ! -f "${_lock}" ] && return 0
  local last
  last=$(cat "${_lock}" 2>/dev/null || echo 0)
  local now
  now=$(date +%s)
  [ $((now - last)) -ge ${_throttle} ]
}

_get_battery() {
  _battery_val=$("${_script_dir}/battery.sh" 2>/dev/null)
}

_parse_dest() {
  local name="${1##*/cm-}"
  local user="${name%%@*}"
  local rest="${name#*@}"
  local host="${rest%%:*}"
  local port="${rest##*:}"
  [ -n "${user}" ] && [ -n "${host}" ] || return 1
  _dest_user="${user}"
  _dest_host="${host}"
  _dest_port="${port:-22}"
}

_push_to_remotes() {
  local socket
  for socket in ~/.ssh/cm-*; do
    [ -S "${socket}" ] || continue
    local _dest_user="" _dest_host="" _dest_port=""
    _parse_dest "${socket}" || continue
    ssh -o ControlPath="${socket}" -O check "${_dest_user}@${_dest_host}" 2>/dev/null || continue
    ssh -o ControlPath="${socket}" -p "${_dest_port}" "${_dest_user}@${_dest_host}" \
      "tmux set-environment -g TMUX_BATTERY '${_battery_val}'" 2>/dev/null &
  done
  wait
}

# ---

_should_run || exit 0
_get_battery
[ -z "${_battery_val}" ] && exit 0
date +%s > "${_lock}"
_push_to_remotes
