$ErrorActionPreference='Stop'
$projectRoot=if($PSScriptRoot){Split-Path -Parent $PSScriptRoot}else{(Get-Location).Path}
$reportPath=Join-Path $projectRoot 'IMPLEMENTATION_REPORT_CHANT_V2_VISUAL_QA_KO.md'
$lore=Get-Content -LiteralPath (Join-Path $projectRoot 'data/research_lore.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$metrics=Get-Content -LiteralPath (Join-Path $projectRoot '.task002_artifacts/chant_v2_visual_qa/physical_permutations.json') -Raw -Encoding UTF8 | ConvertFrom-Json
function Fmt($number){([double]$number).ToString('0.00',[Globalization.CultureInfo]::InvariantCulture)}
function RangeText($rows,$field){(Fmt (($rows.$field|Measure-Object -Minimum).Minimum))+'–'+(Fmt (($rows.$field|Measure-Object -Maximum).Maximum))}
$books=[Text.StringBuilder]::new();$mentors=[Text.StringBuilder]::new()
$states=[ordered]@{seeking='실마리 탐색';stable='공명 관측 후';ready='의식 가능';awakened='이미 개화';oral='구술 — 성격만 공개'}
foreach($element in @('WOOD','FIRE','EARTH','METAL','WATER')){
 $row=$lore.$element
 for($i=0;$i -lt 2;$i++){[void]$books.AppendLine("### $element — $($i+1)페이지`n`n$($row.pages[$i])`n")}
 [void]$mentors.AppendLine("### $element`n")
 foreach($state in $states.Keys){[void]$mentors.AppendLine("- **$($states[$state])**: $($row.mentor.$state)`n")}
}
$table=[Text.StringBuilder]::new()
[void]$table.AppendLine('|주문|피해|비용|발사속도|표시/충돌 반경|거리/범위|넉백|지속|안정|')
[void]$table.AppendLine('|---|---|---|---|---|---|---|---|---|')
$names=@{'OH-001'='Briarbind';'OH-016'='Emberbolt';'OH-031'='Stoneward';'OH-046'='Ironlance';'OH-061'='Tidebolt';'ICE_CRYSTAL_NEEDLE'='빙정침'}
foreach($id in @('OH-001','OH-016','OH-031','OH-046','OH-061','ICE_CRYSTAL_NEEDLE')){
 $rows=@($metrics|Where-Object id -eq $id)
 $speed=if($id -eq 'OH-031'){'—'}else{RangeText $rows 'speed'}
 [void]$table.AppendLine('|'+$names[$id]+'|'+(RangeText $rows 'damage')+'|'+(RangeText $rows 'cost')+'|'+$speed+'|'+(RangeText $rows 'collision_radius')+'|'+(RangeText $rows 'range')+'|'+(RangeText $rows 'knockback')+'|'+(RangeText $rows 'duration')+'|'+(RangeText $rows 'stability')+'|')
}
[void]$table.AppendLine("`n정순/역순은 아래 실제 조작 순서를 사용했다. 일반 UI에 이 표를 표시하지 않는다.`n")
[void]$table.AppendLine('|주문/순서|조작|피해/비용|속도/반경|거리/넉백|지속/안정|월드 캡처|')
[void]$table.AppendLine('|---|---|---|---|---|---|---|')
foreach($id in @('OH-001','OH-016','OH-031','OH-046','OH-061','ICE_CRYSTAL_NEEDLE')){
 $rows=@($metrics|Where-Object id -eq $id)
 foreach($index in @(0,($rows.Count-1))){
  $m=$rows[$index];$suffix=if($index -eq 0){'forward'}else{'reverse'}
  $speed=if($id -eq 'OH-031'){'—'}else{Fmt $m.speed}
  [void]$table.AppendLine('|'+$names[$id]+'/'+$suffix+'|'+($m.order -join ' → ')+'|'+(Fmt $m.damage)+' / '+(Fmt $m.cost)+'|'+$speed+' / '+(Fmt $m.collision_radius)+'|'+(Fmt $m.range)+' / '+(Fmt $m.knockback)+'|'+(Fmt $m.duration)+' / '+(Fmt $m.stability)+'|[화면](.task002_artifacts/chant_v2_visual_qa/world_'+$id+'_'+$suffix+'.png)|')
 }
}
$text=[IO.File]::ReadAllText($reportPath)
foreach($replace in @(@('<!-- BOOK_TEXT -->',$books.ToString()),@('<!-- MENTOR_TEXT -->',$mentors.ToString()),@('<!-- METRIC_TABLE -->',$table.ToString()))){$text=$text.Replace($replace[0],$replace[1])}
[IO.File]::WriteAllText($reportPath,$text,[Text.UTF8Encoding]::new($false))
