#!/bin/bash
# <xbar.title>Toolbox</xbar.title>
# <xbar.desc>Gear menu: headset settings via headsetcontrol, and running keymap.</xbar.desc>
# <xbar.dependencies>headsetcontrol</xbar.dependencies>

HSC=/opt/homebrew/bin/headsetcontrol
KEYMAP="$HOME/bin/keymap"
ICON_FILE="$HOME/.config/xbar-toolbox/gear.b64"

# Actions are run by xbar as: toolbox.sh run <args...>
if [ "$1" = "run" ]; then
  shift
  case "$1" in
    sidetone) "$HSC" -s "$2" ;;
    keymap) "$KEYMAP" ;;
    amphetamine)
      if [ "$(osascript -e 'tell application "Amphetamine" to session is active')" = "true" ]; then
        osascript -e 'tell application "Amphetamine" to end session'
      else
        osascript -e 'tell application "Amphetamine" to start new session'
      fi ;;
    *) "$HSC" "$@" ;;
  esac >/dev/null 2>&1
  exit 0
fi

item() { # label, args...
  local label="$1"; shift
  local i=1 params=""
  for a in "$@"; do params="$params param$((i+1))=$a"; i=$((i+1)); done
  echo "--$label | bash='$0' param1=run$params terminal=false refresh=true"
}

amph_running=false
amph_on=false
# Only query Amphetamine while it runs, since an Apple Event would launch it.
if pgrep -x Amphetamine >/dev/null; then
  amph_running=true
  [ "$(osascript -e 'tell application "Amphetamine" to session is active' 2>/dev/null)" = "true" ] && amph_on=true
fi

# A filled gear shows that an Amphetamine session is active.
$amph_on && ICON_FILE="$HOME/.config/xbar-toolbox/gear-on.b64"
echo "| templateImage=$(cat "$ICON_FILE")"
echo "---"

if $amph_running; then
  label="Amphetamine: off"
  $amph_on && label="Amphetamine: on"
  echo "$label | bash='$0' param1=run param2=amphetamine terminal=false refresh=true"
fi
echo "Run keymap | bash='$0' param1=run param2=keymap terminal=false refresh=true"
echo "---"

if "$HSC" -o json 2>/dev/null | grep -q '"device_count": *[1-9]'; then
  echo "Headset"
  echo "Sidetone"
  for level in 0 16 32 48 64 80 96 112 128; do item "$level" sidetone "$level"; done
else
  echo "Headset not connected | color=gray"
fi
