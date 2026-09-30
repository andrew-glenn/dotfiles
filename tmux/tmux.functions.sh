#!/usr/bin/env zsh
# Portable short-hostname: `hostname -s` isn't guaranteed to exist (it's
# missing on some minimal hosts, which silently dumped us into the default
# theme). Try the cheapest reliable sources in order, strip any domain.
_short_hostname() {
  local h=""
  if [ -n "${HOSTNAME:-}" ]; then h="$HOSTNAME"
  elif command -v hostname >/dev/null 2>&1; then h="$(hostname 2>/dev/null)"
  elif [ -r /etc/hostname ]; then h="$(cat /etc/hostname 2>/dev/null)"
  else h="$(uname -n 2>/dev/null)"
  fi
  # first label only (strip .domain), lowercase for stable matching
  h="${h%%.*}"
  printf '%s' "$h" | tr '[:upper:]' '[:lower:]'
}

# Named palette table. Each theme is 4 true-color hex values:
#   text   = primary window/text color
#   dim    = separators, idle windows, quiet detail
#   accent = active window, session name, borders — the signature color
#   actv   = activity flash (brighter kick of the accent hue)
# Add a theme by adding a case here; wire it to a host in _theme_for_host.
_palette() {
  case "$1" in
    amber)     printf '%s' "#ffcf8f #8a5a1f #ff9e3b #ffd24a|amber (Mr. Robot)" ;;
    cyan)      printf '%s' "#b8f0ff #1f5a6a #38d9ff #7cf3ff|cyan (devbox)" ;;
    pink)      printf '%s' "#ffe0f0 #7a1f52 #ff3aa8 #ff7ac6|hot pink" ;;
    matrix)    printf '%s' "#c8ffc8 #1f6a2f #39ff5a #86ff9e|matrix green" ;;
    synthwave) printf '%s' "#f5d0ff #4a2a6a #b06aff #ff6ad5|synthwave" ;;
    nord)      printf '%s' "#eceff4 #4c566a #88c0d0 #8fbcbb|nord frost" ;;
    gruvbox)   printf '%s' "#ebdbb2 #7c6f64 #fabd2f #fe8019|gruvbox" ;;
    blood)     printf '%s' "#ffd6d6 #7a1f1f #ff3b3b #ff7a7a|blood red" ;;
    *)         printf '%s' "#ffcf8f #8a5a1f #ff9e3b #ffd24a|amber (Mr. Robot)" ;;
  esac
}

# Host -> theme name. This is the per-host map: give each machine its own look
# so you know at a glance which box you're on. Unknown hosts fall through to a
# stable default. Uses case-globs so you can match host families (prod-*, etc).
_theme_for_host() {
  case "$1" in
    archbox)       printf 'blood' ;;
    devbox)        printf 'cyan' ;;
    *radioshack*)  printf 'pink' ;;
    *matrix*|*neo*) printf 'matrix' ;;
    *prod*)        printf 'blood' ;;      # loud on production, stay careful
    *)             printf 'amber' ;;
  esac
}

_host_specific_theme() {
  # Sets palette user options consumed by style strings in tmux.conf
  # (#{@c_text}, #{@c_dim}, #{@c_accent}, #{@c_actv}) plus the two
  # display-panes-*-colour settings, which don't accept format expansion.
  local host theme spec text dim accent actv label
  host="$(_short_hostname)"

  # Explicit override wins if you ever want it: `tmux set -g @theme <name>`
  # in ~/.tmux.local.conf on a specific box.
  theme="$(tmux show -gv @theme 2>/dev/null)"
  [ -n "$theme" ] || theme="$(_theme_for_host "$host")"

  spec="$(_palette "$theme")"
  label="${spec#*|}"
  spec="${spec%|*}"
  # spec is now "text dim accent actv". Split on whitespace in a way that works
  # in BOTH zsh (no auto word-split) and bash: `read` splits on $IFS reliably.
  read -r text dim accent actv <<EOF
$spec
EOF

  tmux set -g @c_text   "$text"
  tmux set -g @c_dim    "$dim"
  tmux set -g @c_accent "$accent"
  tmux set -g @c_actv   "$actv"
  tmux set -g display-panes-colour        "$dim"
  tmux set -g display-panes-active-colour "$accent"
  # clock-mode-colour doesn't accept #{format} expansion, so set the concrete
  # accent hex here to keep the prefix-t clock in sync with the theme.
  tmux setw -g clock-mode-colour "$accent"
  tmux display "Theme: ${host:-unknown} → ${label}"
}

# Ordered list of themes for cycling. Keep in sync with _palette().
_THEME_ORDER="amber cyan pink matrix synthwave nord gruvbox blood"

# Cycle to the next theme in _THEME_ORDER (wraps around), pin it via @theme so
# _host_specific_theme honors it, then re-apply so the change is instant.
# Direction: "next" (default) or "prev".
_theme_cycle() {
  local dir="${1:-next}" cur first last prev found next t
  cur="$(tmux show -gv @theme 2>/dev/null)"
  [ -n "$cur" ] || cur="$(_theme_for_host "$(_short_hostname)")"

  next=""; prev=""; first=""; last=""; found=""
  # NOTE: zsh does not word-split unquoted vars (unlike bash), so a plain
  # `for t in $_THEME_ORDER` iterates once over the whole string. Convert the
  # space-separated list to newlines and read line-by-line — reliable in both.
  while read -r t; do
    [ -n "$t" ] || continue
    [ -n "$first" ] || first="$t"
    last="$t"
    if [ -n "$found" ] && [ -z "$next" ]; then next="$t"; fi
    if [ "$t" = "$cur" ]; then found=1; fi
    [ -n "$found" ] || prev="$t"
  done <<EOF
$(printf '%s' "$_THEME_ORDER" | tr ' ' '\n')
EOF
  # wrap: next-of-last -> first; prev-of-first -> last
  [ -n "$next" ] || next="$first"
  [ -n "$prev" ] || prev="$last"

  if [ "$dir" = "prev" ]; then
    tmux set -g @theme "$prev"
  else
    tmux set -g @theme "$next"
  fi
  _host_specific_theme
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

_zen() {
  local current
  current=$(tmux show -qv @zen 2>/dev/null)

  if [ "${current}" = "on" ]; then
    # Tear down padding panes
    local left right
    left=$(tmux show -qv @zen_left)
    right=$(tmux show -qv @zen_right)
    tmux kill-pane -t "${left}" 2>/dev/null
    tmux kill-pane -t "${right}" 2>/dev/null
    tmux set -u @zen
    tmux set -u @zen_left
    tmux set -u @zen_right
    # Restore border styles
    tmux set pane-border-style "$(tmux show -qv @zen_border)"
    tmux set pane-active-border-style "$(tmux show -qv @zen_aborder)"
    tmux set -u @zen_border
    tmux set -u @zen_aborder
    tmux set status on
    tmux display "Zen: [off]"
  else
    local main
    main=$(tmux display -p '#{pane_id}')

    # Left padding pane (tail -f /dev/null works on macOS; sleep infinity does not)
    local left
    left=$(tmux split-window -hbdP -l 20% -t "${main}" -F '#{pane_id}' "tail -f /dev/null")

    # Right padding pane
    local right
    right=$(tmux split-window -hdP -l 20% -t "${main}" -F '#{pane_id}' "tail -f /dev/null")

    # Focus back to main
    tmux select-pane -t "${main}"

    # Mute pane borders to near-invisible
    tmux set @zen_border "$(tmux show -qv pane-border-style)"
    tmux set @zen_aborder "$(tmux show -qv pane-active-border-style)"
    tmux set pane-border-style "fg=colour236"
    tmux set pane-active-border-style "fg=colour236"

    # Store state
    tmux set @zen on
    tmux set @zen_left "${left}"
    tmux set @zen_right "${right}"
    tmux set status off
    tmux display "Zen: [on]"
  fi
}

_sp() {
  command -v kiro-cli >/dev/null 2>&1 || return 0
  # sp lives in scratch:0. If scratch exists, just switch to it.
  if tmux has-session -t scratch 2>/dev/null; then
    tmux switch-client -t scratch:0
    return
  fi
  # Bootstrap scratch with sp as window 0 (global hooks handle naming + respawn)
  tmux new-session -d -e TMUX_SCRATCH_SESSION=true -s scratch 'kiro-cli chat --agent sp'
  tmux switch-client -t scratch:0
}

_move_window() {
  local src_pane_id cur_sess cur_win US BLUE YELLOW DIM RST selection clean type

  src_pane_id=$(tmux display-message -p '#{pane_id}')
  cur_sess=$(tmux display-message -p '#S')
  cur_win=$(tmux display-message -p '#I')

  US=$'\x1f'
  BLUE="\033[1;34m"
  YELLOW="\033[0;33m"
  DIM="\033[0;90m"
  RST="\033[0m"

  selection=$(
  {
      tmux list-sessions -F '#S' | while read -r s; do
          printf "${BLUE}session${RST}  %-20s${US}_${US}_\n" "$s"
      done

      tmux list-panes -a -F "#{session_name}${US}#{window_index}${US}#{pane_index}${US}#{pane_current_command}${US}#{pane_id}" | \
      while IFS="$US" read -r sess win pane cmd pane_id; do
          [[ "$sess:$win" == "$cur_sess:$cur_win" ]] && continue
          printf "${YELLOW}pane${RST}     %-20s ${DIM}%s${RST}${US}%s${US}%s\n" \
              "${sess}:${win}.${pane}" "$cmd" "$cmd" "$pane_id"
      done
  } | fzf --ansi --prompt='move to › ' --delimiter="$US" --with-nth=1
  ) || return 0

  clean=$(printf '%s' "$selection" | sed $'s/\033\\[[0-9;]*m//g')
  type=$(echo "$clean" | awk '{print $1}')

  if [[ "$type" == "session" ]]; then
      local target_session
      target_session=$(echo "$clean" | awk '{print $2}')
      tmux move-window -t "${target_session}:"

  elif [[ "$type" == "pane" ]]; then
      local target_cmd target_pane_id
      target_cmd=$(printf '%s' "$selection" | awk -F "$US" '{print $2}' | xargs)
      target_pane_id=$(printf '%s' "$selection" | awk -F "$US" '{print $3}' | xargs)

      if [[ "$target_cmd" =~ ^(zsh|bash|fish|sh|dash)$ ]]; then
          tmux swap-pane -s "$src_pane_id" -t "$target_pane_id"
          tmux kill-pane -t "$target_pane_id" 2>/dev/null || true
      else
          tmux join-pane -v -s "$src_pane_id" -t "$target_pane_id"
      fi
  fi
}

_lazygit() {
  local bin
  bin="${LAZYGIT:-}"
  [ -z "$bin" ] && bin=$(command -v lazygit 2>/dev/null)
  [ -z "$bin" ] && bin=$(zsh -lc 'command -v lazygit' 2>/dev/null)
  [ -z "$bin" ] && [ -x "${HOME}/.local/share/mise/shims/lazygit" ] \
    && bin="${HOME}/.local/share/mise/shims/lazygit"
  [ -z "$bin" ] && [ -x "${HOME}/.local/bin/mise" ] \
    && bin=$("${HOME}/.local/bin/mise" which lazygit 2>/dev/null)

  if [ -z "$bin" ] || [ ! -x "$bin" ]; then
    printf 'lazygit not found in PATH (set $LAZYGIT to override)\n' >&2
    read -rsk1 2>/dev/null || read -r
    return 1
  fi

  exec "$bin" "$@"
}

_dock_window() {
  local cur_sess cur_win US BLUE YELLOW DIM RST candidates selection
  local target_pane_id target_cmd flag replace choice panes first_pane anchor p

  cur_sess=$(tmux display-message -p '#S')
  cur_win=$(tmux display-message -p '#I')

  US=$'\x1f'
  BLUE="\033[1;34m"
  YELLOW="\033[0;33m"
  DIM="\033[0;90m"
  RST="\033[0m"

  candidates=$(
    tmux list-panes -s -t "$cur_sess" \
      -F "#{window_index}${US}#{pane_index}${US}#{window_name}${US}#{pane_current_command}${US}#{pane_id}" |
    while IFS="$US" read -r win pane wname cmd pane_id; do
      [ "$win" = "$cur_win" ] && continue
      printf "${BLUE}%-12s${RST} ${YELLOW}%-18s${RST} ${DIM}%s${RST}${US}%s${US}%s\n" \
        "${win}.${pane}" "$wname" "$cmd" "$cmd" "$pane_id"
    done
  )

  if [ -z "$candidates" ]; then
    tmux display "No other panes in session ${cur_sess}"
    return 0
  fi

  selection=$(printf '%s\n' "$candidates" |
    fzf --ansi --reverse --delimiter="$US" --with-nth=1 \
        --header="Move window ${cur_sess}:${cur_win} into a pane" \
        --prompt='dock into › ') || return 0

  target_cmd=$(printf '%s' "$selection" | awk -F "$US" '{print $2}' | xargs)
  target_pane_id=$(printf '%s' "$selection" | awk -F "$US" '{print $3}' | xargs)
  [ -z "$target_pane_id" ] && return 0

  if [[ "$target_cmd" =~ ^(zsh|bash|fish|sh|dash)$ ]]; then
    replace=1
    flag="-v"
  else
    replace=0
    choice=$(printf '%s\n' 'below' 'right' 'above' 'left' |
      fzf --reverse --header="Split ${target_cmd} pane where?" --prompt='split › ') || return 0
    case "$choice" in
      below) flag="-v" ;;
      right) flag="-h" ;;
      above) flag="-vb" ;;
      left)  flag="-hb" ;;
      *) return 0 ;;
    esac
  fi

  panes=$(tmux list-panes -t "${cur_sess}:${cur_win}" -F '#{pane_id}')
  first_pane=""
  anchor="$target_pane_id"
  while read -r p; do
    [ -z "$p" ] && continue
    tmux join-pane $flag -s "$p" -t "$anchor" 2>/dev/null || break
    [ -z "$first_pane" ] && first_pane="$p"
    anchor="$p"
  done <<< "$panes"

  [ -z "$first_pane" ] && return 0

  if [ "$replace" = "1" ]; then
    tmux kill-pane -t "$target_pane_id" 2>/dev/null || true
  fi

  tmux select-window -t "$first_pane"
  tmux select-pane -t "$first_pane"
}

_new_session() {
  local start_dir="${1:-$HOME}"
  local out query pick name
  out="$(tmux list-sessions -F '#S' 2>/dev/null \
    | fzf --reverse --no-sort --print-query \
          --header='Type a name to create, or pick one to switch' \
          --prompt='new session › ')"

  query="$(printf '%s\n' "${out}" | sed -n 1p)"
  pick="$(printf '%s\n' "${out}" | sed -n 2p)"
  name="${pick:-${query}}"
  name="$(printf '%s' "${name}" | tr '.:' '__' | tr -d '[:space:]')"
  [ -z "${name}" ] && return 0

  if tmux has-session -t "=${name}" 2>/dev/null; then
    tmux switch-client -t "=${name}"
    return 0
  fi

  tmux new-session -d -s "${name}" -c "${start_dir}"
  tmux switch-client -t "=${name}"
}

_switcher() {
  local target
  target="$(tmux list-windows -a -F '#{session_name} #{window_index} #{window_name} #{window_active}' \
    | while read -r sess win name active; do
        if [ "${active}" = "1" ]; then
          printf "\033[1;34m%s\033[0m:\033[0;33m%s\033[0m  %s \033[0;90m(active)\033[0m\n" "$sess" "$win" "$name"
        else
          printf "\033[1;34m%s\033[0m:\033[0;33m%s\033[0m  %s\n" "$sess" "$win" "$name"
        fi
      done \
    | fzf --ansi --reverse --prompt='switch to › ')" || return 0
  # Strip ANSI and extract session:window
  local dest
  dest="$(printf '%s' "$target" | sed $'s/\033\\[[0-9;]*m//g' | awk '{print $1}')"
  tmux switch-client -t "${dest}"
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
  "theme_cycle")
    _theme_cycle "${2:-next}"
    ;;
  "sp")
    _sp
    ;;
  "zen")
    _zen
    ;;
  "switcher")
    _switcher
    ;;
  "move_window")
    _move_window
    ;;
  "dock_window")
    _dock_window
    ;;
  "lazygit")
    shift
    _lazygit "$@"
    ;;
  "new_session")
    _new_session "${2}"
    ;;
  *)
    exit 1
    ;;
esac

