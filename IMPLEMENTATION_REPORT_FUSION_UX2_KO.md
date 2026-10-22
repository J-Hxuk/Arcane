# Phase Fusion-UX2 구현·검증 보고서

작업일: 2026-10-17. [오행 융합 A~D](IMPLEMENTATION_REPORT_OHAENG_FUSION_KO.md)를 유지하면서 연구실 Shift 해제 자동 방출, F5 개발 시험 접근, 던전 이동 시전 20% 감속을 적용했다. 새 마법·12키 체계·두 번째 보조 개화·최종 극의는 추가하지 않았다. 시작 시점 코드·테스트·설정 백업은 `.task002_artifacts/fusion_ux2/before_ux2.zip`이다. 기존 미커밋 작업을 되돌리거나 커밋하지 않았다.

## 1. 사용 방법

1. Godot에서 `project.godot`을 열고 **F5**로 실행한다.
2. 실행된 **게임 화면에 포커스를 두고 F2**를 누르거나 오른쪽 위 **개발 시험 [F2]** 버튼을 누른다.
3. 오행 단일 5종·중립 마나·**WATER_METAL**·**FIRE_WATER**와 연구실/던전을 선택하고 임시 캐릭터를 시작한다.
4. 연구실은 **Shift 유지 → 직접 영창 → Shift 해제**로 한 번 자동 방출·기록한다. 던전은 기존 **Shift 유지 → 영창 → 조준·LMB**다. 초집중은 계속 명시적으로 방출한다.
5. F2 → **시험 종료 · 원래 플레이 복귀**로 원래 캐릭터·진행·연구 일지·발견 영창/J 상태를 복구한다. 메뉴 닫기는 시험 종료가 아니다.

`Start_Developer_Lab.cmd`와 `--dev-lab`은 디버그 호환 진입으로 남겼다. CMD 실행이나 에디터 실행 인수 설정은 더 이상 필요하지 않다. F8은 Godot 실행 중지이므로 사용하지 않는다. 일반 F5는 정상 게임을 시작하며 임시 캐릭터를 자동 생성하거나 슬롯을 바꾸지 않는다.

기존 예시 입력은 그대로다: WATER_METAL에서 빙정침 `X → T → Z → F → C`, 빙정방벽 `X → T → Z → F → R → R → C`; FIRE_WATER에서 풍압탄 `Q → T → Z → X → C`. 다른 캐릭터는 개인 키표에 맞는 개발 패널 예시를 따른다.

## 2. Shift 자동 방출 규칙

`CombatInput`이 실제 이동 시전 세션 종료를 별도 신호로 전달한다. 원시 Shift key-up에 바로 주문을 연결하지 않는다. 기존 0.3초 더블탭 후보는 영창 키 입력으로 무효화되며, **실제 영창이 들어간 MOBILE_CAST 세션의 마지막 Shift 소스 해제**만 제출한다. 0.3초 경계의 빈 더블탭은 제출하지 않는다. 좌우 Shift를 함께 잡았다면 둘 다 놓았을 때 한 번만 끝난다. 아직 누른 영창 키의 홀드 시간도 세션 종료 시 한 번 마감한다.

Main은 이 신호를 **연구실·이동 시전·비어 있지 않은 버퍼·편집/모달 아님** 조건에서만 받는다. 세션 자격을 먼저 소비하고 기존 `_cast_spell`과 공통 시뮬레이터/resolver/executor를 호출한다. 이후 성공·실패·마나 부족 모두 새 영창을 시작할 수 있도록 버퍼를 초기화한다. 같은 key-up 재전송이나 다음 프레임으로 실험·마나·일지가 중복되지 않는다. 수동 방출 버튼도 자동 제출 자격을 소비하며, 수동 실패 뒤 Shift 해제에 취소 기록을 중복 저장하지 않는다.

| 입력/상태 | 결과 |
|---|---|
| Shift를 잡고 영창한 뒤 해제 | 연구실에서 한 번 방출 시도·기록 |
| Shift 단독 탭 / 더블탭 중간 해제 | 방출·실험 생성 없음 |
| 초집중 Shift 해제 | 버퍼와 초집중 유지, 자동 방출 없음 |
| 던전 Shift 해제 | 기존 취소/일반 모드 복귀, 자동 방출 없음 |
| Esc / 창 포커스 상실 / 텍스트 편집 / 연구·개발 모달 / 연구실 종료 / 시험 캐릭터 변경 | 자동 방출 없음. 기존 취소 기록은 남을 수 있지만 마나 소비·전투 발현은 없음 |
| 개화 의식의 자동 방출 성공 | 의식 증거와 **수동 영구 확인창**까지만 생성 |
| 결속 원리 연구 / 슬롯 영구 확인 | 계속 명시적 버튼/확인 필요, 자동 승인 없음 |

완성된 주문은 기존 안전 시험장에서 발현·피해·상태효과·VFX를 수행한다. 안정 공명만 완성했으면 관찰 실험으로 기록하며 전투 발현/발견으로 표기하지 않는다. 미완성/붕괴는 실패 실험과 기존 마나 불안정 표시를 사용한다. 연구 일지·단계 재생은 당시 스냅샷을 그대로 사용한다.

기존 성공 실험 저장 실패의 마나·전투 효과·일지·발견 롤백을 유지하고, 실패 실험 저장 실패 시의 마나 페널티·탈진도 복구했다. 실패한 저장을 전투 발현 성공으로 표시하지 않도록 하고 개발 통계도 복구한다. 영구 개화의 저장 실패 롤백은 그대로다.

## 3. F5 개발 접근과 저장 격리

`DeveloperAccess.allowed`는 디버그 빌드이며 에디터 실행 파일의 프로젝트 런타임(`editor_runtime`) 또는 명시적인 개발 조건일 때만 허용한다. 실제 릴리스 빌드에서는 플래그나 시험용 선호값보다 거부 조건을 먼저 적용한다. `editor_runtime`은 에디터 실행 파일로 게임을 실행할 때의 태그이므로 F5/F6와 에디터 바이너리의 CLI 게임 실행도 포함한다. [Godot 공식 feature tag 문서](https://docs.godotengine.org/en/4.5/tutorials/export/feature_tags.html).

에디터 태그가 없는 디버그 템플릿은 `--dev-lab` 등 명시적 조건을 요구한다. 릴리스에서는 F2 패널 생성과 임시 캐릭터 시작을 모두 거부한다. 기본 프로젝트 설정/개인 영창 표/실제 슬롯을 바꾸거나 기본 프리셋을 강제하지 않는다.

개발 시험의 메모리 문서와 원래 플레이 스냅샷 복원을 재사용한다. 개발 중 일지·발견·즐겨찾기·사망 등은 실제 파일/백업에 쓰지 않는다. 임시 Water+Metal과 Fire+Water도 같은 원칙이다.

## 4. v3→v4 이전 및 실제 저장 확인

자동 검사에서 별도 v3 fixture를 **일반 초기 로드**로 열고, `.v3.bak`가 이전 전 원본 바이트와 정확히 같고 현재 문서가 v4인 것을 검사했다. 실제 Godot 에디터의 F5와 같은 메인 씬 실행 경로에서도 별도 복사 프로젝트·fixture를 사용해 이를 다시 검증했다.

이번 실제 파일 감사에서는 요청의 전제와 달리 저장이 **이미 v4**였다. 따라서 실제 파일의 최초 이전을 이번에 다시 실행하지 않았다. 기존 `.v3.bak`는 유효한 v3이고 해시는 앞선 A~D에서 확인한 원본과 같은 `3bc274f331fb76e41e72f791ec733f6e5d20d0d2c6cf71813b211c56f6a905f9`다.

실제 v4 파일은 감사 전후 `c75252f7b021e35a8bf53a6bbd04e080b42b17c8bbb9b822d85f4600ba4b3ac1`로 동일했다. 실제 주속성·보조 슬롯·키표·일지·J 기록에 쓰지 않았다. v3 백업을 단순 정규화한 문서와 현재 v4 전체는 동일하지 않으므로, 이미 존재하는 차이를 이번 이전 결과라고 주장하거나 되돌리지 않았다. [실제 감사 전](.task002_artifacts/fusion_ux2/actual_before.log), [읽기 전용 결과](.task002_artifacts/fusion_ux2/actual_after.log).

## 5. 던전 이동 시전 속도

이동 시전(MOBILE_CAST)에는 기본 속도 **200의 80%인 160**을 적용한다. RMB 목적지 이동과 호환 WASD 경로에 같은 배율을 사용한다. Shift 해제 후 기본 속도로 복귀한다. 초집중은 기존대로 정지하며 Ctrl 회피 속도·거리, 적 이동·투사체 속도·Alt 감각은 변경하지 않았다. HUD에 `Shift: cast / move 80%`를 표시한다.

## 6. 검증 결과

| 구분 | 통과 / 실패 | 내용 |
|---|---:|---|
| 신규 자동 검사 | **65 / 0** | 0.3초 경계·중복 key-up·좌우 Shift·홀드 마감·탭/초집중·취소/모달/편집·롤백·영구 수동 확인·이전·개발 조건·80% 이동 |
| 기존 자동/별도 프로세스 회귀 | **752 / 0** | 입력·연구·개화·마법·결속·일지·저장·v4 재시작 |
| **자동 합계** | **817 / 0** | 반복 실행은 합계에 중복 산입하지 않음 |
| 신규 실제 Godot 창 합성 입력 | **44 / 0** | 실제 키/마우스 이벤트로 자동 발현·일회 기록·F2·양 프리셋·세 주문·취소/모달·수동 영구 확인·복귀·감속 |
| 기존 실제 창 합성 입력 회귀 | **303 / 0** | UX1 61, 융합 50, 보조 9, 연구실 22, 시각화 27, 최초 개화 24, 전투 42, 연구 상태 9, 2B25B 50, 입력 9 |
| **창 합계** | **347 / 0** | 사람이 직접 플레이한 결과와 구분 |
| 실제 에디터 메인 씬 실행 통합 | **성공** | 별도 인수 없이 F5 경로로 자식 게임 실행 → F2 표시 → v3 원본 백업/v4 → 임시 시험 종료 시 문서·파일 복구 |

자동 로그는 `.task002_artifacts/fusion_ux2/unit.log`, `final_test_*.log`, `final_restart_*.log`다. 창 로그는 `window.log`, `final_preview_*.log`다. 기존 연구실 창 검사는 미완성 영창의 Shift 해제가 이제 실패 실험인 점을 반영했고, 그 실패의 불안정을 회복한 뒤 다음 실험을 수행하도록 갱신했다. 실패를 통과로 바꾸거나 회귀 항목을 삭제하지 않았다.

에디터 통합 검사는 사람이 F5를 누른 것이 아니라, 격리 프로젝트의 플러그인이 **실제 EditorInterface.play_main_scene()**를 호출했다. 실제 게임 창에서 합성 F2가 패널을 열었다. [에디터 결과](.task002_artifacts/fusion_ux2/f5_editor_result.json). 포커스 상실 창 검사는 Godot 알림을 주입해 처리 경로를 검사했으며, OS Alt+Tab을 사람이 수행한 검사는 아니다.

마지막 에디터 통합 검사 종료 시 Godot 파일 스캔 스레드 중단 경고가 한 번 출력됐다. 검사 결과는 성공이었고, 이후 별도 `--headless --editor --import --quit` 검사는 오류·경고 없이 종료됐다. 게임 검사 로그에는 스크립트 오류가 없었다.

**미검증:** 설치된 릴리스 export template이 없어 실제 릴리스 바이너리의 실행/화면 검사는 수행하지 못했다. 릴리스 조건에서 모든 개발 플래그/선호값을 거부하는 순수 정책 자동 검사는 통과했고, 정책 비활성 상태의 실제 창에서 F2/패널 미노출을 확인했다. 이를 실제 릴리스 실행 통과로 표현하지 않는다. 사람의 F5/F2 조작·장시간 입력 감각/밸런스 역시 미검증이다.

## 7. 스크린샷

- [에디터 실행 경로의 F2 패널](.task002_artifacts/fusion_ux2/f5_editor_runtime.png), [최신 F2 안내](.task002_artifacts/fusion_ux2/f5_f2_panel.png)
- [Shift 해제 직후 실제 발현](.task002_artifacts/fusion_ux2/water_auto_release.png)
- [최초 주속성 수동 확인](.task002_artifacts/fusion_ux2/manual_confirmation_WOOD.png), [보조속성 수동 확인](.task002_artifacts/fusion_ux2/manual_confirmation_METAL.png)
- [자동 빙정침](.task002_artifacts/fusion_ux2/LAB_ICE_CRYSTAL_NEEDLE.png), [자동 빙정방벽](.task002_artifacts/fusion_ux2/LAB_ICE_CRYSTAL_BARRIER.png), [자동 풍압탄](.task002_artifacts/fusion_ux2/LAB_WIND_PRESSURE_BOLT.png)
- [던전 Shift 이동 감속](.task002_artifacts/fusion_ux2/dungeon_shift_slow.png)

## 8. 수정 파일 및 재현

- `scripts/combat_input.gd`: 실제 이동 시전 세션 종료, 일회 신호, 홀드 마감/세션 폐기.
- `scripts/main.gd`: 연구실 자동 제출·UI 경계·실패 롤백·F5 정책·80% 이동.
- `scripts/developer_access.gd` 신규: 디버그/에디터/명시 조건, 릴리스 최우선 거부.
- `scripts/laboratory_panel.gd`, `scripts/developer_test_panel.gd`: 자동/수동 방출 안내.
- `tests/test_fusion_ux2.gd`, `tests/preview_fusion_ux2.gd`, `tests/run_f5_probe.ps1` 신규 및 `tests/preview_laboratory.gd` 갱신.
- `README.md`, `START_HERE_KO.md`, `DEVELOPER_COMMANDS_KO.md`를 F5→F2 기준으로 수정하고 A~D 보고서에 후속 변경 링크를 추가했다. `project.godot`이나 주문 리소스는 이번 단계에서 변경하지 않았다.

프로젝트 폴더에서 기존 `$Godot` 경로를 사용한다.

```powershell
& $Godot --headless --path . --script tests/test_fusion_ux2.gd
& $Godot --path . --script tests/preview_fusion_ux2.gd
```

`tests/run_f5_probe.ps1`은 실제 사용자 프로젝트/저장을 쓰지 않고 `.task002_artifacts/fusion_ux2/f5_project_*`에 코드·리소스를 복사해 에디터 실행을 검증한다. PowerShell의 파일 실행 정책이 제한된 환경에서는 시스템 정책을 바꾸지 않고 다음처럼 같은 로컬 테스트 코드를 인라인 실행했다.

```powershell
$probeScript = Join-Path (Get-Location).Path 'tests/run_f5_probe.ps1'
& ([scriptblock]::Create([IO.File]::ReadAllText($probeScript))) -ProjectRootOverride (Get-Location).Path
```

저장 스키마는 기존 v4를 유지하고, 개인 영창·원소·슬롯·융합 판정 데이터는 변경하지 않았다.
