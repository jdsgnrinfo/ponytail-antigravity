# Ponytail SessionStart hook for Antigravity
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'ponytail-common.ps1')
Initialize-Utf8Console

try {
    $data = Read-HookInput
    $conversationId = if ($data -and $data.conversationId) { [string]$data.conversationId } else { '' }
    $mode = Get-PonytailDefaultMode
    $project = Get-PonytailProjectName $data
    $model = if ($data -and $data.modelName) { [string]$data.modelName } else { 'auto' }

    $state = @{
        mode        = $mode
        activated   = $true
        lastTurnKey = ''
        startedAt   = [DateTime]::UtcNow.ToString('o')
        project     = $project
        model       = $model
        taskName    = ''
        turns       = 0
        testsRun    = 0
        testsFailed = 0
    }
    Save-PonytailSessionState -ConversationId $conversationId -State $state

    if ($mode -eq 'off') {
        Write-EmptyHookOutput
        exit 0
    }

    $pluginRoot = Split-Path -Parent $PSScriptRoot
    $instructions = Get-PonytailInstructions -Mode $mode -PluginRoot $pluginRoot
    $badge = Format-PonytailBadge -Mode $mode
    Write-InjectSystemMessage -Text $instructions -UserMarkdown $badge
} catch {
    Write-EmptyHookOutput
}
exit 0
