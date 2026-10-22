param(
    [string]$Godot='C:/Users/jh030/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe',
    [string]$ProjectRootOverride='',
    [switch]$Window,
    [switch]$IncludeLegacy
)
$ErrorActionPreference='Stop'
$projectRoot=if($ProjectRootOverride){$ProjectRootOverride}else{Split-Path -Parent $PSScriptRoot}
$artifactRoot=Join-Path $projectRoot '.task002_artifacts/phase4_m1'
New-Item -ItemType Directory -Force $artifactRoot | Out-Null
if($IncludeLegacy){
    $legacy=Join-Path $projectRoot 'tests/run_phase3a_regression.ps1'
    & ([scriptblock]::Create([IO.File]::ReadAllText($legacy))) -Godot $Godot -ProjectRootOverride $projectRoot -Window:$Window
}
$cases=if($Window){@('preview_phase4_m1','preview_phase4_movement','preview_phase4_ux','preview_world_phase2','preview_world_phase3','preview_world_phase4')}else{@('test_phase4_movement','test_phase4_m1','test_phase4_ux','test_phase4_profiles','test_world_visual')}
if(-not $Window -and (Test-Path -LiteralPath (Join-Path $artifactRoot 'user_save_resume.json'))){$cases+='test_phase4_compat'}
$results=@()
foreach($case in $cases){
    $log=Join-Path $artifactRoot ($case+'.log')
    $arguments=@('--path',$projectRoot,'--script',"tests/$case.gd",'--log-file',$log)
    if(-not $Window){$arguments=@('--headless')+$arguments}
    if($case -eq 'preview_world_phase4'){$arguments+=@('--','--normal-only')}
    & $Godot @arguments | Out-Null
    if($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR|ERROR:|FAIL:' -Quiet)){throw "Failed $case; see $log"}
    $summary=[string](Get-Content -Encoding UTF8 -LiteralPath $log | Select-Object -Last 1)
    $count=if($summary -match '(\d+) checks, 0 failures'){[int]$Matches[1]}else{0}
    $results+=[ordered]@{case=$case;checks=$count;summary=$summary;log=$log}
    Write-Output "$case : $summary"
}
$total=0
foreach($result in $results){$total+=$result['checks']}
$manifest=[ordered]@{mode=if($Window){'rendered_synthetic_input'}else{'headless_automatic'};engine='Godot 4.7.2';checks=$total;results=$results}
$name=if($Window){'window_results.json'}else{'automatic_results.json'}
[IO.File]::WriteAllText((Join-Path $artifactRoot $name),($manifest | ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
