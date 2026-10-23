# Arcane Legacy — 변경 이력

현재 동작은 [CURRENT_STATE](CURRENT_STATE_KO.md), 게임 설계는 [GDD](../GDD_v1_0_KO.md)를 참조한다. **각 작업마다 별도 `IMPLEMENTATION_REPORT_*.md`를 생성하지 않는다.**

## 2026-10-23 — Phase 2B 마나 실시간 시각화

- `scripts/mana_orb_view.gd`, `scripts/world/world_player_view.gd`: 실제 엔진 스냅샷을 공용 구체에 연결. 반경·밀도·흐름·떨림 등을 0.18초 동안 화면에서만 보간하며 끝에는 정확한 목표 표현에 도달. 일반 영창은 머리 위 64×64 투명 영역, 초집중은 흐름 선·입자 궤적 강조. 물성 공식·초집중 계수·이동/입력·안정화 시간 변경 없음.
- `scripts/mana_observation_panel.gd`, `mana_observation_plot.gd`, `laboratory_panel.gd`: 수치표를 유지하고 선택 입력 전/후 및 이전 기록의 실제 스냅샷 구체를 함께 표시. 그래프는 같은 입력의 전/후 점을 강조하며 구체 바로 아래 표시. 작은 창은 수직 스크롤. 과거 미기록 상태는 명시적으로 미기록 표시하고 재계산하지 않음. 실패·취소도 원래 저장된 마지막 단계로 재생.
- `tests/test_mana_realtime_visuals.gd`, `run_mana_observation.ps1`, `test_mana_observation_ui.gd`, `test_water15_window_input.gd`: ON/OFF 결과 불변·실제 단계 연동·순서 차이·전후/기록 비교·실패/취소·미기록·초집중 이동 잠금·500회 선택 중 노드 수 불변 검사. 실행기는 출력을 비동기로 소비하고 필요한 디렉터리 생성·과거 fixture 누락을 사전 검사. 창 합성 입력은 중첩 레이아웃의 갱신 뒤 클릭.
- headless 전체 실행은 **19개 / 2,374 checks / 0 failures**, 취소 후 애니메이션 처리 정지를 추가한 Phase2B 최종22검사도 재실행하여 최신 합계 **2,375 checks / 0 failures**. 과거 사용자 복사본이 없는 `test_attributes_model`, 그 산출물에 의존하는 `test_attributes_restart`, `test_current_developer` 3개는 완료 불가로 전체 실행기 종료 코드는 실패를 유지한다. 개인 데이터를 임의 생성하지 않음. 실제 창 합성은 단독 순차 실행: Phase2B22·Phase2A32·F2기반56 검사 통과. 로그/JSON은 `.task002_artifacts/mana_observation/`, `.task002_artifacts/phase2b_*`, 비교 캡처는 `.task002_artifacts/current_world_options/phase2b_*.png`.
- 물15 실제 창 검사는 최종 **86검사 / 2실패**(OH-069/OH-072 보스 명중). 변경 전 `dccffe2` 게임 소스의 격리 복사본에 동일한 레이아웃 대기 합성 입력을 적용해도 **86검사 / 1실패**(OH-072)가 재현됐다. 전체 창 회귀 통과로 간주하지 않으며 추가 원인 조사가 필요하다. Godot 4.7.2 / Intel Arc 140V / Compatibility. 원인 미확정이며 보스·월드 진행·전투 로직은 이번 시각화 작업에서 변경하지 않음.
- `master`에서 `origin/master` pull은 `dccffe2` 최신 상태. 기존 미커밋 33개 파일을 stash 보존·복원 후 SHA-256 전부 일치 확인, 안전 백업 stash 유지. 저장v6/일지v1·개인 키맵·마나탈진·정식28종/신규20계열 계수·전투 등록 변경 없음. 신규 구현 보고서 생성 없음. 사용자 수동 QA·릴리스 export·장시간 성능은 미실행.

## 2026-10-23 — Phase 2A 실시간 마나 관측

- `scripts/mana_observation.gd`: 기존 단계 스냅샷의 입력·Multiset·실제 속성·전후/Δ·B/raw/rawΔ 및 기존 투영을 읽는 관측 계층. O/T는 기존 설정으로 분해 후 raw와 검산한 진단값이며 압축 안정성 보정은 별도 보관. 공식·계수·시전/자원/권한 로직 변경 없음. 새20계열 미정 계수·음양을 추측하지 않음.
- `mana_observation_panel.gd`, `mana_observation_plot.gd`, `laboratory_panel.gd`, `main.gd`: 연구실 수치 관측 표시 토글, 단계 선택·기록 비교·8개 물성 표/간단한 그래프. 상·하한으로 Δ가 0이어도 raw 변화가 있으면 구분. OFF는 기존 구체/재생 화면으로 복귀. 정답/미발견 주문 ID/전체 개인 키맵 공개 없음.
- `experiment_journal.gd`: 새 정식 실험에만 선택적 단계 메타데이터 `mana_observation.version=1` 추가. 저장v6/일지v1 유지. 실패·취소도 보관하며 과거 기록은 자동 보충/재계산하지 않음. 미지원·손상된 부가 데이터는 원래 스냅샷만 표시. 취소·방출·퇴장·F2 복원 시 실시간 버퍼 정리.
- `tests/test_mana_observation.gd`, `test_mana_observation_ui.gd`, `run_mana_observation.ps1`: 기존28종 **1,280고유 순열 / 6,094단계**의 실제 상태·B/raw/O/T 검산·ON/OFF 계산 동일성, 반복·붕괴·취소·이전기록·보안 경계·저장 왕복 검사. headless21개 **2,447 checks / 0 failures**.
- 실제 Godot 4.7.2 / Intel Iris Xe / Compatibility 창을 **단독 실행**, 수치 관측32 + F2 신규기반56 + 물15 Shift/LMB86 = **174 checks / 0 failures**. 기본 크기에서 표의 8개 물성이 보이는 캡처 확인. 세부 로그/JSON은 `.task002_artifacts/mana_observation/`, 캡처는 기존 `.task002_artifacts/current_world_options/mana_observation_*.png`.
- 공식/계수/입력/키맵/등록/마나탈진/Phase1 모델 등 보호 소스11개와 실제 사용자 저장·백업14개의 전후 SHA-256 불변. 270종 전투 등록·HOLD·지팡이·독·마모·증기 은폐·보스/월드 변경 없음. 사람 수동 QA·릴리스 export·장시간 성능은 미실행. Phase2B의 복잡한 VFX와 새20계열 물성 계수/관측은 미구현.

## 2026-10-23 — Phase 1 신규20계열 데이터 기반

- `data/magic_schools.json`, `scripts/magic_schools.gd`, `magic_attunement.gd`, `magic_design_catalog.gd`: 동양 음양10/서양10, 독립 기질 선택·전계열 자격 표현, 270종 기획 CSV·75 OH 계보·중복/누락·BIND 검사. 실행 주문 자동 등록 없음.
- `magic_foundation_panel.gd`, `developer_test_panel.gd`: F2의 **신규 20계열 데이터 시험**. 메모리 해금·활성 선택·기획 Multiset 검사만 제공, 실제 월드 장착/저장 변경 없음. 창 종료 시 선택 폐기.
- `chant_engine_v2.gd`, `chant_identity.gd`: 신규 문맥이 기존 전투/중립/연구실/이동술로 우회되지 않게 차단. 미정 계수를 임의 적용하지 않음. 정식28종·개인 키맵·raw 공식·밸런스·입력 유지.
- `character_save.gd`: 기존 v6 유지, 선택적 `magic_attunement.version=1`만 검증. 기존 캐릭터에 필드나 음양을 자동 추가하지 않음. 격리 fixture 저장 왕복·불량 요청 거부·F2 복원 검사 및 실제 저장/백업14개 SHA-256 불변 확인.
- `tests/run_magic_foundation.ps1`: 최종 headless18개 **2,264 checks / 0 failures**, 실제 창 합성2개 **142 checks / 0 failures**. 신규 기반 검사에서 **16,007 고유 순열** ID 불변 확인. Iris Xe / GL Compatibility. `test_fusion_ux2.gd`의 오래된 v5 고정 기대값을 현재 지원 스키마와 원본 백업 바이트 검사로 보정.
- 창 합성 검사는 다른 Godot 검사와 병렬 실행 시 실패가 있었고 원래 HEAD 복사본에서도 창 검사 실패를 관측했다. 최종 창 검사는 단독 실행해 통과했으며 병렬 환경의 포커스/타이밍 간섭 원인은 확정하지 않았다. 사람 수동 QA·릴리스 export·신규20계열 전투·HOLD/독/마모/은폐는 미실행/미구현.

## 2026-10-23 — README/GDD 정리 및 Codex 문서 정책

- 중복·상충하는 시점별 '최신' 단락을 README와 GDD에서 통합·교체.
- `docs/CURRENT_STATE_KO.md`, `docs/CHANGELOG_KO.md`, `AGENTS.md`를 마련해 **하나의 현황 문서 + 변경 이력** 체계 도입.
- 기존의 raw 적용 보류, 최대 3속성 잠금, 휠 속성 선택, 음수 마나 등의 구형 안내는 현재 규칙에서 제외.
- **게임 코드·리소스·테스트·개인 저장 파일 변경 없음. Godot 테스트 이번 작업에서 미실행.**

## 2026-10-23 — 과거 구현 보고서 정리 (PR #1)

- 후속 구현으로 대체된 보고서 10개를 삭제하고 Markdown 수 50개에서 40개로 감소.
- 다른 문서의 16개 역사 참조를 삭제 전 커밋으로 고정. 코드 변경 없음.

## 2026-10-20 — 물속성 15종 정식 연결 (이전 구현·검증 보고서 기준)

- `OH-061~OH-075` 연결. 기존 16종 + 신규 12종 = 정식 등록 **28종**.
- 정식 영창에 `raw` 잔차 gain 0.8 적용, 계산 버전 구분 및 물속성 F2 QA 추가.
- 일부 특수 현상은 QA용 제안 기본안이며 최종 수동 승인과 구분.
- 자세한 검증: [물속성 통합 보고서](../IMPLEMENTATION_REPORT_WATER15_INTEGRATION_KO.md).

## 2026-10-19 — 영창·속성 선택·월드 통합 (과거 작업 기록)

- 전체 오행 개화 목록과 주·보조 장착 분리, ID와 입력 순서별 물성 분리.
- Tab·Alt+숫자 선택 UI, 휠 줌 복구, 융합의 필수 결속 연구 이력 조건 제거.
- 연구실·관측렌즈·점멸·야외 전투·재생성 등의 이전 단계 통합.
- 이 시점 보고서의 **'raw 적용 보류', '정식 16종'**은 2026-10-20 이후 현재 상태가 아니다.
- 근거: [수식 검증](../IMPLEMENTATION_REPORT_MANA_FORMULA_KO.md), [후속 비교](../IMPLEMENTATION_REPORT_FORMULA_FOLLOWUP_KO.md).

## 앞으로 기록하는 방식

새 작업은 **날짜 / 바뀐 기능·파일 / 실제 테스트와 미실행 / 저장·호환성 영향 / 남은 제한**만 간략히 추가한다. 구형 규칙은 [CURRENT_STATE](CURRENT_STATE_KO.md)에 남기지 않고 이 변경 이력이나 Git 커밋으로 추적한다.
