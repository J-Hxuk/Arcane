# Arcane Legacy — 현재 구현 현황

> **기준:** 2026-10-23 GitHub `master`에 반영된 코드·설정과 2026-10-20 물속성 통합 보고서의 교차 확인. **로컬 미푸시 작업은 이 문서에 반영되지 않을 수 있다.** 이번 문서 정리에서는 Godot를 실행하지 않았으며 과거 테스트 기록을 재실행 성과로 주장하지 않는다.

## 정식 경로

| 기능 | 확인된 상태 | 주요 근거 |
|---|---|---|
| 메인 씬 | `res://scenes/world_main.tscn`, Godot 4.7.2 / Compatibility | `project.godot` |
| 월드·전투 | 중앙 마을·연구실·야외 적·수호 기사·지도·인벤토리·대장간 코드 존재 | `scripts/world/`, `scenes/` |
| 기본 조작 | RMB 이동, Shift 영창/초집중, LMB 직접 발동, Ctrl 회피→연구 후 점멸 | `scripts/world/world_main.gd` 및 입력 로직 |
| 속성 선택 | Tab 슬롯 전환, Alt+1~5 오행 선택, Alt+6 보조 없음, 일반 휠 줌 | `scripts/world/world_main.gd`, `scripts/world/attribute_selector_hud.gd` |
| 오행 | 木火土金水 각각 개화, 주속성 1/보조속성 최대 1 장착 | 연구·장착 로직 |
| 주문 ID | 속성/계보 + 최대 5조작 Multiset, 중복 허용 | `scripts/chant_identity.gd` |
| 순서별 물성 | B+O+T·tanh, 불안정/붕괴, raw gain 0.8 정식 적용 | `scripts/mana_variation.gd`, `data/chant_v2_prototype.json` |
| 융합 | 양쪽 개화·장착, BIND, 계보·구조 검사; 연구 이력은 정식 허가 아님 | `scripts/fusion_rules.gd` |
| 등록 주문 | 기존 16종 + 물 추가 12종 = **정식 28종**(물 15종 OH-061~075 포함) | `scripts/formal_spell_registry.gd`, `data/water15_spells.json` |
| 저장 | `schema_version=6`, 일반 마나 0 이상 + `mana_debt` 보호 | `scripts/character_save.gd`, `scripts/mana_overdraw.gd` |
| 시험 | F2 개발 패널·물15 QA 및 자동 검사 스크립트 보유 | `tests/run_water15.ps1`, `tests/test_water15_*.gd` |

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
| 75종 v06 설계 | 현재 GitHub 저장소에서 확인한 문서 원본은 v05. 사용자/로컬에 있는 v06과 실제 diff 확인 전 임의 이식 금지 |
| 물15 고유 현상 | 실제 연결된 QA용 제안 기본안이 있으나 최종 밸런스·VFX 사람 승인과 구분 |
| 동양 음양·서양 원소 대륙 | 후속 세계관/속성 설계 검토. 코드에 구현됐다고 주장 금지 |
| 고위/시그니처·자동 축약 | 사용자 승인된 세부 설계·별도 구현·검증 필요 |
| 테스트·플레이 감각 | 과거 보고서의 자동 검사와 합성 입력은 **사람 플레이 승인**이 아님 |
| 배포/장시간 성능 | 이번 정리에서 릴리스 export·장시간 수동·하드웨어 검증 **미실행** |

## 이 문서의 유지 규칙

기능이 구현되거나 삭제될 때 해당 행을 바로 수정하고, 실제 확인한 소스/테스트 근거를 남긴다. **새 '현재' 단락을 맨 앞에 반복해서 붙이지 않는다.** 테스트 미실행이면 미실행으로 표시한다. 날짜별 변경은 [CHANGELOG](CHANGELOG_KO.md)로, 확정 기획은 [GDD](../GDD_v1_0_KO.md)로 분리한다.
