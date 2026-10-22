param([string]$ProjectRootOverride='')
$ErrorActionPreference='Stop'
$projectRoot=if($ProjectRootOverride){$ProjectRootOverride}else{Split-Path -Parent $PSScriptRoot}
$config=Get-Content -LiteralPath (Join-Path $projectRoot 'data/chant_v2_prototype.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$stats=Get-Content -LiteralPath (Join-Path $projectRoot '.task002_artifacts/mana_formula_audit/math_results.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$fields=@('mana_amount','cohesion','stability','form_integrity','flow_strength','persistence','spread','energy_loss')
$lines=[Collections.Generic.List[string]]::new()
$lines.Add(@'
# 마나 수식 실제 데이터 표 — Phase 0~3

2026-10-19. `data/chant_v2_prototype.json`과 실제 Godot 전수 결과에서 생성했다. 전체 해석·전투 검증·미확정 사항은 [검증 보고서](../IMPLEMENTATION_REPORT_MANA_FORMULA_KO.md)를 참조한다. 수치 순서는 마나량 / 응집 / 안정 변화 / 형상 / 흐름 / 유지 / 분포 / 손실이다.

## 조작 벡터 V(c)

|조작|mana|cohesion|stability|form|flow|persistence|spread|loss|
|---|---:|---:|---:|---:|---:|---:|---:|---:|
'@)
foreach($entry in $config.operations.PSObject.Properties){$values=@($entry.Name);foreach($field in $fields){$values+=$entry.Value.$field};$lines.Add('|'+($values -join '|')+'|')}
$lines.Add(@'

## 속성 계수

생략된 물성 계수는 1, 압축 위험은 0이다. 친화성·재능은 이 수식에 입력하지 않는다. 융합은 두 속성의 각 계수를 산술 평균한다. 압축 위험과 interaction도 평균한다.

|속성|mana|cohesion|stability|form|flow|persistence|spread|loss|compression_risk|interaction|
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
'@)
foreach($entry in $config.elements.PSObject.Properties){$values=@($entry.Name);foreach($field in $fields){$property=$entry.Value.PSObject.Properties[$field];$values+=if($property){$property.Value}else{1}};$values+=$entry.Value.compression_risk;$values+=$entry.Value.interaction;$lines.Add('|'+($values -join '|')+'|')}
$lines.Add("`n## 인접 상호작용 T`n`n표에 없는 137개 순서쌍(자기 반복 포함)은 영벡터다. 표 값에 lambda=0.2와 속성 interaction을 곱한다. V의 속성별 물성 계수를 T에 다시 곱하지 않는다.`n`n|순서쌍|비영 성분|`n|---|---|")
foreach($entry in $config.transitions.PSObject.Properties){$values=@();foreach($property in $entry.Value.PSObject.Properties){$values+=$property.Name+'='+$property.Value};$lines.Add('|'+$entry.Name+'|'+($values -join ', ')+'|')}
$lines.Add("`n## 전역 계수와 위험 임계값`n`nr=$($config.r), kappa=$($config.kappa), lambda=$($config.lambda), maximum_inputs=$($config.maximum_inputs).`n`n|계수|값|`n|---|---:|")
foreach($property in $config.thresholds.PSObject.Properties){$lines.Add('|'+$property.Name+'|'+$property.Value+'|')}
$lines.Add("`n## 물성 변형 계수`n`n|계수|값|`n|---|---:|")
foreach($property in $config.tuning.PSObject.Properties){$lines.Add('|'+$property.Name+'|'+$property.Value+'|')}
$lines.Add("`n## 전수 상태 검사 집계`n`n각 속성 271,452개. 포화는 내부 tanh 입력 절댓값 > 2(출력 절댓값 > 약 0.964)로 정의한다. 이는 동일 결과라는 뜻이 아닌, 응답 기울기가 작아지는 구간이다.`n`n|속성|붕괴(<25)|불안정(25~40 미만)|음수 raw 마나|흐름 잘림|집중 포화|운동 포화|`n|---|---:|---:|---:|---:|---:|---:|")
foreach($entry in $config.elements.PSObject.Properties){$m=$stats.($entry.Name);$lines.Add('|'+(@($entry.Name,$m.collapsed,$m.unstable,$m.negative_raw_mana,$m.clipped_flow,$m.saturated_order_focus,$m.saturated_order_motion) -join '|')+'|')}
foreach($term in @('max_abs_O','max_abs_T')){
 $lines.Add("`n## 전수 $term 성분별 절댓값 상한`n`n|속성|mana|cohesion|stability|form|flow|persistence|spread|loss|`n|---|---:|---:|---:|---:|---:|---:|---:|---:|")
 foreach($entry in $config.elements.PSObject.Properties){$values=@($entry.Name);foreach($field in $fields){$values+=[Math]::Round([double]$stats.($entry.Name).$term.$field,6)};$lines.Add('|'+($values -join '|')+'|')}
}
$lines.Add("`n상한은 성분별 독립 최댓값이며 한 주문이나 한 순서가 이 값들을 동시에 달성한다는 뜻이 아니다. 전체 raw 최솟값·최댓값과 설정 복사본은 `.task002_artifacts/mana_formula_audit/math_results.json`에 기록했다.")
[IO.File]::WriteAllText((Join-Path $projectRoot 'docs/MANA_FORMULA_REFERENCE_KO.md'),($lines -join "`n"),[Text.UTF8Encoding]::new($false))
Write-Output 'Wrote docs/MANA_FORMULA_REFERENCE_KO.md'
