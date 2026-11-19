# Shared helpers for Ponytail Antigravity lifecycle hooks (Windows PowerShell)

$script:ValidModes = @('off', 'lite', 'full', 'ultra')

function Initialize-Utf8Console {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    try { [Console]::InputEncoding = $utf8NoBom } catch {}
    try { [Console]::OutputEncoding = $utf8NoBom } catch {}
    $script:OutputEncoding = $utf8NoBom
}

function Read-HookInput {
    try {
        $raw = [Console]::In.ReadToEnd()
        if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
        $raw = $raw.TrimStart([char]0xFEFF)
        return $raw | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Get-PonytailHideStatus {
    if ($null -ne $env:PONYTAIL_HIDE_STATUS) {
        $v = $env:PONYTAIL_HIDE_STATUS.Trim().ToLowerInvariant()
        return ($v -ne '' -and $v -ne '0' -and $v -ne 'false' -and $v -ne 'no')
    }
    $configPath = Get-PonytailConfigPath
    if (Test-Path -LiteralPath $configPath) {
        try {
            $raw = [System.IO.File]::ReadAllText($configPath, [System.Text.Encoding]::UTF8).TrimStart([char]0xFEFF)
            $cfg = $raw | ConvertFrom-Json
            return ($cfg.hideStatus -eq $true)
        } catch {}
    }
    return $false
}

function Format-PonytailBadge {
    param(
        [string]$Mode,
        [string]$Extra = ''
    )
    if (Get-PonytailHideStatus) { return '' }
    $m = if ([string]::IsNullOrWhiteSpace($Mode)) { 'full' } else { $Mode.Trim().ToLowerInvariant() }
    $label = switch ($m) {
        'ultra' { '⚡ `[PONYTAIL:ULTRA]`' }
        'lite'  { '`[PONYTAIL:LITE]`' }
        'off'   { '`[PONYTAIL:OFF]`' }
        default { '`[PONYTAIL:FULL]`' }
    }
    if (-not [string]::IsNullOrWhiteSpace($Extra)) {
        return "$label — $Extra"
    }
    return $label
}

function Write-InjectSystemMessage {
    param(
        [string]$Text,
        [string]$UserMarkdown = ''
    )
    $sysMsg = @{
        systemMessage = $Text
    }
    if (-not [string]::IsNullOrWhiteSpace($UserMarkdown)) {
        $sysMsg['metadata'] = @{
            user_markdown = $UserMarkdown
        }
    }
    $payload = @{
        injectSteps = @(
            @{
                systemMessage = $sysMsg
            }
        )
    }
    Write-Output ($payload | ConvertTo-Json -Depth 6 -Compress)
}

function Write-EmptyHookOutput {
    Write-Output '{}'
}

function Normalize-PonytailMode {
    param([string]$Mode)
    if ([string]::IsNullOrWhiteSpace($Mode)) { return $null }
    $norm = $Mode.Trim().ToLowerInvariant()
    if ($script:ValidModes -contains $norm) { return $norm }
    return $null
}

function Test-DeactivationCommand {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
    $t = ($Text.Trim().ToLowerInvariant() -replace '[.!?\s]+$', '')
    return ($t -eq 'stop ponytail' -or $t -eq 'normal mode')
}

function Get-PonytailConfigDir {
    if (-not [string]::IsNullOrWhiteSpace($env:XDG_CONFIG_HOME)) {
        return Join-Path $env:XDG_CONFIG_HOME 'ponytail'
    }
    $appData = if (-not [string]::IsNullOrWhiteSpace($env:APPDATA)) {
        $env:APPDATA
    } else {
        Join-Path $HOME 'AppData\Roaming'
    }
    return Join-Path $appData 'ponytail'
}

function Get-PonytailConfigPath {
    return Join-Path (Get-PonytailConfigDir) 'config.json'
}

function Get-PonytailBandDir {
    $dir = Join-Path (Get-PonytailConfigDir) 'band'
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    return $dir
}

function Get-PonytailDefaultMode {
    $envMode = Normalize-PonytailMode $env:PONYTAIL_DEFAULT_MODE
    if ($envMode) { return $envMode }

    $configPath = Get-PonytailConfigPath
    if (Test-Path -LiteralPath $configPath) {
        try {
            $raw = [System.IO.File]::ReadAllText($configPath, [System.Text.Encoding]::UTF8).TrimStart([char]0xFEFF)
            $cfg = $raw | ConvertFrom-Json
            $cfgMode = Normalize-PonytailMode $cfg.defaultMode
            if ($cfgMode) { return $cfgMode }
        } catch {}
    }

    return 'full'
}

function Set-PonytailDefaultMode {
    param([string]$Mode)
    $norm = Normalize-PonytailMode $Mode
    if (-not $norm) { return $null }

    $configDir = Get-PonytailConfigDir
    if (-not (Test-Path -LiteralPath $configDir)) {
        New-Item -ItemType Directory -Force -Path $configDir | Out-Null
    }
    $configPath = Get-PonytailConfigPath
    $cfg = @{}
    if (Test-Path -LiteralPath $configPath) {
        try {
            $raw = [System.IO.File]::ReadAllText($configPath, [System.Text.Encoding]::UTF8).TrimStart([char]0xFEFF)
            $parsed = $raw | ConvertFrom-Json
            if ($parsed -is [PSCustomObject]) {
                foreach ($prop in $parsed.PSObject.Properties) {
                    $cfg[$prop.Name] = $prop.Value
                }
            }
        } catch {}
    }
    $cfg['defaultMode'] = $norm
    $json = $cfg | ConvertTo-Json -Depth 4
    [System.IO.File]::WriteAllText($configPath, $json, (New-Object System.Text.UTF8Encoding($false)))
    return $norm
}

function Get-PonytailProjectName {
    param($HookData)
    $candidate = ''
    if ($HookData) {
        if ($HookData.workspacePaths -and $HookData.workspacePaths.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($HookData.workspacePaths[0])) {
            $candidate = [string]$HookData.workspacePaths[0]
        } elseif (-not [string]::IsNullOrWhiteSpace($HookData.cwd)) {
            $candidate = [string]$HookData.cwd
        }
    }
    if ([string]::IsNullOrWhiteSpace($candidate)) { return 'general' }
    $trimmed = $candidate.TrimEnd('\', '/')
    $leaf = Split-Path -Leaf $trimmed
    if ([string]::IsNullOrWhiteSpace($leaf)) { return 'general' }
    return $leaf
}

function Get-PonytailSessionPath {
    param([string]$ConversationId)
    $sessionsDir = Join-Path (Get-PonytailConfigDir) 'sessions'
    if (-not (Test-Path -LiteralPath $sessionsDir)) {
        New-Item -ItemType Directory -Force -Path $sessionsDir | Out-Null
    }
    $safeId = if ([string]::IsNullOrWhiteSpace($ConversationId)) {
        'default'
    } else {
        ($ConversationId -replace '[^A-Za-z0-9._-]', '_')
    }
    return Join-Path $sessionsDir "$safeId.json"
}

function Get-PonytailSessionState {
    param([string]$ConversationId)
    $path = Get-PonytailSessionPath $ConversationId
    if (Test-Path -LiteralPath $path) {
        try {
            $raw = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8).TrimStart([char]0xFEFF)
            $obj = $raw | ConvertFrom-Json
            $ht = @{}
            foreach ($prop in $obj.PSObject.Properties) {
                $ht[$prop.Name] = $prop.Value
            }
            return $ht
        } catch {}
    }
    return @{}
}

function Save-PonytailSessionState {
    param(
        [string]$ConversationId,
        [hashtable]$State
    )
    try {
        $path = Get-PonytailSessionPath $ConversationId
        $json = $State | ConvertTo-Json -Compress
        [System.IO.File]::WriteAllText($path, $json, (New-Object System.Text.UTF8Encoding($false)))
    } catch {}
}

function Get-PonytailInstructions {
    param(
        [string]$Mode,
        [string]$PluginRoot
    )
    $effectiveMode = Normalize-PonytailMode $Mode
    if (-not $effectiveMode -or $effectiveMode -eq 'off') { $effectiveMode = 'full' }

    $skillPath = Join-Path $PluginRoot 'skills\ponytail\SKILL.md'
    $body = ''
    if (Test-Path -LiteralPath $skillPath) {
        try {
            $raw = [System.IO.File]::ReadAllText($skillPath, [System.Text.Encoding]::UTF8)
            $withoutFm = [regex]::Replace($raw, '(?s)^---.*?---\s*', '')
            $lines = $withoutFm -split "\r?\n"
            $filtered = foreach ($line in $lines) {
                if ($line -match '^\|\s*\*\*(.+?)\*\*\s*\|') {
                    $labelMode = Normalize-PonytailMode $Matches[1]
                    if ($labelMode) {
                        if ($labelMode -eq $effectiveMode) { $line }
                        continue
                    }
                }
                if ($line -match '^-\s*([^:]+):\s*"') {
                    $exMode = Normalize-PonytailMode $Matches[1]
                    if ($exMode) {
                        if ($exMode -eq $effectiveMode) { $line }
                        continue
                    }
                }
                $line
            }
            $body = ($filtered -join "`n").Trim()
        } catch {}
    }

    if ([string]::IsNullOrWhiteSpace($body)) {
        $body = "You are a lazy senior developer. The best code is the code never written. Solve the whole problem with the least new code. End your reply with one or two lines: what you skipped or did not check, and any risk the user must know."
    }

    return "PONYTAIL MODE ACTIVE - level: $effectiveMode`n`n$body"
}
