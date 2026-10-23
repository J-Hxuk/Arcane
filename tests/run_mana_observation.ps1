param(
 [string]$Godot='C:/Users/jh030/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe',
 [switch]$Window
)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$artifact=Join-Path $projectRoot '.task002_artifacts/mana_observation'
foreach($folder in @('mana_observation','current_world_options','water15_integration','mana_visuals')){
 New-Item -ItemType Directory -Force (Join-Path $projectRoot ".task002_artifacts/$folder")|Out-Null
}
$cases=if($Window){@('test_mana_observation_ui','test_magic_foundation_ui','test_water15_window_input')}else{@(
 'test_mana_observation','test_mana_observation_ui','test_mana_visuals',
 'test_magic_foundation','test_magic_foundation_ui',
 'test_chant_v2','test_combat','test_fusion_ux2','test_mana_overdraw','test_mana_overdraw_catalog',
 'test_water15_integration','test_water15_physics','test_water15_persistence','test_formula_followup_balance',
 'test_attributes_model','test_attributes_interpreter','test_attributes_world','test_attributes_research','test_attributes_restart',
 'test_current_developer','test_lab_equipment'
)}
$results=@()
foreach($case in $cases){
 $mode=if($Window){'window'}else{'headless'}
 $log=Join-Path $artifact "$($case)_$mode.log"
 $info=[Diagnostics.ProcessStartInfo]::new();$info.FileName=$Godot
 $info.Arguments="$(if(-not $Window){'--headless '})--path `"$projectRoot`" --script tests/$case.gd --log-file `"$log`""
 $info.UseShellExecute=$false;$info.CreateNoWindow=$true
 $process=[Diagnostics.Process]::Start($info)
 $completed=$process.WaitForExit(180000)
 if(-not $completed){Stop-Process -Id $process.Id -ErrorAction SilentlyContinue;$process.WaitForExit()}
 $body=if(Test-Path -LiteralPath $log){Get-Content -LiteralPath $log -Raw -Encoding UTF8}else{''}
 $matchesSummary=[regex]::Matches($body,'(\d+) checks, (\d+) failures')
 $count=0;$failures=0
 if($matchesSummary.Count){$summary=$matchesSummary[$matchesSummary.Count-1];$count=[int]$summary.Groups[1].Value;$failures=[int]$summary.Groups[2].Value}
 $passed=$completed -and $process.ExitCode -eq 0 -and $body -notmatch 'SCRIPT ERROR|ERROR:|FAIL:' -and $count -gt 0 -and $failures -eq 0
 $results+=[ordered]@{case=$case;mode=$mode;checks=$count;failures=$failures;passed=$passed;exit=$process.ExitCode;completed=$completed;log=$log}
 Write-Output "$case : $count checks / $failures failures / passed=$passed"
 if(-not $passed){Write-Output ($body -split "`r?`n" | Select-Object -Last 18)}
}
[IO.File]::WriteAllText((Join-Path $artifact "${mode}_results.json"),($results|ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
if(@($results|Where-Object {-not $_.passed}).Count){throw 'Mana observation regression failed. Inspect logs.'}
