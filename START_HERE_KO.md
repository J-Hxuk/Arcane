# 여기서부터 시작

- 최신 기획서: [GDD_v1_0_KO.md](GDD_v1_0_KO.md)
- 작업 기준: [CODEX_TASK_002.md](CODEX_TASK_002.md)
- 실행 프로젝트: `project.godot`
- 현재 조작법: [README.md](README.md)
- 이번 변경·검증·미구현 범위: [IMPLEMENTATION_REPORT_KO.md](IMPLEMENTATION_REPORT_KO.md)

Godot에서 `project.godot`을 가져오고 F5로 실행한다. 거점에서 1/2로 입장한다.
Shift 유지로 이동 시전, Shift 빠르게 두 번으로 초집중 토글, Q → E → LMB로 기초 마력탄을 직접 시전한다.
초집중에서는 이동이 멈추고 WASD가 커맨드로 기록된다. RMB/Esc로 취소한다.
일반 모드의 F는 상호작용, 시전 모드의 F는 커맨드다. 초월 감각은 임시 Alt로 분리했다.

Godot 4.7.2에서 자동 테스트와 실제 렌더링을 확인했다.
캐릭터의 영구 3속성 연구 잠금·확인 UI·화염/축약 연구는 아직 미구현이다.
이전 `CODEX_TASK.md`의 Shift/RMB 조작 설명은 현재 구현과 다르다.
