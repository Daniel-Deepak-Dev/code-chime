# win-notify: Windows toast + one sound per Claude Code hook event.
# Runs as an async hook, so it never blocks Claude. Always exits 0.

# Default sound per event. A bare file name is looked up in C:\Windows\Media.
# Override any of them in notify-config.json under "sounds" (a full path to any .wav works).
$sounds = @{
    Finished = "tada.wav"
    Question = "Windows Notify Messaging.wav"
    Plan     = "Windows Notify Calendar.wav"
    NeedsYou = "Windows Message Nudge.wav"
    Error    = "Windows Critical Stop.wav"
}

# State lives in the Claude config folder, not the plugin folder, so plugin updates never reset it.
$claudeDir     = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE ".claude" }
$configPath    = Join-Path $claudeDir "notify-config.json"
$errorLog      = Join-Path $claudeDir "notify-errors.log"

function Write-NotifyError($err) {
    try { "$(Get-Date -Format s)  $err" | Out-File -Append -Encoding utf8 $errorLog } catch {}
}

try {
    $hookInput = [Console]::In.ReadToEnd() | ConvertFrom-Json

    # Switch set by notify-switch.ps1 (/notify). Missing or unreadable file = on, with sound.
    $config = try { Get-Content $configPath -Raw -ErrorAction Stop | ConvertFrom-Json } catch { $null }
    if ($config -and $config.enabled -eq $false) { exit 0 }
    $playSound = -not ($config -and $config.sound -eq $false)
    if ($config -and $config.sounds) {
        foreach ($p in $config.sounds.PSObject.Properties) { $sounds[$p.Name] = $p.Value }
    }

    $hookEvent = $hookInput.hook_event_name
    $project   = if ($hookInput.cwd) { Split-Path $hookInput.cwd -Leaf } else { "Claude Code" }

    # A plan or question also raises "Claude needs your permission to use ExitPlanMode",
    # some 20+ seconds after the PreToolUse alert already went out. Skip that repeat.
    if ($hookEvent -eq "Notification" -and "$($hookInput.message)" -match 'ExitPlanMode|AskUserQuestion') {
        exit 0
    }

    switch ($hookEvent) {
        "Stop" {
            $title = "Claude finished"
            $body  = "Task done in $project"
            $soundKey = "Finished"
        }
        "StopFailure" {
            $reason = @($hookInput.error, $hookInput.error_details, $hookInput.error_type, $hookInput.reason) | Where-Object { $_ } | Select-Object -First 1
            $title = "Claude stopped"
            $body  = if ($reason) { "$reason" } else { "Turn ended by an error (usage limit?)" }
            $soundKey = "Error"
        }
        "PreToolUse" {
            if ($hookInput.tool_name -eq "ExitPlanMode") {
                $title = "Plan ready for review"
                $body  = "Approve or edit the plan in $project"
                $soundKey = "Plan"
            } else {
                $title = "Claude has a question"
                $body  = "Waiting for your answer in $project"
                $soundKey = "Question"
            }
        }
        default {
            $title = "Claude needs you"
            $body  = if ($hookInput.message) { $hookInput.message } else { "Needs your attention" }
            $soundKey = "NeedsYou"
        }
    }

    # Toast is silent; the sound below is what tells events apart.
    try {
        New-BurntToastNotification -Text $title, $body -Silent
    } catch {
        Write-NotifyError "toast failed (is BurntToast installed? Install-Module BurntToast -Scope CurrentUser): $_"
    }

    if ($playSound) {
        try {
            $wav = $sounds[$soundKey]
            if (-not [IO.Path]::IsPathRooted($wav)) { $wav = Join-Path "$env:WINDIR\Media" $wav }
            # PlaySync: the process must stay alive until the sound ends. The hook is async, so Claude does not wait.
            (New-Object System.Media.SoundPlayer $wav).PlaySync()
        } catch {
            Write-NotifyError "sound failed ($wav): $_"
        }
    }
} catch {
    # Hooks run async, so failures are otherwise invisible. Leave a trace.
    Write-NotifyError $_
}
exit 0
