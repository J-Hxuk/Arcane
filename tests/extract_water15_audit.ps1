param([string]$ProjectRootOverride='')
$ErrorActionPreference='Stop'
$projectRoot=if($ProjectRootOverride){$ProjectRootOverride}else{Split-Path -Parent $PSScriptRoot}
$source='docs/design/Arcane_Legacy_75종_Codex_통합명세_v05.md'
$text=Get-Content -LiteralPath (Join-Path $projectRoot $source) -Raw -Encoding UTF8
$rows=@()
foreach($match in [regex]::Matches($text,'(?ms)^#### (OH-0(?:6[1-9]|7[0-5])) — ([^\r\n]+)\r?\n(.*?)(?=^#### |\z)')){
 $block=$match.Groups[3].Value;$original=$block.Substring(0,$block.IndexOf('**v0.5'))
 $fields=[ordered]@{}
 foreach($field in [regex]::Matches($original,'(?m)^- \*\*([^*]+)\*\*: ([^\r\n]+)')){$fields[$field.Groups[1].Value]=$field.Groups[2].Value}
 $rows+=[ordered]@{id=$match.Groups[1].Value;name=$match.Groups[2].Value;source_fields=$fields;minimum_inputs=[int]$fields['최소 입력'];maximum_inputs=[int]$fields['최대 입력'];mana=[double]$fields['마나 비용'];damage=[double]$fields['대표 직접피해'];requires_input_redesign=([int]$fields['최소 입력'] -gt 5);decision_lines=@($block -split '\r?\n'|Where-Object {$_ -match '^\- \*\*(남은 세부 결정|속박·경직|다단타·DoT·특수 규칙|방어술 판정|변위·보스 저항)'})}
}
if($rows.Count -ne 15){throw 'Expected all 15 original water spells'}
$workbook='Arcane_Legacy_75종_마법설계_결정반영_v05(2).xlsx'
$binary=@(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'docs/design') -Filter $workbook -File -Recurse)
if(Test-Path -LiteralPath (Join-Path $projectRoot $workbook)){$binary+=Get-Item -LiteralPath (Join-Path $projectRoot $workbook)}
$document=[ordered]@{status='SOURCE_AUDIT_ONLY_NOT_RUNTIME';requested_workbook='Arcane_Legacy_75종_마법설계_결정반영_v05(2).xlsx';workbook_found=($binary.Count -gt 0);actual_source=$source;source_sha256=(Get-FileHash -LiteralPath (Join-Path $projectRoot $source)).Hash;source_equivalence='User previously confirmed English-named v05 Markdown as same material; binary differences cannot be verified without workbook';spells=$rows}
$out=Join-Path $projectRoot 'docs/design/WATER15_SOURCE_AUDIT.json'
[IO.File]::WriteAllText($out,($document|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
Write-Output "Extracted $($rows.Count) original spells; input-range conflicts=$(@($rows|Where-Object requires_input_redesign).Count)"
