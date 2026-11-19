# Ponytail Band tracker hook for Antigravity (PostToolUse + Stop)
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'ponytail-common.ps1')
. (Join-Path $PSScriptRoot 'ponytail-band-board.ps1')
Initialize-Utf8Console

function ConvertTo-CsvField {
    param([string]$Value)
    $s = if ($null -eq $Value) { '' } else { [string]$Value }
    $s = $s -replace '[\r\n]+', ' '
    if ($s.Contains(',') -or $s.Contains('"')) {
        return '"' + ($s -replace '"', '""') + '"'
    }
    return $s
}

function Upsert-PonytailBandCsv {
    param([hashtable]$Row)
    $bandDir = Get-PonytailBandDir
    $csvPath = Join-Path $bandDir 'tasks.csv'
    $header = 'key,started,project,name,level,model,turns,elapsed_sec,tests'

    $existing = @()
    if (Test-Path -LiteralPath $csvPath) {
        try {
            $imported = Import-Csv -LiteralPath $csvPath -Encoding UTF8
            if ($imported) { $existing = @($imported) }
        } catch {}
    }

    $updated = New-Object System.Collections.ArrayList
    $found = $false
    foreach ($item in $existing) {
        if ($item.key -eq $Row['key']) {
            [void]$updated.Add([PSCustomObject]$Row)
            $found = $true
        } else {
            [void]$updated.Add($item)
        }
    }
    if (-not $found) {
        [void]$updated.Add([PSCustomObject]$Row)
    }

    $lines = New-Object System.Collections.ArrayList
    [void]$lines.Add($header)
    foreach ($r in $updated) {
        $line = @(
            (ConvertTo-CsvField $r.key),
            (ConvertTo-CsvField $r.started),
            (ConvertTo-CsvField $r.project),
            (ConvertTo-CsvField $r.name),
            (ConvertTo-CsvField $r.level),
            (ConvertTo-CsvField $r.model),
            (ConvertTo-CsvField $r.turns),
            (ConvertTo-CsvField $r.elapsed_sec),
            (ConvertTo-CsvField $r.tests)
        ) -join ','
        [void]$lines.Add($line)
    }

    [System.IO.File]::WriteAllText($csvPath, ($lines -join "`n") + "`n", (New-Object System.Text.UTF8Encoding($false)))
}

try {
    $data = Read-HookInput
    if (-not $data) {
        Write-EmptyHookOutput
        exit 0
    }

    $eventName = if ($data.hookEventName) { [string]$data.hookEventName } else { '' }
    $conversationId = if ($data.conversationId) { [string]$data.conversationId } else { 'default' }
    $state = Get-PonytailSessionState -ConversationId $conversationId

    if (-not $state.ContainsKey('startedAt') -or [string]::IsNullOrWhiteSpace($state['startedAt'])) {
        $state['startedAt'] = [DateTime]::UtcNow.ToString('o')
    }
    if (-not $state.ContainsKey('mode') -or [string]::IsNullOrWhiteSpace($state['mode'])) {
        $state['mode'] = Get-PonytailDefaultMode
    }
    if (-not $state.ContainsKey('project') -or [string]::IsNullOrWhiteSpace($state['project'])) {
        $state['project'] = Get-PonytailProjectName $data
    }
    if (-not $state.ContainsKey('model') -or [string]::IsNullOrWhiteSpace($state['model'])) {
        $state['model'] = if ($data.modelName) { [string]$data.modelName } else { 'auto' }
    } elseif ($data.modelName) {
        $state['model'] = [string]$data.modelName
    }
    if (-not $state.ContainsKey('turns')) { $state['turns'] = 0 }
    if (-not $state.ContainsKey('testsRun')) { $state['testsRun'] = 0 }
    if (-not $state.ContainsKey('testsFailed')) { $state['testsFailed'] = 0 }

    if ($eventName -eq 'PostToolUse') {
        $cmdLine = ''
        if ($data.toolCall -and $data.toolCall.args -and $data.toolCall.args.CommandLine) {
            $cmdLine = [string]$data.toolCall.args.CommandLine
        }
        if ($cmdLine -match '(?i)(^|\s)(pytest|vitest|jest|mocha|phpunit|rspec|ctest|unittest)(\s|$)|(?i)\b(npm|pnpm|yarn|bun|cargo|go|dotnet|mvn|gradle|mix|deno)\s+test\b|(?i)\bnode\s+--test\b') {
            $state['testsRun'] = [int]$state['testsRun'] + 1
            if (-not [string]::IsNullOrWhiteSpace($data.error)) {
                $state['testsFailed'] = [int]$state['testsFailed'] + 1
            }
            Save-PonytailSessionState -ConversationId $conversationId -State $state
        }
        Write-EmptyHookOutput
        exit 0
    }

    if ($eventName -eq 'Stop') {
        $state['turns'] = [int]$state['turns'] + 1
        if ((-not $state.ContainsKey('taskName') -or [string]::IsNullOrWhiteSpace($state['taskName'])) -and -not [string]::IsNullOrWhiteSpace($data.lastUserInput)) {
            $cleanTask = ([string]$data.lastUserInput -replace '[\r\n\t]+', ' ').Trim()
            if ($cleanTask.Length -gt 80) { $cleanTask = $cleanTask.Substring(0, 77) + '...' }
            $state['taskName'] = $cleanTask
        }
        Save-PonytailSessionState -ConversationId $conversationId -State $state

        $elapsedSec = 0
        try {
            $startDt = [DateTime]::Parse($state['startedAt']).ToUniversalTime()
            $elapsedSec = [int][Math]::Max(0, ([DateTime]::UtcNow - $startDt).TotalSeconds)
        } catch {}

        $testsStatus = 'none'
        if ([int]$state['testsRun'] -gt 0) {
            $testsStatus = if ([int]$state['testsFailed'] -gt 0) { 'fail' } else { 'pass' }
        }

        $row = @{
            key         = $conversationId
            started     = [string]$state['startedAt']
            project     = [string]$state['project']
            name        = if ([string]::IsNullOrWhiteSpace($state['taskName'])) { '(session)' } else { [string]$state['taskName'] }
            level       = [string]$state['mode']
            model       = [string]$state['model']
            turns       = [int]$state['turns']
            elapsed_sec = $elapsedSec
            tests       = $testsStatus
        }
        Upsert-PonytailBandCsv -Row $row
        Build-PonytailBandBoard | Out-Null

        Write-Output '{"decision":"allow"}'
        exit 0
    }

    Write-EmptyHookOutput
} catch {
    Write-EmptyHookOutput
}
exit 0
