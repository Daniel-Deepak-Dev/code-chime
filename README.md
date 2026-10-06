# win-notify

Windows notifications for [Claude Code](https://claude.com/claude-code). You get a toast plus a different sound for each kind of event, so you can tell what happened without looking.

Works with the Claude Code terminal CLI and the Claude Code VS Code extension, in every project. **Windows only, Claude Code only.** In other Claude apps (claude.ai chat, Cowork) and on macOS or Linux the plugin does nothing useful.

| Event | Toast | Sound (`C:\Windows\Media`) |
| --- | --- | --- |
| Task finished | Claude finished | `tada.wav` |
| Claude asks you a question | Claude has a question | `Windows Notify Messaging.wav` |
| Plan ready for approval | Plan ready for review | `Windows Notify Calendar.wav` |
| Permission or input needed | Claude needs you | `Windows Message Nudge.wav` |
| Turn stopped by an API error (rate limit, auth, server) | Claude stopped | `Windows Critical Stop.wav` |

## Requirements

- Windows 10 or 11
- Claude Code with Git for Windows, which Claude Code already needs on Windows
- Windows PowerShell 5.1 (built in)
- The [BurntToast](https://github.com/Windos/BurntToast) PowerShell module

## Install

1. Install BurntToast once per PC. In PowerShell:

   ```powershell
   Install-Module BurntToast -Scope CurrentUser
   ```

2. In Claude Code:

   ```
   /plugin marketplace add Daniel-Deepak-Dev/win-notify
   /plugin install win-notify@win-notify
   ```

   Pick the **user** scope so it applies to every project.

3. Restart Claude Code. In VS Code, run **Developer: Reload Window**.

## Turn it on and off

```
/win-notify:notify off       no toasts, no sounds
/win-notify:notify on        back on
/win-notify:notify mute      toasts only, no sound
/win-notify:notify unmute    sounds back
/win-notify:notify status    show the current state
```

You can also just tell Claude "turn off notifications" or "mute Claude sounds".

The switch applies to every project and every open session. It takes effect on the next notification.

## Change a sound

Add a `sounds` block to `%USERPROFILE%\.claude\notify-config.json`. A bare file name is looked up in `C:\Windows\Media`. A full path can point at any `.wav` file.

```json
{
  "enabled": true,
  "sound": true,
  "sounds": {
    "Finished": "chimes.wav",
    "Error": "C:/Users/me/Music/oops.wav"
  }
}
```

The keys are `Finished`, `Question`, `Plan`, `NeedsYou` and `Error`. The file lives outside the plugin folder, so plugin updates keep your settings.

## How it works

- `hooks/hooks.json` registers async command hooks on four events: `Stop`, `StopFailure`, `Notification` (`permission_prompt|elicitation_dialog`) and `PreToolUse` (`AskUserQuestion|ExitPlanMode`).
- Each hook runs `scripts/notify.ps1`. It shows a silent BurntToast toast and plays the event's `.wav` with `System.Media.SoundPlayer`. The hooks are async, so Claude never waits for them.
- A plan or question also triggers a later `Notification` ("Claude needs your permission to use ExitPlanMode"), about 20 seconds after the first alert. The script skips that repeat.
- `skills/notify` is the `/win-notify:notify` command. It runs `scripts/notify-switch.ps1`.
- Headless `claude -p` runs can exit before an async hook finishes, so expect no toast there.

## What it runs, reads and stores

Everything stays on your PC. The plugin makes no network calls and sends no data anywhere.

- **Runs:** `powershell.exe` with `scripts/notify.ps1` on the four hook events above, and with `scripts/notify-switch.ps1` when you use `/win-notify:notify`. The `/win-notify:notify` skill pre-approves only that one switch command.
- **Reads:** the event JSON that Claude Code passes to the hook. The toast shows the project folder name and Claude's own notification text, such as "Claude needs your permission to use Bash". It also reads `notify-config.json` and the `.wav` files.
- **Writes:** `notify-config.json` (on/off state and sound overrides) and, only when something fails, `notify-errors.log`. Both are in `%USERPROFILE%\.claude` (or `CLAUDE_CONFIG_DIR` if set).
- **Uses:** the BurntToast module, which you install yourself. The plugin never installs anything.

## Troubleshooting

- **Nothing happens.** Look in `%USERPROFILE%\.claude\notify-errors.log`. The script writes every failure there, because async hooks have no visible output.
- **The toast appears only in the notification panel.** Windows Do Not Disturb is on. Sounds still play. Use `/win-notify:notify mute` for quiet time.
- **Writing your own hook commands on Windows.** Claude Code runs them through Git Bash. A bare `C:\path\to\script.ps1` loses its backslashes there. Use forward slashes or quote the path.

## Uninstall

```
/plugin uninstall win-notify@win-notify
```

Then delete `%USERPROFILE%\.claude\notify-config.json` if you no longer want your settings.

## License

MIT
