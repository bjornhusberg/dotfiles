#!/bin/bash
# <xbar.title>Battery (unplugged only)</xbar.title>
# <xbar.desc>Shows a battery icon only while the Mac is not charging</xbar.desc>

# Template icons (144 DPI PNG, base64) for each level live outside the plugins folder.
ICON_DIR="$HOME/.config/xbar-battery"

info=$(pmset -g batt)

# No output makes xbar remove the item from the menu bar.
echo "$info" | grep -q "Now drawing from 'AC Power'" && exit 0

percent=$(echo "$info" | grep -oE '[0-9]+%' | head -1 | tr -d '%')
[ -z "$percent" ] && exit 0

icon_level=$(( (percent + 5) / 10 * 10 ))
[ "$icon_level" -gt 100 ] && icon_level=100

echo "| templateImage=$(cat "$ICON_DIR/$icon_level.b64")"
echo "---"
echo "Battery: $percent% (on battery)"
echo "$info" | grep -oE '[0-9]+:[0-9]+ remaining' | head -1
