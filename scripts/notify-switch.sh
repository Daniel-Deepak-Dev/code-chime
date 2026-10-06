#!/usr/bin/env bash
# code-chime switch.
# Usage: notify-switch.sh [on | off | mute | unmute | status]
#   on / off       all notifications and sounds
#   mute / unmute  sounds only; notifications keep showing
# Portable across macOS (BSD tools, bash 3.2), Linux and Git Bash: awk + mv, no sed -i.

CONFIG_DIR=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
CONFIG_FILE=$CONFIG_DIR/code-chime.json

action=$(printf '%s' "${1:-status}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
[ -n "$action" ] || action=status

key=""
case "$action" in
  on)     key=enabled; value=true ;;
  off)    key=enabled; value=false ;;
  mute)   key=sound;   value=false ;;
  unmute) key=sound;   value=true ;;
  status) ;;
  *) echo "Unknown option '$1'. Use: on | off | mute | unmute | status"; exit 1 ;;
esac

read_bool() {
  [ -f "$CONFIG_FILE" ] || return 0
  grep -Eo "\"$1\"[[:space:]]*:[[:space:]]*(true|false)" "$CONFIG_FILE" | head -n 1 | grep -Eo '(true|false)$'
}

if [ -n "$key" ]; then
  mkdir -p "$CONFIG_DIR"
  # Start from defaults when the file is missing or holds no keys.
  if [ ! -f "$CONFIG_FILE" ] || ! grep -q '"' "$CONFIG_FILE"; then
    printf '{\n  "enabled": true,\n  "sound": true\n}\n' > "$CONFIG_FILE"
  fi
  tmp="$CONFIG_FILE.tmp.$$"
  if grep -Eq "\"$key\"[[:space:]]*:[[:space:]]*(true|false)" "$CONFIG_FILE"; then
    awk -v key="$key" -v value="$value" '
      BEGIN { pat = "\"" key "\"[ \t]*:[ \t]*(true|false)" }
      { if (!done && sub(pat, "\"" key "\": " value)) done = 1; print }
    ' "$CONFIG_FILE" > "$tmp"
  else
    # Key missing: add it right after the opening brace. Other keys, such as "sounds", stay.
    awk -v key="$key" -v value="$value" '
      { if (!done && sub(/\{/, "{\n  \"" key "\": " value ",")) done = 1; print }
    ' "$CONFIG_FILE" > "$tmp"
  fi
  mv "$tmp" "$CONFIG_FILE"
fi

enabled=$(read_bool enabled)
sound=$(read_bool sound)
if [ "$enabled" = false ]; then
  echo "code-chime: OFF - no notifications, no sounds"
elif [ "$sound" = false ]; then
  echo "code-chime: ON, sounds muted - notifications only"
else
  echo "code-chime: ON - notifications + sounds"
fi
