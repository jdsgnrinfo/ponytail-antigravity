# Ponytail PreInvocation hook for Antigravity
# Tracks /ponytail commands, level switches, defaults, deactivation phrases,
# and captures the first user task description for the Band board.
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'ponytail-common.ps1')
Initialize-Utf8Console

try {
    $data = Read-HookInput
    if (-not $data) {
        Write-EmptyHookOutput
        exit 0
    }

    $conversationId = if ($data.conversationId) { [string]$data.conversationId } else { '' }
    $promptRaw = if ($data.lastUserInput) { [string]$data.lastUserInput } else { '' }
    $prompt = $promptRaw.Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($prompt)) {
        Write-EmptyHookOutput
        exit 0
    }

    $stepMarker = if ($null -ne $data.initialNumSteps) { [string]$data.initialNumSteps } else { '' }
    $turnKey = "$stepMarker|$prompt"
    $state = Get-PonytailSessionState -ConversationId $conversationId

    # Ensure baseline fields exist if SessionStart did not run (e.g. plugin enabled mid-session)
    if (-not $state.ContainsKey('startedAt') -or [string]::IsNullOrWhiteSpace($state['startedAt'])) {
        $state['startedAt'] = [DateTime]::UtcNow.ToString('o')
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

    # Deduplicate across multiple model invocations within the same user turn.
    if ($state['lastTurnKey'] -eq $turnKey) {
        Write-EmptyHookOutput
        exit 0
    }

    $currentMode = if ($state.ContainsKey('mode') -and -not [string]::IsNullOrWhiteSpace($state['mode'])) {
        [string]$state['mode']
    } else {
        Get-PonytailDefaultMode
    }
    $state['mode'] = $currentMode
    $pluginRoot = Split-Path -Parent $PSScriptRoot

    # Match /ponytail, @ponytail, $ponytail commands
    if ($prompt -match '^[/@$]ponytail(\s|$)') {
        $parts = $prompt -split '\s+'
        $cmd = $parts[0] -replace '^[@$]', '/'
        $arg = if ($parts.Length -ge 2) { $parts[1] } else { '' }

        if ($cmd -eq '/ponytail' -or $cmd -eq '/ponytail:ponytail') {
            if ($arg -eq 'default') {
                $dmode = if ($parts.Length -ge 3) { Normalize-PonytailMode $parts[2] } else { $null }
                if ($dmode) {
                    Set-PonytailDefaultMode -Mode $dmode | Out-Null
                    $state['lastTurnKey'] = $turnKey
                    Save-PonytailSessionState -ConversationId $conversationId -State $state
                    $badge = Format-PonytailBadge -Mode $dmode -Extra "default for new sessions"
                    Write-InjectSystemMessage -Text "PONYTAIL DEFAULT SET - new sessions start in $dmode." -UserMarkdown $badge
                    exit 0
                }
            }

            $targetMode = $null
            $isReportOnly = $false

            if ($arg -eq 'lite' -or $arg -eq 'full' -or $arg -eq 'ultra' -or $arg -eq 'off') {
                $targetMode = $arg
            } elseif ($arg -eq '') {
                if ($currentMode -and $currentMode -ne 'off') {
                    $isReportOnly = $true
                    $targetMode = $currentMode
                } else {
                    $def = Get-PonytailDefaultMode
                    $targetMode = if ($def -eq 'off') { 'full' } else { $def }
                }
            }

            if ($isReportOnly) {
                $state['mode'] = $targetMode
                $state['activated'] = $true
                $state['lastTurnKey'] = $turnKey
                Save-PonytailSessionState -ConversationId $conversationId -State $state
                $badge = Format-PonytailBadge -Mode $targetMode
                Write-InjectSystemMessage -Text "PONYTAIL MODE ACTIVE - level: $targetMode" -UserMarkdown $badge
                exit 0
            } elseif ($targetMode -and $targetMode -ne 'off') {
                $state['mode'] = $targetMode
                $state['activated'] = $true
                $state['lastTurnKey'] = $turnKey
                Save-PonytailSessionState -ConversationId $conversationId -State $state
                $instructions = Get-PonytailInstructions -Mode $targetMode -PluginRoot $pluginRoot
                $badge = Format-PonytailBadge -Mode $targetMode
                Write-InjectSystemMessage -Text "PONYTAIL MODE CHANGED - level: $targetMode`n`n$instructions" -UserMarkdown $badge
                exit 0
            } elseif ($targetMode -eq 'off') {
                $state['mode'] = 'off'
                $state['activated'] = $true
                $state['lastTurnKey'] = $turnKey
                Save-PonytailSessionState -ConversationId $conversationId -State $state
                $badge = Format-PonytailBadge -Mode 'off'
                Write-InjectSystemMessage -Text "PONYTAIL MODE OFF - resume normal mode without ponytail constraints." -UserMarkdown $badge
                exit 0
            }
        }
    }

    # Match standalone deactivation phrases ("stop ponytail", "normal mode")
    if (Test-DeactivationCommand $prompt) {
        $state['mode'] = 'off'
        $state['activated'] = $true
        $state['lastTurnKey'] = $turnKey
        Save-PonytailSessionState -ConversationId $conversationId -State $state
        $badge = Format-PonytailBadge -Mode 'off'
        Write-InjectSystemMessage -Text "PONYTAIL MODE OFF - resume normal mode without ponytail constraints." -UserMarkdown $badge
        exit 0
    }

    # Record first non-command user prompt as the session's task name for the Band board
    if ((-not $state.ContainsKey('taskName') -or [string]::IsNullOrWhiteSpace($state['taskName'])) -and -not ($prompt -match '^[/@$]ponytail')) {
        $cleanTask = ($promptRaw -replace '[\r\n\t]+', ' ').Trim()
        if ($cleanTask.Length -gt 80) { $cleanTask = $cleanTask.Substring(0, 77) + '...' }
        $state['taskName'] = $cleanTask
    }

    # Fallback activation on first PreInvocation if SessionStart did not fire
    if (-not ($state.ContainsKey('activated') -and $state['activated'] -eq $true)) {
        $state['activated'] = $true
        $state['lastTurnKey'] = $turnKey
        Save-PonytailSessionState -ConversationId $conversationId -State $state
        if ($currentMode -ne 'off') {
            $instructions = Get-PonytailInstructions -Mode $currentMode -PluginRoot $pluginRoot
            $badge = Format-PonytailBadge -Mode $currentMode
            Write-InjectSystemMessage -Text $instructions -UserMarkdown $badge
            exit 0
        }
        Write-EmptyHookOutput
        exit 0
    }

    $state['lastTurnKey'] = $turnKey
    Save-PonytailSessionState -ConversationId $conversationId -State $state
    Write-EmptyHookOutput
} catch {
    Write-EmptyHookOutput
}
exit 0
