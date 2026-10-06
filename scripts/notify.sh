#!/usr/bin/env bash
# code-chime: desktop notification + one sound per Claude Code hook event.
# Works on macOS, Linux, Windows (Git Bash) and WSL. Runs as an async hook,
# so it never blocks Claude. Always exits 0.
# Keep this bash 3.2 compatible (macOS /bin/bash): no associative arrays, no ${var,,}.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# Own settings folder, so the plugin never touches Claude Code's config folder.
CONFIG_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/code-chime
CONFIG_FILE=$CONFIG_DIR/config.json
ERROR_LOG=$CONFIG_DIR/errors.log

log_error() {
  mkdir -p "$CONFIG_DIR" 2>/dev/null
  printf '%s  %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$*" >> "$ERROR_LOG" 2>/dev/null
}

# Log a message only the first time, so a missing tool does not fill the log.
log_once() {
  grep -qF -- "$*" "$ERROR_LOG" 2>/dev/null || log_error "$*"
}

# First string value of "$1" in the JSON text "$2". Hook input fields we read are
# flat strings, so this avoids depending on jq.
json_str() {
  printf '%s' "$2" \
    | grep -Eo "\"$1\"[[:space:]]*:[[:space:]]*\"([^\"\\\\]|\\\\.)*\"" \
    | head -n 1 \
    | sed -E 's/^"[^"]*"[[:space:]]*:[[:space:]]*"//; s/"$//; s/\\"/"/g; s/\\\\/\\/g'
}

json_bool() {
  printf '%s' "$2" \
    | grep -Eo "\"$1\"[[:space:]]*:[[:space:]]*(true|false)" \
    | head -n 1 \
    | grep -Eo '(true|false)$'
}

detect_os() {
  # CODE_CHIME_OS is for tests only: it forces a backend.
  if [ -n "${CODE_CHIME_OS:-}" ]; then echo "$CODE_CHIME_OS"; return; fi
  case "$(uname -s 2>/dev/null)" in
    Darwin) echo darwin ;;
    MINGW*|MSYS*|CYGWIN*) echo windows ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then echo wsl; else echo linux; fi ;;
    *) echo unknown ;;
  esac
}

# Built-in sound for an event, per OS.
default_sound() {
  case "$1:$2" in
    windows:Finished|wsl:Finished) echo "tada.wav" ;;
    windows:Question|wsl:Question) echo "Windows Notify Messaging.wav" ;;
    windows:Plan|wsl:Plan)         echo "Windows Notify Calendar.wav" ;;
    windows:NeedsYou|wsl:NeedsYou) echo "Windows Message Nudge.wav" ;;
    windows:Error|wsl:Error)       echo "Windows Critical Stop.wav" ;;
    darwin:Finished) echo "Hero.aiff" ;;
    darwin:Question) echo "Ping.aiff" ;;
    darwin:Plan)     echo "Glass.aiff" ;;
    darwin:NeedsYou) echo "Submarine.aiff" ;;
    darwin:Error)    echo "Basso.aiff" ;;
    linux:Finished) echo "complete.oga" ;;
    linux:Question) echo "message-new-instant.oga" ;;
    linux:Plan)     echo "dialog-information.oga" ;;
    linux:NeedsYou) echo "window-attention.oga" ;;
    linux:Error)    echo "dialog-warning.oga" ;;
  esac
}

# Full path for a sound name: absolute paths pass through, bare names go to the OS sound folder.
sound_path() {
  case "$2" in
    /*|[A-Za-z]:*|\\\\*) echo "$2"; return ;;
  esac
  case "$1" in
    windows) echo "${WINDIR:-C:\\Windows}\\Media\\$2" ;;
    wsl)     echo "C:\\Windows\\Media\\$2" ;;
    darwin)  echo "/System/Library/Sounds/$2" ;;
    linux)   echo "/usr/share/sounds/freedesktop/stereo/$2" ;;
  esac
}

notify_windows() {
  local ps1 err
  if [ "$OS" = wsl ]; then
    ps1=$(wslpath -w "$SCRIPT_DIR/win-toast.ps1" 2>/dev/null)
  else
    ps1=$(cygpath -w "$SCRIPT_DIR/win-toast.ps1" 2>/dev/null) || ps1=$SCRIPT_DIR/win-toast.ps1
  fi
  # Text travels in env vars, not arguments, so no shell quoting can mangle it.
  # WSLENV carries them from WSL into the Windows process.
  err=$(CHIME_TITLE=$1 CHIME_BODY=$2 CHIME_SOUND=$3 \
        WSLENV="${WSLENV:+$WSLENV:}CHIME_TITLE:CHIME_BODY:CHIME_SOUND" \
        powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$ps1" 2>&1 >/dev/null)
  [ -z "$err" ] || log_error "$err"
}

notify_darwin() {
  if command -v terminal-notifier >/dev/null 2>&1; then
    terminal-notifier -title "$1" -message "$2" >/dev/null 2>&1 || log_error "terminal-notifier failed"
  else
    # argv keeps the text out of the AppleScript source, so quotes in it cannot break it.
    osascript -e 'on run argv' \
              -e 'display notification (item 2 of argv) with title (item 1 of argv)' \
              -e 'end run' "$1" "$2" >/dev/null 2>&1 || log_error "osascript notification failed"
  fi
  [ -n "$3" ] || return 0
  afplay "$3" >/dev/null 2>&1 || log_error "afplay failed: $3"
}

notify_linux() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -a "Claude Code" "$1" "$2" >/dev/null 2>&1 || log_error "notify-send failed"
  else
    log_once "notify-send not found (install libnotify-bin or libnotify); playing sound only"
  fi
  [ -n "$3" ] || return 0
  if [ ! -f "$3" ]; then log_once "sound file not found (install sound-theme-freedesktop?): $3"; return 0; fi
  if command -v paplay >/dev/null 2>&1; then
    paplay "$3" >/dev/null 2>&1 || log_error "paplay failed: $3"
  elif command -v pw-play >/dev/null 2>&1; then
    pw-play "$3" >/dev/null 2>&1 || log_error "pw-play failed: $3"
  elif command -v canberra-gtk-play >/dev/null 2>&1; then
    canberra-gtk-play -f "$3" >/dev/null 2>&1 || log_error "canberra-gtk-play failed: $3"
  elif command -v aplay >/dev/null 2>&1 && [ "${3##*.}" = wav ]; then
    aplay -q "$3" >/dev/null 2>&1 || log_error "aplay failed: $3"
  else
    log_once "no sound player found (paplay, pw-play, canberra-gtk-play, or aplay for .wav)"
  fi
}

INPUT=$(cat)

CONFIG=""
[ -f "$CONFIG_FILE" ] && CONFIG=$(cat "$CONFIG_FILE" 2>/dev/null)
[ "$(json_bool enabled "$CONFIG")" = false ] && exit 0
PLAY_SOUND=1
[ "$(json_bool sound "$CONFIG")" = false ] && PLAY_SOUND=0

EVENT=$(json_str hook_event_name "$INPUT")
TOOL=$(json_str tool_name "$INPUT")
CWD=$(json_str cwd "$INPUT")
MESSAGE=$(json_str message "$INPUT")
PROJECT=${CWD##*[/\\]}
[ -n "$PROJECT" ] || PROJECT="Claude Code"

case "$EVENT" in
  Stop)
    TITLE="Claude finished"; BODY="Task done in $PROJECT"; SOUND_ID=Finished ;;
  StopFailure)
    REASON=$(json_str error "$INPUT")
    [ -n "$REASON" ] || REASON=$(json_str error_details "$INPUT")
    [ -n "$REASON" ] || REASON=$(json_str error_type "$INPUT")
    TITLE="Claude stopped"; BODY=${REASON:-"Turn ended by an error (usage limit?)"}; SOUND_ID=Error ;;
  PreToolUse)
    if [ "$TOOL" = ExitPlanMode ]; then
      TITLE="Plan ready for review"; BODY="Approve or edit the plan in $PROJECT"; SOUND_ID=Plan
    else
      TITLE="Claude has a question"; BODY="Waiting for your answer in $PROJECT"; SOUND_ID=Question
    fi ;;
  *)
    # A plan or question also raises "Claude needs your permission to use ExitPlanMode",
    # some 20+ seconds after the PreToolUse alert already went out. Skip that repeat.
    case "$MESSAGE" in *ExitPlanMode*|*AskUserQuestion*) exit 0 ;; esac
    TITLE="Claude needs you"; BODY=${MESSAGE:-"Needs your attention"}; SOUND_ID=NeedsYou ;;
esac

OS=$(detect_os)
SOUND=""
if [ "$PLAY_SOUND" = 1 ]; then
  NAME=$(json_str "$SOUND_ID" "$CONFIG")
  [ -n "$NAME" ] || NAME=$(default_sound "$OS" "$SOUND_ID")
  [ -n "$NAME" ] && SOUND=$(sound_path "$OS" "$NAME")
fi

case "$OS" in
  windows|wsl) notify_windows "$TITLE" "$BODY" "$SOUND" ;;
  darwin)      notify_darwin "$TITLE" "$BODY" "$SOUND" ;;
  linux)       notify_linux "$TITLE" "$BODY" "$SOUND" ;;
  *)           log_once "unsupported OS: $(uname -s 2>/dev/null)" ;;
esac
exit 0
