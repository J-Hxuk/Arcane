> 2026-10-20: 아래 벡터·계수·B+O+T는 보존한다. 현재 정식 잔차는 raw S−raw B, gain0.8, 계산 버전 raw-bot-1이다. [물15 통합 보고](../IMPLEMENTATION_REPORT_WATER15_INTEGRATION_KO.md)의 버전·질적 F와 구분한다.

# 마나 수식 실제 데이터 표 — Phase 0~3

2026-10-19. `data/chant_v2_prototype.json`과 실제 Godot 전수 결과에서 생성했다. 전체 해석·전투 검증·미확정 사항은 [검증 보고서](../IMPLEMENTATION_REPORT_MANA_FORMULA_KO.md)를 참조한다. 수치 순서는 마나량 / 응집 / 안정 변화 / 형상 / 흐름 / 유지 / 분포 / 손실이다.

## 조작 벡터 V(c)

|조작|mana|cohesion|stability|form|flow|persistence|spread|loss|
|---|---:|---:|---:|---:|---:|---:|---:|---:|
|ACCUMULATE|12|0|-2|0|0|0|0.1|0.2|
|COMPRESS|2|35|-18|5|-0.1|0.1|-0.4|1.5|
|STABILIZE|2|3|22|5|-0.05|0.6|-0.1|-0.3|
|RESONATE|3|2|-7|7|0.1|0.3|0.4|0.8|
|SHAPE|2|5|-6|40|0.1|0.2|0.2|0.4|
|DIRECT|2|5|-4|5|0.7|-0.1|-0.2|0.4|
|BIND|2|8|-1|15|0.1|0.3|0.1|1|
|EXPAND|3|-15|-12|5|0.1|0|0.8|2|
|SPLIT|2|-12|-16|10|0.2|-0.1|0.6|2|
|CYCLE|3|3|5|10|0.3|0.7|0.1|-0.3|
|ANCHOR|2|12|12|15|-0.4|0.8|-0.2|0.5|
|DISSIPATE|-4|-8|15|-5|0.1|-0.2|0.5|-0.7|

## 속성 계수

생략된 물성 계수는 1, 압축 위험은 0이다. 친화성·재능은 이 수식에 입력하지 않는다. 융합은 두 속성의 각 계수를 산술 평균한다. 압축 위험과 interaction도 평균한다.

|속성|mana|cohesion|stability|form|flow|persistence|spread|loss|compression_risk|interaction|
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
|WOOD|1|0.75|1.15|1.1|1|1.3|1|1|6|1.0|
|FIRE|1.1|1|0.9|1|1|1|1.35|1|15|1.25|
|EARTH|1|1.3|1.2|1|0.65|1.2|1|1|0|0.8|
|METAL|1|1.3|1|1.25|1.15|1|0.65|1|1|1.0|
|WATER|1|0.8|1|1.15|1.35|1|1.15|1|8|1.15|

## 인접 상호작용 T

표에 없는 137개 순서쌍(자기 반복 포함)은 영벡터다. 표 값에 lambda=0.2와 속성 interaction을 곱한다. V의 속성별 물성 계수를 T에 다시 곱하지 않는다.

|순서쌍|비영 성분|
|---|---|
|ACCUMULATE>COMPRESS|cohesion=8, stability=-5|
|COMPRESS>DIRECT|flow_strength=0.2, energy_loss=0.3|
|SHAPE>STABILIZE|persistence=0.3, stability=5|
|DIRECT>SHAPE|spread=0.4, flow_strength=-0.1|
|STABILIZE>COMPRESS|stability=-5, cohesion=5|
|RESONATE>DIRECT|flow_strength=0.25, spread=-0.1|
|BIND>COMPRESS|cohesion=7, stability=-4|

## 전역 계수와 위험 임계값

r=1.5, kappa=1.15, lambda=0.2, maximum_inputs=5.

|계수|값|
|---|---:|
|initial_stability|65|
|collapse_below|25|
|unstable_below|40|
|compression_penalty_scale|0.35|

## 물성 변형 계수

|계수|값|
|---|---:|
|focus_denominator|65|
|form_density_ratio|0.5|
|motion_persistence|0.6|
|damage_focus|0.35|
|speed_motion|0.5|
|range_focus|-0.22|
|range_motion|0.15|
|radius_focus|-0.3|
|knockback_motion|-0.35|
|duration_focus|0.35|
|duration_motion|-0.25|
|cost_focus|0.2|
|cost_motion|0.1|
|cost_loss|0.01|
|order_gain|0.8|
|order_focus_scale|4.0|
|order_motion_scale|0.16|
|base_projectile_radius|9.0|
|core_focus|0.4|
|core_motion|0.28|
|barrier_area_tradeoff|2.0|

## 전수 상태 검사 집계

각 속성 271,452개. 포화는 내부 tanh 입력 절댓값 > 2(출력 절댓값 > 약 0.964)로 정의한다. 이는 동일 결과라는 뜻이 아닌, 응답 기울기가 작아지는 구간이다.

|속성|붕괴(<25)|불안정(25~40 미만)|음수 raw 마나|흐름 잘림|집중 포화|운동 포화|
|---|---:|---:|---:|---:|---:|---:|
|WOOD|40107|38731|9800|62701|53517|26365|
|FIRE|28682|38350|9800|62764|68867|23730|
|EARTH|39584|38616|9800|52227|87918|11665|
|METAL|25592|39201|9800|71125|96805|32648|
|WATER|30765|39179|9800|86488|59115|45552|

## 전수 max_abs_O 성분별 절댓값 상한

|속성|mana|cohesion|stability|form|flow|persistence|spread|loss|
|---|---:|---:|---:|---:|---:|---:|---:|---:|
|WOOD|4.412512|10.341825|12.685972|13.651209|0.30336|0.358517|0.330938|0.744611|
|FIRE|4.853763|13.7891|9.928152|12.41019|0.30336|0.275782|0.446767|0.744611|
|EARTH|4.412512|17.925829|13.237536|12.41019|0.197184|0.330938|0.330938|0.744611|
|METAL|4.412512|17.925829|11.03128|15.512737|0.348864|0.275782|0.21511|0.744611|
|WATER|4.412512|11.03128|11.03128|14.271718|0.409536|0.275782|0.380579|0.744611|

## 전수 max_abs_T 성분별 절댓값 상한

|속성|mana|cohesion|stability|form|flow|persistence|spread|loss|
|---|---:|---:|---:|---:|---:|---:|---:|---:|
|WOOD|0|3.2|2|0|0.1|0.12|0.16|0.12|
|FIRE|0|4|2.5|0|0.125|0.15|0.2|0.15|
|EARTH|0|2.56|1.6|0|0.08|0.096|0.128|0.096|
|METAL|0|3.2|2|0|0.1|0.12|0.16|0.12|
|WATER|0|3.68|2.3|0|0.115|0.138|0.184|0.138|

상한은 성분별 독립 최댓값이며 한 주문이나 한 순서가 이 값들을 동시에 달성한다는 뜻이 아니다. 전체 raw 최솟값·최댓값과 설정 복사본은 .task002_artifacts/mana_formula_audit/math_results.json에 기록했다.
