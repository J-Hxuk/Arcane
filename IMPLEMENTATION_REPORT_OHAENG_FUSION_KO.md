# 오행 융합 A~D 구현·검증 보고서

> **문서 정리(2026-10-23):** 아래의 과거 구현 보고서 링크는 삭제 전 Git 커밋에 고정된 역사 기록입니다. 현재 구현 및 확정 규칙은 최신 코드와 후속 문서를 우선합니다.

> 후속 [Fusion-UX2](https://github.com/J-Hxuk/Arcane/blob/5da9e9a497c64941f29792948a2c5b0ffa53a182/IMPLEMENTATION_REPORT_FUSION_UX2_KO.md)에서 **F5 → F2 개발 진입**, 연구실 **Shift 해제 자동 방출·기록**, 던전 이동 시전 **80% 속도**를 적용했다. 아래 CMD 필수 및 연구실 버튼 방출 설명은 A~D 당시 기록이다. 주문·계보·슬롯 규칙은 유지한다.

작업일: 2026-10-17, 한국 시간. 기준은 [오행 융합 GDD v1.0](Arcane_Legacy_GDD_Ohaeng_Fusion_v1_0_KO.md), [Codex 구현 명세 v1.0](Arcane_Legacy_Codex_Ohaeng_Fusion_Implementation_v1_0_KO.md), 이후 사용자의 D 세 주문 확장 지시다. 개인 키표·최종 상태 판정·RMB 이동·Shift 이동/초집중·Ctrl 회피·Alt·연구실·J HUD를 유지했다.

## 1. 단계 순서와 검증 관문

[사전 영향도·이전 정책](FUSION_MIGRATION_ANALYSIS_KO.md)을 코드 변경 전에 작성하고 시작 시점의 미커밋 코드/데이터/장면/테스트/설정을 `.task002_artifacts/fusion/pre_fusion_workspace.zip`에 백업했다. 기준 커밋은 `22d8309`이며 기존 UX1 변경과 사용자 명세를 되돌리거나 커밋하지 않았다.

D 리소스 추가 **이전** A 35개, B 12개, C 52개가 모두 통과했다. [D 진입 관문 기록](.task002_artifacts/fusion/checkpoints_before_d.md), [A 로그](.task002_artifacts/fusion/checkpoint_a.log), [B 로그](.task002_artifacts/fusion/checkpoint_b.log), [C 로그](.task002_artifacts/fusion/checkpoint_c.log)를 남겼다.

이후 빙정침만 추가해 자동 26개·실제 창 24개 통과 → 빙정방벽 추가 후 자동 50개·창 35개 통과 → 풍압탄 추가 후 자동 70개·창 50개 통과 순서로 진행했다. 로그는 각각 `checkpoint_d1/d2/d3.log`, `window_d1/d2/d3.log`다. 마지막에는 아래 최종 회귀 검사를 별도로 실행했다. 초기 중간 실패 로그를 최종 통과 수에 합산하지 않는다.

## 2. A: 다섯 오행과 순수 마나 / 저장 v4

- 기본 원소 레지스트리는 木·火·土·金·水 다섯 개다. 옛 VOID 리소스 식별자는 중립 호환 레지스트리에 남긴다. `VOID_WAVE` ID와 기존 기록을 유지하되 요구 원소는 빈 목록이다.
- ChantProfile의 여섯 첫 선언과 14개 조작 키는 **기존 표 그대로** 유지한다. VOID 대응 키는 중립 동력 문맥을 열고 오행 집합에 들어가지 않는다. C 시작 순수 마나볼트와 QE 튜토리얼을 보존한다.
- 새 캐릭터만 다섯 오행 중 하나의 높은 친화 점수를 받는다. 기존 친화 수치·미지 필드는 변경하지 않는다. 옛 VOID가 최고인 경우 이를 새 오행 친화성으로 해석하거나 재추첨하지 않는다.
- 구 VOID 역할은 `neutral_mana.original_roles`, 기존 충격파 권한과 전환 대기 상태로 보존한다. VOID 주속성은 다른 오행으로 자동 치환하지 않는다. 연구실의 **기존 중립 역할 전환 확인** 후에도 새 주속성은 미지정이며 직접 의식이 필요하다. 오행 주속성+VOID 보조는 기존 오행 역할을 유지하고 중립 슬롯만 분리한다. `void/none/無` 옛 표기도 원문 역할 기록에 남긴다.
- v0~v3 파일은 정상 검증 후 `.v0.bak`~`.v3.bak` 원본 바이트 백업을 만들고 v4로 기록한다. 과거 일지의 규칙 버전·스냅샷·메모·개인 대응표·발견 주문·모르는 JSON 필드는 재시뮬레이션하거나 삭제하지 않는다. 손상·충돌 데이터는 읽기 전용 보호한다.

이번 작업은 실제 사용자 저장에 쓰지 않았다. 최종 검증 전후 실제 저장은 v3이고 SHA-256이 동일했다: `3bc274f331fb76e41e72f791ec733f6e5d20d0d2c6cf71813b211c56f6a905f9`. [검증 전](.task002_artifacts/fusion/player_before_final.log), [검증 후](.task002_artifacts/fusion/player_after_final.log). 앞으로 사용자가 일반 플레이를 실행하면 위 무손실 이전이 적용된다.

## 3. B: 첫 보조속성 개화

연구실 **단서 / 개화**에서 대상 오행을 고르고 서적·스승·환경 촉매 단서를 수집한다. 단서나 첫 선언만으로 슬롯을 소비하지 않는다. 안정 공명 2회와 주속성의 압력 속에서도 응집·형상을 유지한 간섭 안정화 실험이 필요하다. 현재 프로토타입의 간섭 증거 조건은 안정 공명의 응집 50 이상·형상 50 이상·안정 85 이상이며, 숫자는 일반 UI에 공개하지 않는다. 동일한 실제 실험이 두 종류의 증거를 모두 충족할 수 있다.

**직접 보조 개화 의식 → 영구 확인**에서만 보조 슬롯을 점유한다. 주속성은 변경하지 않는다. 취소·재도전·중복·잘못된 확인 표·구 `request_research` API 우회를 차단한다. 저장 실패 시 슬롯/연구 상태를 롤백한다. 실험 저장 실패 시 마나, 발현 효과, 일지, 발견 기록도 되돌린다.

획득한 보조의 단독 기초·하급은 허용하고 중급 이상은 차단한다. 기존 화염창/화염폭발은 중급 판정을 명시해 주속성에서의 기존 사용은 유지하며 보조 단독 우회를 막았다. 새 두 번째 보조 개화는 아직 제공하지 않는다. 기존 저장의 두 보조 및 3개 확정 슬롯은 삭제하지 않고, 기존 미지정 슬롯의 역할 지정은 새 획득과 구분한다.

## 4. C: 결속 문법·권한·시각화

보조 개화와 간섭 연구 후 서고의 **결속 원리 연구**를 누르면 해당 주속성+보조의 연구 문맥을 저장한다. 문법은 첫 선언 → 마나 조작 → 충분한 마나와 안정화로 결속 창 열기 → 연구된 상대 원소 재선언 → 후속 조작이다. 안정화 직후의 재선언 문맥에서만 상대의 첫 단어 뜻을 읽는다. 그 외에는 기존 개인 조작어 뜻을 그대로 읽는다. 연속 두 선언은 결속되지 않는다.

최종 상태는 정렬된 `base_attributes`, 원소별 공명, `binding_quality`, `interference`, 형상, 흐름을 갖는다. 순서가 바뀌어도 같은 최종 구조이면 같은 리소스를 고른다. 상생/상극·선천 친화·문헌/스승 지식이 결속 간섭과 안정화 난도에 반영되며 랜덤 성공 판정은 없다. 준비된 결속은 50의 원소별 공명을 유지하는 최소 상태이며, 높은 결속 연구를 단축 실전 영창으로 재현하는 구조다.

최종 resolver와 파일 저장/불러오기 경계에서 **주속성 포함·확정 보조·연구한 결속·정확한 원소 계보**를 모두 검사한다. 두 보조만의 결속, 중립 참여, 水 단독 빙정, 火 또는 水 단독 바람, 미연구 결속을 거부한다. 세 원소 엔진은 제공하지 않는다.

일지의 `fusion_observations`는 현상 관찰이며 `spell_discoveries`의 실제 성공 전투술식과 별개다. 성공 영창의 원시 키·시간·홀드·규칙 버전·계보를 저장하고 J HUD와 즐겨찾기를 재사용한다. 재생은 당시 스냅샷과 연구 문맥을 읽으며 다시 시뮬레이션하지 않는다.

첫 키는 계속 중립이다. 결속 준비는 열린 호, 성공은 두 색의 잔광과 연결선, 부분 결속은 흔들리는 간격, 붕괴는 깨지고 흩어진 윤곽으로 표시한다. 모델 버전은 3, 새 시뮬레이터 규칙 버전은 5다. 옛 규칙 버전·스냅샷은 그대로 보존한다.

## 5. D: 세 주문과 임시 밸런스

| 주문 / 계보 | 등급 | 검증 입력 수 | 마나 | 실제 전투 효과 | 시각 효과 |
|---|---|---:|---:|---|---|
| 빙정침 / 水+金 | 하급 | 5 | 20 | 피해 22, 결정 구속 0.9초, 속도 520의 단일 타격 투사체 | 흰 결정 중심선·청색 결정침·파편·결정 구속 |
| 빙정방벽 / 水+金 | 중급 | 7 | 26 | 직접 피해 0, 전방 95에 반경 28 장벽, 6초간 이동·투사체 차단 | 청백색 육각 결정과 방사 격자 |
| 풍압탄 / 火+水 | 하급 | 5 | 18 | 피해 10, 밀기 175, 행동 방해 0.65초, 투사체 속도 460 | 물방울 대신 겹친 기류 호와 나선 압력 잔광 |

수치는 프로토타입 임시값이다. 기존 水는 비용 9/피해 12/밀기 135/방해 0.45초, 金은 비용 16/피해 24/세 적 관통, 土 장벽은 비용 16/반경 22/5초다. 빙정침은 金의 관통을 가져오지 않고 짧은 제어를 얻으며, 풍압탄은 水보다 비싼 대신 더 긴 밀기/방해를 얻는다. 빙정방벽은 흙 장벽보다 크고 오래 유지된다. 모든 투사체·밀기·장벽은 기존 충돌과 만료 규칙을 따른다. DPS 균형의 사람 플레이 평가는 미검증이다.

빙정방벽은 적·자신·벽·출구와 겹치지 않는 열린 공간을 조준해야 한다. 세 주문 모두 연구실과 던전에서 공통 `ElementalCombat`을 사용한다. 고정 문자열 레시피나 자동 영창을 추가하지 않았다. 압축 등 경로에 따라 에너지 손실 비용이 더 붙을 수 있다.

## 6. 현재 키표의 실제 검증 커맨드

실제 저장의 키표만 읽기 전용으로 복사해 **메모리 임시 Water+Metal / Fire+Water 캐릭터**에서 검증했다. [로그](.task002_artifacts/fusion/current_commands.log). 실제 저장 캐릭터의 주속성·보조 슬롯은 변경하지 않았다.

| 주문 | 정방향 | 역방향 |
|---|---|---|
| 빙정침 | `X → T → Z → F → C` | `F → T → Z → X → C` |
| 빙정방벽 | `X → T → Z → F → R → R → C` | `F → T → Z → X → R → R → C` |
| 풍압탄 | `Q → T → Z → X → C` | `X → T → Z → Q → C` |

다른 캐릭터는 키표가 다를 수 있다. Shift를 누른 채 키를 순서대로 짧게 눌렀다 떼고, 던전에서는 Shift를 유지해 조준 후 좌클릭으로 방출한다. 연구실은 **방출 / 기록** 버튼을 사용한다. 초집중 시전도 동일한 원소/최종 상태 해석을 재사용한다. 위 5/7/5는 대표 예시이며 최소 입력이나 유일한 정답이라고 주장하지 않는다.

## 7. 개발 시험

기존 [Start_Developer_Lab.cmd](Start_Developer_Lab.cmd)를 더블클릭하거나 `-- --dev-lab`으로 실행한다. 일반 F5만으로는 개발 UI가 켜지지 않는다. **F2** 또는 오른쪽 위 개발 시험 버튼 → **WATER_METAL** / **FIRE_WATER** → 연구실/던전 → 임시 캐릭터 시작 순서다. 다섯 오행 단독과 **중립 마나 (舊 無)** 시험도 남겼다.

임시 캐릭터는 실제 키표를 복사한다. 두 슬롯·결속 연구는 임시 문서에만 있으며 기록·발견·사망·복귀도 메모리로 분리한다. F2 → **시험 종료 · 원래 플레이 복귀**로 원래 캐릭터/위치/진행을 복원한다. 메뉴 닫기는 시험 종료가 아니다. 실제 사용자 주속성을 시험용으로 바꾸지 않는다.

## 8. 최종 검증 결과

자동 테스트와 실제 창 검사는 구분한다. 창 검사는 Godot 렌더러와 합성 키/마우스 이벤트를 사용했으며 사람의 수동 플레이가 아니다. 모두 격리 세이브 또는 메모리 임시 캐릭터다.

| 자동 검사 | 통과 / 실패 |
|---|---:|
| 기존 입력·연구·영창·개화·전투·시각화·2B25B·UX1 | 520 / 0 |
| A 무손실 이전 | 43 / 0 |
| A 별도 프로세스 재시작 | 6 / 0 |
| B 첫 보조 개화·롤백·권한 | 12 / 0 |
| C 양방향·미연구/보조끼리/중립 차단·난도·시각화 | 68 / 0 |
| D 세 주문 / 두 방향 / 연구실·던전 | 70 / 0 |
| 융합 실제 저장·실패 롤백 | 8 / 0 |
| 융합 별도 프로세스 재시작 | 4 / 0 |
| 기존 재시작 5종 | 21 / 0 |
| **합계** | **752 / 0** |

| 실제 Godot 창 합성 입력 검사 | 통과 / 실패 |
|---|---:|
| 새 융합 3종: 선택·영창·전투·시각화·J·복귀 | 50 / 0 |
| 새 보조 개화: 단서·실험·의식·영구 확인·결속 연구 | 9 / 0 |
| UX1: 이동·회피·시전·Alt·개발 시험·관측 | 61 / 0 |
| 기존 연구실 / 마나 시각화 / 개화 | 22 + 27 + 24 / 0 |
| 기존 원소·중립 전투 / 연구 상태 / 2B25B / 입력 | 42 + 9 + 50 + 9 / 0 |
| **합계** | **303 / 0** |

최종 로그는 `.task002_artifacts/fusion/final_*.log`다. 예전 중간 로그와 구분한다. 기존 테스트의 옛 여섯 영구 원소/보조 미구현/고정 키 복합 허용 기대값은 최신 오행·중립·보조 의식·결속 문법으로 갱신했다. 네 번째 오행 차단 검사는 세 오행 fixture로 유지하고, VOID 슬롯 이전은 전용 A 검사로 분리했다. 회귀 중 발견한 중립 충격파의 마나볼트 덮어쓰기와 기존 확정 슬롯 의식의 확인창 누락을 수정했다.

## 9. 스크린샷

| 장면 | 이미지 |
|---|---|
| 보조 개화 단서와 진행 | [서고](.task002_artifacts/fusion/auxiliary_clues.png) |
| 직접 의식 후 영구 확인 | [보조 확인창](.task002_artifacts/fusion/auxiliary_confirmation.png) |
| 빙정침 연구실 / 던전 | [연구실 구속](.task002_artifacts/fusion/lab_effect_ICE_CRYSTAL_NEEDLE.png), [던전 결정침](.task002_artifacts/fusion/dungeon_flight_ICE_CRYSTAL_NEEDLE.png) |
| 빙정방벽 연구실 / 던전 | [연구실 결정벽](.task002_artifacts/fusion/lab_effect_ICE_CRYSTAL_BARRIER.png), [던전 결정벽](.task002_artifacts/fusion/dungeon_effect_ICE_CRYSTAL_BARRIER.png) |
| 풍압탄 연구실 / 던전 | [연구실 기류](.task002_artifacts/fusion/lab_flight_WIND_PRESSURE_BOLT.png), [던전 기류](.task002_artifacts/fusion/dungeon_flight_WIND_PRESSURE_BOLT.png) |
| 당시 결속 상태 / 발견 영창 | [결속 구체](.task002_artifacts/fusion/binding_WATER_METAL_ICE_CRYSTAL_BARRIER.png), [J HUD](.task002_artifacts/fusion/j_WIND_PRESSURE_BOLT.png) |

## 10. 주요 변경 파일과 재현

`ohaeng_migration.gd`, `base_elements.gd`, `chant_profile.gd`, `character_research.gd`, `character_save.gd`, `fusion_rules.gd`, `mana_simulator.gd`, `combat_spell_resolver.gd`, `spell_definition.gd`가 분류·이전·권한·상태 판정을 담당한다. `awakening_panel.gd`, `research_panel.gd`, `main.gd`, `developer_test_data.gd`, `developer_test_panel.gd`를 기존 UI/흐름에 연결했다. `mana_visual_model.gd`, `mana_orb_view.gd`, `spell_vfx.gd`, `elemental_combat.gd`, `laboratory_arena.gd`, `spell_discoveries.gd`를 재사용·확장했다. 신규 주문 리소스는 정확히 세 개다.

프로젝트 폴더에서 `$Godot`에 기존 실행 파일 경로를 지정한 뒤:

```powershell
& $Godot --headless --path . --script tests/test_fusion_a.gd
& $Godot --headless --path . --script tests/test_fusion_a_restart.gd
& $Godot --headless --path . --script tests/test_fusion_b.gd
& $Godot --headless --path . --script tests/test_fusion_c.gd
& $Godot --headless --path . --script tests/test_fusion_d.gd -- --expect=3
& $Godot --headless --path . --script tests/test_fusion_persistence.gd
& $Godot --headless --path . --script tests/test_fusion_persistence.gd -- --verify-restart
& $Godot --path . --script tests/preview_fusion.gd
& $Godot --path . --script tests/preview_auxiliary.gd
```

사람이 추가 확인할 항목 다섯 개: (1) RMB 이동 중 5입력 융합 방출 감각, (2) 초집중에서 양방향 커맨드 직접 재현, (3) 빙정방벽 배치·우회·만료의 전술적 유용성, (4) 풍압탄 밀기의 비용 대비 체감, (5) 실험 기록을 보고 개인 키 의미를 추론할 수 있는지. 이 사람 플레이 평가와 장시간 밸런스는 **미검증**이다.

다른 조합의 전투마법·새 두 번째 보조 개화·3속성 엔진·마을·추가 스킬은 구현하지 않았다. 10조합 현상 표는 데이터/기획으로만 남겼다.
