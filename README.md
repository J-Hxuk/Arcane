# Arcane Legacy — Godot 2D 탑뷰 프로토타입

최신 구현은 **Phase 2B-2.5B 연구·시전 경험 개선 및 火 심화 연구**다. 기초 개인 영창 단축, 안전 연구실의 실제 마법 발현, 발견 영창 저장/J HUD, 여섯 속성 공용 이펙트, 화염창·화염폭발을 추가했다. [구현 보고서·스크린샷·검증](IMPLEMENTATION_REPORT_PHASE_2B_2_5B_KO.md)을 참조한다. 기존 [연구실 마나 시각화](IMPLEMENTATION_REPORT_LAB_MANA_VISUALIZATION_KO.md)의 스냅샷 재생을 유지한다.
기존 **Phase 2B-2.5A 단일 속성 기초 전투마법**, [Phase 2B-2 최초 개화 명세](Arcane_Legacy_Phase_2B-2_First_Awakening_Spec.md)와 [GDD](GDD_v1_0_KO.md)·[v1.2](Arcane_Legacy_Magic_Research_Spec_v1_2.md)의 확정 규칙을 유지한다. Phase 2B-3A 복합마법 개발은 보류했다.
여섯 속성의 공명·단서·개화에 이어, 개화한 주속성의 실제 던전 전투마법을 연결했다. 변경·검증은 [2B-2.5A 보고서](IMPLEMENTATION_REPORT_PHASE_2B_2_5A_KO.md)에 정리했다.
거점 **L → 단서 / 개화**로 시작한다. **B**는 기존 영구 연구 상태 조회다. 개인 키 정답과 선천 친화성 수치는 일반 UI에 표시하지 않는다.

## 실행 및 조작

Godot에서 `project.godot`을 가져오고 F5로 실행한다. 실제 검증 엔진은 Godot 4.7.2이며 다른 4.x 버전은 미검증이다.

| 상태 | 입력 | 동작 |
|---|---|---|
| 거점 | 1 / 2 | 고정 / 변동 던전 입장 |
| 거점 | H | 기존 부상 회복 |
| 거점 | B / 연구 버튼 | 연구 상태 조회·연구실 안내 |
| 거점 | L | 연구실 진입 |
| 연구실 | Shift 유지 / 두 번, 직접 키 입력 | 개인 영창, WASD는 초집중에서만 입력 |
| 연구실 | 방출 / 기록 버튼 | 현재 영창 방출 시도·자동 실험 저장 |
| 연구실 | 시험장 / 관측·실험 일지 | 안전 표적의 실제 피해·상태 효과 확인 / 저장 스냅샷 관측으로 전환 |
| 연구실 | 회복 / 표적 초기화 | 자원 회복과 안전 시험장 재설정 |
| 연구실 | 두 실험 선택 + 이전/다음 | 스냅샷만 읽는 단계 재생·나란히 비교 |
| 연구실 | 각 기록의 재생 / 일시정지 / 시간 막대 | 저장된 시각에 따라 입력 전·후 구체를 재생·탐색, 재시뮬레이션 없음 |
| 연구실 | 메모 저장 / 회복 / 거점으로 | 가설 기록 / 마나·탈진 회복 / 귀환 |
| 단서 / 개화 | 대상 선택 → 서적 / 스승 | 해당 속성의 서로 다른 출처 단서 수집, 슬롯 소모 없음 |
| 단서 / 개화 | 안정 공명 2회 재현 후 의식 시작 | 새로운 세션에서 직접 영창, 형상·방향까지 완성 |
| 의식 성공 | 주속성 영구 확정 / 취소 | 확인 전 슬롯 변화 없음, 주속성 1개만 확정 |
| 일반 전투 | WASD, 마우스 조준 + LMB | 이동, 검 공격 |
| 일반 전투 | F | 유실물 회수 / 출구에서 귀환 |
| 이동 시전 | Shift 유지 | 시전 모드, WASD는 계속 이동 |
| 초집중 시전 | Shift 빠르게 두 번 | 초집중 토글, 이동 정지, WASD도 커맨드로 사용 |
| 시전 모드 | Q → E → LMB | 기초 마력탄 직접 시전 |
| 시전 모드 | RMB / Esc | 큐 취소, 초집중이면 일반 전투로 복귀 |
| 시전 모드 | F | 상호작용 대신 커맨드 입력 |
| 던전 | Alt 유지 | 기존 초월 감각 시험 |
| 던전 | J / 발견 영창 HUD | 펼침·접기, 페이지·즐겨찾기·대표 영창 변경. 자동 시전 없음 |

보조 커맨드는 Q/E/R/F/Z/X/C/V/T/G, 초집중 추가 커맨드는 W/A/S/D다.
기존 튜토리얼 `Q → E → LMB`를 그대로 유지한다. 개인 영창은 첫 C로 속성 비의존 시전을 시작하거나 개인 속성어로 시작한 뒤 후속 조작을 입력한다.
같은 키라도 첫 입력과 후속 입력의 해석은 다르다. 대응표는 캐릭터마다 한 번 생성해 저장하며 로드할 때 재추첨하지 않는다.
개인 영창은 최종 마나 구조로 판정한다. 기초 마력탄은 개인 영창 3입력(기존 Q→E도 유지), 여섯 기초 속성마법은 속성 선언 포함 5입력으로 완성 가능하다. 개화한 주속성의 마나·응집·안정·형상·방향을 요구하며, 기초 전투마다 개화 의식의 공명을 반복할 필요는 없다. 연구실의 안정 공명 2회·단서·영구 개화 조건은 유지한다. 火 심화는 더 많은 마나와 안정 공명, 집중/넓은 형상 조건이 추가된다. 특정 키 공식이나 자동 시전 버튼을 추가하지 않았다.
연구실의 완성된 마법은 **발현 성공 · 주문 이름** 표시와 함께 안전 시험장에서 던전과 같은 효과로 나타난다. 공명만 성공하면 **공명 성공 · 전투마법은 아직 발현되지 않았습니다**로 구분한다. 실제 발현한 개인 영창만 저장하여 던전 J HUD에 표시한다. 복수 경로·대표 영창·즐겨찾기·입력 유지/겹침을 보관하고, 키의 내부 의미나 미발견 정답은 공개하지 않는다.
서적과 스승은 개인 키 정답 대신 관찰·축적·응집·안정화·공명의 원리를 알려준다. 안정 공명을 서로 다른 실험 기록으로 2회 재현한 뒤 의식에서 형상·방향까지 직접 완성하면 영구 확인 창이 열린다.
선천 친화·양방향 상극·단서는 제어 조건을 바꾸며 확률 재시도나 영구 봉쇄를 만들지 않는다. 無는 오행 간섭 고리 밖이다.
모든 발동에 직접 커맨드를 다시 입력해야 한다. 재생 버튼은 과거 마법을 발동하지 않는다.
주속성 전투 효과는 木 덩굴 속박(이동 정지), 火 불씨 탄(연소), 土 돌 장벽(5초간 양측 이동·투사체 충돌), 金 관통 쇠창(최대 3적), 水 밀물 탄(벽까지 밀기), 無 힘의 파동(주변 광역 피해·밀기·짧은 경직)이다. 전투 비용은 주문 기본 비용 + 영창 조작 손실이다. 장벽은 마우스 방향 95 거리의 열린 공간에만 설치되며 적·벽·출구에 겹치면 마나를 쓰지 않고 영창을 유지한다.
화면에 입력 상태, 누적 커맨드, 마나, 미완성·오입력·마나 부족 피드백이 표시된다.
연구실 왼쪽은 실시간 마나 구체, 오른쪽 두 열은 각각 선택한 실험의 입력 전/후 장면이다. 크기·밀도·밝기·형상·결속선·입자 흐름·회전·떨림·갈라짐을 비교한다. 첫 속성어는 모두 같은 중립 장면이고, 개인 키 의미·친화성·내부 상태 수치는 표시하지 않는다. 플레이어 자원인 현재/소모 마나와 기록 시간은 기존처럼 표시한다.
재생은 기록된 `before`/`after`와 입력 시각·유지시간만 읽는다. 현재 키 표로 과거 실험을 다시 해석하지 않으며, 기록의 원문 관찰도 유지한다. `실패 단계 없음`은 저장값 0을 뜻하고, 실제 첫 입력 오류는 `입력 오류: 1번째 입력`이다. 미완성과 붕괴는 별도로 표기한다.

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
- `scripts/character_research.gd`: 주속성·보조 역할·기존 미배정 슬롯·단서·공명 근거, 의식과 일회성 영구 확인 표식 검증.
- `scripts/character_save.gd`: v0/v1/v2 → v3 이전, 원본 백업, 임시 파일 저장, 알 수 없는 필드 보존.
- `scripts/research_panel.gd`: B 연구 상태 조회. 기존 단순 확정 경로는 개화 절차를 우회하지 못하도록 차단.
- `scripts/resonance_rules.gd`, `data/elements/*.tres`: 여섯 공명 요구치·관찰 문구·책/멘토 단서·상생/상극 제어 조건.
- `scripts/awakening_panel.gd`: 임시 서고/스승 상호작용·단서 일지·의식 준비·영구 확인. 새 마을은 만들지 않음.
- `scripts/chant_profile.gd`: 캐릭터 시드·버전·첫 속성어 6키/후속 조작 14키의 저장된 대응표.
- `scripts/mana_simulator.gd`: 순수 결정론적 상태 기계·마나 변화·최종 구조 판정·관찰 표현. 연구실/던전 공용.
- `scripts/experiment_journal.gd`: 실험별 입력 시간·유지시간·전후 스냅샷·소모·실패 위치·메모와 읽기 전용 재생/비교.
- `scripts/laboratory_panel.gd`: 일반 관찰 UI. 정답 표시는 디버그 빌드의 명시적 `--chant-debug` 실행에서만 별도 창으로 제공.
- `scripts/mana_visual_model.gd`, `scripts/mana_orb_view.gd`: 저장 상태를 읽는 순수 시각 투영과 결정론적 Godot 2D 구체. 키/친화성/실제 마법 실행과 분리.
- `tests/test_mana_visuals.gd`, `tests/preview_mana_visuals.gd`: 시각 차이·기록 불변·실시간 일치·시간축·실제 창 픽셀/움직임/배치 검증.
- `scripts/spell_definition.gd`, `data/spells/mana_bolt.tres`: Resource 기반 주문 데이터.
- `data/spells/{wood_bind,fire_ember,earth_barrier,metal_lance,water_push,void_wave}.tres`: 단일 속성 기초 전투 데이터 6개, 고정 커맨드 없음.
- `scripts/combat_spell_resolver.gd`: 시뮬레이션 최종 상태와 영구 주속성에서 전투 주문/비용 판정.
- `scripts/elemental_combat.gd`: 투사체·상태 효과·장벽·충격파·충돌·시각 피드백, 전투 중에만 존재.
- `scripts/laboratory_arena.gd`, `scripts/spell_vfx.gd`: 안전 표적과 연구실/던전 공용 덩굴·불꽃·암석·쇠창·유체·압력파 그림. 물리 판정과 분리.
- `scripts/spell_discoveries.gd`, `scripts/spell_record_hud.gd`: 실제 성공 입력·유지/겹침·복수 경로·즐겨찾기 저장, 던전 J 조회 HUD.
- `data/spells/fire_lance.tres`, `data/spells/fire_blast.tres`: 火 단일 속성 심화 2개. 보조·복합 속성을 사용하지 않음.
- `tests/test_elemental_combat.gd`, `tests/preview_elemental_combat.gd`: 별도 캐릭터의 여섯 기능·개화 후 전투·실제 창 입력/렌더링 검증.
- `scripts/spell_book.gd`: 커맨드 판정·진행 피드백·필요 속성 접근 검사. 4속성 이상 조합은 거부.
- `tests/test_combat.gd`, `tests/preview_combat.gd`: 회귀 테스트 및 실제 렌더링/입력 전달 확인.
- `tests/test_research.gd`, `tests/preview_research.gd`: 연구·저장·별도 프로세스 재실행·실제 GUI 입력/렌더링 검증.
- `tests/test_chant.gd`, `tests/preview_laboratory.gd`: 개인 영창·기록·최종 상태·호환성·연구실 GUI 검증.
- `tests/test_awakening.gd`, `tests/preview_awakening.gd`: 36개 친화/목표 조합·개화/취소/저장·실제 GUI 전체 흐름.

기존 캐릭터 저장·재능·발견 기록·사망·유실물·고정/변동 던전 동작은 유지한다.
이전 실험 주문 EMBER/MEND/PULSE는 연구 조건 없이 발동하던 방식이어서 현재 시전 목록에서 제외했다.
기존 저장의 발견 이름은 삭제하거나 다른 주문으로 바꾸지 않는다.

저장 경로는 기존 `user://arcane_legacy_save.json`을 유지한다. 현재 v3는 `main_attribute`, `auxiliary_attributes`, `legacy_committed_attributes`를 영구 역할의 단일 원본으로 쓴다. `researched_base_elements` 조회는 이 역할들에서 계산하며 중복 저장하지 않는다.
v0/v1/v2 이전 전 `.v0.bak`/`.v1.bak`/`.v2.bak` 원본을 남긴다. 기존 재능·친화성·시드·키 표·슬롯·발견·유실물·실험 스냅샷·메모와 알 수 없는 필드는 보존한다.
기존 연구 목록은 `legacy_committed_attributes`로 옮기고 주속성을 임의 배정하지 않는다. 가득 찬 기존 캐릭터는 이미 확정한 속성 중 하나를 동일한 의식과 확인으로 주속성 지정할 수 있으며 슬롯 총수는 변하지 않는다.
기존 미기록 친화성 `{}`는 유지한다. 기록된 숫자의 유일한 최댓값을 공명 난도의 친화 기준으로 읽으며, 비어 있거나 동률이면 중립 처리한다. 새 캐릭터만 높은 친화성 1개를 생성한다(임시 85/나머지 25). 공명 난도 계수는 임시이며 전투 피해 배율은 바꾸지 않는다.
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
& $Godot --headless --path . --script tests/test_awakening.gd
& $Godot --headless --path . --script tests/test_awakening.gd -- --verify-restart
& $Godot --headless --path . --script tests/test_elemental_combat.gd
& $Godot --headless --path . --script tests/test_mana_visuals.gd
& $Godot --headless --path . --script tests/test_phase2b25b.gd
& $Godot --headless --path . --script tests/test_discoveries_restart.gd
& $Godot --path . --script tests/preview_phase2b25b.gd
& $Godot --path . --audio-driver Dummy --rendering-driver opengl3 --script tests/preview_mana_visuals.gd
& $Godot --path . --audio-driver Dummy --rendering-driver opengl3 --script tests/preview_elemental_combat.gd
& $Godot --path . --audio-driver Dummy --rendering-driver opengl3 --script tests/preview_awakening.gd
& $Godot --path . --audio-driver Dummy --rendering-driver opengl3 --script tests/preview_laboratory.gd
& $Godot --path . --audio-driver Dummy --rendering-driver opengl3 --script tests/preview_research.gd
& $Godot --path . --audio-driver Dummy --rendering-driver opengl3 --script tests/preview_combat.gd
```

테스트 세이브·로그·이미지는 Git에서 제외한 `.task002_artifacts/`에 둔다.
실제 플레이어의 `user://arcane_legacy_save.json`은 테스트에서 사용하지 않는다.
렌더링 검사는 한 번에 하나씩 실행한다. 현재 결과는 [2B-2.5B 보고서](IMPLEMENTATION_REPORT_PHASE_2B_2_5B_KO.md), 이전 기록은 [시각화](IMPLEMENTATION_REPORT_LAB_MANA_VISUALIZATION_KO.md)·[2B-2.5A](IMPLEMENTATION_REPORT_PHASE_2B_2_5A_KO.md)·[2B-2](IMPLEMENTATION_REPORT_PHASE_2B_2_KO.md)·[2B-1](IMPLEMENTATION_REPORT_PHASE_2B_1_KO.md)·[2A](IMPLEMENTATION_REPORT_PHASE_2A_KO.md)에 정리했다.

보조속성 정식 획득·복합 결속/재선언·고등/시그니처·신체강화 효과·상점·완성 마을·멀티플레이·배포 빌드는 이번 작업에 포함하지 않았다.
사용자가 Phase 2B-2까지 완료를 보고했다. 이번 전투마법은 자동 및 실제 Godot 창의 합성 입력으로 검증했으며 사람의 장시간 수동 조작감·난도 밸런스는 미검증이다.
