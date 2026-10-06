---
name: notify
description: Turn Claude's Windows toast + sound notifications on or off, mute only the sounds, or show the current state. Use when the user says "/notify", "turn off notifications", "mute claude sounds", "unmute", or asks whether notifications are on.
argument-hint: on | off | mute | unmute | status
allowed-tools: Bash(powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File *notify-switch.ps1*)
---

Switch result:

!`powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/notify-switch.ps1" $ARGUMENTS`

Reply to the user with that one line and nothing else.

If no result appears above, run `scripts/notify-switch.ps1` from this plugin's root folder yourself with the Bash tool, the same way (`powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "<path>" <option>`), passing the user's option (`on`, `off`, `mute`, `unmute` or `status`; default `status`), and reply with its output line.

The switch lives in `~/.claude/notify-config.json` and applies to every project at once. It takes effect on the next notification; no restart needed.
