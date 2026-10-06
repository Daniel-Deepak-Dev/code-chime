# code-chime Windows backend: one silent toast, then one sound.
# notify.sh passes the text in env vars (CHIME_TITLE, CHIME_BODY, CHIME_SOUND) so no
# argument quoting can mangle it. Errors go to stderr; notify.sh logs them.
# ASCII only: Windows PowerShell 5.1 reads a BOM-less script as ANSI.

$title = "$env:CHIME_TITLE"
$body  = "$env:CHIME_BODY"
$sound = "$env:CHIME_SOUND"

try {
    # Built-in WinRT toast API, so no module is needed.
    $null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
    $null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
    $t = [Security.SecurityElement]::Escape($title)
    $b = [Security.SecurityElement]::Escape($body)
    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $xml.LoadXml("<toast><visual><binding template=`"ToastGeneric`"><text>$t</text><text>$b</text></binding></visual><audio silent=`"true`"/></toast>")
    # Windows only shows toasts from a registered app id; PowerShell's always is.
    $appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show([Windows.UI.Notifications.ToastNotification]::new($xml))
} catch {
    $winrtError = $_
    try {
        # Fallback for systems where the WinRT call is blocked.
        Import-Module BurntToast -ErrorAction Stop
        New-BurntToastNotification -Text $title, $body -Silent
    } catch {
        [Console]::Error.WriteLine("toast failed: $winrtError")
    }
}

if ($sound) {
    try {
        # PlaySync: the process must stay alive until the sound ends. The hook is async, so Claude does not wait.
        (New-Object System.Media.SoundPlayer $sound).PlaySync()
    } catch {
        [Console]::Error.WriteLine("sound failed ($sound): $_")
    }
}
exit 0
