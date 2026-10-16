# 여기서부터 시작

- 최신 기획서: [GDD_v1_0_KO.md](GDD_v1_0_KO.md)
- 작업 기준: [CODEX_TASK_002.md](CODEX_TASK_002.md)
- 실행 프로젝트: `project.godot`
- 현재 조작법: [README.md](README.md)
- 최신 연구 명세: [Arcane_Legacy_Magic_Research_Spec_v1_2.md](Arcane_Legacy_Magic_Research_Spec_v1_2.md) (이번 구현은 Phase 2B-1)
- 최신 변경·검증·미구현 범위: [IMPLEMENTATION_REPORT_PHASE_2B_1_KO.md](IMPLEMENTATION_REPORT_PHASE_2B_1_KO.md)
- 이전 Phase 2A: [IMPLEMENTATION_REPORT_PHASE_2A_KO.md](IMPLEMENTATION_REPORT_PHASE_2A_KO.md)
- 이전 입력 구현 보고: [IMPLEMENTATION_REPORT_KO.md](IMPLEMENTATION_REPORT_KO.md)

Godot에서 `project.godot`을 가져오고 F5로 실행한다. 거점에서 1/2로 입장한다.
Shift 유지로 이동 시전, Shift 빠르게 두 번으로 초집중 토글, Q → E → LMB로 기초 마력탄을 직접 시전한다.
초집중에서는 이동이 멈추고 WASD가 커맨드로 기록된다. RMB/Esc로 취소한다.
일반 모드의 F는 상호작용, 시전 모드의 F는 커맨드다. 초월 감각은 임시 Alt로 분리했다.

Godot 4.7.2에서 자동 테스트와 실제 렌더링을 확인했다.
거점에서 B 또는 연구 버튼으로 속성 연구 UI를 연다. 열람/단서는 슬롯을 쓰지 않으며, 연구 선택 후 확인 창의 영구 확정으로 최대 3종까지 선택한다.
세 번째 확정 후 다른 기본 속성 연구는 영구 차단된다. 취소·교체·초기화는 없다.
기존 저장은 원본 백업 후 이전하며 재능과 미기록 친화성을 임의로 재생성하지 않는다.
거점 L로 연구실에 진입한다. Shift 유지/두 번으로 영창하고 방출 버튼으로 실험한다. C는 속성 비의존 시작이다.
실험 기록 두 개를 선택해 이전/다음으로 단계를 비교하고 가설 메모를 저장한다. 재생은 마나를 쓰거나 슬롯을 점유하지 않는다.
개인 키의 내부 의미·선천 친화성 수치는 일반 화면에 표시하지 않는다. 실패 시 마나 소모·짧은 탈진이 있으며 연구실에서는 회복 버튼을 사용할 수 있다.
화염/축약 연구·복합 콘텐츠·계보도·고등·시그니처 마법은 아직 미구현이다.
이전 `CODEX_TASK.md`의 Shift/RMB 조작 설명은 현재 구현과 다르다.
