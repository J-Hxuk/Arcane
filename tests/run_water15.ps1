param([string]$ProjectRootOverride='', [switch]$Window, [switch]$Performance)
$ErrorActionPreference='Stop'
$projectRoot=if($ProjectRootOverride){$ProjectRootOverride}else{Split-Path -Parent $PSScriptRoot}
$godot='C:/Users/jh030/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe'
$artifact=Join-Path $projectRoot '.task002_artifacts/water15_integration'
New-Item -ItemType Directory -Force $artifact|Out-Null
$cases=if($Performance){@('test_water15_performance')}elseif($Window){@('test_water15_integration','test_water15_physics','test_water15_window_input','test_formula_followup_ui','test_formula_followup_fusion')}else{@('test_water15_integration','test_water15_physics','test_water15_persistence','test_formula_followup_balance')}
$results=@()
foreach($case in $cases){
 $mode=if($Window -or $Performance){'window'}else{'auto'};$log=Join-Path $artifact "$($case)_$mode.log"
 $info=[Diagnostics.ProcessStartInfo]::new();$info.FileName=$godot
 $info.Arguments="$(if($mode -eq 'auto'){'--headless '})--path `"$projectRoot`" --script tests/$case.gd --log-file `"$log`""
 $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$process=[Diagnostics.Process]::Start($info)
 $completed=$process.WaitForExit(170000)
 if(-not $completed){Stop-Process -Id $process.Id -ErrorAction SilentlyContinue;$process.WaitForExit()}
 $stream=[IO.File]::Open($log,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite);$reader=[IO.StreamReader]::new($stream);$body=$reader.ReadToEnd();$reader.Dispose()
 $m=[regex]::Matches($body,'(\d+) checks, (\d+) failures');$count=0;$failures=0
 if($m.Count){$last=$m[$m.Count-1];$count=[int]$last.Groups[1].Value;$failures=[int]$last.Groups[2].Value}
 $passed=$completed -and $process.ExitCode -eq 0 -and $body -notmatch 'SCRIPT ERROR|ERROR:|FAIL:' -and $count -gt 0 -and $failures -eq 0
 $results+=[ordered]@{case=$case;mode=$mode;checks=$count;failures=$failures;passed=$passed;exit=$process.ExitCode;log=$log}
 Write-Output "$case : $count checks / $failures failures / passed=$passed"
}
$name=if($Performance){'performance_results.json'}else{"$($mode)_results.json"}
[IO.File]::WriteAllText((Join-Path $artifact $name),($results|ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
if(@($results|Where-Object {-not $_.passed}).Count){throw 'Water15 validation failed. Inspect logs.'}
