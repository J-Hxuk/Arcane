# Phase 2A 속성 연구 시스템 구현 보고서

> Phase 2A 당시의 기록이다. 현재 개인 영창·연구실·저장 v2 및 친화성 공개 정책은 [Phase 2B-1 보고서](IMPLEMENTATION_REPORT_PHASE_2B_1_KO.md)를 따른다. 기존 재능·연구 슬롯·친화성 데이터는 보존한다.

작업일: 2026-10-16 (한국 시간). 기준: 이번 사용자 확정 규칙, `GDD_v1_0_KO.md`, `CODEX_TASK_002.md`.

## 분석 결과와 적용 범위

기존 실행 구조는 `project.godot` → `scenes/main.tscn` → `scripts/main.gd`다. Main이 도형 맵·HUD·캐릭터·저장을 관리하고, `combat_input.gd`가 일반/이동 시전/초집중 입력을 분리한다. `SpellDefinition` Resource와 `SpellBook`은 이미 기본 6속성 이름, 빈 속성 요구 조건, 구성 속성 전부에 대한 접근 검사 계약을 갖고 있었다. Main에서 그 검사에 캐릭터의 연구 목록을 전달하는 연결은 없었다.

기존 저장은 버전 없는 JSON으로 `magic/body/bank/injury/armor/fixed_seed/corpse/learned`를 기록했다. 속성 친화성·연구 상태는 없었다. 이전 로더는 읽기나 JSON 해석 실패 시 새 재능을 생성하고 같은 경로에 저장할 수 있었으므로, 이번에는 기존 파일 오류 시 재생성·덮어쓰기를 차단했다.

기존 1차 보고서의 연구 관련 미구현 항목을 이번에 구현했다. `CODEX_TASK_002.md`의 화염 공격·축약 연구는 이번 범위에서 제외한다는 최신 지시를 상단에 반영했다. GDD의 확인 UI 제안을 필수 규칙으로 확정하고, 테스트용 초기화 제안 대신 격리된 새 테스트 캐릭터를 사용하도록 갱신했다. 4속성 이상 조합은 후속 구현 대상이 아닌 규칙상 불가로 명시했다.

사용자가 정상 확인한 기존 이동·이동 시전·초집중·WASD 커맨드·마력탄·HUD·Alt 감각·모드 해제 8개 항목은 유지했다. `combat_input.gd`, Input Map, 기존 주문 데이터, 전투 효과·이동·충돌 계산은 변경하지 않았다.

## 구현과 파일

| 파일 | 구현 |
|---|---|
| `scripts/element_definition.gd`, `data/elements/{wood,fire,earth,metal,water,void}.tres` | 안정적인 저장 ID·한국어 이름·영역·파생 개념을 갖는 6개 독립 Resource |
| `scripts/base_elements.gd` | 기존 enum 유지, Resource 레지스트리와 최대 연구 3종 상수 추가 |
| `scripts/character_research.gd` | 친화성·확정 연구·단서 분리, 연구 요청/취소/확정, 최대 3종·중복·잘못된 속성 검사 |
| `scripts/character_save.gd` | v0 → v1 이전, 원본 백업, 임시 파일 저장 및 실패 시 원본 복원 시도, 손상/미지원 파일 보호 |
| `scripts/research_panel.gd` | 거점 전용 한국어 연구 UI, 단서 열람, 영구 선택 확인, 마지막 슬롯 경고, 확정/잠금 상태 |
| `scripts/main.gd` | 모델·UI·기존 저장 연결, 저장 실패 시 연구 선택 복원, 실제 시전 검사에 확정 연구 전달, 하단 0~3개 요약 |
| `tests/test_research.gd` | 모델·실제 Main·UI 신호·이전 저장·저장 실패·3속성 상태 전투·별도 프로세스 재실행 검사 |
| `tests/preview_research.gd` | 실제 OpenGL 렌더링과 엔진 GUI 마우스/키 이벤트로 확인·취소·3슬롯 잠금 검사 |
| GDD·작업 지시서·README·시작 안내·구현 보고서 | 확정 규칙과 현재 구현 상태 반영 |

`innate_affinity`는 선천적 값, `researched_base_elements`는 순서가 보존되는 중복 없는 영구 선택, `research_clues`는 책/관찰/힌트 기록이다. 외부 조회는 복사본을 반환한다. 연구 요청은 아무 슬롯도 쓰지 않으며, 선택 속성에 묶인 일회성 확인 표식을 발행한다. `start_element_research`는 표식 없는 호출·잘못된 속성·취소/만료된 요청을 거부하고 확정 순간에도 자격을 재검사한다. 같은 속성의 재확정은 `already_researched`로 변경 없이 종료한다. 3개가 차면 UI와 모델 양쪽에서 새 기본 속성을 차단한다. 게임 및 디버그 UI에 초기화·교체 API를 제공하지 않았다.

無는 물리력·운동·중력·공간의 독립 속성이다. 기본 마력탄과 일반 신체강화 같은 속성 비의존 부여는 빈 `requires_elements`로 표현하므로 無와 동일하지 않으며 연구를 변경하지 않는다. 복합/파생 술식의 접근 자격은 기존 기본 속성 목록만 참조한다. **신체강화 효과나 복합 주문 콘텐츠를 추가한 것은 아니다.** 접근 데이터 계약은 테스트용 Resource로 검증했다.

## 저장 정책과 호환성

현재 포맷은 `schema_version: 1`이며 기존 최상위 필드에 다음 `research` 블록을 추가한다.

```json
{
  "schema_version": 1,
  "research": {
    "innate_affinity": {},
    "researched_base_elements": [],
    "research_clues": []
  }
}
```

- 기존 경로 `user://arcane_legacy_save.json`을 유지한다. 버전이 없거나 0이면 v0으로 처리하고 이전 전에 `.v0.bak`으로 원본 바이트를 보관한다. 이전은 반복 실행해도 친화성·연구를 새로 만들지 않는다.
- 기존 마법/신체 재능, 재화·부상·내구도·고정 지도 시드·유실물·발견 이름, 알 수 없는 최상위 및 연구 블록 필드를 보존한다. JSON 재직렬화로 공백·키 순서·숫자 표기는 달라질 수 있으며 값은 보존한다. 원본 백업은 바이트 동일성을 검사했다.
- 기존 캐릭터의 없는 친화성은 `{}`(미기록)로 남긴다. 연구·친화성이 이미 기록되어 있으면 그대로 읽는다. 신규 캐릭터만 6개 임시 점수(0~100)를 처음 한 번 생성한다. 점수 분포는 확정 밸런스가 아니며 현재 연구 효율/전투 성능에 연결하지 않았다.
- 저장은 `.tmp`를 기록·flush한 다음 이전 파일을 `.bak`으로 옮기고 교체한다. 연구 확정 저장이 실패하면 메모리에서도 직전 연구 상태로 복원한다.
- 손상 JSON, 미지원 버전, 중복/4개 이상/알 수 없는 연구, v1 필수 연구 필드 누락은 원본을 수정하지 않고 저장·연구를 차단한다. 본 파일 없이 `.bak/.tmp`만 남으면 중단 흔적으로 보고 재능을 새로 생성하지 않는다. 자동 백업 복구 UI는 이번 범위에 없다.
- 확인 표식과 UI 상태는 저장하지 않는다. 저장 데이터를 임의 조작하는 오프라인 사용자를 막는 보안 기능은 아니다.

## 실제 검증 결과

엔진: `4.7.2.stable.official.ed1daf0bf`, Windows, 실제 렌더러: Intel Iris Xe / OpenGL 3.3, 1160×720.

| 실행한 검사 | 최종 결과 |
|---|---|
| Godot headless editor import | 통과 |
| 연구·저장·UI 신호·3속성 상태 전투 자동 검사 | **75개 통과 / 실패 0** |
| 종료 후 별도 Godot 프로세스 재실행 검사 | **5개 통과 / 실패 0** |
| 기존 전투·입력·저장 회귀 검사 | **51개 통과 / 실패 0** |
| 실제 연구 GUI 입력·렌더링 | **16개 통과 / 실패 0** |
| 기존 전투 엔진 입력 전달·렌더링 | **9개 통과 / 실패 0** |
| Git 공백 오류 검사 (`git diff --check`) | 통과 |

검사 156개가 통과했다. 렌더링 검사의 이미지 저장/해상도 검사도 이 수에 포함하며, 서로 다른 수동 플레이 시나리오 156개라는 뜻은 아니다.

요청한 테스트 대응:

| 요청 | 실행 증거 |
|---|---|
| 0→1→2→3 연구 | 모델·Main UI 신호·실제 GUI 버튼으로 확인 |
| 네 번째 연구 불가 | UI 비활성 및 모델/Main 직접 호출 거부 |
| 동일 속성 중복 소모 없음 | 반복 확정 결과와 슬롯 수 확인 |
| 단서가 슬롯을 소모하지 않음 | book/observation/hint 및 실제 열람 버튼 확인 |
| 저장 후 재실행 유지 | 새 장면과 별도 엔진 프로세스에서 연구·친화성·단서·기존 캐릭터 확인 |
| UI 외 잘못된 요청 거부 | 확인 없음·잘못된 속성·선택 불일치·취소/지난 표식·가짜 표식·한도 초과 검사 |
| 기존 시전/마력탄 회귀 없음 | 기존 51+9 검사, 추가 3속성 상태 이동/초집중/Alt/취소/마력탄 검사 |

추가로 사망 후 연구 보존, 저장 실패 시 연구 확정 복원, 신규 캐릭터 친화성 재추첨 방지, 원본 백업 바이트 동일성, 알 수 없는 필드 보존, 손상/미지원 파일 보호를 검사했다.

실행 중 발견과 수정: 초기 샌드박스 실행은 Godot 사용자 캐시/설정 접근 오류로 종료했고, 허용된 일반 실행으로 import했다. 최초 자동 검사 2건은 Godot JSON 숫자가 실수로 로드되어 중첩 Dictionary의 타입 비교가 달라진 문제였으며 양쪽 JSON 값을 정규화하여 비교하도록 수정했다. 실제 렌더링에서 패널의 배경 겹침을 발견해 불투명 스타일을 적용했다. GUI 테스트에서 hover 후 프레임 대기와 임베디드 확인 창 좌표 변환을 보완했다. 추가 전투 테스트 작성 중 잘못 놓인 함수 경계로 파싱 오류 1회가 있었고 수정 후 최종 75개가 통과했다. 최종 실패는 없다.

로그·격리 저장·이미지 위치: `.task002_artifacts/phase2a/` (`import.log`, `research_tests.log`, `restart_tests.log`, `combat_tests.log`, `research_preview.log`, `combat_preview.log`). 이미지 `research_zero/confirm/third_warning/three/dungeon.png` 5장을 생성했다. 기존 전투 화면 5장은 `.task002_artifacts/`에 생성된다. 연구 0개·세 번째 경고·3개 잠금·던전 요약 화면을 직접 이미지로 열어 글자/겹침/버튼 상태를 확인했다.

모든 게임 테스트는 프로젝트 내부의 격리 저장 경로를 지정했다. **실제 플레이어의 `user://arcane_legacy_save.json`을 테스트에서 읽거나 수정하지 않았다.** 수정 전 Main/GDD/작업 지시서는 `.task002_artifacts/phase2a/*.bak`에 보관했다.

재현 명령(`$Godot`은 설치된 console 실행 파일 경로):

```powershell
& $Godot --headless --path . --editor --import --quit
& $Godot --headless --path . --script tests/test_research.gd
& $Godot --headless --path . --script tests/test_research.gd -- --verify-restart
& $Godot --headless --path . --script tests/test_combat.gd
& $Godot --path . --audio-driver Dummy --rendering-driver opengl3 --script tests/preview_research.gd
& $Godot --path . --audio-driver Dummy --rendering-driver opengl3 --script tests/preview_combat.gd
```

렌더링 검사는 순서대로 단독 실행한다. 키·마우스 입력은 엔진에 전달하는 합성 이벤트이며 사람이 손으로 조작한 테스트는 아니다.

## 플레이 방법과 남은 범위

거점에서 **B / 속성 연구 버튼 → 열람 또는 연구 선택… → 확인 창의 영구 확정**을 사용한다. 취소는 슬롯을 쓰지 않는다. 세 번째 선택은 다른 기본 속성 연구가 불가능해짐을 경고한다. B/Esc/닫기 버튼으로 연구 화면을 닫은 뒤 기존 1/2 던전 진입과 모든 기존 조작을 그대로 사용한다. 하단 `Research: n/3`은 전투 중에도 유지된다.

이번 연구 UI의 사람 손 조작감, 장시간 플레이, 배포 빌드, 다른 Godot 버전, 실제 정전/강제종료 중 파일 시스템 내구성은 검증하지 않았다. 저장 실패 경로와 중단 흔적의 처리는 테스트했지만 OS 수준의 모든 장애를 보증하는 것은 아니다. 복합마법 전체·연구 계보도·고등·시그니처·화염/축약 연구·일반 신체강화 효과는 구현하지 않았다.

다음 권장 작업은 **격리된 새 캐릭터로 연구 선택의 수동 플레이테스트**다. 영구 선택 문구와 마지막 슬롯 경고를 이해하고 의도대로 취소할 수 있는지 확인한다.
