param(
 [string]$Godot='C:/Users/jh030/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe',
 [string]$ProjectRootOverride='', [switch]$Window, [switch]$IncludeExisting
)
$ErrorActionPreference='Stop'
$projectRoot=if($ProjectRootOverride){$ProjectRootOverride}else{Split-Path -Parent $PSScriptRoot}
$artifactRoot=Join-Path $projectRoot '.task002_artifacts/phase4_integrated'
New-Item -ItemType Directory -Force $artifactRoot | Out-Null
if($IncludeExisting){
 $runner=Join-Path $projectRoot 'tests/run_mana_overdraw.ps1'
 & ([scriptblock]::Create([IO.File]::ReadAllText($runner))) -Godot $Godot -ProjectRootOverride $projectRoot -Window:$Window -IncludeExisting
}
$case=if($Window){'preview_phase4_integrated'}else{'test_phase4_integrated'}
if($Window -and -not (Test-Path -LiteralPath (Join-Path $artifactRoot 'user_before.json'))){throw 'Rendered current-user compatibility requires an explicitly supplied isolated user_before.json fixture. No actual user save is read by this runner.'}
$log=Join-Path $artifactRoot ($case+'.log')
$arguments=@('--path',$projectRoot,'--script',"tests/$case.gd",'--log-file',$log)
if(-not $Window){$arguments=@('--headless')+$arguments}
& $Godot @arguments | Out-Null
if($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR|ERROR:|FAIL:' -Quiet)){throw "Failed $case; see $log"}
$summary=[string](Get-Content -LiteralPath $log -Encoding UTF8 | Select-Object -Last 1)
$count=0;if($summary -match '(\d+) checks, 0 failures'){$count=[int]$Matches[1]}
$result=[ordered]@{mode=if($Window){'rendered_synthetic_input'}else{'headless_automatic'};checks=$count;summary=$summary;log=$log}
$filename=if($Window){'window_results.json'}else{'automatic_results.json'}
[IO.File]::WriteAllText((Join-Path $artifactRoot $filename),($result|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
Write-Output $summary
