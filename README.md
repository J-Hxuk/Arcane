# Arcane Legacy — Godot 2D 탑뷰 프로토타입

최신 규칙은 [GDD_v1_0_KO.md](GDD_v1_0_KO.md), 작업 기준은 [CODEX_TASK_002.md](CODEX_TASK_002.md)를 따른다.
현재 구현은 일반 전투·이동 시전·초집중 시전과 속성 비의존 기초 마력탄에 집중한다.
연구 확정 UI와 캐릭터의 영구 3속성 잠금은 아직 구현하지 않았다.

## 실행 및 조작

Godot에서 `project.godot`을 가져오고 F5로 실행한다. 실제 검증 엔진은 Godot 4.7.2이며 다른 4.x 버전은 미검증이다.

| 상태 | 입력 | 동작 |
|---|---|---|
| 거점 | 1 / 2 | 고정 / 변동 던전 입장 |
| 거점 | H | 기존 부상 회복 |
| 일반 전투 | WASD, 마우스 조준 + LMB | 이동, 검 공격 |
| 일반 전투 | F | 유실물 회수 / 출구에서 귀환 |
| 이동 시전 | Shift 유지 | 시전 모드, WASD는 계속 이동 |
| 초집중 시전 | Shift 빠르게 두 번 | 초집중 토글, 이동 정지, WASD도 커맨드로 사용 |
| 시전 모드 | Q → E → LMB | 기초 마력탄 직접 시전 |
| 시전 모드 | RMB / Esc | 큐 취소, 초집중이면 일반 전투로 복귀 |
| 시전 모드 | F | 상호작용 대신 커맨드 입력 |
| 던전 | Alt 유지 | 기존 초월 감각 시험 |

보조 커맨드는 Q/E/R/F/Z/X/C/V/T/G, 초집중 추가 커맨드는 W/A/S/D다.
현재 유효한 주문은 기초 마력탄 하나다. 모든 발동에 직접 커맨드를 다시 입력해야 한다.
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
- `scripts/spell_definition.gd`, `data/spells/mana_bolt.tres`: Resource 기반 주문 데이터.
- `scripts/spell_book.gd`: 커맨드 판정·진행 피드백·필요 속성 접근 검사. 4속성 이상 조합은 거부.
- `tests/test_combat.gd`, `tests/preview_combat.gd`: 회귀 테스트 및 실제 렌더링/입력 전달 확인.

기존 캐릭터 저장·재능·발견 기록·사망·유실물·고정/변동 던전 동작은 유지한다.
이전 실험 주문 EMBER/MEND/PULSE는 연구 조건 없이 발동하던 방식이어서 현재 시전 목록에서 제외했다.
기존 저장의 발견 이름은 삭제하거나 다른 주문으로 바꾸지 않는다.

## 검증

`$Godot`을 설치된 Godot console 실행 파일 경로로 지정한 뒤 PowerShell에서 실행한다.

```powershell
& $Godot --headless --path . --editor --import --quit
& $Godot --headless --path . --script tests/test_combat.gd
& $Godot --path . --audio-driver Dummy --rendering-driver opengl3 --script tests/preview_combat.gd
```

테스트 세이브·로그·이미지는 Git에서 제외한 `.task002_artifacts/`에 둔다.
실제 플레이어의 `user://arcane_legacy_save.json`은 테스트에서 사용하지 않는다.
전체 변경 내역, 테스트 결과, 미검증 범위는 [구현 보고서](IMPLEMENTATION_REPORT_KO.md)에 정리했다.

아트·오디오·완성형 연구 시스템·멀티플레이·배포 빌드는 이번 작업에 포함하지 않았다.
실제 손으로 조작하는 플레이테스트와 밸런싱은 후속 확인이 필요하다.
