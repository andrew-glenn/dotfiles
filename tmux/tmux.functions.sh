 set -e

 _old_new_status(){
     set -x
     while getopts 'x:X:w:g:' opt "$@"; do
         case $opt in
             "g")
                 _old=$(tmux show -gv $OPTARG)
             ;;
             "x")
                 _tmux_command_options=$OPTARG
             ;;
             "X")
                 _tmux_additional_flags=$OPTARG
             ;;
             "w")
                if [ "${_tmux_command_options}a" = "a" ]; then
                    _tmux_command_options="show-window-option -gv"
                fi
                if [ "${_tmux_additional_flags}a" != "a" ]; then
                    _old=$(tmux "${_tmux_command_options}" -"${_tmux_additional_flags}" "${OPTARG}")
                else
                    _old=$(tmux "${_tmux_command_options}" "${OPTARG}")
                fi
             ;;
         esac
   done
   shift $((OPTIND -1))
   new=""

   if [ "$_old" = "on" ]; then
     new="off"
   else
     new="on"
   fi
   onsv=$new
   export onsv
   unset _old _tmux_command_options opt
}
_toggle_mouse() {
   _old_new_status -g "mouse"

   tmux set -qg mouse $onsv \;\
       display "Mouse Mode: [$onsv]"
}

_toggle_pane_sync(){
    _old_new_status -x "show-options" -X "wv" -w "synchronize-panes"
    tmux set-window-option -q synchronize-panes $onsv \;\
        display "Pane Sync: [$onsv]"
}

 _urlview() {
   tmux capture-pane -J -S - -E - -b "urlview-$1" -t "$1"
   tmux split-window "tmux show-buffer -b urlview-$1 | urlview || true; tmux delete-buffer -b urlview-$1"
 }

 _fpp() {
   tmux capture-pane -J -S - -E - -b "fpp-$1" -t "$1"
   tmux split-window "tmux show-buffer -b fpp-$1 | fpp || true; tmux delete-buffer -b fpp-$1"
 }

 
 _toggle_chime_mute(){
   if [ ! "$(which osascript)" ]; then
     tmux display "Applescript not available!"
     return
  fi
  osascript <<EOD
tell application "System Events"
	tell application process "Amazon Chime"
		try
			set frontmost to true
			perform action "AXRaise" of (first window whose name contains "Meeting")
		end try
	end tell
	key down {{command}}
	keystroke "y"
	key up {{command}}
end tell
EOD
tmux display "Chime Mute toggled!"
}


