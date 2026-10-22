param([string]$ProjectRootOverride='', [switch]$Window, [switch]$Math, [switch]$Analysis)
$ErrorActionPreference='Stop'
$projectRoot=if($ProjectRootOverride){$ProjectRootOverride}else{Split-Path -Parent $PSScriptRoot}
$godot='C:/Users/jh030/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe'
$artifact=Join-Path $projectRoot '.task002_artifacts/mana_formula_audit'
New-Item -ItemType Directory -Force $artifact | Out-Null
$cases=if($Math){@('test_mana_formula_math','test_mana_formula_analysis','test_mana_formula_combat')}elseif($Analysis){@('test_mana_formula_analysis')}else{@('test_mana_formula_combat')}
$results=@()
foreach($case in $cases){
 $mode=if($Window){'window'}else{'auto'};$log=Join-Path $artifact "$($case)_$mode.log"
 $info=[Diagnostics.ProcessStartInfo]::new();$info.FileName=$godot
 $info.Arguments="$(if(-not $Window){'--headless '})--path `"$projectRoot`" --script tests/$case.gd --log-file `"$log`""
 $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$process=[Diagnostics.Process]::Start($info)
 $completed=$process.WaitForExit($(if($case -eq 'test_mana_formula_math'){1200000}else{180000}))
 if(-not $completed){Stop-Process -Id $process.Id -ErrorAction SilentlyContinue;$process.WaitForExit()}
 $stream=[IO.File]::Open($log,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite);$reader=[IO.StreamReader]::new($stream);$body=$reader.ReadToEnd();$reader.Dispose()
 $matchesSummary=[regex]::Matches($body,'(\d+) checks, (\d+) failures');$count=0;$failures=0
 if($matchesSummary.Count){$match=$matchesSummary[$matchesSummary.Count-1];$count=[int]$match.Groups[1].Value;$failures=[int]$match.Groups[2].Value}
 $ok=$completed -and $process.ExitCode -eq 0 -and $body -notmatch 'SCRIPT ERROR|ERROR:|FAIL:' -and $count -gt 0
 $results+=[ordered]@{case=$case;mode=$mode;completed=$completed;exit=$process.ExitCode;checks=$count;failures=$failures;passed=$ok;log=$log}
 Write-Output "$case : $count checks / $failures failures / passed=$ok"
}
$name=$(if($Math){'math_'}elseif($Analysis){'analysis_'}else{''})+$mode+'_results.json'
[IO.File]::WriteAllText((Join-Path $artifact $name),($results|ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
if(@($results | Where-Object {-not $_.passed}).Count){throw 'Mana formula verification failed. See logs.'}
