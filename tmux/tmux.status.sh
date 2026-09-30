#!/usr/bin/env bash
# Status-bar helpers. Each sub-command prints a tmux-format-ready snippet
# (may include #[fg=...] tags) to stdout.
#
# Usage: tmux.status.sh <battery|utc|ssh|load>

set -eu

_battery() {
  local bat=/sys/class/power_supply/BAT0
  [ -r "${bat}/capacity" ] || { printf 'NOBAT'; return; }

  local status pct color
  status=$(cat "${bat}/status")
  pct=$(cat "${bat}/capacity")

  # No label — the color carries the state:
  #   yellow = charging, red = low, amber = mid, dim = healthy.
  if [ "${status}" = "Charging" ]; then
    color=220
  elif [ "${pct}" -lt 20 ]; then
    color=196
  elif [ "${pct}" -lt 50 ]; then
    color=208
  else
    color=94
  fi

  printf '#[fg=colour%s]%s%%' "${color}" "${pct}"
}

# ---

_utc() {
  date -u +'%H:%M:%S'
}

# ---

# 1-minute load average, color-coded against core count so the number actually
# means something at a glance:
#   green  : load < 0.7 * ncpu   (comfortable)
#   amber  : load < 1.0 * ncpu   (getting warm)
#   red    : load >= ncpu        (saturated / oversubscribed)
# Emits just the colored number; the "load" label lives in the tmux format.
_load() {
  local one ncpu warn crit color
  one=$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo 0)
  ncpu=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 1)

  # thresholds (float compare via awk to avoid bash integer-only math)
  warn=$(awk -v n="$ncpu" 'BEGIN{printf "%.2f", n*0.7}')
  crit="$ncpu"

  color=$(awk -v l="$one" -v w="$warn" -v c="$crit" 'BEGIN{
    if (l+0 >= c+0)      print "colour196";   # red: saturated
    else if (l+0 >= w+0) print "colour208";   # amber: warm
    else                 print "colour46";    # green: fine
  }')
  printf '#[fg=%s]%s' "$color" "$one"
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
  load)    _load ;;
  *)       printf 'Usage: %s <battery|utc|ssh|load>\n' "$0" >&2; exit 1 ;;
esac
