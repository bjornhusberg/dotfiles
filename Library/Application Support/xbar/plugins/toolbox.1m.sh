#!/bin/bash
# <xbar.title>Toolbox</xbar.title>
# <xbar.desc>Gear menu: headset settings via headsetcontrol, and running keymap.</xbar.desc>
# <xbar.dependencies>headsetcontrol</xbar.dependencies>

# TODO: Display 'speaker' as icon when sound is unmuted
# TODO: Render WIFI icon only when disconnected, OR when on mobile hotspot
# TODO: Render the caffeine icon dynamically when active
# TODO: Render Low power icon dynamically when on low power
# TODO: Render Teams logo when online but not 'active'

HSC=/opt/homebrew/bin/headsetcontrol
KEYMAP="$HOME/bin/keymap"
CONFIG_DIR="$HOME/.config/xbar-toolbox"
CACHE_DIR="$CONFIG_DIR/cache"
CACHE_TTL=900  # 15 minutes in seconds
COPILOT_TTL=600  # 10 minutes in seconds
COPILOT_ICON_CACHE="$CACHE_DIR/copilot.b64"
COPILOT_STATS_CACHE="$CACHE_DIR/copilot_stats.txt"

mkdir -p "$CACHE_DIR"

# Check if Amphetamine session is active
is_amphetamine_active() {
  if pgrep -x Amphetamine >/dev/null 2>/dev/null; then
    [ "$(osascript -e 'tell application "Amphetamine" to session is active' 2>/dev/null)" = "true" ]
    return $?
  fi
  return 1
}

# Returns the icon state string based on current system state
# Format: "battery-{level}" or "none" if charging
get_battery_state() {
  pmout=$(pmset -g batt 2>/dev/null)
  if echo "$pmout" | grep -q "'Battery Power'"; then
    battery_percent=$(echo "$pmout" | grep -Eo '[0-9]+%' | head -1 | tr -d '%')
    if [ "$battery_percent" -lt 75 ]; then
      level=$(( (battery_percent + 5) / 10 * 10 ))
      echo "battery-$level"
    else
      echo "none"
    fi
  else
    echo "none"
  fi
}

# Returns "hotspot", "disconnected", or "connected"
get_wifi_state() {
  if [ "$(route -n get default 2>/dev/null | awk '/gateway:/ {print $2}')" = "172.20.10.1" ]; then
    echo "hotspot"
  elif ipconfig getsummary en0 2>/dev/null | grep -q "SSID :"; then
    echo "connected"
  else
    echo "disconnected"
  fi
}

# Returns "none" (muted), "speaker", "airpods", or "headphones"
# Muted check is always live; device name is cached for 30s (changes rarely)
AUDIO_DEVICE_CACHE="$CACHE_DIR/audio_device"
get_audio_state() {
  if [ "$(osascript -e 'output muted of (get volume settings)' 2>/dev/null)" = "true" ]; then
    echo "none"; return
  fi
  if [ -f "$AUDIO_DEVICE_CACHE" ] && [ $(( $(date +%s) - $(stat -f%m "$AUDIO_DEVICE_CACHE") )) -lt 30 ]; then
    cat "$AUDIO_DEVICE_CACHE"; return
  fi
  device=$(swift - <<'SWIFT' 2>/dev/null
import CoreAudio
var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
    mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
var id: AudioDeviceID = 0; var sz = UInt32(MemoryLayout<AudioDeviceID>.size)
AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &sz, &id)
addr.mSelector = kAudioObjectPropertyName; sz = UInt32(MemoryLayout<CFString>.size)
var ref: Unmanaged<CFString>? = nil
AudioObjectGetPropertyData(id, &addr, 0, nil, &sz, &ref)
print(ref?.takeRetainedValue() as String? ?? "")
SWIFT
)
  case "$device" in
    *AirPod*) result="airpods" ;;
    *MacBook*|*Built*in*|*Speaker*|"") result="speaker" ;;
    *) result="headphones" ;;
  esac
  echo "$result" | tee "$AUDIO_DEVICE_CACHE"
}

# Fetches Copilot AIC usage, caches for 10 min; writes empty files when no usage or faulty
get_copilot_data() {
  if [ -f "$COPILOT_ICON_CACHE" ] && [ $(( $(date +%s) - $(stat -f%m "$COPILOT_ICON_CACHE") )) -lt $COPILOT_TTL ]; then
    return
  fi
  local plugin="$HOME/Library/Application Support/xbar/plugins/copilot_aic.5m.py"
  local output
  output=$(python3 "$plugin" 2>/dev/null)
  # Empty = no usage today; "Error" / "not found" in line 3 = faulty — suppress both
  local ok=false
  if [ -n "$output" ]; then
    local third_line
    third_line=$(echo "$output" | sed -n '3p')
    echo "$third_line" | grep -qiE "error|not found" || ok=true
  fi
  if $ok; then
    echo "$output" | head -1 | sed 's/.* image=//' > "$COPILOT_ICON_CACHE"
    echo "$output" | tail -n +3                    > "$COPILOT_STATS_CACHE"
  else
    printf '' > "$COPILOT_ICON_CACHE"
    printf '' > "$COPILOT_STATS_CACHE"
  fi
  # Clean up stale versioned copilot composites
  find "$CACHE_DIR" -name "*-copilot-*.b64" -mmin +11 -delete 2>/dev/null
}

# Check if cache file is fresh (within TTL)
is_cache_fresh() {
  local cache_file="$1"
  if [ ! -f "$cache_file" ]; then
    return 1
  fi
  local file_age=$(( $(date +%s) - $(stat -f%m "$cache_file") ))
  [ $file_age -lt $CACHE_TTL ]
}

# Get composite icon (gear + optional coffee + optional wifi/hotspot + optional audio + optional copilot + optional battery)
get_icon() {
  local amph_active="$1"
  local battery_state="$2"
  local wifi_state="$3"
  local audio_state="$4"
  local copilot_active="$5"
  local cache_key="gear"

  [ "$amph_active" = "true" ] && cache_key="${cache_key}-coffee"
  [ "$wifi_state" = "disconnected" ] && cache_key="${cache_key}-wifi"
  [ "$wifi_state" = "hotspot" ] && cache_key="${cache_key}-hotspot"
  [ "$audio_state" != "none" ] && cache_key="${cache_key}-${audio_state}"
  if [ "$copilot_active" = "true" ]; then
    # Include mtime so composite regenerates when copilot data refreshes
    local copilot_mtime
    copilot_mtime=$(stat -f%m "$COPILOT_ICON_CACHE" 2>/dev/null || echo "0")
    cache_key="${cache_key}-copilot-${copilot_mtime}"
  fi
  [ "$battery_state" != "none" ] && cache_key="${cache_key}-${battery_state}"

  local cache_file="$CACHE_DIR/$cache_key.b64"

  # Return cached icon if fresh
  if is_cache_fresh "$cache_file"; then
    cat "$cache_file"
    return 0
  fi

  # Generate composite icon
  local icon_b64=$(swift - <<SWIFT 2>/dev/null
import AppKit

let dir = "$CONFIG_DIR"
let cacheDir = "$CACHE_DIR"
let amphetamineActive = $([[ "$amph_active" == "true" ]] && echo "true" || echo "false")
let batteryState = "$battery_state"
let wifiState = "$wifi_state"
let audioState = "$audio_state"
let copilotActive = $([[ "$copilot_active" == "true" ]] && echo "true" || echo "false")
let isDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
let iconColor = isDark ? NSColor.white : NSColor.black
let wifiColor = NSColor(red: 144/255, green: 152/255, blue: 158/255, alpha: 1.0)

func loadIcon(_ name: String) -> NSBitmapImageRep {
    let b64 = try! String(contentsOfFile: "\(dir)/\(name).b64", encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
    return NSBitmapImageRep(data: Data(base64Encoded: b64)!)!
}

func recolor(_ bmp: NSBitmapImageRep, to color: NSColor) {
    let rgb = color.usingColorSpace(.deviceRGB)!
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
    rgb.getRed(&r, green: &g, blue: &b, alpha: nil)
    guard let data = bmp.bitmapData else { return }
    let stride = bmp.bytesPerRow
    for y in 0..<bmp.pixelsHigh {
        for x in 0..<bmp.pixelsWide {
            let o = y * stride + x * 4
            if data[o + 3] > 0 {
                data[o]     = UInt8(r * 255)
                data[o + 1] = UInt8(g * 255)
                data[o + 2] = UInt8(b * 255)
            }
        }
    }
}

func renderComposite() -> String {
    let gear = loadIcon("gear")
    let gearW = gear.pixelsWide, gearH = gear.pixelsHigh

    var coffee: NSBitmapImageRep? = nil
    var coffeeW = 0
    if amphetamineActive {
        coffee = loadIcon("coffee")
        coffeeW = coffee?.pixelsWide ?? 0
    }

    var wifi: NSBitmapImageRep? = nil
    var wifiW = 0
    if wifiState == "disconnected" {
        wifi = loadIcon("wifi")
        wifiW = wifi?.pixelsWide ?? 0
    } else if wifiState == "hotspot" {
        wifi = loadIcon("hotspot")
        wifiW = wifi?.pixelsWide ?? 0
    }

    var audio: NSBitmapImageRep? = nil
    var audioW = 0
    if audioState != "none" {
        audio = loadIcon("audio-\(audioState)")
        audioW = audio?.pixelsWide ?? 0
    }

    // Load copilot icon from cache (not recolored — has its own colors)
    var copilot: NSBitmapImageRep? = nil
    var copilotW = 0
    if copilotActive,
       let b64 = try? String(contentsOfFile: "\(cacheDir)/copilot.b64", encoding: .utf8)
                      .trimmingCharacters(in: .whitespacesAndNewlines),
       !b64.isEmpty,
       let data = Data(base64Encoded: b64),
       let rep = NSBitmapImageRep(data: data) {
        copilot = rep
        copilotW = rep.pixelsWide
    }

    let batteryW = (batteryState != "none") ? 51 : 0
    let gap = 32

    var totalW = gearW + coffeeW + wifiW + audioW + copilotW + batteryW
    if coffeeW > 0 { totalW += gap }
    if wifiW > 0 { totalW += gap }
    if audioW > 0 { totalW += gap }
    if copilotW > 0 { totalW += gap }
    if batteryW > 0 { totalW += gap }

    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: totalW, pixelsHigh: gearH, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: Double(totalW) / 2, height: Double(gearH) / 2)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let scale = NSAffineTransform(); scale.scale(by: 0.5); scale.concat()

    recolor(gear, to: iconColor)

    var xPos = 0

    // Draw gear
    gear.draw(in: NSRect(x: xPos, y: 0, width: gearW, height: gearH))
    xPos += gearW

    // Draw coffee if active
    if let coffee = coffee, coffeeW > 0 {
        xPos += gap
        recolor(coffee, to: iconColor)
        let coffeeY = (gearH - coffee.pixelsHigh) / 2
        coffee.draw(in: NSRect(x: xPos, y: coffeeY, width: coffee.pixelsWide, height: coffee.pixelsHigh))
        xPos += coffeeW
    }

    // Draw WiFi if disconnected
    if let wifi = wifi, wifiW > 0 {
        xPos += gap
        let wifiY = (gearH - wifi.pixelsHigh) / 2
        recolor(wifi, to: wifiState == "hotspot" ? iconColor : wifiColor)
        wifi.draw(in: NSRect(x: xPos, y: wifiY, width: wifi.pixelsWide, height: wifi.pixelsHigh))
        xPos += wifiW
    }

    // Draw audio icon if not muted
    if let audio = audio, audioW > 0 {
        xPos += gap
        let audioY = (gearH - audio.pixelsHigh) / 2
        recolor(audio, to: iconColor)
        audio.draw(in: NSRect(x: xPos, y: audioY, width: audio.pixelsWide, height: audio.pixelsHigh))
        xPos += audioW
    }

    // Draw copilot donut chart if active (no recolor — colors are intentional)
    if let copilot = copilot, copilotW > 0 {
        xPos += gap
        let copilotY = (gearH - copilot.pixelsHigh) / 2
        copilot.draw(in: NSRect(x: xPos, y: copilotY, width: copilot.pixelsWide, height: copilot.pixelsHigh))
        xPos += copilotW
    }

    // Draw battery if on battery power
    if batteryState != "none" {
        xPos += gap
        let level = Int(batteryState.split(separator: "-").last ?? "0") ?? 0
        let batH = 24, by = (gearH - batH) / 2

        iconColor.setStroke(); iconColor.setFill()
        let body = NSRect(x: xPos + 1, y: by + 1, width: 44, height: 22)
        let outline = NSBezierPath(roundedRect: body, xRadius: 6, yRadius: 6)
        outline.lineWidth = 2
        outline.stroke()
        NSBezierPath(roundedRect: NSRect(x: xPos + 47, y: by + 8, width: 4, height: 8), xRadius: 2, yRadius: 2).fill()
        let fillW = Int(36.0 * Double(level) / 100)
        if fillW > 0 {
            NSBezierPath(roundedRect: NSRect(x: xPos + 5, y: by + 5, width: max(fillW, 3), height: 14), xRadius: 2, yRadius: 2).fill()
        }
    }

    NSGraphicsContext.restoreGraphicsState()
    let png = rep.representation(using: .png, properties: [:])!
    return png.base64EncodedString()
}

print(renderComposite())
SWIFT
)

  if [ -n "$icon_b64" ]; then
    echo "$icon_b64" > "$cache_file"
    echo "$icon_b64"
  fi
}

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
amph_active=false
# Only query Amphetamine while it runs, since an Apple Event would launch it.
if pgrep -x Amphetamine >/dev/null; then
  amph_running=true
  is_amphetamine_active && amph_active=true
fi

# Get icon state and retrieve/generate icon with caching
battery_state=$(get_battery_state)
wifi_state=$(get_wifi_state)
audio_state=$(get_audio_state)
get_copilot_data
copilot_active=false
[ -s "$COPILOT_ICON_CACHE" ] && copilot_active=true
icon_b64=$(get_icon "$amph_active" "$battery_state" "$wifi_state" "$audio_state" "$copilot_active")
echo "| image=$icon_b64"
echo "---"

# Battery status
pmout=$(pmset -g batt 2>/dev/null)
battery_percent=$(echo "$pmout" | grep -Eo '[0-9]+%' | head -1 | tr -d '%')
battery_remaining=$(echo "$pmout" | grep -Eo '[0-9]+:[0-9]+ remaining' | head -1)

if echo "$pmout" | grep -q "'Battery Power'"; then
  if [ -n "$battery_remaining" ]; then
    echo "Battery: $battery_percent% ($battery_remaining) | refresh=true"
  else
    echo "Battery: $battery_percent% | refresh=true"
  fi
else
  echo "Battery: $battery_percent% (charging) | refresh=true"
fi

echo "---"

# Lock screen
echo "Lock screen | bash='$0' param1=run param2=lock terminal=false"

# Sound
muted=$(osascript -e "output muted of (get volume settings)")
if [ "$muted" = "true" ]; then
  echo "Sound on | bash='$0' param1=run param2=unmute refresh=true"
else
  echo "Sound on ✓ | bash='$0' param1=run param2=mute refresh=true"
fi

# Keep awake
if $amph_running; then
  label="Keep awake"
  $amph_active && label="Keep awake ✓"
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
echo "Keymap | bash='$0' param1=run param2=keymap terminal=false"

# Copilot AIC
if $copilot_active; then
  echo "Copilot AIC | image=$(cat "$COPILOT_ICON_CACHE")"
  while IFS= read -r line; do
    if [ "$line" = "---" ]; then
      echo "-----"
    elif [ -n "$line" ]; then
      echo "--$line"
    fi
  done < "$COPILOT_STATS_CACHE"
fi

# Headset
if "$HSC" -o json 2>/dev/null | grep -q '"device_count": *[1-9]'; then
  echo "---"
  echo "Headset sidetone"
  for level in 0 16 32 48 64 80 96 112 128; do item "$level" sidetone "$level"; done
fi
