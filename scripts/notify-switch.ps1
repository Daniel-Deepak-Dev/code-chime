# win-notify switch.
# Usage: notify-switch.ps1 [on | off | mute | unmute | status]
#   on / off       all toasts and sounds
#   mute / unmute  sounds only; toasts keep showing
param([string]$Action = "status")

$claudeDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE ".claude" }
$path = Join-Path $claudeDir "notify-config.json"

# Keep every other key (such as "sounds") when rewriting the file.
$config = $null
if (Test-Path $path) { try { $config = Get-Content $path -Raw | ConvertFrom-Json } catch {} }
if (-not $config) { $config = New-Object PSObject }
foreach ($key in "enabled", "sound") {
    if ($null -eq $config.$key) { $config | Add-Member -NotePropertyName $key -NotePropertyValue $true }
}

$Action = "$Action".Trim().ToLower()
if (-not $Action) { $Action = "status" }
switch ($Action) {
    "on"     { $config.enabled = $true }
    "off"    { $config.enabled = $false }
    "mute"   { $config.sound   = $false }
    "unmute" { $config.sound   = $true }
    "status" { }
    default  { "Unknown option '$Action'. Use: on | off | mute | unmute | status"; exit 1 }
}
if ($Action -ne "status") {
    if (-not (Test-Path $claudeDir)) { New-Item -ItemType Directory -Path $claudeDir | Out-Null }
    $config | ConvertTo-Json -Depth 5 | Set-Content -Path $path -Encoding utf8
}

$state = if (-not $config.enabled) { "OFF - no toasts, no sounds" }
         elseif (-not $config.sound) { "ON, sounds muted - toasts only" }
         else { "ON - toasts + sounds" }
"Claude notifications: $state"
