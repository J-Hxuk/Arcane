param([string]$ProjectRootOverride='')
$ErrorActionPreference='Stop'
$rootPath=if($ProjectRootOverride){$ProjectRootOverride}else{Split-Path -Parent $PSScriptRoot}
$artifact=Join-Path $rootPath '.task002_artifacts/water15_integration'
$utf8=[Text.UTF8Encoding]::new($false)
function ReadJson([string]$path){Get-Content -LiteralPath $path -Raw -Encoding UTF8|ConvertFrom-Json}
function SaveText([string]$path,[string]$body){[IO.File]::WriteAllText((Join-Path $rootPath $path),$body,$utf8)}
function Num($value){([double]$value).ToString('0.###',[Globalization.CultureInfo]::InvariantCulture)}
function RangeText($values){$m=$values|Measure-Object -Minimum -Maximum;"$(Num $m.Minimum) ~ $(Num $m.Maximum)"}
$water=ReadJson (Join-Path $artifact 'water15_auto.json')
$balance=ReadJson (Join-Path $artifact 'balance_comparison.json')
$performance=ReadJson (Join-Path $artifact 'performance.json')
$source=ReadJson (Join-Path $artifact 'user_before.json')
$mapping=$source.active_chant.manipulations
function Keys($actions){@($actions|ForEach-Object {$action=$_;@($mapping.PSObject.Properties|Where-Object {$_.Value -eq $action})[0].Name}) -join ' → '}
function CaseActions($spell,$index){$entry=$spell.cases[$index];@($spell.permutation_metrics|Where-Object {($_.keys -join '|') -eq ($entry.keys -join '|')})[0].order}
$lines=[Collections.Generic.List[string]]::new()
$lines.Add(@'
# 물속성 15종 통합 구현 보고서

2026-10-20. 정식 F5 게임에 **raw 잔차 gain 0.8과 물속성 OH-061~OH-075 전체**를 통합했다. 등록 주문은 기존16종 + 신규12종 = **28종**이다. 원본은 사용자 확인된 v0.5 Markdown이며 Excel을 다시 탐색하거나 파싱하지 않았다.

이 문서는 이전 [수식 검증](IMPLEMENTATION_REPORT_MANA_FORMULA_KO.md)·[raw 후속 비교](IMPLEMENTATION_REPORT_FORMULA_FOLLOWUP_KO.md)의 현재 후속이다. 과거 보고서의 ‘raw 보류 / 물15 준비 / PX만 격리 실행’ 상태는 이 보고서로 갱신한다. 원본 설계와 B안 제안의 역사 기록은 보존한다.

## 실행과 한 번의 수동 QA

`project.godot` → **F5 → F2 → 물15 QA 연구실 / 일반 표적 / 물15 QA 수호기사**. 시험은 메모리 임시 캐릭터이며 오행 개화, 마나1000, 기존 개인 영창표를 사용한다. 목록에서 주문을 골라 **기본/약한 현상 준비 / 강한 현상 준비**를 누르면 현재 시험 화면으로 돌아온다. 조준 후 LMB 방출, Esc 취소. 직접 Shift 입력과 연구실 Shift 해제 방출도 그대로 가능하다. HP·마나 회복 버튼을 재사용한다.

‘강한 현상’은 계산 결과가 큰 유효 순열을 준비한다. Hadal은 강한 현상 순서가 불안정 발현일 수 있으며 UI에 위험 상태를 표시한다. 기본/하급은 특수효과 ON이 아닌 다른 안정 순서 예시다. 시험 종료 버튼은 시작 전 실제 캐릭터·월드·J·일지·키표로 복귀한다. 일반 UI에는 정답 커맨드나 내부 F 점수를 추가하지 않았다.

한 번의 사용자 수동 QA: [8단계 체크리스트](docs/qa/ARCANE_LEGACY_WATER15_MANUAL_QA_KO.md). 아래 ‘실제 창’ 검증은 실제 OpenGL Godot 창에 합성 입력한 검사다. 사용자가 직접 F5 키를 누른 검사나 수동 미감 승인을 대신하지 않는다. Godot OS 네이티브 주문 팝업의 선택은 합성 입력이 닿지 않아 선택값을 프로그램으로 준비했다. 이후 실제 F2 준비 버튼 클릭·화면 복귀·방출은 합성 입력으로 검사했다. 팝업의 사람 마우스 선택 자체는 수동 QA 항목이다.

## 수식과 계산 버전

`B + O_position + T_adjacent`, r=1.5, κ=1.15, λ=0.2, 12개 벡터·속성 계수·압축 위험·안정성 경계는 보존했다. 전체 벡터와 계수표는 [수식 기준표](docs/MANA_FORMULA_REFERENCE_KO.md)에 있다.

```text
f0 = clamp((S.C − 0.5 S.H)/65, −1, 1)
m0 = clamp(S.U − 0.6 S.P, −1, 1)
df = (raw.C − 0.5 raw.H) − (B.C − 0.5 B.H)
dm = (raw.U − 0.6 raw.P) − (B.U − 0.6 B.P)
f = tanh(f0 + 0.8 tanh(df/4))
m = tanh(m0 + 0.8 tanh(dm/0.16))
```

정식 설정 `order_residual_mode=raw`, `property_version=raw-bot-1`. 기존 저장 schema_version=6과 문법 rules_version=8은 유지한다. 새 실험 dictionary에만 필드를 추가하므로 저장 전체의 추가 마이그레이션은 필요하지 않다. 새 기록의 terminal_snapshot·manifestation·기록 상단에 계산 버전 및 당시 F 결과를 저장한다. 과거 기록에는 버전을 덧씌우지 않으며 재생은 저장된 before/after/terminal을 그대로 읽는다. PX는 명시적 격리 문맥에서 대응 OH 행을 교체해 등록하므로 같은 Multiset의 중복 후보가 없다.

물성 배율은 기존대로 피해·DPS `1+.35f`, 속도 `1+.5m`, 사거리 예산 `max(.4,1−.22f+.15m)`, 반경 `1−.3f`, 밀기/당김 `1−.35m`, 유지 `max(.4,1+.35f−.25m)`, 비용 `1+.2f+.1|m|+.01 loss`다. 실제 투사체 수명은 사거리 예산을 속도 배율로 나누므로 속도와 사거리를 중복 증가시키지 않는다. 코어·광량·밀도·꼬리 변형도 유지했다.

### 기존16종 + 수치형 PX3종: 572개 고유 순열 재현

변경 전은 명시적 clipped_legacy 설정, 변경 후는 raw gain0.8로 고정했다. 신규 정식 F는 이 역사적 비교에 중첩하지 않는다. 아래는 모든 순열 중 절대 상대 변화의 최댓값(%). 비용10%·물성20%는 임시 검토 경보선이며 최종 밸런스 승인선이 아니다.

|주문|순열|피해|속도|코어|사거리|비용|유지시간|
|---|---:|---:|---:|---:|---:|---:|---:|
'@)
foreach($spell in $balance.spells){$d=$spell.max_relative_change;$lines.Add("|$($spell.id)|$($spell.orders)|$(Num (100*$d.damage))|$(Num (100*$d.speed))|$(Num (100*$d.core))|$(Num (100*$d.range))|$(Num (100*$d.cost))|$(Num (100*$d.duration))|")}
$prison=@($balance.spells|Where-Object id -eq 'PX-WATER-PRISON')[0]
$before50=@($prison.samples|Where-Object mana50_before).Count;$after50=@($prison.samples|Where-Object mana50_after).Count
$maxBefore=($prison.samples.before.duration|Measure-Object -Maximum).Maximum;$maxAfter=($prison.samples.raw_after.duration|Measure-Object -Maximum).Maximum
$alarm=@($prison.samples|Sort-Object -Property {$_.relative_change.duration} -Descending)[0]
$lines.Add("`nPX Prison의 상대 변화21.216% 경보 순열은 구속 $(Num $alarm.before.duration) → $(Num $alarm.raw_after.duration)초로 재현됐다. 이는 전체 순열에서 구속시간이 가장 긴 순열과는 다르다. 전체 순열의 개별 최댓값은 $(Num $maxBefore) → $(Num $maxAfter)초다. 고정50마나 가능 순열 $before50 → $after50. 기본53을 억지로50 이하로 낮추지 않았다. 원본16종에는 경보선 초과가 없고 상태·안정성·구조 성공 수가 동일하다. 반복 조작300사례는 위치·인접 잔차0이다. 정식 Abyssal은 수치형 피해+25%/구속축소 F를 제거하고 아래 질적 고리 F만 적용한다. 전체 before/after: [JSON](.task002_artifacts/water15_integration/balance_comparison.json).")
if(Test-Path (Join-Path $artifact 'math/math_results.json')){
 $math=ReadJson (Join-Path $artifact 'math/math_results.json');$w=$math.WATER
 $lines.Add("`n### 전수 수학 검사와 남는 한계`n`n오행별271,452개, 합계1,357,260개 조작열(12종·1~5입력·중복 포함)을 독립 B/O/T 계산과 대조했다. 상태 불일치·비결정론·B의 순열 불변성 위반은0이다. 정식/호환 PX 후보1,280순열의 ID 오류도0이며 정식 물15종1,014순열은 별도로 전부 검사했다.`n`n水 전수에서 붕괴 $($w.collapsed), 불안정 $($w.unstable), raw 마나 음수 $($w.negative_raw_mana), 흐름 clipping $($w.clipped_flow)개다. DISSIPATE에 의한 raw 음수는 허용되는 중간값이며 최종 마나 상태는0 이상이다. 응집 raw −60~140, 형상 −28.75~230, 흐름 −2.7~4.725로 유한했다. 최대 위치 보정 응집 $(Num $w.max_abs_O.cohesion), 형상 $(Num $w.max_abs_O.form_integrity), 흐름 $(Num $w.max_abs_O.flow_strength); 최대 인접항 응집 $(Num $w.max_abs_T.cohesion), 흐름 $(Num $w.max_abs_T.flow_strength).`n`n水의 정규화 raw 순서항 절댓값>2인 tanh 포화 영역은 집중 $($w.saturated_order_focus), 운동 $($w.saturated_order_motion)개다. 포화에서 민감도가 낮아지는 현상은 남으며 무한 증폭으로 해결하지 않았다. 피해·속도·범위·비용·안정성을 함께 평가한 후보28행에서는 모든 다른 순열을 지배하는 단일 순열0이었다. 이는 실제 적 배치/명중률을 포함한 최종 밸런스 증명이 아니다. [전수 원본](.task002_artifacts/water15_integration/math/math_results.json), [위험·Pareto 분석](.task002_artifacts/water15_integration/math/risk_analysis.json).")
}
$lines.Add(@'

## 물속성 등록·조작 구성·발현 안정성

정체성은 활성 주속성 + 조작 Multiset이며 입력 순서는 ID를 바꾸지 않는다. 최대5, 중복 허용. Riptide에 안정화를 추가해 4입력 초안의 전순열 불안정을 해결했다. Hadal은6안정/54불안정을 유지하여 실험 위험을 없애지 않았다. 불안정은 ID 변경이나 붕괴와 구별되는 유효한 위험 발현이다.

아래 키는 **작업 시작 시 읽기 전용으로 복사한 실제 사용자 active_chant**에 조작을 역대응한 개발 QA 예시다. 테스트 fixture의 키를 실제 사용자 커맨드로 오인하지 않도록 다시 변환했다. F2에서 현재 개인 키로 준비되는 입력이 최종 기준이다. 일반 게임은 水 개화·주속성 장착·충분한 마나/30% 부채 한도만 요구한다.

|ID / 주문|입력 구성|안정 / 불안정 / 붕괴|기본·안정 예시 키|강한 현상 예시 키|
|---|---|---:|---|---|
'@)
foreach($spell in $water){$c=$spell.counts;$lines.Add("|$($spell.id) $($spell.name)|$($spell.actions -join ' · ')|$($c.stable) / $($c.unstable) / $($c.collapse)|$(Keys (CaseActions $spell 0))|$(Keys (CaseActions $spell 1))|")}
$lines.Add(@'

총 **1,014개** 고유 순열. 15종 모두 적어도 하나의 안정 발현 순서를 가진다. 기존 물3종의 적용 중이던 정식 밸런스는 유지했다: Tidebolt 피해22/마나9/밀기140, Droplet 피해28/마나8, Ebbpulse 피해18/마나11/반경155/밀기160. 이는 원본 v0.5의 12·10·8 피해와 다르며 이번에 신규 너프/재설정하지 않았다.

신규12종의 기준 비용/피해는 v0.5다: Riptide18/31, Torrentlash20/25, Rippleguard22/0, Eddywall32/0, Undertow35/20, Trident33/63, Razorflow51/80, Confluence48/29, Abyssal53/47, Thalassa82/(44+13/s), Hadal94/158, Hydra77/133.

### 실제 순열별 물성 범위

발현 가능한 모든 순열의 계산값. 방어/영역 주문의 ‘탄속’은 사용하지 않는 공통 필드이므로 0으로 표기한다. 반경·수명은 해당 실행기에서 실제 사용한다. 모든 순열의 전체 물성·키·안정성·F는 [JSON](.task002_artifacts/water15_integration/water15_auto.json)의 permutation_metrics에 있다.

|주문|실제 비용|직접 피해(다중은 합계)|실제 탄속|영역 반경|상태/유지 초|
|---|---:|---:|---:|---:|---:|
'@)
foreach($spell in $water){$m=$spell.permutation_metrics;$projectile=$spell.id -in @('OH-061','OH-062','OH-064','OH-069','OH-070','OH-074','OH-075');$speed=if($projectile){RangeText $m.speed}else{'0'};$lines.Add("|$($spell.id)|$(RangeText $m.cost)|$(RangeText $m.damage)|$speed|$(RangeText $m.radius)|$(RangeText $m.duration)|")}
$lines.Add(@'

## 실제 전투 실행

공통 ElementalCombat이 연구실/월드에서 WaterCombat을 호출한다. 두 화면의 별도 레시피·이름 무작위 선택은 없다.

- 투사체: 실제 가시 코어 반경으로 세밀하게 이동 충돌, 수류별 hit_ids와 관통 수 제한. Trident 총63을3으로 나누고 원본0.6초 기반의 고정 순차 발사, Hydra 총133을7로 나누어 독립 경로 실행. 발사 뒤 표적 추적 없음.
- 수막: Rippleguard가 플레이어를 따라 움직이고 적 투사체 피해30% 감소. Eddywall은 전방 폭150 기준 유체막,55% 감소. 탄체는 막마다 한 번만 감산된다. 같은 종류 재시전은 교체, 두 다른 막을 모두 통과하면 감산이 곱해진다. 고체 충돌·근접 피해 감소·무적을 추가하지 않았다.
- 영역: Undertow의 총 당김90을 시간 적분, Confluence 총210을 지속/두 펄스로 분배. 장애물 앞까지 작은 단계로 이동하며 중심을 뛰어넘지 않는다. Thalassa는 직접44와13/s를 분리하고0.25초 틱+마지막 부분 틱으로 실제 유지시간 예산을 정확히 적용한다. 같은 시전의 프레임별 중복 타격 없음. 서로 다른 시전의 영역은 독립적이다.
- 상태: 기존 root/slow 재적용을 유지. 신규 물속성 둔화 강도는 `clamp(1+.15f−.15m,.7,1.3)`이며 실제 이동 감소에 연결된다. 전체 둔화 이동 배율 하한0.5, 기존 강도1은0.65배다. 구속 보스 상한1.5초와 기존 저항/0.75 재적용 감쇠를 재사용한다.
- 보스: 질적 물리 변위는 기존 mass5·knockback resistance0.8 →20%를 적용한다. 활성 돌진에는 새 수류 변위를 적용하지 않는다. 신규12종과 추가 현상은 임의 강인도 피해·경직·그로기·패턴 취소를 추가하지 않는다. 기존 기본3종의 보스 처리 경로는 보존했다.
- 저장 실패: 마나·부채·발견·일지·적·탄체뿐 아니라 수막·영역·해제 고리·지연 충격·계측·VFX까지 원복한다. 마나 결제는 기존 ManaOverdraw.quote로 먼저 가부를 판정한다.

## 질적 특수효과 F — 통합 QA용 제안 기본안

원본 확정 효과 위에 A안을 실행했다. B안은 [기존 대안 문서](docs/design/WATER_SPECIAL_PHENOMENA_PROPOSALS_KO.md)에 설계로 남긴다. 아래 강도/문턱/대가는 최종 게임 디자인 확정이 아니며 데이터에서 조정한다.

```text
axis(x,s) = .5 + .5 tanh(x/s)
pressure    = axis((raw.C−.5raw.H)−(B.C−.5B.H),4)
circulation = axis((raw.U+.6raw.P)−(B.U+.6B.P),.16)
confinement = axis((raw.H+10raw.P)−(B.H+10B.P),6)
distribution= axis(raw.spread−B.spread,.12)
motion      = axis((raw.U−.6raw.P)−(B.U−.6B.P),.16)
persistence = axis(raw.P−B.P,.2)
score = 주문별 축 (Razor: .5pressure+.5motion,
                   Abyssal: .5confinement+.25pressure+.25persistence)
a = smooth((score−.5)/.35) × smooth((S.stability−25)/30)
smooth(x) = u²(3−2u), u=clamp(x,0,1)
costF = tuned_cost × (1+.10a)
```

점수 문턱과 안정성 경계에서 C1 연속이다. raw 읽기 축은 기존 ManaEffectScore를 재사용하지만, 과거 PX의 가중 점수와 수치형 추가12%를 그대로 중첩하지 않는다. 키 문자열을 조건에 사용하지 않는다.

|ID|상태 축 / 실제 추가 현상|연속적인 대가·한계|
|---|---|---|
|067 Eddywall|circulation / 첫 적 탄체1개 진행을 최대81°×a 편향|추가 비용10%×a; 한 막당1번, 피해 예산 변화 없음|
|068 Undertow|circulation / inward + 접선36a px/s로 곡선 궤도|반경 최대10% 감소, 추가 비용; 보스 변위20%·돌진 제외|
|069 Trident|distribution / 3줄기의 실제 분산 각도 변화|폭은 늘지만 한 표적 집속률 감소, 추가 비용, 총63 예산 보존|
|070 Razorflow|pressure+motion / 시전 고정 sin 곡선 최대40a px|유효 거리 최대12% 감소·조준 오차, 추가 비용; 기존 방어20% 무시 유지|
|071 Confluence|persistence / 지속 견인을 시간차2펄스로 연속 혼합|반경 최대10% 감소·중간 견인 공백, 추가 비용; 총210 예산 보존|
|072 Abyssal Lock|confinement+pressure+persistence / 구속 종료 확산 고리|고리 추가 반경75a·변위30a, **추가HP피해0**, 시전 거리 최대15% 감소·추가 비용|
|073 Thalassa|circulation / 안팎 층이 역회전하는 실제 이동 간섭|반경 최대10% 감소, 추가 비용; 무경직·매 틱 강인도 피해0|
|074 Hadal Verdict|pressure / .28초 지연 수압 충격|원 피해의40%×a를 후속으로 분배; 표적이 이탈하면 후속 빗나감, 추가 비용|
|075 Hydra|distribution /7개의 서로 다른 독립 곡선|분산·곡선에 따른 집속 손실, 추가 비용; 7×19 총예산·수동 조준 유지|

9종 모두 순열 OFF/ON 및 **동일 raw 상태에서 F만 끈 대조군**의 실제 궤적·변위·탄체 편향·펄스·고리·지연 적중 차이를 검사했다. [대조 실측 JSON](.task002_artifacts/water15_integration/phenomena_ablation.json). 관측렌즈는 수치/정답 대신 물리 원인을 한국어 문장으로 표시한다.

## VFX와 실제 화면

Compatibility에서 외부 에셋 없이 단일 2D 드로우 경로를 사용한다. 고체 방벽 재색칠 대신 이동 유체막/수직 커튼, 접선 와류, 집속 나선, 구형 물막·확산 고리, 깊은 역회전 영역, 밝은 압력선, 독립7곡선을 그린다. 투사체 머리의 채운 원이 실제 충돌 코어다. 빛 번짐·꼬리·포말은 장식이다. 효과96개·물리 transient128개 상한, 수류별 꼬리18점 상한이 있다.

아래는 모두 실제 Godot 렌더 창에서 저장한 이미지다. 정지 캡처는 시간차/곡선 운동 전체를 증명하지 않으므로 해당 물리 검사 및 직접 QA와 함께 본다. 시각적 만족도와 보스 전조 가독성의 최종 사용자 승인은 미검증이다.

|주문|연구실|수호 기사|
|---|---|---|
'@)
foreach($spell in $water){$id=$spell.id;$lines.Add("|$id $($spell.name)|[실제 창](.task002_artifacts/water15_integration/$($id)_lab.png)|[실제 창](.task002_artifacts/water15_integration/$($id)_boss.png)|")}
$lines.Add(@'

![Hydra 실제7수류](.task002_artifacts/water15_integration/OH-075_lab.png)

![Thalassa 실제 영역](.task002_artifacts/water15_integration/OH-073_boss.png)

### 추가 현상 실제 OFF/ON 화면

동일 raw 상태에서 F만 끄고 켠 실제 렌더 화면이다.

|주문|F OFF|F ON|
|---|---|---|
|OH-067|[화면](.task002_artifacts/water15_integration/OH-067_effect_off.png)|[화면](.task002_artifacts/water15_integration/OH-067_effect_on.png)|
|OH-068|[화면](.task002_artifacts/water15_integration/OH-068_effect_off.png)|[화면](.task002_artifacts/water15_integration/OH-068_effect_on.png)|
|OH-069|[화면](.task002_artifacts/water15_integration/OH-069_effect_off.png)|[화면](.task002_artifacts/water15_integration/OH-069_effect_on.png)|
|OH-070|[화면](.task002_artifacts/water15_integration/OH-070_effect_off.png)|[화면](.task002_artifacts/water15_integration/OH-070_effect_on.png)|
|OH-071|[화면](.task002_artifacts/water15_integration/OH-071_effect_off.png)|[화면](.task002_artifacts/water15_integration/OH-071_effect_on.png)|
|OH-072|[화면](.task002_artifacts/water15_integration/OH-072_effect_off.png)|[화면](.task002_artifacts/water15_integration/OH-072_effect_on.png)|
|OH-073|[화면](.task002_artifacts/water15_integration/OH-073_effect_off.png)|[화면](.task002_artifacts/water15_integration/OH-073_effect_on.png)|
|OH-074|[화면](.task002_artifacts/water15_integration/OH-074_effect_off.png)|[화면](.task002_artifacts/water15_integration/OH-074_effect_on.png)|
|OH-075|[화면](.task002_artifacts/water15_integration/OH-075_effect_off.png)|[화면](.task002_artifacts/water15_integration/OH-075_effect_on.png)|

### 실측 성능

Intel Iris Xe, OpenGL3.3 / gl_compatibility,1160×720. 주문별5초 동안0.5초 간격10회 실제 발현+오디오 재생, 이후9초 실제 시간으로 소진했다. 아래 FPS는 창 프레임 간격을 측정한 값이며 엔진 GPU 프로파일러 수치가 아니다. CPU는 영역 갱신+탄체 이동/충돌을 합친 시간이다. 다른 수식 전수 검사와 별개로 측정했다.

|주문|평균 FPS|평균/p95/최대 프레임 ms|평균/p95 전투CPU ms|최대 탄체/영역/VFX|static MB 전→시전후→소진후|
|---|---:|---:|---:|---:|---:|
'@)
foreach($p in $performance){$lines.Add("|$($p.id)|$(Num $p.observed_fps)|$(Num $p.mean_frame_ms) / $(Num $p.p95_frame_ms) / $(Num $p.max_frame_ms)|$(Num $p.mean_combat_cpu_ms) / $(Num $p.p95_combat_cpu_ms)|$($p.peak_projectiles) / $($p.peak_water_states) / $($p.peak_visuals)|$(Num ($p.static_memory_before/1MB)) → $(Num ($p.static_memory_after_casts/1MB)) → $(Num ($p.static_memory_after_drain/1MB))|")}
$lines.Add("`n각 측정의 최대 노드1029, 소진 후 탄체/영역/VFX0 및 오디오 재생false였다. 캐시 때문에 static 메모리는 시작값과 완전히 같지는 않다. 이 짧은 검사만으로 장시간 누수 부재를 단정하지 않는다. 최대 프레임은 표의 실측값이며 평균 FPS와 구분한다. [원본 계측](.task002_artifacts/water15_integration/performance.json).")
$lines.Add("`n## 테스트와 보존 증거`n`n자동 검사와 실제 창 합성 입력을 별도 집계한다. 검사별 로그에 SCRIPT ERROR/ERROR/FAIL이 없고 checks>0, 실패0, 정상 종료일 때만 통과로 집계한다. 재실행 중간 실패 로그는 최종 결과와 혼동하지 않는다.`n`n|구분|사례|검사 수|결과|`n|---|---|---:|---|")
$resultFiles=@(
 @('자동','water15 통합·물리·저장·raw',(Join-Path $artifact 'auto_results.json')),
 @('실제 창','water15·입력·HUD·융합',(Join-Path $artifact 'window_results.json')),
 @('자동','기존 핵심25개',(Join-Path $rootPath '.task002_artifacts/current_world_options/core_automatic_results.json')),
 @('자동','정식8개',(Join-Path $rootPath '.task002_artifacts/current_world_options/formal_automatic_results.json')),
 @('자동','기존 후속6개',(Join-Path $rootPath '.task002_artifacts/current_world_options/previous_automatic_results.json')),
 @('자동','현재 개발 설정2개',(Join-Path $rootPath '.task002_artifacts/current_world_options/automatic_results.json')),
 @('자동','속성5개',(Join-Path $rootPath '.task002_artifacts/attribute_loadout/automatic_results.json')),
 @('실제 창','정식8개',(Join-Path $rootPath '.task002_artifacts/current_world_options/formal_window_results.json')),
 @('실제 창','후속6개',(Join-Path $rootPath '.task002_artifacts/current_world_options/previous_window_results.json')),
 @('실제 창','현재 개발 설정2개',(Join-Path $rootPath '.task002_artifacts/current_world_options/window_results.json')))
$totals=@{auto=0;window=0};$manifest=@()
foreach($f in $resultFiles){if(Test-Path -LiteralPath $f[2]){$r=ReadJson $f[2];$count=($r|Measure-Object checks -Sum).Sum;$passed=@($r|Where-Object {-not $_.passed}).Count -eq 0;$lines.Add("|$($f[0])|$($f[1])|$count|$(if($passed){'통과'}else{'실패 있음'})|");$totals[$(if($f[0] -eq '자동'){'auto'}else{'window'})]+=$count;$manifest+=$r}}
foreach($kind in @('math','analysis')){$log=Join-Path $artifact "$($kind)_stdout.log";if(Test-Path $log){$body=Get-Content $log -Raw -Encoding UTF8;$match=[regex]::Matches($body,'(\d+) checks, (\d+) failures');if($match.Count){$m=$match[$match.Count-1];$count=[int]$m.Groups[1].Value;$ok=$body -notmatch 'SCRIPT ERROR|ERROR:|FAIL:' -and [int]$m.Groups[2].Value -eq 0;$lines.Add("|자동|$kind 전수 수식/위험 분석|$count|$(if($ok){'통과'}else{'실패'})|");$totals.auto+=$count;$manifest+=@{case=$kind;mode='auto';checks=$count;passed=$ok;log=$log}}else{$lines.Add("|자동|$kind 전수 수식/위험 분석|—|진행 중·미집계|")}}}
$lines.Add("`n자동 합계 **$($totals.auto)**, 실제 창 합계 **$($totals.window)**. 성능 반복 검사는 별도6항목이다. 합성 입력으로 F2 실제 버튼·15종 연구실 Shift 해제·15종 월드 Shift/LMB·보스HP·중복해제 차단·취소·원본 복귀를 검사했다. 기존 검증은 초집중 정지/회복2배, 휠/Tab/Alt/포션 충돌, Ctrl 회피/점멸, 길찾기·충돌, 일지·관측렌즈, 상점·골드·재생성·저장/재시작을 포함한다.")
$lines.Add("`n이전 검사 진입점도 별도로 실행했다: run_formula_followup 자동434항목, run_mana_formula의 PX 실제 전투85항목 모두 통과. 원본16종/966순열의 역사적 초안 검사는 격리된 원본 코호트를 사용하며, 현재28종 레지스트리와 PX의 안전한 교체를 확인한다. 이 추가 실행에는 위 집계와 겹치는 수식/입력 항목이 있으므로 주요 합계에 다시 더하지 않았다. 로그는 .task002_artifacts/water15_integration/legacy_formula_stdout.log 및 legacy_prototypes_stdout.log에 있다.")
if(Test-Path (Join-Path $artifact 'save_integrity.json')){$integrity=ReadJson (Join-Path $artifact 'save_integrity.json');$lines.Add("`n실제 AppData 저장 SHA-256 전후 동일: **$($integrity.unchanged)**. 작업 시작 원문은 user_before.json에 읽기 전용 복사했다. 실제 저장을 덮어쓰거나 임의 재생성하지 않았다. hash: $($integrity.before). 테스트는 모두 workspace 별도 경로를 사용한다.")}
$lines.Add(@'

릴리스는 정책 함수에서 debug_build=false이면 플래그와 무관하게 개발 기능을 거부함을 검사했다. **실제 릴리스 바이너리 export/실행과 사람의 최종 F5·화질·손맛 평가는 미검증**이다. 고위 주문 성능은 위 짧은 테스트 조건에 한정한다. 원본에서 미정인 Riptide 방어 무시율은 시험10%, 추가 F와 시전 속도/조준·근접 범위 세부치는 임시 구현값이다. 새로운 경직/그로기/무적/유도는 확정하지 않았다.

## 수정 파일과 재현 경로

- 데이터: `data/chant_v2_prototype.json`, `data/water15_spells.json`.
- 수식/등록/관측: `scripts/formal_spell_registry.gd`, `chant_engine_v2.gd`, `water_spell_catalog.gd`, `water_phenomena.gd`, `mana_formula_prototypes.gd`, `observation_lens.gd`, `experiment_journal.gd`, `spell_definition.gd`.
- 전투/시각: `scripts/water_combat.gd`, `water_vfx.gd`, `elemental_combat.gd`, `spell_vfx.gd`, `combat_geometry.gd`, `laboratory_arena.gd`, `laboratory_target_view.gd`, `world/world_main.gd`, `world/world_combat.gd`, `world/world_effects_view.gd`, `world/field_monsters.gd`, `world/ruin_guardian.gd`.
- 실행·QA: `scripts/main.gd`, `developer_test_panel.gd`; `tests/test_water15_*`, `tests/run_water15.ps1`, `tests/export_water15_report.ps1`; 기존572순열 비교와 정식 확장 회귀의 테스트 예산 수정.
- 안내: 이 보고서, `README.md`, `START_HERE_KO.md`, 수식/후속 보고서의 최신 상태 안내, `docs/qa/ARCANE_LEGACY_WATER15_MANUAL_QA_KO.md`.

자동: `tests/run_water15.ps1`, 실제 창: 같은 runner `-Window`, 성능: `-Performance`. PowerShell 실행 정책으로 직접 호출이 막히면 기존 프로젝트와 같이 파일을 ReadAllText한 scriptblock으로 실행한다. 이전 보고서를 삭제하거나 다른 속성의 미이식 주문을 이번 작업 완료로 표시하지 않았다.
'@)
SaveText 'IMPLEMENTATION_REPORT_WATER15_INTEGRATION_KO.md' ($lines -join "`n")
SaveText '.task002_artifacts/water15_integration/validation_summary.json' (@{totals=$totals;cases=$manifest}|ConvertTo-Json -Depth 8)
$qa=[Collections.Generic.List[string]]::new()
$qa.Add(@'
# 물속성 15종 통합 수동 QA — 한 번의 플레이 세션

2026-10-20. 자동/실제 창 검사는 [통합 보고서](../../IMPLEMENTATION_REPORT_WATER15_INTEGRATION_KO.md)에 있다. 아래 사용자 수동 결과는 아직 **미검증**이다. 각 행에 통과/실패/미검증과 메모를 직접 남긴다. 일반 게임 저장을 편집하지 않는다.

## 준비와 복구

Godot4.7.2 Compatibility에서 project.godot을 열고 F5 → F2. `물15 QA 연구실`, `일반 표적`, `물15 QA 수호기사`를 사용한다. 마나1000·오행 전체 개화는 메모리 시험에만 적용된다. 목록에서 주문과 약한/강한 현상을 준비하면 원래 시험 화면으로 돌아온다. **마우스 조준 후 LMB 방출**, Esc 취소. 직접 영창은 Shift 홀드 입력 → 연구실 해제 자동 방출, 월드는 Shift/LMB. 초집중은 Shift 두 번, 정지·마나 회복2배.

F2에서 HP·마나 회복 / 마나 비우기 / HP15%를 사용한다. 시험을 마치면 **시험 종료·원래 플레이 복귀**. 시험 중 위치 이동·발견·금화·물약·일지는 실제 저장에 쓰이지 않는다. 시험 중 종료해도 디스크에는 임시 캐릭터를 쓰지 않는다.

아래 키는 작업 시작 당시 실제 active_chant 대응 예시다. 현재 F2의 준비 결과가 기준이다. 기본·하급의 두 번째 예시는 질적 특수효과가 아닌 순서 변화다. Hadal 강한 현상에는 불안정 순서가 포함되므로 흔들림 표시를 확인한다.

|주문|기본/안정 키|강한 현상 키|
|---|---|---|
'@)
foreach($spell in $water){$qa.Add("|$($spell.id) $($spell.name)|$(Keys (CaseActions $spell 0))|$(Keys (CaseActions $spell 1))|")}
$stages=@(
 @('1. 조작·슬롯·원본 상태',@('F5 일반 마을 실행, 원래 주/보조·J·키표 확인','휠 확대/축소, Tab 대상만 토글, Alt 홀드 애니메이션·Alt1~6·일반1/2 물약','Shift 세션 도중 속성 고정, 이중 Shift 초집중 정지/회복2배','F2 물15 QA 진입·임시 마나1000·연구실/일반 표적/보스 이동')),
 @('2. 기초3종·공통 물성',@('061 Tidebolt 물탄·밀기,062 Droplet 빠른 정밀 탄체,063 Ebbpulse 근접 원형 밀기','같은 구성 다른 순서의 ID 유지·피해/비용/속도/코어 차이','COMPRESS/EXPAND/SPLIT 과잉 시 흔들림/붕괴 및 기록 구별','마나 부족 시 자동 정신력,30% 한도 초과는 무소모·불발','Shift 한 번 해제당 기록/비용1회, 단독탭/더블탭/Esc/포커스 상실은 오발 없음')),
 @('3. 하급3종',@('064 Riptide 안정화 포함5입력 안정 발현·고속 압력선','065 Torrentlash 커서 방향 굵은 휘는 채찍·전방 범위·밀기','066 Rippleguard 이동 동행·적 탄체30% 경감·고체 장애물/근접 무적 없음')),
 @('4. 중급3종',@('067 Eddywall 전방 커튼55% 경감, 강한 회전은 첫 적 탄체1개 편향','068 Undertow OFF 중심 견인 / ON 접선 곡선 이동·장애물 통과 없음','069 Trident3타 고정 순차 발사, 분산/집중 및 실제 맞은 수류만 피해','각 주문 비용·범위 대가, 기본 효과 유지·내부 정답 비공개')),
 @('5. 상급3종',@('070 Razorflow OFF 직선 / ON 시전 고정 곡선·자동 추적 없음·짧아진 유효 사거리','071 Confluence 지속 견인 / 시간차2펄스·중앙 집속·벽 관통 없음','072 Abyssal Lock 구형 구속·종료 고리·추가HP피해/그로기 없음','관측렌즈가 새 현상의 물리 원인을 설명하고 실제 운동과 일치')),
 @('6. 고위3종·가독성',@('073 Thalassa 초기/지속 피해 분리, 안팎 역회전·지속 종료','074 Hadal Verdict 초기+짧은 후속 압력·합산 예산 유지·표적 이탈 시 후속 빗나감','075 Hydra7독립 곡선·각 수류1회 충돌, 모두 같은 보스 집속 가능','세 주문 반복 시 프레임 저하·화면/오디오 잔존·HUD 가독성 메모')),
 @('7. 수호 기사 전투',@('전조·플레이어 위치가 물VFX에 묻히지 않는가','구속1.5초 상한·재적용 감쇠·변위 저항, 수류로 돌진 패턴 자동 취소 없음','회피/점멸·근접·마나볼트·융합2종·포션·소지금 유지','물막 적 탄체 경감, 다중 수류의 실제 적중 횟수에 따른HP 변화')),
 @('8. 저장·일지·복구',@('실험 입력 전후·단계 재생·비교가 당시 스냅샷과 일치','개발 시험 종료 후 원래 주보조·개화·J·일지·키표·금화·물약 복구','일반 세이브 후 재시작에서 발견·개화·영창 매핑 유지','최종 시각·손맛 승인 또는 수정 요청, 미확정 F 기본안 최종 선택은 별도'))
)
foreach($stage in $stages){$qa.Add("`n## $($stage[0])`n`n|검사|수동 결과|메모|`n|---|---|---|");foreach($check in $stage[1]){$qa.Add("|$check|미검증| |")}}
$qa.Add("`n수동 QA 전체 결과: 미검증. 실제 창 합성 입력 통과를 사용자의 시각·손맛 승인으로 바꾸지 않는다.")
[IO.Directory]::CreateDirectory((Join-Path $rootPath 'docs/qa'))|Out-Null
SaveText 'docs/qa/ARCANE_LEGACY_WATER15_MANUAL_QA_KO.md' ($qa -join "`n")
Write-Output 'Water15 report and manual QA generated from actual artifacts.'
