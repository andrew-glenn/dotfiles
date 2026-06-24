#!/usr/bin/env zsh
_host_specific_theme() {
  # Sets palette user options consumed by style strings in tmux.conf
  # (#{@c_text}, #{@c_dim}, #{@c_accent}, #{@c_actv}) plus the two
  # display-panes-*-colour settings, which don't accept format expansion.
  local text dim accent actv label
  case "$(hostname -s)" in
    devbox)
      text=159; dim=24;  accent=45;  actv=87;  label="cyan (devbox)" ;;
    *radioshack*)
      text=255; dim=89;  accent=198; actv=201; label="hot pink" ;;
    *)
      text=223; dim=94;  accent=208; actv=220; label="amber (Mr. Robot)" ;;
  esac

  tmux set -g @c_text   "colour${text}"
  tmux set -g @c_dim    "colour${dim}"
  tmux set -g @c_accent "colour${accent}"
  tmux set -g @c_actv   "colour${actv}"
  tmux set -g display-panes-colour        "colour${dim}"
  tmux set -g display-panes-active-colour "colour${accent}"
  tmux display "Theme: $(hostname -s) → ${label}"
}
_old_new_status() {
  while getopts 'x:X:w:g:d:n:' opt "$@"; do
    case $opt in
    "g")
      _current=$(tmux show -gv $OPTARG)
      ;;
    "d")
      _default="${OPTARG}"
      ;;
    "n")
      _new="${OPTARG}"
      ;;
    "x")
      _tmux_command_options=$OPTARG
      ;;
    "X")
      _tmux_additional_flags=$OPTARG
      ;;
    "w")
      _current=$(tmux show-window-options -v "${OPTARG}")
      ;;
    esac
  done
  shift $((OPTIND - 1))
  new=""
  case "${_current}" in
  "${_default}"|"")
    new="${_new}"
    ;;
  "${_new}")
    new="${_default}"
    ;;
  esac
  onsv=$new
  export onsv
  unset _tmux_command_options _current _default _new _tmux_command_options _tmux_additional_flags
}
_toggle_mouse() {
  _old_new_status -g "mouse" -d "on" -n "off"
  tmux set -qg mouse $onsv \; display "Mouse Mode: [$onsv]"
}

_pane_jumper() {
  local pick target
  pick=$(tmux list-panes -aF '#{session_name}:#{window_index}.#{pane_index}  [#{pane_current_command}]  #{=|40|…:pane_title}' \
    | fzf --reverse --no-sort --header='jump to pane') || return 0
  target=${pick%% *}
  [ -z "${target}" ] && return 0
  tmux switch-client -t "${target%%:*}"
  tmux select-window  -t "${target%.*}"
  tmux select-pane    -t "${target}"
}

_toggle_pane_sync() {
  local current new
  current=$(tmux show-window-options -v synchronize-panes 2>/dev/null || echo off)
  [ "${current}" = "on" ] && new=off || new=on
  tmux set-window-option -q synchronize-panes "${new}"
  tmux refresh-client -S
  tmux display "Pane Sync: [${new}]"
}

_toggle_prefix() {
  local current
  current=$(tmux show -qv prefix 2>/dev/null)
  [ -z "${current}" ] && current=$(tmux show -gqv prefix 2>/dev/null)
  local new
  if [ "${current}" = "None" ]; then
    new="C-b"
    tmux set -q status on
  else
    new="None"
    tmux set -q status off
  fi
  tmux set -q prefix "${new}"
  tmux display "Prefix: [${new}]"
}

_pick_mode() {
  printf '  \033[1m(o)\033[0m break-out ↗   \033[1m(i)\033[0m break-in ↙  ' >&2
  read -rsk1 mode
  echo "${mode}"
}

_break_out() {
  tmux break-pane -s "${1}" || tmux display-message "send-pane: break-out failed"
}

_pick_session() {
  local cur="${1}"
  tmux list-sessions -F '#S [#{session_windows} win]' | awk -v cur="${cur}" '
      { name=$1 }
      name==cur { $0=$0" (current)"; first=$0; next }
      { rest[++n]=$0 }
      END { if(first) print first; for(i=1;i<=n;i++) print rest[i] }
  ' | fzf --reverse --header="Session:" --prompt="> "
}

_pick_window() {
  local ses="${1}" cur_ses="${2}" cur_win="${3}"
  tmux list-windows -t "${ses}" -F '#I: #W [#{window_panes} panes]' | while IFS= read -r line; do
    idx="${line%%:*}"
    if [ "${ses}" = "${cur_ses}" ] && [ "${idx}" = "${cur_win}" ]; then
      echo "${line} (current)"
    else
      echo "${line}"
    fi
  done | fzf --reverse --header="Window in ${ses}:" --prompt="> "
}

_pick_split() {
  printf '\n  \033[1m(h)\033[0m horizontal ─   \033[1m(v)\033[0m vertical │  ' >&2
  read -rsk1 key
  case "${key}" in
    h) echo "-h" ;;
    v) echo "-v" ;;
  esac
}

_join_pane() {
  local flag="${1}" src="${2}" target="${3}"
  tmux join-pane ${flag} -s "${src}" -t "${target}" || tmux display-message "send-pane: join failed"
}

_send_pane() {
  local src_pane="${1:?Usage: send-pane <pane_id>}"
  local src_ses src_win
  src_ses="$(tmux display-message -p -t "${src_pane}" '#S')"
  src_win="$(tmux display-message -p -t "${src_pane}" '#I')"

  local mode
  mode="$(_pick_mode)"
  case "${mode}" in
    o) _break_out "${src_pane}"; return ;;
    i) ;;
    *) return 0 ;;
  esac

  local dest_ses_line dest_ses
  dest_ses_line="$(_pick_session "${src_ses}")" || return 0
  dest_ses="${dest_ses_line%% *}"

  local dest_win_line dest_win
  dest_win_line="$(_pick_window "${dest_ses}" "${src_ses}" "${src_win}")" || return 0
  dest_win="${dest_win_line%%:*}"

  if [ "${dest_ses}" = "${src_ses}" ] && [ "${dest_win}" = "${src_win}" ]; then
    tmux display-message "Pane is already in that window."
    return 0
  fi

  local flag
  flag="$(_pick_split)" || return 0
  [ -z "${flag}" ] && return 0

  _join_pane "${flag}" "${src_pane}" "${dest_ses}:${dest_win}"

  [[ "${src_ses}" != "${dest_ses}" ]] && tmux switch-client -t "${dest_ses}"
  return 0
}

_toggle_silence() {
  local cur
  cur=$(tmux show-window-options -v monitor-silence 2>/dev/null)
  if [ "${cur}" -gt 0 ] 2>/dev/null; then
    tmux set-window-option monitor-silence 0 \; display "Monitor Silence: [off]"
  else
    tmux set-window-option monitor-silence 10 \; display "Monitor Silence: [on – 10s]"
  fi
}

_switch_session() {
  local current
  current="$(tmux display-message -p '#S')"
  local target
  target="$(tmux list-sessions -F '#S' \
    | grep -v "^${current}$" \
    | fzf --reverse --header='Switch session:' --prompt='> ')" || return 0
  tmux switch-client -t "${target}"
}

_switch_window() {
  local current
  current="$(tmux display-message -p '#I')"
  local target
  target="$(tmux list-windows -F '#I: #W' \
    | grep -v "^${current}:" \
    | fzf --reverse --header='Switch window:' --prompt='> ')" || return 0
  local idx="${target%%:*}"
  tmux select-window -t "${idx}"
}

_switch_prev_session() {
  tmux switch-client -l
}

_launch_assistant() {
  command -v kiro-cli >/dev/null 2>&1 || return 0
  local cwd
  cwd="$(tmux display-message -p '#{pane_current_path}')"
  tmux new-window -c "${cwd}" -n "assistant" "kiro-cli chat --agent assistant"
}

# ---

# Dispatcher only fires when the script is invoked with a subcommand;
# `source`-ing without args just loads the function definitions.
if [ $# -eq 0 ]; then
  return 0 2>/dev/null || exit 0
fi

case "${1}" in
  "prefix")
    _toggle_prefix
    ;;
  "send_pane")
    _send_pane "${2}"
    ;;
  "silence")
    _toggle_silence
    ;;
  "session")
    _switch_session
    ;;
  "window")
    _switch_window
    ;;
  "prev")
    _switch_prev_session
    ;;
  "pane_jumper")
    _pane_jumper
    ;;
  "theme")
    _host_specific_theme
    ;;
  "assistant")
    _launch_assistant
    ;;
  *)
    exit 1
    ;;
esac

