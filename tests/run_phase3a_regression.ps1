param(
    [string]$Godot = 'C:/Users/jh030/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe',
    [string]$ProjectRootOverride = '',
    [string]$StartAt = '',
    [switch]$Window
)
$ErrorActionPreference = 'Stop'
$projectRoot = if ($ProjectRootOverride) { $ProjectRootOverride } else { Split-Path -Parent $PSScriptRoot }
$artifactRoot = Join-Path $projectRoot '.task002_artifacts/phase3a'
New-Item -ItemType Directory -Force $artifactRoot | Out-Null
$cases = if ($Window) {
    @('preview_ux1','preview_fusion','preview_auxiliary','preview_laboratory','preview_mana_visuals','preview_awakening','preview_elemental_combat','preview_research','preview_phase2b25b','preview_combat','preview_fusion_ux2')
} else {
    @('test_combat','test_research','test_chant','test_awakening','test_elemental_combat','test_mana_visuals','test_phase2b25b','test_ux1','test_fusion_a','test_fusion_a_restart','test_fusion_b','test_fusion_c','test_fusion_d','test_fusion_persistence','test_fusion_persistence:restart','test_research:restart','test_chant:restart','test_awakening:restart','test_ux1_restart','test_discoveries_restart','test_fusion_ux2','test_world_phase1','test_world_phase2','test_world_phase3','test_world_phase4')
}
foreach ($case in $cases) {
    if ($StartAt -and $case -ne $StartAt) { continue }
    $StartAt = ''
    $parts = $case.Split(':')
    $name = $parts[0]
    $log = Join-Path $artifactRoot ('final_' + $case.Replace(':','_') + '.log')
    $arguments = @('--path',$projectRoot,'--script',"tests/$name.gd",'--log-file',$log)
    if (-not $Window) { $arguments = @('--headless') + $arguments }
    if ($name -eq 'test_fusion_d') { $arguments += @('--','--expect=3') }
    if ($parts.Count -gt 1) { $arguments += @('--','--verify-restart') }
    if ($name -eq 'test_ux1_restart') { $arguments += @('--','--dev-lab','--legacy-wasd') }
    & $Godot @arguments | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Godot $case failed with exit $LASTEXITCODE. See $log" }
    if (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR|ERROR:|FAIL:' -Quiet) { throw "Godot $case has errors. See $log" }
    $summary = Get-Content -Encoding UTF8 -LiteralPath $log | Select-Object -Last 1
    Write-Output "$case : $summary"
}
