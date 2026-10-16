# Phase 2B-2 최초 개화 구현 보고서

작업일: 2026-10-16 (한국 시간). 최신 기준: `Arcane_Legacy_Phase_2B-2_First_Awakening_Spec.md`. 기존 GDD 및 v1.2와 충돌하는 획득 절차는 최신 명세를 적용했다. 사용자가 통과를 보고한 Phase 2B-1 수동 테스트 8개 항목을 회귀 범위로 유지했다.

## 구현 결과와 단계

1. 기존 6개 속성 Resource에 공명 요구치·약한/부분/안정 관찰·서적/스승 설명을 추가하고 기존 마나 시뮬레이터를 확장했다.
2. 친화성·양방향 상극·상생 보조·지식에 따른 결정론적 제어 요구치를 도입했다. 키 표와 시전 입력 라우터를 재구현하지 않았다.
3. 기존 연구실 안에 임시 서고/스승 UI와 단서 일지, 의식 진입점을 붙였다. 완성 마을·NPC AI·인벤토리는 만들지 않았다.
4. 단서 → 안정 공명 2회 → 새 직접 의식 영창 → 영구 확인 → 주속성 1개 저장의 전체 흐름을 연결했다.
5. 역할 기반 저장 v3와 이전 저장 호환을 검증하고 기존 영창·전투·일지 회귀를 실행했다.

**의식 시작 버튼은 세션만 연다.** 키를 자동 입력하거나 즉시 마법을 시전하지 않는다. 같은 시전 모드에서 사용자가 새 영창으로 목표의 안정 공명·형상·방향을 완성해야 확인 표식이 발급된다. 최종 확인 전에는 어떤 슬롯도 바뀌지 않는다. 취소 후 다른 대상 탐구·의식이 가능하다. 확정 후 다른 주속성과 보조속성 획득을 차단한다.

## 기존 구조 분석과 주요 결정

기존 `ChantProfile`의 캐릭터 시드·첫 속성어/후속 조작 표, `CombatInput`의 NORMAL/MOBILE_CAST/FOCUS_CAST, `ManaSimulator`의 순수 데이터 상태와 `ExperimentJournal`의 스냅샷 조회를 재사용했다. Main의 저장·시전·마력탄 실행 연결에 연구 조건과 의식 검증을 추가했다. `project.godot`, `combat_input.gd`, 개인 키 생성 알고리즘, 기존 마력탄 Resource 및 이동·검술·충돌·피해 계산은 수정하지 않았다.

기존 B 화면은 확인만으로 임의 3속성을 새로 확정할 수 있어 최신 개화 규칙을 우회했다. 지금은 상태 조회와 연구실 이동 안내로 바꾸고, 구 `request_research`도 의식 확인 표식을 발급하지 않도록 했다. 장기 총 3속성 제한은 유지하고 **이번 새 획득은 주속성 1개만** 제공한다. 과거에 이미 점유한 1~3슬롯은 지우거나 임의로 주/보조 역할을 붙이지 않는다.

선천 친화성은 기존 저장을 그대로 읽는다. 새 캐릭터의 1개 높은 친화성 생성은 기존 방식 그대로다. 예전 수치형 친화성은 유일한 최댓값을 난도 기준으로 읽되 저장 값은 바꾸지 않는다. 미기록 `{}`·숫자 최댓값 동률은 중립이며 재추첨하지 않는다. 일반 UI는 이 내부 기준과 개인 키 정답을 보여 주지 않는다.

## 변경/추가 파일

| 파일 | 내용 |
|---|---|
| `scripts/element_definition.gd`, `data/elements/*.tres` | 기존 6속성 데이터에 요구치·관찰 단계·속성별 책/멘토 원리 추가 |
| `scripts/resonance_rules.gd` (추가) | 친화·상생·양방향 상극 관계와 공명/안정화 요구치 |
| `scripts/mana_simulator.gd` | 6종 공명, 문맥 기반 변화/판정, 반응 단계, 첫 붕괴 위치. 규칙 버전 2 |
| `scripts/character_research.gd` | 영구 역할의 단일 원본, 단서·공명 근거, 의식 시작/구조 재검증/일회성 확인, 이전 슬롯 호환 |
| `scripts/awakening_panel.gd` (추가) | 대상 선택, 서적/스승, 단서 일지, 의식 접근, 취소 및 영구 확인 |
| `scripts/laboratory_panel.gd` | 기존 연구실에 단서/개화 진입, 반응 단계 표기. 재생/비교/메모 유지 |
| `scripts/research_panel.gd` | B 연구 상태 조회·연구실 안내, 친화성 숨김 유지, 구 직접 확정 경로 차단 |
| `scripts/main.gd` | 공통 시뮬레이션 문맥, 단서/근거 저장, 의식과 최종 확정 연결, 실패 시 복원 |
| `scripts/character_save.gd` | 스키마 v3 및 v2 원본 백업 이전 |
| `scripts/experiment_journal.gd` | 새 기록에 평가 문맥·반응 단계 보관, 기존 기록은 변경하지 않음 |
| `tests/test_awakening.gd`, `tests/preview_awakening.gd` (추가) | 새 인수 검사·실제 창 전체 흐름 및 캡처 |
| `tests/test_research.gd`, `tests/test_chant.gd`, `tests/preview_research.gd` | 바뀐 획득 절차/역할 스키마/관찰 지식에 맞춘 회귀 기대값 갱신 |
| `README.md`, `START_HERE_KO.md`, GDD, 작업 지시서, 이전/신규 보고서 | 현재 규칙·조작·호환 정책·검증 범위 설명 |

사용자 원본 `Arcane_Legacy_Phase_2B-2_First_Awakening_Spec.md`는 수정하지 않았다. 새 GDScript의 Godot `.uid`도 포함한다.

## 공명과 단서 규칙

여섯 속성은 같은 데이터 인터페이스로 판정한다. 木은 뻗는 결, 火는 온기, 土는 알갱이/중심, 金은 은빛 윤곽/울림, 水는 물결, 無는 점의 궤적/간격을 관찰한다. 이는 초기 공명의 텍스트 피드백이며 여섯 전투 주문이나 실제 지형/물리 효과를 추가한 것이 아니다.

첫 키는 마나 대상을 선언할 뿐이다. 첫 키 하나의 관찰은 모든 속성·친화 조합에서 동일한 무반응이다. 뒤에서 마나를 축적·응집하고 공명을 탐색하면 약한 징후 → 부분 반응/불안정 → 안정 구조를 구분할 수 있다. 붕괴는 첫 발생 단계부터 실패로 고정해 기록한다. 서로 다른 조작 순서라도 최종 구조가 같으면 같은 종류에 도달하는 기존 원칙을 유지했다.

수치표는 프로토타입이며 확정 밸런스가 아니다.

| 조건 | 제어 변화 |
|---|---|
| 선천 친화와 같은 대상 | 공명 누적량 증가, 간섭 감소, 안정화/공명 요구 완화 |
| 木克土·土克水·水克火·火克金·金克木의 어느 방향이든 해당 | 공명 누적량 감소, 간섭 증가, 추가 안정화/공명 요구 |
| 상생 연결 | 안정화 요구를 소폭 완화 |
| 無가 포함된 서로 다른 대상 관계 | 오행 간섭/상생 보조 없음 |
| 서적 지식 | 필요한 공명 준비량 완화 |
| 스승 지식 | 필요한 안정화 제어 완화 |
| 환경 제어 조건 | 공통 `control_penalty` 문맥으로 동일하게 판정. 현재 연구실/던전 모두 0 |

확률 성공은 없다. 36개 선천/목표 조합 모두 32단계 이내의 준비·안정화·공명·형상·방향 경로로 의식까지 도달함을 검사했다. 게임 내 동적 환경/날씨는 구현하지 않았고, 연구실만 유리하게 만드는 숨은 성공 버프도 없다. 순수 마력탄은 이 속성 조건의 적용 대상이 아니다.

책과 멘토는 각 속성에 대해 다른 원리 설명을 제공한다. 실제 키 표는 읽지 않으며 `Q=火`/`R=압축`처럼 캐릭터별 답을 출력하지 않는다. 두 출처의 단서가 필요하고, 안정적 공명은 서로 다른 **저장된 실험 2개**가 있어야 재현으로 인정한다. 같은 기록 ID를 중복 계수하거나 재생하여 조건을 채울 수 없다. 과거 단서와 관찰도 일지에 보존하며, 새 안정 관찰에는 대응 실험 번호를 보여 준다.

## 저장 v3와 호환 처리

```text
research:
  innate_affinity              # 기존 값 그대로
  main_attribute               # 미개화 null, 확정 후 기본 속성 ID
  auxiliary_attributes         # 신규 캐릭터 [], 이번 획득 경로 없음
  legacy_committed_attributes  # 과거에 이미 확정됐지만 역할 미배정인 슬롯
  research_clues               # 기존 단서 + 서적/멘토/관찰
  resonance_discoveries        # 속성별 stable_experiment_ids
```

`researched_base_elements`는 위 영구 역할들의 합집합으로 조회하며 **중복 저장하지 않는다**. 저장된 옛 목록을 `legacy_committed_attributes`로 이전하여 영구 선택의 값을 보존한다. `awakening_state`는 주속성 여부·현재 의식·확인 대기에서 계산하는 일시 상태로, 별도 영속 원본을 만들지 않았다. 재실행 후 이미 확정한 역할은 유지하고 미확정 의식/확인 표식은 폐기한다. 단서와 안정 재현 근거는 남으므로 다시 의식에 도전할 수 있다.

- 기존 경로 `user://arcane_legacy_save.json`, `.tmp`/`.bak` 쓰기 구조를 유지한다. v0/v1/v2를 읽고 각각 `.v0.bak`/`.v1.bak`/`.v2.bak` 원본 바이트를 남긴 후 v3로 이전한다.
- 기존 재능·친화성·지도/캐릭터 시드·개인 대응표·슬롯·발견·유실물·재화·부상·내구도·실험·메모·알 수 없는 필드는 보존한다. 기존 표를 시드로 재생성하지 않는다.
- 기존 3슬롯 캐릭터는 새 네 번째 대상을 확정할 수 없다. 이미 점유한 대상 중 원하는 하나를 같은 단서·공명·의식·최종 확인으로 주속성 지정할 수 있다. 기존 선택을 풀거나 다른 기본 속성으로 바꾸지 않고, 총 슬롯 수는 그대로 유지한다. 나머지 기존 슬롯의 역할도 임의로 보조라고 추정하지 않는다.
- 최종 확인은 모델에서 목표·일회성 표식·준비 조건·주속성 여부·최대 3종을 다시 검사한다. 확정 성공 시 역할과 슬롯 원본을 한 JSON 거래로 저장한다. 쓰기 실패 시 메모리 역할도 복원하고 재사용 가능한 성공 표식을 없앤다.
- 실험 기록과 새 공명 근거도 같은 저장 거래로 쓴다. 기록 저장 실패 시 두 모델을 복원한다. 실제 실험에 이미 쓴 마나는 반환하지 않는다.
- v3 역할 중복·4종 이상·미지원 버전·손상 구조·없는 실험을 가리키는 안정 근거는 원본을 덮어쓰지 않고 보호한다. 과거 스냅샷은 새 규칙으로 다시 계산하거나 새 성공 근거로 자동 승격하지 않는다.

실제 플레이어 저장은 테스트에서 읽거나 수정하지 않았다. 마이그레이션 검사는 프로젝트 내부 복사본/fixture에서만 수행했다. 기존 목록 필드의 이름·표현은 v3 역할 구조로 바뀌며 원본 바이트는 백업으로 보존한다. OS 정전/강제 종료 중의 모든 파일 시스템 장애를 보장하는 내구성 검증은 하지 않았다.

## 실행한 헤드리스 자동 검사

엔진: `Godot 4.7.2.stable.official.ed1daf0bf`, Windows.

| 검사 | 최종 결과 |
|---|---|
| `tests/test_awakening.gd` | 55개 통과 / 실패 0 |
| `tests/test_awakening.gd -- --verify-restart` | 별도 프로세스 5개 통과 / 실패 0 |
| 기존 `tests/test_combat.gd` | 51개 통과 / 실패 0 |
| 갱신 `tests/test_research.gd` | 60개 통과 / 실패 0 |
| `tests/test_research.gd -- --verify-restart` | 별도 프로세스 5개 통과 / 실패 0 |
| 갱신 `tests/test_chant.gd` | 63개 통과 / 실패 0 |
| `tests/test_chant.gd -- --verify-restart` | 별도 프로세스 5개 통과 / 실패 0 |
| Godot headless editor import | 통과 |
| `git diff --check` | 통과 |

헤드리스 assertion 244개. 36조합의 도달 가능성/결정론/첫 입력 비공개/전체 모델 획득 흐름은 묶음 assertion으로 계산했다. 주요 인수 대응은 다음과 같다.

| 요구 | 실제 검사 |
|---|---|
| 미개화 시작 / 단서·실험은 슬롯 미소모 | 모델과 실제 Main/저장/GUI |
| 여섯 공명 및 친화·상극 차이 / 모두 획득 가능 | 36조합 시뮬레이터와 의식·확정 모델 흐름, 5개 상극 간선의 양방향 |
| 준비 없이 확정 불가 / 성공 후 취소 | 단서 없음·안정 근거 부족·같은 ID 중복·형상/방향 부족·취소/지난 표식·잘못된 목표 거부 |
| 원하는 비친화 주속성 1개 저장 | 실제 Main에서 선천 木, 목표 土 확정 및 새 장면/새 엔진 프로세스 로드 |
| 두 번째/우회 확정 거부 | 구 Phase 2A API·가짜 확인·다른 주속성·보조 획득 차단 |
| 이전 데이터 보존 | v0/v1/v2 fixture, 원본 백업 동일성, 키 표·재능·일지·메모·이전 슬롯/추가 필드 비교 |
| 저장 실패/잘못된 근거 | 역할/슬롯 동시 복원 및 원본 바이트 보존, 없는 실험 근거 보호 |
| 기존 전투/기록 회귀 | 기존 전투 51개 그대로, 개인 영창·상태 판정·일지·3슬롯 상태 전투·저장 검사 |

기존 연구 검사의 “B에서 새 속성을 3개 바로 확정”은 최신 규칙과 충돌하므로 개화 우회 거부와 이미 확정된 3슬롯 fixture 보존으로 바꿨다. 새 획득의 영구 확인·취소·재시작·중복 차단은 신규 개화 검사가 담당한다. 실험으로 관찰 지식은 추가되므로 이전의 “연구 객체 전체 불변” 비교는 영구 역할/친화성 불변 비교로 수정했다. 기록/메모 자체의 보존 비교는 계속 수행한다.

## 실제 Godot 창 실행 검증

OpenGL 3.3 / Intel Iris Xe 호환 렌더러, 1160×720에서 엔진에 합성 키/마우스 이벤트를 전달했다. **사람의 손 조작 플레이테스트와 구분한다.**

| 검사 | 최종 결과 |
|---|---|
| `tests/preview_awakening.gd` | 24개 통과 / 실패 0 |
| 기존 `tests/preview_laboratory.gd` | 22개 통과 / 실패 0 |
| 개발자 플래그를 지정한 연구실 | 3개 통과 / 실패 0 |
| 갱신 `tests/preview_research.gd` | 9개 통과 / 실패 0 |
| 기존 `tests/preview_combat.gd` | 9개 통과 / 실패 0 |

실제 창 assertion 67개. 새 전체 흐름은 선천 木인 테스트 캐릭터로 **土 선택 → 책/스승 → 직접 2회 공명 → 의식 → 취소 → 金을 새 목표로 탐구 → 의식 → 영구 확인 → 주속성 金 저장 → 다른 의식 차단 → 던전 입장**을 실행했다. 대상 드롭다운·책/멘토·재생·취소/확정 버튼을 실제 GUI 이벤트로 조작했다. 의식 버튼이 입력을 자동 생성하지 않는 것도 확인했다. 기존 이동/초집중·WASD·마력탄·HUD·연구실 비교/메모/회복도 별도 실행했다.

헤드리스 244 + 실제 창 67 = **311개 검사 통과, 최종 실패 0**. 화면 저장/해상도 검사도 이 수에 포함한다. 서로 다른 수동 플레이 시나리오 311개를 사람이 실행했다는 뜻은 아니다.

생성한 새 이미지: `awakening_clues.png`, `awakening_first_word.png`, `awakening_confirmation.png`, `awakening_committed.png`, `awakening_dungeon.png`. 단서·첫 입력·영구 확인·확정 후 역할 화면과 기존 3슬롯 조회 화면을 이미지로 열어 레이아웃/한국어/숨김 정책을 검토했다.

작업 중 수정: 새 테스트 헬퍼의 비정적 비교 함수를 클래스에서 호출한 파싱 오류를 정적 함수로 수정했다. 기존 단순 확정·v2 표현·실험의 지식 불변을 전제로 한 회귀 기대값은 최신 규칙에 맞춰 위와 같이 갱신했다. GUI 드롭다운 테스트에서 첫 Down이 0번 항목을 가리키는 동작을 보완해 대상 오선택으로 연쇄 실패하던 검사를 재실행했다. 이전 저장 재실행 fixture의 단서 1개 기대를 맞추기 위해 실제 구 단서가 있는 복사본으로 검사했다. 중간 실패를 최종 통과로 간주하지 않았으며 최종 로그에는 스크립트 오류/실패가 없다.

## 재현 명령과 증거

`$Godot`은 로컬 Godot console 실행 파일 경로로 설정한다.

```powershell
& $Godot --headless --path . --editor --import --quit
& $Godot --headless --path . --script tests/test_awakening.gd
& $Godot --headless --path . --script tests/test_awakening.gd -- --verify-restart
& $Godot --headless --path . --script tests/test_combat.gd
& $Godot --headless --path . --script tests/test_research.gd
& $Godot --headless --path . --script tests/test_research.gd -- --verify-restart
& $Godot --headless --path . --script tests/test_chant.gd
& $Godot --headless --path . --script tests/test_chant.gd -- --verify-restart
& $Godot --path . --audio-driver Dummy --rendering-driver opengl3 --script tests/preview_awakening.gd
& $Godot --path . --audio-driver Dummy --rendering-driver opengl3 --script tests/preview_laboratory.gd
& $Godot --path . --audio-driver Dummy --rendering-driver opengl3 --script tests/preview_laboratory.gd -- --chant-debug
& $Godot --path . --audio-driver Dummy --rendering-driver opengl3 --script tests/preview_research.gd
& $Godot --path . --audio-driver Dummy --rendering-driver opengl3 --script tests/preview_combat.gd
```

창 검사는 한 번에 하나씩 실행한다. 로그·개화 fixture·원본 코드 사본·새 PNG는 Git에서 제외한 `.task002_artifacts/phase2b2/`에 보관한다. 핵심 로그는 `awakening_tests/awakening_restart/research_tests/research_restart/chant_tests/chant_restart/combat_tests/awakening_preview/lab_preview/developer_preview/research_preview/combat_preview/import.log`다. 기존 스크립트 자체의 화면/fixture는 이전 `.task002_artifacts/phase2a/`, `phase2b1/`, 최상위에도 남는다.

## 플레이 방법 / 미검증 / 남은 범위

1. 거점 L → **단서 / 개화**에서 원하는 대상을 고르고 마법서적과 스승 단서를 읽는다.
2. 자유 실험으로 돌아가 Shift 유지 또는 두 번 → 개인 영창 → 방출/기록으로 관찰한다. 단서가 설명하는 축적·응집·안정화·공명의 변화를 기록/재생/비교하며 같은 대상의 안정 공명을 2회 재현한다.
3. 다시 단서/개화에서 의식을 시작하고 새 영창으로 공명과 형상·방향을 완성한다. 영구 확인을 취소하면 더 탐구할 수 있고, 확인하면 해당 주속성 1개만 저장한다.
4. 이미 3슬롯을 가진 캐릭터는 기존 확정 대상 중 하나를 같은 의식으로 주속성 지정한다. 기존 저장을 지우거나 초기화할 필요가 없다.

사용자가 통과한 것은 **이전 Phase 2B-1 수동 8항목**이다. 이번 명세의 새 수동 체크리스트는 아직 사람이 실행하지 않았으므로 미검증이다. 특히 단서만으로 원리를 추론할 수 있는지, 친화/상극 난도가 납득되는지, 취소/영구 확인 문구를 이해하는지, 실제 키보드 손맛을 확인해야 한다. 장시간 플레이·대용량 일지·다른 Godot 버전·Windows 배포 빌드·OS 강제 종료/정전 복구도 미검증이다.

이번 범위에서 확인한 최종 실패/알려진 재현 결함은 없다. 임시 텍스트 기반 공명이며 완성 마을·원소별 전투 이펙트·동적 환경은 제공하지 않는다. 보조속성 정식 획득, 복합 결속/재선언, 고위 파생·시그니처·축약 연구, 육체 성장/초월감각 제한 변경, 경제/인벤토리/네트워크는 구현하지 않았다.
