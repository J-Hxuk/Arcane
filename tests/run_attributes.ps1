param([string]$ProjectRootOverride='', [switch]$Window, [switch]$Core, [switch]$Formal, [switch]$Realtime, [switch]$Previous)
$ErrorActionPreference='Stop'
$projectRoot=if($ProjectRootOverride){$ProjectRootOverride}else{Split-Path -Parent $PSScriptRoot}
$godot='C:/Users/jh030/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe'
$artifact=Join-Path $projectRoot '.task002_artifacts/attribute_loadout'
$cases=@('test_attributes_model','test_attributes_interpreter','test_attributes_world','test_attributes_research','test_attributes_restart')
if($Formal){$cases=@('test_formal_phase1','test_formal_phase3','test_formal_phase5','test_formal_phase6','test_formal_phase7','test_formal_phase8','test_formal_phase9','test_formal_restart')}
if($Core){$cases=@('test_research','test_chant','test_combat','test_awakening','test_elemental_combat','test_mana_visuals','test_fusion_a','test_fusion_b','test_fusion_c','test_fusion_d','test_fusion_persistence','test_phase2b25b','test_phase4_m1','test_phase4_profiles','test_mana_overdraw','test_mana_overdraw_catalog','test_chant_v2','test_shake_zoom','test_phase4_qa0','test_phase4_qa_combat','test_phase4_qa_safety','test_phase4_qa_ux','test_chant_v2_visual_qa','test_phase4_movement','test_world_phase3')}
$results=@()
if($Realtime){$cases=@('test_followup_respawn_realtime')}
if($Previous){$cases=@('test_followup_balance','test_followup_blink','test_followup_lens','test_followup_field','test_followup_developer','test_followup_restart')}
foreach($case in $cases){
 $mode=if($Window){'window'}else{'auto'};$log=Join-Path $artifact "$($case)_$mode.log"
 $info=[Diagnostics.ProcessStartInfo]::new();$info.FileName=$godot
 $info.Arguments="$(if(-not $Window){'--headless '})--path `"$projectRoot`" --script tests/$case.gd --log-file `"$log`""
 if($case -eq 'test_fusion_d'){$info.Arguments+=' -- --expect=3'}
 $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$process=[Diagnostics.Process]::Start($info)
 $completed=$process.WaitForExit($(if($Realtime){90000}else{45000}))
 if(-not $completed){Get-CimInstance Win32_Process | Where-Object {$_.Name -like 'Godot*' -and $_.CommandLine -like "*--script tests/$case.gd*"} | ForEach-Object {Stop-Process -Id $_.ProcessId -ErrorAction SilentlyContinue};$process.WaitForExit()}
 $body=''
 if(Test-Path -LiteralPath $log){$stream=[IO.File]::Open($log,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite);$reader=[IO.StreamReader]::new($stream);$body=$reader.ReadToEnd();$reader.Dispose()}
 $count=0;$failures=0;$matchesSummary=[regex]::Matches($body,'(\d+) checks, (\d+) failures')
 if($matchesSummary.Count){$match=$matchesSummary[$matchesSummary.Count-1];$count=[int]$match.Groups[1].Value;$failures=[int]$match.Groups[2].Value}
 $ok=$completed -and $process.ExitCode -eq 0 -and $body -notmatch 'SCRIPT ERROR|ERROR:|FAIL:' -and $count -gt 0
 $results+=[ordered]@{case=$case;mode=$mode;completed=$completed;exit=$process.ExitCode;checks=$count;failures=$failures;passed=$ok;log=$log}
 Write-Output "$case : $count checks / $failures failures / passed=$ok"
}
$name=$(if($Previous){'previous_'}elseif($Realtime){'realtime_'}elseif($Core){'core_'}elseif($Formal){'formal_'}else{''})+$(if($Window){'window'}else{'automatic'})+'_results.json'
[IO.File]::WriteAllText((Join-Path $artifact $name),($results|ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
