extends Control
static var FONT:Font=preload("res://scripts/ui_fonts.gd").UI
var game
var attribute_selector
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	attribute_selector=preload("res://scripts/world/attribute_selector_hud.gd").new();attribute_selector.game=game;add_child(attribute_selector)
func text(point: Vector2, value: String, size := 16, color := Color("e1e6dc")) -> void:
	draw_string(FONT, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
func _draw() -> void:
	if game == null: return
	draw_rect(Rect2(16, 16, 1128, 92), Color(0.06, 0.09, 0.12, 0.94))
	text(Vector2(34, 43), "ARCANE LEGACY · " + ("현재 월드 개발 설정 · " if game.current_world_development else "개발 임시 시험 · " if game.developer_mode else "") + game.region_title(), 22, Color("f1dba6"))
	text(Vector2(34, 70), "HP %d/%d   마나 %d/%d   보관 골드 %d   배율 %.2f" % [roundi(game.player_hp), roundi(game._max_hp()), roundi(game.player_mana), roundi(game._max_mana()), game.bank_gold, game.world_camera.zoom.x])
	var symbols={"WOOD":"木","FIRE":"火","EARTH":"土","METAL":"金","WATER":"水"}
	text(Vector2(594,70),"개화 %d/5"%game.research.awakened_attributes.size(),14)
	var main:String=symbols.get(game.research.main_attribute,"없음")
	var aux:String=symbols.get(game.research.auxiliary_attributes[0],"없음") if not game.research.auxiliary_attributes.is_empty() else "없음"
	for slot in ["main","auxiliary"]:
		var x:float=690 if slot=="main" else 796
		var selected:bool=game.research.selected_attribute_slot==slot
		if selected:draw_rect(Rect2(x-6,50,102,25),Color("455962"))
		text(Vector2(x,69),("주: "+main if slot=="main" else "보조: "+aux),15,Color("ffe0a0") if selected else Color("b6c2c6"))
	text(Vector2(899,91),"Tab 슬롯 · Alt+1~6 · 휠 배율",12)
	text(Vector2(34, 94), "RMB 이동 · LMB 검/방출 · Shift 영창/두 번 초집중 · "+("Ctrl 점멸(마나 5)" if game.research.blink_unlocked() else "Ctrl 회피")+" · E · I 가방 · M 지도 · 1/2 물약",14)
	if game.guardian.active or (game.guardian.state == "VICTORY" and game.layout.region(game.player_pos) == "RUINS"):
		var boss = game.guardian
		draw_rect(Rect2(230, 120, 700, 49), Color(0.07, 0.09, 0.12, 0.95))
		text(Vector2(245, 141), "%s · %d단계 · %s" % [boss.definition["name"], boss.phase, boss.caption()], 16, Color("f0d4b1"))
		draw_rect(Rect2(245, 151, 670, 8), Color("353c43"))
		draw_rect(Rect2(245, 151, 670 * maxf(0, boss.actor.get("hp", 0)) / boss.definition["max_hp"], 8), Color("bc7161"))
	draw_rect(Rect2(16, 555, 1128, 122), Color(0.06, 0.09, 0.12, 0.92))
	var nearest: Dictionary = game.layout.nearest(game.player_pos)
	var guidance := "마을: 북서쪽 연구실 · 북동쪽 도서관 · 남서쪽 쉼터 · 동쪽 성문"
	if game.layout.region(game.player_pos) != "TOWN": guidance = "서쪽 성문으로 돌아가면 마을입니다." if "RUIN_GUARDIAN" in game.world_progress.data["bosses"] else "동쪽 폐허 입구에서 E로 수호 기사에게 도전하세요."
	if game.layout.region(game.player_pos)=="NORTH":guidance="이끼 들판 · 남쪽 북문으로 마을 귀환 · 공격 전조를 보고 거리를 벌리세요."
	text(Vector2(34, 580), "[E] " + nearest["name"] if not nearest.is_empty() else guidance, 17, Color("f1dba6"))
	text(Vector2(34, 606), "영창: " + (" → ".join(game.runes) if not game.runes.is_empty() else "(대기)"))
	text(Vector2(34, 630), game.cast_feedback.left(108), 14)
	if game.mana_debt>0:
		text(Vector2(34,657),"정신력으로 버티는 중 · 시야가 흐리고 몸이 무겁습니다. 회복할 시간을 확보하세요.",15,Color("ffd19e"))
	elif not game.save_writable: text(Vector2(34, 657), "저장 보호 · " + game.save_error.left(90), 15, Color("ffba98"))
	elif game.status_time > 0: text(Vector2(34, 657), game.status_message.left(100), 15, Color("bce2c2"))
