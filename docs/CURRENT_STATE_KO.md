# Arcane Legacy — 현재 구현 현황

> **기준:** 2026-10-23 로컬 Phase 2B 실시간 마나 시각화. Phase 1 신규20계열 기반·Phase 2A 수치 관측·기존 정식 전투28종을 유지한다. 관측 계층은 기존 계산 결과를 읽으며 공식·계수·입력·자원에는 관여하지 않는다. 검증 수치는 아래 현황과 변경 이력에 기록하며 사람 수동 QA·릴리스 export·270종 신규 전투 발현과 구별한다.

## 정식 경로

| 기능 | 확인된 상태 | 주요 근거 |
|---|---|---|
| 메인 씬 | `res://scenes/world_main.tscn`, Godot 4.7.2 / Compatibility | `project.godot` |
| 월드·전투 | 중앙 마을·연구실·야외 적·수호 기사·지도·인벤토리·대장간 코드 존재 | `scripts/world/`, `scenes/` |
| 기본 조작 | RMB 이동, Shift 영창/초집중, LMB 직접 발동, Ctrl 회피→연구 후 점멸 | `scripts/world/world_main.gd` 및 입력 로직 |
| 속성 선택 | Tab 슬롯 전환, Alt+1~5 오행 선택, Alt+6 보조 없음, 일반 휠 줌 | `scripts/world/world_main.gd`, `scripts/world/attribute_selector_hud.gd` |
| 오행 | 木火土金水 각각 개화, 주속성 1/보조속성 최대 1 장착 | 연구·장착 로직 |
| 신규 계열 기반 | 동양 음양10 + 서양 기본4/융합6 식별·자격·오행별 음양 선택 모델. 기존 전투 장착과 분리된 F2 메모리 시험 | `data/magic_schools.json`, `scripts/magic_schools.gd`, `scripts/magic_attunement.gd` |
| 주문 ID | 속성/계보 + 최대 5조작 Multiset, 중복 허용 | `scripts/chant_identity.gd` |
| 순서별 물성 | B+O+T·tanh, 불안정/붕괴, raw gain 0.8 정식 적용 | `scripts/mana_variation.gd`, `data/chant_v2_prototype.json` |
| 실시간 수치 관측 | 연구실 **수치 관측** ON/OFF, 입력 단계·누적 Multiset·전/후/Δ·B/O/T/raw/rawΔ·기록Δ·기존 집중/운동 투영과 실제 단계 그래프. OFF는 기존 구체/두 기록 재생 UI로 복귀하는 표시 토글이며 새 정식 기록의 수치 보관은 동일. 미발견 ID/정답/전체 개인 키표 공개 없음 | `scripts/mana_observation.gd`, `mana_observation_panel.gd`, `mana_observation_plot.gd`, `laboratory_panel.gd` |
| 관측값 출처 | B/raw/전후는 엔진 스냅샷. O/T는 당시 설정으로 분해 후 raw와 검산한 진단값이며 압축 안정성 보정은 별도 표시. 범위에 가려진 raw 변화와 실제 무변화를 구별. 미래 조작의 수치를 예측/생성하지 않음 | `mana_observation.gd::capture()` |
| 실시간 마나 시각화 | 전투/연구실 공용 구체의 물성 표현을 0.18초 화면 보간. 전투는 머리 위 64×64 투명 영역만 사용. 초집중에서 입자 궤적·흐름 강조, 이동/계수/안정화 대기 변경 없음. 연구실 수치 관측에 선택 입력 전·후·비교 기록 구체와 그래프 단계 강조를 함께 표시. 기록은 원래 스냅샷만 정지 재생하며 없으면 미기록 표시. 좁은 창은 수직 스크롤 | `mana_orb_view.gd`, `world/world_player_view.gd`, `mana_observation_panel.gd`, `mana_observation_plot.gd`, `laboratory_panel.gd` |
| 관측 기록 | 신규 정식 실험의 단계에 선택적 `mana_observation.version=1` 메타데이터 저장. 실패·취소도 보존. 과거 기록은 원래 스냅샷만 읽고 O/T·조작 의미를 현재 설정/키맵으로 재계산하지 않음. 기존 저장v6·일지v1 유지 | `experiment_journal.gd::append()`, `mana_observation.gd::from_record()` |
| 융합 | 양쪽 개화·장착, BIND, 계보·구조 검사; 연구 이력은 정식 허가 아님 | `scripts/fusion_rules.gd` |
| 등록 주문 | 기존 16종 + 물 추가 12종 = **정식 28종**(물 15종 OH-061~075 포함) | `scripts/formal_spell_registry.gd`, `data/water15_spells.json` |
| 저장 | `schema_version=6` 유지. 선택적 `magic_attunement.version=1` 검증·왕복 지원. 기존 저장에 필드/음양 자동 추가 없음. 일반 마나 + `mana_debt` 유지 | `scripts/character_save.gd`, `scripts/magic_attunement.gd` |
| 시험 | F2 → 신규 20계열 데이터 시험: 메모리 해금·활성 선택·기획 ID 검사. 닫으면 선택 폐기. 기존 오행/물15 QA와 격리 저장 복원 유지 | `scripts/magic_foundation_panel.gd`, `tests/run_magic_foundation.ps1` |
| 최신 관측 회귀 | headless19개 최신 결과 합계 **2,375검사/0실패**(전체 실행 후 Phase2B 최종22검사 재실행). 과거 사용자 fixture가 없는 모델/재시작/F2 실사용자 복사본 검사3개는 완료 불가. 단독 실제 창 합성 Phase2B22·Phase2A32·F2기반56 검사 통과. 물15 창86검사는 2실패이며 변경 전 HEAD 격리본에서도 1실패 재현, 원인 미확정. 기존28종 1,280고유 순열·6,094단계 대조 유지. 기존 로컬 변경33개 파일 SHA-256 일치 | `tests/run_mana_observation.ps1`, `tests/test_mana_realtime_visuals.gd`, `.task002_artifacts/phase2b_verification.json` |
| 신규 기획 카탈로그 | 270행·20계열·75 OH 계보·중복/누락·조작/예시/BIND 검사. 16,007 고유 순열의 기획 ID 불변성 확인. 실행 주문 등록 아님 | `scripts/magic_design_catalog.gd`, `tests/test_magic_foundation.gd` |

## 현재 설정·이전 규칙과의 차이

- **영창:** `rules_version=8`, `property_version=raw-bot-1`, `order_residual_mode=raw`, `order_gain=0.8`. 'raw 보류' 문서는 역사 자료.
- **속성:** 최대 3개를 영구 잠그던 초기 방식이 아니라 **다섯 개 개화 목록 + 활성 주/보조**. 無/VOID는 현재 여섯 번째 개화 슬롯이 아님.
- **입력:** 현재 **휠은 줌**이고 **Alt+숫자로 속성 선택**. 기존 휠 속성 순환/Alt+휠 확대 안내는 구형.
- **융합:** 과거 결속 연구 기록은 보존되지만 현재 정식 시전 허가를 차단하지 않음.
- **자원:** 음수 마나 잔액 대신 비공개 `mana_debt`.
- **콘텐츠:** 정식 '16종'이라고 적은 2026-10-19 문서는 물 15종 통합 이전 기록.

## 아직 확정·검증되지 않은 범위

| 항목 | 상태 및 주의점 |
|---|---|
| 전체 75종 주문 | **미완성.** 28종 등록과 75종 설계를 혼동 금지 |
| 최신 설계 원본 | `Arcane_Legacy_Codex_Magic_270/` 규칙 MD > 권장 CSV/override > 원본 v11 CSV. 구형 수치·기존 조작 구성 차이는 보존하며 자동 덮어쓰기 금지 |
| 물15 고유 현상 | 실제 연결된 QA용 제안 기본안이 있으나 최종 밸런스·VFX 사람 승인과 구분 |
| 신규20계열 전투/성장 | 데이터 기반만 구현. 신규 계수·전투 주문·개화/NG+ 시점·최종 활성 슬롯/UI 키는 미구현/미확정. 신규 계열 문맥은 기존 전투·관측·이동술 우회 발현도 차단. 이번 수치 관측은 현재 엔진이 계산하는 기존 오행/중립/융합만 지원하며 음양은 임의 배정하지 않음 |
| HOLD·지팡이·독·마모·증기 은폐 | 이번 단계 미구현. CSV 설명/구형 스택 문구를 실행 정의로 자동 사용하지 않음 |
| 고위/시그니처·자동 축약 | 사용자 승인된 세부 설계·별도 구현·검증 필요 |
| 테스트·플레이 감각 | 과거 보고서의 자동 검사와 합성 입력은 **사람 플레이 승인**이 아님 |
| 배포/장시간 성능 | 릴리스 export·장시간 수동 QA **미실행**. 실제 창 합성 검사는 Intel Iris Xe / Compatibility에서 수행 |

## 이 문서의 유지 규칙

기능이 구현되거나 삭제될 때 해당 행을 바로 수정하고, 실제 확인한 소스/테스트 근거를 남긴다. **새 '현재' 단락을 맨 앞에 반복해서 붙이지 않는다.** 테스트 미실행이면 미실행으로 표시한다. 날짜별 변경은 [CHANGELOG](CHANGELOG_KO.md)로, 확정 기획은 [GDD](../GDD_v1_0_KO.md)로 분리한다.
