#!/usr/bin/env bash
# Toggle kitty color scheme between two themes.
# Usage: toggle-colors.sh [dark|light]
#   No arg = toggle. Arg = set explicitly.

# ─── Config ───────────────────────────────────────────────────────────────────
KITTY_DIR="$HOME/.config/kitty"
LINK_NAME="colors-active.conf"        # symlink that kitty.conf includes
DARK_THEME="colors-hacker.conf"       # dark mode file
LIGHT_THEME="colors-daylight.conf"    # light mode file
# ──────────────────────────────────────────────────────────────────────────────

link="$KITTY_DIR/$LINK_NAME"
dark="$KITTY_DIR/$DARK_THEME"
light="$KITTY_DIR/$LIGHT_THEME"

# Determine current theme from symlink target
current="$(readlink "$link" 2>/dev/null)"

pick_target() {
    case "${1:-}" in
        dark)  echo "$dark" ;;
        light) echo "$light" ;;
        *)
            # Toggle: if current points to dark, switch to light (and vice versa)
            if [[ "$current" == *"$DARK_THEME" ]]; then
                echo "$light"
            else
                echo "$dark"
            fi
            ;;
    esac
}

target="$(pick_target "$1")"

# Swap the symlink
ln -sf "$target" "$link"

# Reload all running kitty instances (socket has PID suffix)
if command -v kitty &>/dev/null; then
    for sock in /tmp/kitty-socket-*; do
        [[ -S "$sock" ]] && kitty @ --to "unix:$sock" set-colors --all --configured "$target" 2>/dev/null
    done
fi

# Report
basename "$target" | sed 's/colors-//;s/\.conf//'
