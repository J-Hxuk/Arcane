param([string]$ProjectRootOverride='')
$ErrorActionPreference='Stop'
$projectRoot=if($ProjectRootOverride){$ProjectRootOverride}else{Split-Path -Parent $PSScriptRoot}
$data=Get-Content -LiteralPath (Join-Path $projectRoot '.task002_artifacts/formula_followup/balance_comparison.json') -Raw -Encoding UTF8|ConvertFrom-Json
$lines=[Collections.Generic.List[string]]::new();$csv=@()
function Number([double]$value){$value.ToString('0.###',[Globalization.CultureInfo]::InvariantCulture)}
$lines.Add(@'
# raw 잔차 전후 비교 — 19종 572순열

기존 정식 16종 + 격리 시제품 3종. 원시 데이터와 572행 CSV는 `.task002_artifacts/formula_followup/balance_comparison.json`, `balance_permutations.csv`에 있다. raw 보정은 `ManaVariation.projection`의 `order_residual_mode=raw` 경로로 구현했으나, 시제품 구속시간 최대 +21.216% 등 큰 변화에 대한 선행 보고 조건 때문에 **정식 기본 모드에는 적용하지 않았다**.

아래 변화는 발현 가능한 동일 순열에서 계산한 최대 절댓값 상대 변화(%)다. 최솟값/최댓값을 서로 다른 순서끼리 빼지 않았다. —는 해당 주문에 없는 물성이다. 구조 성공률은 마나가 충분할 때이며 50마나 열은 충분한 마나 조건의 차이를 따로 보여준다. 안정성은 모든 순열에서 동일하다. 면적 주문에 가상의 투사체 속도/사거리를 넣지 않았다.

|ID|고유 순열|구조 성공 전/후|피해 Δ%|속도 Δ%|사거리 Δ%|영역 반경 Δ%|가시·충돌 코어 Δ%|비용 Δ%|지속 Δ%|50마나 성공 전/후|
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
'@)
foreach($spell in $data.spells){
 $valid=@($spell.samples|Where-Object manifestable);$changes=@{}
 foreach($field in @('damage','speed','range','radius','core','cost','duration')){$maximum=0.0;foreach($sample in $valid){$maximum=[Math]::Max($maximum,[Math]::Abs([double]$sample.relative_change.$field))};$changes[$field]=Number($maximum*100)}
 if($spell.effect -ne 'projectile'){$changes.speed='—';$changes.range='—';$changes.core='—'}
 if(-not @($valid|Where-Object {$_.before.radius -gt 0}).Count){$changes.radius='—'}
 if(-not @($valid|Where-Object {$_.before.duration -gt 0}).Count){$changes.duration='—'}
 $before50=@($spell.samples|Where-Object mana50_before).Count;$after50=@($spell.samples|Where-Object mana50_after).Count
 $lines.Add('|'+(@($spell.id,$spell.orders,"$($spell.manifestable_before)/$($spell.manifestable_after)",$changes.damage,$changes.speed,$changes.range,$changes.radius,$changes.core,$changes.cost,$changes.duration,"$before50/$after50") -join '|')+'|')
 foreach($sample in $spell.samples){
  $record=[ordered]@{id=$spell.id;order=($sample.order -join ' ');manifestable=$sample.manifestable;mana50_before=$sample.mana50_before;mana50_after=$sample.mana50_after}
  foreach($field in @('damage','speed','range','radius','core','cost','duration','knockback','stability')){$record[$field+'_before']=$sample.before.$field;$record[$field+'_raw_after']=$sample.raw_after.$field}
  $csv+=[pscustomobject]$record
 }
}
$lines.Add("`n## 큰 변화 검토 대상`n")
foreach($flag in $data.review_flags){$lines.Add('- '+$flag.id+' / '+($flag.order -join ' → ')+' / '+$flag.field+': '+(Number $flag.before)+' → '+(Number $flag.after)+' ('+(Number($flag.relative_change*100))+'%)')}
$lines.Add("`n## order_gain 대안(미적용)`n`n|gain|정식 16종: 관련 물성 최대 변화%|시제품 3종: 관련 물성 최대 변화%|`n|---|---:|---:|")
foreach($gain in @(0.6,0.4,0.2)){
 $formal=0.0;$prototypes=0.0
 foreach($spell in $data.spells){foreach($sample in @($spell.samples|Where-Object manifestable)){
  $alternative=@($sample.alternatives|Where-Object {$_.gain -eq $gain})[0]
  foreach($property in $sample.relative_change.PSObject.Properties){$field=$property.Name;$before=[double]$sample.before.$field;if([Math]::Abs($before) -lt 0.000001){continue};$change=[Math]::Abs(([double]$alternative.metrics.$field-$before)/$before)*100;if($spell.id.StartsWith('PX-')){$prototypes=[Math]::Max($prototypes,$change)}else{$formal=[Math]::Max($formal,$change)}}
 }}
 $lines.Add('|'+(@($gain,(Number $formal),(Number $prototypes)) -join '|')+'|')
}
$lines.Add("`n계수 축소는 잘림 편향이 없었던 순서의 체감까지 바꾼다. 따라서 더 작은 gain이 자동으로 더 안전한 해결책이라는 결론을 내리지 않았다. 모든 대안은 raw S−raw B를 사용하며 상태 S·안정성·구조 성공 여부는 변경하지 않는다.")
$body=$lines -join "`n"
[IO.File]::WriteAllText((Join-Path $projectRoot 'docs/FORMULA_RAW_COMPARISON_KO.md'),$body,[Text.UTF8Encoding]::new($false))
$csv|Export-Csv -LiteralPath (Join-Path $projectRoot '.task002_artifacts/formula_followup/balance_permutations.csv') -NoTypeInformation -Encoding UTF8
Write-Output "Exported $($csv.Count) permutation rows and docs/FORMULA_RAW_COMPARISON_KO.md"
