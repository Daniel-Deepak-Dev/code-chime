# code-chime

Desktop notifications for [Claude Code](https://claude.com/claude-code), with a different sound for each kind of event. You can tell what happened without looking at the screen.

Works in the Claude Code terminal CLI and the **Claude Code VS Code extension**, in every project, on **macOS, Windows (including WSL) and Linux**. It is a Claude Code plugin: in other Claude apps (claude.ai chat, Cowork) it does nothing.

| Event | Notification | Windows | macOS | Linux |
| --- | --- | --- | --- | --- |
| Task finished | Claude finished | `tada.wav` | Hero | `complete` |
| Claude asks you a question | Claude has a question | `Windows Notify Messaging.wav` | Ping | `message-new-instant` |
| Plan ready for approval | Plan ready for review | `Windows Notify Calendar.wav` | Glass | `dialog-information` |
| Permission or input needed | Claude needs you | `Windows Message Nudge.wav` | Submarine | `window-attention` |
| Turn stopped by an API error (rate limit, auth, server) | Claude stopped | `Windows Critical Stop.wav` | Basso | `dialog-warning` |

Every sound is one the OS already ships: `C:\Windows\Media` on Windows, `/System/Library/Sounds` on macOS, and the freedesktop sound theme (`/usr/share/sounds/freedesktop/stereo`) on Linux.

## Requirements

- **All:** Claude Code and `bash`. On Windows that is Git Bash, which Claude Code uses to run hooks.
- **Windows:** nothing else. Windows PowerShell 5.1 is built in.
- **macOS:** nothing else. [`terminal-notifier`](https://github.com/julienXX/terminal-notifier) is used if you have it.
- **Linux:** `notify-send` (package `libnotify-bin` or `libnotify`). For sound, one of `paplay`, `pw-play`, `canberra-gtk-play`, or `aplay`, plus the freedesktop sound theme (`sound-theme-freedesktop`). Most desktop distros ship all of this.
- **WSL:** Windows interop turned on (the default), so `powershell.exe` runs from WSL.

## Install

In Claude Code:

```
/plugin marketplace add Daniel-Deepak-Dev/code-chime
/plugin install code-chime@code-chime
```

Pick the **user** scope so it works in every project. Then restart Claude Code, or in VS Code run **Developer: Reload Window**.

## Turn it on and off

```
/code-chime:notify off       no notifications, no sounds
/code-chime:notify on        back on
/code-chime:notify mute      notifications only, no sound
/code-chime:notify unmute    sounds back
/code-chime:notify status    show the current state
```

You can also just tell Claude "turn off notifications" or "mute Claude sounds".

The switch applies to every project and every open session. It takes effect on the next notification.

## Change a sound

Add a `sounds` block to `~/.claude/code-chime.json` (`%USERPROFILE%\.claude\code-chime.json` on Windows). A bare file name is looked up in your OS's sound folder above. A full path can point at any file your OS can play.

```json
{
  "enabled": true,
  "sound": true,
  "sounds": {
    "Finished": "Glass.aiff",
    "Error": "/Users/me/Music/oops.wav"
  }
}
```

The keys are `Finished`, `Question`, `Plan`, `NeedsYou` and `Error`. The file lives outside the plugin folder, so plugin updates keep your settings. If you set `CLAUDE_CONFIG_DIR`, the file lives there instead.

## How it works

- `hooks/hooks.json` registers async command hooks on four events: `Stop`, `StopFailure`, `Notification` (`permission_prompt|elicitation_dialog`) and `PreToolUse` (`AskUserQuestion|ExitPlanMode`). Each runs `bash scripts/notify.sh`. The hooks are async, so Claude never waits for them.
- `scripts/notify.sh` reads the event, picks the title, text and sound, detects the OS, and hands off:
  - **Windows and WSL:** `scripts/win-toast.ps1` through `powershell.exe`. It shows a silent toast with the built-in Windows toast API and plays the `.wav`. If the toast API is blocked and the BurntToast module is installed, it uses that instead.
  - **macOS:** `terminal-notifier` or `osascript` for the notification, `afplay` for the sound.
  - **Linux:** `notify-send` for the notification, the first available sound player for the sound.
- A plan or question also triggers a later `Notification` ("Claude needs your permission to use ExitPlanMode"), about 20 seconds after the first alert. The script skips that repeat.
- `skills/notify` is the `/code-chime:notify` command. It runs `scripts/notify-switch.sh`.

## What it runs, reads and stores

Everything stays on your computer. The plugin makes no network calls and sends no data anywhere.

- **Runs:** `bash` with `scripts/notify.sh` on the four hook events. That script runs only local programs: `powershell.exe` (Windows, WSL); `terminal-notifier` or `osascript`, and `afplay` (macOS); `notify-send` and a sound player (Linux). The `/code-chime:notify` command runs `scripts/notify-switch.sh`, and the skill pre-approves only that command.
- **Reads:** the event JSON that Claude Code passes to the hook. The notification shows the project folder name and Claude's own notification text, such as "Claude needs your permission to use Bash". It also reads `code-chime.json` and the sound files.
- **Writes:** `code-chime.json` (on/off state and sound overrides) and, only when something fails, `code-chime-errors.log`. Both are in `~/.claude`, or in `CLAUDE_CONFIG_DIR` if set.
- **Installs:** nothing.

## Limitations

- **macOS:** notifications sent through `osascript` appear under "Script Editor". If none show up, allow notifications for Script Editor in System Settings > Notifications, or install `terminal-notifier`.
- **VS Code Remote-SSH, Dev Containers and Codespaces:** Claude Code and its hooks run on the remote machine, so notifications cannot reach your local desktop. WSL is handled.
- **Headless `claude -p` runs** can exit before an async hook finishes, so expect no notification there.
- **Windows Do Not Disturb** hides the toast but the sound still plays. Use `/code-chime:notify mute` for quiet time.

## Troubleshooting

- **Nothing happens.** Look in `~/.claude/code-chime-errors.log`. The script writes every failure there, because async hooks have no visible output.
- **Linux: notification but no sound.** Install `pulseaudio-utils` (for `paplay`) or `pipewire` tools (for `pw-play`), and `sound-theme-freedesktop`.
- **Writing your own hook commands on Windows.** Claude Code runs them through Git Bash. A bare `C:\path\to\script.ps1` loses its backslashes there. Use forward slashes or quote the path.

## Uninstall

```
/plugin uninstall code-chime@code-chime
```

Then delete `~/.claude/code-chime.json` if you no longer want your settings.

## License

MIT
