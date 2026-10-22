param(
 [string]$Godot='C:/Users/jh030/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe',
 [string]$ProjectRootOverride='', [switch]$Window, [switch]$IncludeExisting
)
$ErrorActionPreference='Stop'
$projectRoot=if($ProjectRootOverride){$ProjectRootOverride}else{Split-Path -Parent $PSScriptRoot}
$artifactRoot=Join-Path $projectRoot '.task002_artifacts/phase4_qa_v2'
if(-not (Test-Path -LiteralPath (Join-Path $artifactRoot 'user_before.json'))){throw 'Prepare an explicit isolated user_before.json fixture first. This runner never reads or replaces the actual player save.'}
if($IncludeExisting){
 $runner=Join-Path $projectRoot 'tests/run_phase4_integrated.ps1'
 & ([scriptblock]::Create([IO.File]::ReadAllText($runner))) -Godot $Godot -ProjectRootOverride $projectRoot -Window:$Window -IncludeExisting
 if(-not $?){throw 'Existing regression failed'}
}
$cases=if($Window){@('test_phase4_qa0','preview_phase4_qa_v2','preview_phase4_qa_journal')}else{@('test_phase4_qa0','test_phase4_qa_ux','test_chant_v2','test_phase4_qa_combat','test_phase4_qa_safety')}
$results=@();$total=0
foreach($case in $cases){
 $log=Join-Path $artifactRoot ($case+$(if($Window){'_window'}else{''})+'.log')
 $arguments=@('--path',$projectRoot,'--script',"tests/$case.gd",'--log-file',$log)
 if(-not $Window){$arguments=@('--headless')+$arguments}
 & $Godot @arguments | Out-Null
 if($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR|ERROR:|FAIL:' -Quiet)){throw "Failed $case; see $log"}
 $summary=[string](Get-Content -Encoding UTF8 -LiteralPath $log | Where-Object {$_ -match '\S'} | Select-Object -Last 1)
 $count=0;if($summary -match '(\d+) checks, 0 failures'){$count=[int]$Matches[1]}
 $total+=$count;$results+=[ordered]@{case=$case;checks=$count;summary=$summary;log=$log}
 Write-Output $summary
}
$manifest=[ordered]@{mode=if($Window){'rendered_synthetic_or_scene_driven'}else{'headless_automatic'};checks=$total;results=$results}
$filename=if($Window){'window_results.json'}else{'automatic_results.json'}
[IO.File]::WriteAllText((Join-Path $artifactRoot $filename),($manifest|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
