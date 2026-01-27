#!/usr/bin/env zsh
_host_specific_theme() {
  hostname=$(hostname)
  if [[ $(hostname) =~ dev-dsk ]]; then
    tmux source-file "${HOME}/.tmux-themepack/powerline/block/orange.tmuxtheme"
  elif [[ $(hostname) =~ radioshack ]]; then
    tmux source-file "${HOME}/.tmux-themepack/powerline/block/magenta.tmuxtheme"
  else
    tmux source-file "${DOTFILES_GIT_REPO}/tmux/.tmux-themepack/powerline/block/red.tmuxtheme"
  fi
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

set -x
case "${1}" in 
  "prefix")
    _toggle_prefix
    ;;
  *)
    exit 1
    ;;
esac
set +x

