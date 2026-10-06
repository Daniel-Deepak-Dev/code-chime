---
name: notify
description: Turn code-chime's desktop notifications and sounds on or off, mute only the sounds, or show the current state. Use when the user says "/code-chime:notify", "turn off notifications", "mute claude sounds", "unmute", or asks whether notifications are on.
argument-hint: on | off | mute | unmute | status
allowed-tools: Bash(bash "${CLAUDE_PLUGIN_ROOT}/scripts/notify-switch.sh":*)
---

Switch result:

!`bash "${CLAUDE_PLUGIN_ROOT}/scripts/notify-switch.sh" $ARGUMENTS`

Reply to the user with that one line and nothing else.

If no result appears above, run `scripts/notify-switch.sh` from this plugin's root folder yourself with the Bash tool (`bash "<path>/scripts/notify-switch.sh" <option>`), passing the user's option (`on`, `off`, `mute`, `unmute` or `status`; default `status`), and reply with its output line.

The switch lives in `~/.config/code-chime/config.json` and applies to every project at once. It takes effect on the next notification; no restart needed.
