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
    wifi)
      # The password is read from the login keychain: security add-generic-password -U -s xbar-wifi -a <ssid> -w
      networksetup -setairportnetwork en0 "$2" "$(security find-generic-password -s xbar-wifi -a "$2" -w)" ;;
    wifi-disconnect) swift "$HOME/.config/xbar-toolbox/disconnect.swift" ;;
    lock) swift "$HOME/.config/xbar-toolbox/lock.swift" ;;
    mute) osascript -e "set volume with output muted" ;;
    unmute) osascript -e "set volume without output muted" ;;
    lowpower)
      # pmset needs root, so macOS asks for the password each time.
      osascript -e "do shell script \"pmset -a lowpowermode $2\" with administrator privileges" ;;
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
# While on battery, a gear+battery composite (10% steps) replaces the plain gear.
pmout=$(pmset -g batt)
battery_percent=$(echo $pmout | grep -Eo '[0-9]+%' | head -1 | tr -d '%')
battery_remaining=$(echo $pmout | grep -Eo '[0-9]+:[0-9]+ remaining' | head -1 | tr -d '%')
battery_draining=$(echo $pmout | grep -q "'Battery Power'")
if [ -n "$battery_draining" ]; then
  level=$(( (battery_percent + 5) / 10 * 10 ))
  base=$(basename "$ICON_FILE" .b64)
  ICON_FILE="$HOME/.config/xbar-toolbox/$base-bat-$level.b64"
fi
echo "| templateImage=$(cat "$ICON_FILE")"
echo "---"

if [ -z "$battery_draining" ]; then
  echo "Battery: $battery_percent% (charging) | refresh=true"
elif [ -n "$battery_remaining" ]; then
  echo "Battery: $battery_percent% ($battery_remaining) | refresh=true"
else
  echo "Battery: $battery_percent% | refresh=true"
fi

echo "---"

# Lock screen
echo "Lock screen | bash='$0' param1=run param2=lock terminal=false"

# Mute
muted=$(osascript -e "output muted of (get volume settings)")
if [ "$muted" = "true" ]; then
  echo "Mute ✓ | bash='$0' param1=run param2=unmute refresh=true"
else
  echo "Mute | bash='$0' param1=run param2=mute refresh=true"
fi

# Keep awake
if $amph_running; then
  label="Keep awake"
  $amph_on && label="Keep awake ✓"
  echo "$label | bash='$0' param1=run param2=amphetamine terminal=false refresh=true"
fi

# Mobile hotspot
wifi_label="Mobile hotspot"
wifi_action="param2=wifi param3=VIRU2"
# iPhone hotspots hand out 172.20.10.0/28, so this gateway means we are on the hotspot.
if [ "$(route -n get default 2>/dev/null | awk '/gateway:/ {print $2}')" = "172.20.10.1" ]; then
  wifi_label="Mobile hotspot ✓"
  wifi_action="param2=wifi-disconnect"
fi
echo "$wifi_label | bash='$0' param1=run $wifi_action terminal=false refresh=true"

# Low power mode
if pmset -g | grep -Eq 'lowpowermode[[:space:]]+1'; then
  echo "Low power mode ✓ | bash='$0' param1=run param2=lowpower param3=0 terminal=false refresh=true"
else
  echo "Low power mode | bash='$0' param1=run param2=lowpower param3=1 terminal=false refresh=true"
fi

# Keymap
echo "Keymap | bash='$0' param1=run param2=keymap terminal=false refresh=true"

# Headset
if "$HSC" -o json 2>/dev/null | grep -q '"device_count": *[1-9]'; then
  echo "---"
  echo "Headset sidetone"
  for level in 0 16 32 48 64 80 96 112 128; do item "$level" sidetone "$level"; done
fi
