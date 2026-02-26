#!/usr/bin/env zsh
_host_specific_theme() {
  set -x
  local repo="${DOTFILES_GIT_REPO:-$HOME/dotfiles}"
  if [[ $(hostname) == *dev-dsk* ]]; then
    tmux source-file "${repo}/tmux/tmux-themepack/powerline/block/yellow.tmuxtheme"
  elif [[ $(hostname) == *radioshack* ]]; then
    tmux source-file "${repo}/tmux/tmux-themepack/powerline/block/magenta.tmuxtheme"
  else
    tmux source-file "${repo}/tmux/tmux-themepack/powerline/block/red.tmuxtheme"
  fi
  set +x
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
  "${_default}" || "")
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

  tmux set -qg mouse-select-pane ${onsv}
  tmux set -qg mouse $onsv \; display "Mouse Mode: [$onsv]"
}

_toggle_pane_sync() {
  _old_new_status -x "show-options" -X "wv" -w "synchronize-panes"
  tmux set-window-option -q synchronize-panes $onsv \; display "Pane Sync: [$onsv]"
}

_toggle_prefix() {
  _old_new_status -w "prefix" -d "C-b" -n "None"
  if [[ "${onsv}" == "None" ]]; then
    tmux setw -q status off
  else
    tmux setw -q status on
  fi
  tmux setw -q prefix "${onsv}"
}

_urlview() {
  tmux capture-pane -J -S - -E - -b "urlview-$1" -t "$1"
  tmux split-window "tmux show-buffer -b urlview-$1 | urlview || true; tmux delete-buffer -b urlview-$1"
}

_fpp() {
  tmux capture-pane -J -S - -E - -b "fpp-$1" -t "$1"
  tmux split-window "tmux show-buffer -b fpp-$1 | fpp || true; tmux delete-buffer -b fpp-$1"
}

_toggle_scratch_session() {
  if [ -n "${TMUX_SCRATCH_SESSION}" ]; then
    tmux detach -s scratch
  else
    tmux new-session -A -e "TMUX_SCRATCH_SESSION=true" -s scratch
  fi
}

_conditional_new_window() {
  if [[ -d "/Users/" ]]; then
    tmux new-window
  fi
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

# ---

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
  "theme")
    _host_specific_theme
    ;;
  *)
    exit 1
    ;;
esac

