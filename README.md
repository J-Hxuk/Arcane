# Arcane Legacy — Godot 2D 탑뷰 프로토타입

최신 마법 연구 기준은 [명세 v1.2](Arcane_Legacy_Magic_Research_Spec_v1_2.md)의 **Phase 2B-1**이며 기존 [GDD](GDD_v1_0_KO.md)의 3슬롯 규칙과 전투를 유지한다.
개인 영창 키 대응표·최종 마나 상태 판정·연구실 자동 기록/단계 재생/두 실험 비교를 추가했다.
거점에서 **L**로 연구실, **B**로 기존 연구 확정 UI를 연다. 선천적 친화성 수치와 개인 키의 실제 의미는 일반 UI에 표시하지 않는다.

## 실행 및 조작

Godot에서 `project.godot`을 가져오고 F5로 실행한다. 실제 검증 엔진은 Godot 4.7.2이며 다른 4.x 버전은 미검증이다.

| 상태 | 입력 | 동작 |
|---|---|---|
| 거점 | 1 / 2 | 고정 / 변동 던전 입장 |
| 거점 | H | 기존 부상 회복 |
| 거점 | B / 연구 버튼 | 속성 연구 디버그 UI 열기/닫기 |
| 거점 | L | 연구실 진입 |
| 연구실 | Shift 유지 / 두 번, 직접 키 입력 | 개인 영창, WASD는 초집중에서만 입력 |
| 연구실 | 방출 / 기록 버튼 | 현재 영창 방출 시도·자동 실험 저장 |
| 연구실 | 두 실험 선택 + 이전/다음 | 스냅샷만 읽는 단계 재생·나란히 비교 |
| 연구실 | 메모 저장 / 회복 / 거점으로 | 가설 기록 / 마나·탈진 회복 / 귀환 |
| 연구 UI | 열람 / 단서 | 단서만 저장, 슬롯 소모 없음 |
| 연구 UI | 연구 선택… → 영구 확정 | 기본 속성 1개 영구 선택, 최대 3종 |
| 일반 전투 | WASD, 마우스 조준 + LMB | 이동, 검 공격 |
| 일반 전투 | F | 유실물 회수 / 출구에서 귀환 |
| 이동 시전 | Shift 유지 | 시전 모드, WASD는 계속 이동 |
| 초집중 시전 | Shift 빠르게 두 번 | 초집중 토글, 이동 정지, WASD도 커맨드로 사용 |
| 시전 모드 | Q → E → LMB | 기초 마력탄 직접 시전 |
| 시전 모드 | RMB / Esc | 큐 취소, 초집중이면 일반 전투로 복귀 |
| 시전 모드 | F | 상호작용 대신 커맨드 입력 |
| 던전 | Alt 유지 | 기존 초월 감각 시험 |

보조 커맨드는 Q/E/R/F/Z/X/C/V/T/G, 초집중 추가 커맨드는 W/A/S/D다.
기존 튜토리얼 `Q → E → LMB`를 그대로 유지한다. 개인 영창은 첫 C로 속성 비의존 시전을 시작하거나 개인 속성어로 시작한 뒤 후속 조작을 입력한다.
같은 키라도 첫 입력과 후속 입력의 해석은 다르다. 대응표는 캐릭터마다 한 번 생성해 저장하며 로드할 때 재추첨하지 않는다.
개인 영창의 효과는 최종 마나 구조로 판정한다. 현재는 기초 마력탄과 火 실험 공명만 완성 대상으로 삼는다. 후자는 공격 마법/개화 해금이 아닌 실험 피드백이다.
모든 발동에 직접 커맨드를 다시 입력해야 한다. 재생 버튼은 과거 마법을 발동하지 않는다.
화면에 입력 상태, 누적 커맨드, 마나, 미완성·오입력·마나 부족 피드백이 표시된다.

Shift 첫 누름은 즉시 이동 시전이며, 해제를 사이에 둔 두 번째 누름이 첫 누름부터 임시 0.3초 이내이면 초집중이 우선한다.
긴 홀드나 명시적인 커맨드·공격·상호작용·취소는 더블탭 후보를 해제한다.
이동 시전에서 Shift를 놓으면 큐를 비우고 일반 전투로 돌아간다.
Main 노드의 Inspector에서 시간 창을, Project Settings → Input Map에서 키를 조정할 수 있다.
현재 키 의미·주문 순서·수치는 테스트용이다.

## 코드 구조

- `scenes/main.tscn`, `scripts/main.gd`: 기존 도형 기반 맵·전투·저장·HUD, 입력 신호와 주문 실행 연결.
- `scripts/combat_input.gd`: 3가지 상태, 입력 이벤트·홀드·더블탭·키 반복 방지.
- `scripts/base_elements.gd`: 확정 기본 속성 6종. 속성 비의존 조작은 빈 요구 목록으로 표현.
- `scripts/element_definition.gd`, `data/elements/*.tres`: 木/火/土/金/水/無 독립 Resource. 파생 개념은 별도 기본 속성이 아님.
- `scripts/character_research.gd`: 친화성·확정 연구·단서 분리, 확인 요청과 일회성 확인 표식, 중복/4번째/잘못된 속성 거부.
- `scripts/character_save.gd`: 버전 없는 v0 → v1 마이그레이션, 원본 백업, 임시 파일 저장, 알 수 없는 필드 보존.
- `scripts/research_panel.gd`: 거점 전용 한국어 디버그 UI와 영구 선택 확인 창. 전투 중에는 숨김.
- `scripts/chant_profile.gd`: 캐릭터 시드·버전·첫 속성어 6키/후속 조작 14키의 저장된 대응표.
- `scripts/mana_simulator.gd`: 순수 결정론적 상태 기계·마나 변화·최종 구조 판정·관찰 표현. 연구실/던전 공용.
- `scripts/experiment_journal.gd`: 실험별 입력 시간·유지시간·전후 스냅샷·소모·실패 위치·메모와 읽기 전용 재생/비교.
- `scripts/laboratory_panel.gd`: 일반 관찰 UI. 정답 표시는 디버그 빌드의 명시적 `--chant-debug` 실행에서만 별도 창으로 제공.
- `scripts/spell_definition.gd`, `data/spells/mana_bolt.tres`: Resource 기반 주문 데이터.
- `scripts/spell_book.gd`: 커맨드 판정·진행 피드백·필요 속성 접근 검사. 4속성 이상 조합은 거부.
- `tests/test_combat.gd`, `tests/preview_combat.gd`: 회귀 테스트 및 실제 렌더링/입력 전달 확인.
- `tests/test_research.gd`, `tests/preview_research.gd`: 연구·저장·별도 프로세스 재실행·실제 GUI 입력/렌더링 검증.
- `tests/test_chant.gd`, `tests/preview_laboratory.gd`: 개인 영창·기록·최종 상태·호환성·연구실 GUI 검증.

기존 캐릭터 저장·재능·발견 기록·사망·유실물·고정/변동 던전 동작은 유지한다.
이전 실험 주문 EMBER/MEND/PULSE는 연구 조건 없이 발동하던 방식이어서 현재 시전 목록에서 제외했다.
기존 저장의 발견 이름은 삭제하거나 다른 주문으로 바꾸지 않는다.

저장 경로는 기존 `user://arcane_legacy_save.json`을 유지한다. 현재 포맷은 v2로 `chant`와 `laboratory`를 추가했다.
v0/v1 이전 전 각각 `.v0.bak`/`.v1.bak` 원본을 남기고, 일반 저장에는 `.tmp`와 직전 파일 `.bak`을 사용한다. 기존 재능·친화성·확정 슬롯·발견·유실물·알 수 없는 필드를 보존한다.
기존 캐릭터의 미기록 친화성은 `{}`로 보존하며 새로 뽑지 않는다. 신규 캐릭터만 숨겨진 높은 친화성 1개를 생성한다(임시 점수 85, 나머지 25). 난도/성능 반영은 후속 범위다.
손상·미지원 버전·잘못된 연구 데이터는 원본을 보존하고 저장/연구 변경을 차단한다. 중단된 저장의 `.bak/.tmp`만 남아도 새 캐릭터를 자동 생성하지 않는다. 자동 복구 UI는 아직 없다.
확정된 연구의 취소·교체·리롤/초기화 기능은 없으며 세 번째 속성 확정 후 나머지 속성의 새 연구는 영구 차단된다. 확인 창에서 확정 전 취소는 가능하다.

## 검증

`$Godot`을 설치된 Godot console 실행 파일 경로로 지정한 뒤 PowerShell에서 실행한다.

```powershell
& $Godot --headless --path . --editor --import --quit
& $Godot --headless --path . --script tests/test_combat.gd
& $Godot --headless --path . --script tests/test_research.gd
& $Godot --headless --path . --script tests/test_research.gd -- --verify-restart
& $Godot --headless --path . --script tests/test_chant.gd
& $Godot --headless --path . --script tests/test_chant.gd -- --verify-restart
& $Godot --path . --audio-driver Dummy --rendering-driver opengl3 --script tests/preview_laboratory.gd
& $Godot --path . --audio-driver Dummy --rendering-driver opengl3 --script tests/preview_research.gd
& $Godot --path . --audio-driver Dummy --rendering-driver opengl3 --script tests/preview_combat.gd
```

테스트 세이브·로그·이미지는 Git에서 제외한 `.task002_artifacts/`에 둔다.
실제 플레이어의 `user://arcane_legacy_save.json`은 테스트에서 사용하지 않는다.
렌더링 검사는 한 번에 하나씩 실행한다. 현재 결과는 [Phase 2B-1 보고서](IMPLEMENTATION_REPORT_PHASE_2B_1_KO.md), 이전 기록은 [Phase 2A 보고서](IMPLEMENTATION_REPORT_PHASE_2A_KO.md)와 [1차 보고서](IMPLEMENTATION_REPORT_KO.md)에 정리했다.

개화 의식·주/보조속성 역할 분리·복합 결속/재선언·고등/시그니처·화염 공격·신체강화 효과·상점·멀티플레이·배포 빌드는 이번 작업에 포함하지 않았다.
기존 입력 8개 항목은 사용자가 1차 플레이테스트에서 정상 확인했다. 이번 연구실의 손 조작감·단서 밀도·실패 비용 밸런스는 후속 확인이 필요하다.
