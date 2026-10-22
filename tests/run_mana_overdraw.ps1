param(
    [string]$Godot='C:/Users/jh030/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe',
    [string]$ProjectRootOverride='',
    [switch]$Window,
    [switch]$IncludeExisting
)
$ErrorActionPreference='Stop'
$projectRoot=if($ProjectRootOverride){$ProjectRootOverride}else{Split-Path -Parent $PSScriptRoot}
$artifactRoot=Join-Path $projectRoot '.task002_artifacts/mana_overdraw'
New-Item -ItemType Directory -Force $artifactRoot | Out-Null
if($IncludeExisting){
    $runner=Join-Path $projectRoot 'tests/run_phase4_regression.ps1'
    & ([scriptblock]::Create([IO.File]::ReadAllText($runner))) -Godot $Godot -ProjectRootOverride $projectRoot -Window:$Window -IncludeLegacy
}
$cases=if($Window){@('preview_mana_overdraw')}else{@('test_mana_overdraw','test_mana_overdraw_catalog')}
$results=@();$total=0
foreach($case in $cases){
    $log=Join-Path $artifactRoot ($case+'.log')
    $arguments=@('--path',$projectRoot,'--script',"tests/$case.gd",'--log-file',$log)
    if(-not $Window){$arguments=@('--headless')+$arguments}
    & $Godot @arguments | Out-Null
    if($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR|ERROR:|FAIL:' -Quiet)){throw "Failed $case; see $log"}
    $summary=[string](Get-Content -Encoding UTF8 -LiteralPath $log | Select-Object -Last 1)
    $count=if($summary -match '(\d+) checks, 0 failures'){[int]$Matches[1]}else{0}
    $total+=$count;$results+=[ordered]@{case=$case;checks=$count;summary=$summary;log=$log}
    Write-Output "$case : $summary"
}
$manifest=[ordered]@{mode=if($Window){'rendered_synthetic_input'}else{'headless_automatic'};engine='Godot 4.7.2';checks=$total;results=$results}
$name=if($Window){'window_results.json'}else{'automatic_results.json'}
[IO.File]::WriteAllText((Join-Path $artifactRoot $name),($manifest | ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
