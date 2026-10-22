extends "res://scripts/main.gd"
## A new world shell around the tested magic/laboratory controller.
const Layout = preload("res://scripts/world/world_layout.gd")
const WorldNavigation = preload("res://scripts/world/world_navigation.gd")
const Prop = preload("res://scripts/world/world_prop.gd")
const PlayerView = preload("res://scripts/world/world_player_view.gd")
const Hud = preload("res://scripts/world/world_hud.gd")
const EffectsView = preload("res://scripts/world/world_effects_view.gd")
const Progress = preload("res://scripts/world/world_progress.gd")
const Guardian = preload("res://scripts/world/ruin_guardian.gd")
const WorldCombat = preload("res://scripts/world/world_combat.gd")
const GuardianView = preload("res://scripts/world/guardian_view.gd")
var layout := Layout.new()
var world_navigation := WorldNavigation.new()
var world_camera: Camera2D
var world_root: Node2D
var actors: Node2D
var player_view: Node2D
var world_hud: Control
var effects_view: Node2D
var world_enabled := true
var _lab_return := Layout.LAB_DOOR
var _world_developer_snapshot: Dictionary = {}
var world_progress := Progress.new()
var _world_ready := false
var _save_timer := 0.0
var _last_region := "TOWN"
var world_dialog: AcceptDialog
var library_text: Label
var book_view: Control
var mentor_dialog: AcceptDialog
var mentor_text: Label
var guardian := Guardian.new()
var guardian_view: Node2D
var victory_pending := false
const Inventory=preload("res://scripts/world/inventory.gd")
var inventory:=Inventory.new()
var inventory_dialog:AcceptDialog
var inventory_text:Label
var shop_dialog:AcceptDialog
var shop_text:Label
var shop_quantity:SpinBox
var field_system:=preload("res://scripts/world/field_monsters.gd").new()
var field_views:Array[Node2D]=[]
var map_dialog:AcceptDialog
var map_view:Control
var _attribute_alt_held:=false
var _attribute_digit_sources:Dictionary={}
const ATTRIBUTE_SHORTCUTS=["FIRE","WATER","WOOD","METAL","EARTH",null]
func _init()->void:formal_rules=true

func _load_or_create_character() -> void:
	var loaded := CharacterSave.load_file(save_path)
	if loaded.get("state") == "loaded":
		var old_field=loaded["data"].get("world",{}).get("field",{})
		if not old_field is Dictionary:_protect_save("필드 저장 형식이 손상되었습니다. 원본 유지");return
		if not old_field.is_empty() and old_field.get("version",1)==1 and not FileAccess.file_exists(save_path+".respawn.bak"):
			if DirAccess.copy_absolute(save_path,save_path+".respawn.bak")!=OK:_protect_save("필드 재생성 이전 백업 실패 · 원본 유지");return
		inventory.load_data(loaded["data"].get("inventory",{}))
		var error := world_progress.load_data(loaded["data"].get("world", {}))
		if not error.is_empty(): _protect_save(error); return
		var saved:Dictionary=loaded["data"]
		var saved_magic=saved.get("magic",50);var saved_injury=saved.get("injury",0)
		if (saved_magic is int or saved_magic is float) and (saved_injury is int or saved_injury is float) and is_finite(float(saved_magic)) and is_finite(float(saved_injury)):
			var maximum:float=(45.0+float(saved_magic)*1.1)*(1.0-0.10*clampi(int(saved_injury),0,3))
			if world_progress.data.get("vitals",{}).get("mana_debt",0)>ManaOverdraw.limit(maximum)+0.000001:
				_protect_save("저장된 마나가 정신력 초과 한도를 넘었습니다. 원본을 보존합니다.");return
	super._load_or_create_character()

func _character_document() -> Dictionary:
	var document := super._character_document()
	var world := world_progress.to_data()
	if _world_ready and world_enabled:
		var point := _lab_return if game_state == "LAB" else player_pos
		world["region"] = layout.region(point)
		world["position"] = [point.x, point.y]
		var vitals:Dictionary=world.get("vitals",{}).duplicate(true)
		vitals.merge({"hp": player_hp, "mana": player_mana, "mana_debt":mana_debt,"focus": focus},true)
		world["vitals"]=vitals
		world["encounter"] = guardian.definition["id"] if guardian.active else null
	document["world"] = world
	document["inventory"]=inventory.to_data()
	return document

func _ready() -> void:
	super._ready()
	cast_feedback="Shift를 유지하며 영창을 엮으세요."
	inventory.load_data(_save_document.get("inventory",{}))
	navigation = world_navigation
	world_root = Node2D.new(); world_root.name = "WorldChunks"; add_child(world_root)
	for scene in [preload("res://scenes/world/town.tscn"), preload("res://scenes/world/wilds.tscn"), preload("res://scenes/world/ruins.tscn")]: world_root.add_child(scene.instantiate())
	var north=preload("res://scripts/world/world_chunk.gd").new();north.region="NORTH";world_root.add_child(north)
	actors = Node2D.new(); actors.name = "DepthSortedActors"; actors.y_sort_enabled = true; world_root.add_child(actors)
	for data in layout.props:
		var prop := Prop.new(); prop.configure(data); actors.add_child(prop)
	player_view = PlayerView.new(); player_view.game = self; actors.add_child(player_view)
	guardian_view = GuardianView.new(); guardian_view.game = self; guardian_view.position = Guardian.HOME; actors.add_child(guardian_view)
	elemental_combat = WorldCombat.new()
	effects_view = EffectsView.new(); effects_view.game = self; world_root.add_child(effects_view)
	world_camera = Camera2D.new(); world_camera.name = "WorldCamera"; add_child(world_camera)
	world_camera.position_smoothing_enabled = true; world_camera.position_smoothing_speed = 7.0
	world_camera.zoom = Vector2.ONE * 1.0
	world_camera.limit_left = int(Layout.BOUNDS.position.x); world_camera.limit_top = int(Layout.BOUNDS.position.y); world_camera.limit_right = int(Layout.BOUNDS.end.x); world_camera.limit_bottom = int(Layout.BOUNDS.end.y)
	var canvas := CanvasLayer.new(); canvas.layer = 26; add_child(canvas) # Sharp critical HUD above single-pass exhaustion.
	world_hud = Hud.new(); world_hud.game = self; canvas.add_child(world_hud)
	research_panel.close(); research_panel.set_hub(false)
	game_state = "DUNGEON"; dungeon_kind = "WORLD"
	player_pos = world_progress.position_value()
	var interrupted: bool = world_progress.data.get("encounter") != null
	if interrupted: player_pos = world_progress.safe_position(); world_progress.data["encounter"] = null
	if layout.blocked(player_pos, 13): player_pos = world_progress.safe_position()
	if layout.blocked(player_pos, 13): player_pos = Layout.SPAWN
	var vitals: Dictionary = world_progress.data.get("vitals", {})
	player_hp = clampf(vitals.get("hp", _max_hp()), 1, _max_hp())
	player_mana = clampf(vitals.get("mana", _max_mana()), 0, _max_mana())
	mana_debt = vitals.get("mana_debt",0.0)
	focus = clampf(vitals.get("focus", 100), 0, 100)
	_last_region = layout.region(player_pos)
	_world_ready = true
	_build_library()
	_build_inventory()
	_build_world_map()
	_rebuild_field()
	if guardian.definition["id"] in world_progress.data["bosses"]:
		guardian.state = "VICTORY"; guardian.actor = {"pos": Guardian.HOME, "hp": 0.0}
	if developer_panel != null:
		developer_panel.location.clear();developer_panel.location.add_item("공유 연구 시험장");developer_panel.location.add_item("월드 보스 시험")
		for connection in developer_panel.start_button.pressed.get_connections(): developer_panel.start_button.pressed.disconnect(connection["callable"])
		developer_panel.start_button.pressed.connect(func(): developer_panel.start_requested.emit(DeveloperTestData.OPTIONS[developer_panel.elements.selected], ["LAB", "WORLD"][developer_panel.location.selected]))
	world_camera.position = player_pos; world_camera.reset_smoothing()
	_message("중앙 마을 · E로 시설 이용 · 동쪽 성문으로 탐험")
	if interrupted: _message("진행 중 종료된 보스전입니다. 마지막 안전 위치에서 재도전할 수 있습니다.")
	_sync_world_view()
	_update_mana_exhaustion(0)

func _cast_transaction_state() -> Dictionary:
	if not world_enabled or game_state!="DUNGEON":return {}
	return {"guardian":guardian.snapshot()} if guardian.active else {"field":field_system.actors.duplicate(true)}
func _restore_cast_transaction(snapshot:Dictionary) -> void:
	if snapshot.has("guardian"):guardian.restore(snapshot.guardian,enemies)
	if snapshot.has("field"):
		for actor in field_system.actors:
			for before in snapshot.field:
				if actor.field_id==before.field_id:actor.clear();actor.merge(before,true);break
		for index in enemies.size():
			for actor in field_system.actors:
				if enemies[index].get("field_id")==actor.field_id:enemies[index]=actor;break

func arena_locked() -> bool: return world_enabled and guardian.active
func _legacy_sense_available() -> bool: return not world_enabled or developer_mode
func region_title() -> String:
	return {"TOWN": "중앙 마을 · 안전 구역", "WILDS": "성벽 밖 탐험로", "RUINS": "폐허 · 위험 지대","NORTH":"북쪽 이끼 들판"}[layout.region(player_pos)]

func _sync_world_view() -> void:
	if world_camera == null: return
	var active := world_enabled and game_state == "DUNGEON"
	world_root.visible = active; world_camera.enabled = active; world_hud.visible = active
	if not active:get_viewport().canvas_transform=Transform2D.IDENTITY
	if active:
		world_camera.offset=hit_feedback.camera_offset(hit_screen.shake_scale,world_camera.zoom)
		world_camera.position = player_pos
		player_view.position = player_pos; player_view.queue_redraw(); world_hud.queue_redraw()
		effects_view.queue_redraw()
		guardian_view.position = guardian.actor.get("pos", Guardian.HOME); guardian_view.queue_redraw()

func _process(delta: float) -> void:
	if world_enabled and _world_modal_open(): _sync_world_view(); return
	super._process(delta)
	if world_enabled and game_state == "DUNGEON" and not _developer_menu_visible():
		var region := layout.region(player_pos)
		_save_timer += delta
		if not guardian.active and (region != _last_region or (_save_timer > 6 and player_pos.distance_to(world_progress.position_value()) > 24)):
			_last_region = region; _save_timer = 0
			_save_character()
	_sync_world_view()

func _save_character() -> bool:
	var result := super._save_character()
	if result and _world_ready: world_progress.load_data(_character_document()["world"])
	return result

func _notification(what: int) -> void:
	super._notification(what)
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		_attribute_alt_held=false;_attribute_digit_sources.clear()
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _world_ready and not developer_mode and save_writable: _save_character()

func _draw() -> void:
	if not world_enabled or game_state == "LAB": super._draw()

func _is_blocked(point: Vector2, radius: float = 13.0) -> bool:
	if not world_enabled: return super._is_blocked(point, radius)
	if arena_locked() and not Layout.ARENA.grow(-radius).has_point(point): return true
	return layout.blocked(point, radius) or elemental_combat.blocks(point, radius)

func _blink_position_blocked(point:Vector2,radius:float)->bool:
	return _is_blocked(point,radius) or (world_enabled and guardian.active and point.distance_to(guardian.actor.pos)<radius+26)

func _pointer_over_game_ui(point: Vector2) -> bool:
	if not world_enabled: return super._pointer_over_game_ui(point)
	if point.y < 112 or point.y > 552: return true
	if spell_record_hud != null and spell_record_hud.owns_pointer(point): return true
	var hovered := get_viewport().gui_get_hovered_control()
	return hovered != null and hovered.is_visible_in_tree() and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE and hovered.get_global_rect().has_point(point)

func _input(event: InputEvent) -> void:
	if world_enabled and event is InputEventKey:
		if event.keycode==KEY_ALT:_attribute_alt_held=event.pressed
		if _attribute_digit_sources.has(event.keycode):
			if not event.pressed:_attribute_digit_sources.erase(event.keycode)
			get_viewport().set_input_as_handled();return
		if event.keycode>=KEY_1 and event.keycode<=KEY_6 and (event.alt_pressed or _attribute_alt_held):
			if event.pressed:
				_attribute_digit_sources[event.keycode]=true
				if not event.echo and _attribute_ui_available():_choose_attribute_shortcut(ATTRIBUTE_SHORTCUTS[event.keycode-KEY_1])
			get_viewport().set_input_as_handled();return
	if world_enabled and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_M and map_dialog!=null and map_dialog.visible:map_dialog.hide();get_viewport().set_input_as_handled();return
		if event.keycode==KEY_I and inventory_dialog!=null and inventory_dialog.visible:
			inventory_dialog.hide();get_viewport().set_input_as_handled();return
		if not _world_modal_open() and game_state=="DUNGEON" and combat_input.mode==CombatInput.Mode.NORMAL and not _developer_menu_visible():
			if event.keycode==KEY_M:
				_reset_combat_input();map_dialog.popup_centered(Vector2i(800,500));get_viewport().set_input_as_handled();return
			if event.keycode==KEY_I:
				_reset_combat_input();_refresh_inventory();inventory_dialog.popup_centered(Vector2i(460,350));get_viewport().set_input_as_handled();return
			if event.keycode in [KEY_1,KEY_2]:
				_use_potion("HP_POTION" if event.keycode==KEY_1 else "MANA_POTION");get_viewport().set_input_as_handled();return
	if world_enabled and _world_modal_open(): return
	if world_enabled and game_state == "DUNGEON" and not _developer_menu_visible():
		var attribute_input:bool=(event is InputEventKey and event.keycode==KEY_TAB) or (event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN])
		if attribute_input and not (spell_record_hud!=null and spell_record_hud.expanded) and not (journal_manager!=null and journal_manager.visible):
			if event.is_pressed() and not event.is_echo():
				if event is InputEventKey:_toggle_attribute_slot()
				elif not _pointer_over_game_ui(event.position):world_camera.zoom=Vector2.ONE*clampf(world_camera.zoom.x+(.15 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -.15),.65,1.6)
			get_viewport().set_input_as_handled();return
		if event.is_pressed() and not event.is_echo() and combat_input.mode == CombatInput.Mode.NORMAL:
			if event.is_action("world_interact"):
				_interact(); get_viewport().set_input_as_handled(); return
	super._input(event)

func _attribute_ui_available()->bool:
	return game_state=="DUNGEON" and not _world_modal_open() and not _developer_menu_visible() and not (spell_record_hud!=null and spell_record_hud.expanded) and not (journal_manager!=null and journal_manager.visible)
func attribute_selector_visible()->bool:return _attribute_alt_held and _attribute_ui_available()
func attribute_shortcut_allowed(element:Variant)->bool:
	var auxiliary:Variant=null if research.auxiliary_attributes.is_empty() else research.auxiliary_attributes[0]
	return element in CharacterResearch.Loadout.candidates(research.awakened_attributes,research.main_attribute,auxiliary,research.selected_attribute_slot)
func _choose_attribute_shortcut(element:Variant)->bool:
	if not attribute_shortcut_allowed(element):
		cast_feedback="미개화·중복 속성 또는 주속성 없음은 선택할 수 없습니다.";return false
	if _attribute_session_locked():cast_feedback="영창 중에는 현재 속성이 고정됩니다.";return false
	var main=research.main_attribute;var auxiliary:Variant=null if research.auxiliary_attributes.is_empty() else research.auxiliary_attributes[0]
	if research.selected_attribute_slot=="main":main=element
	else:auxiliary=element
	return _change_active_attributes(main,auxiliary)

func _update_enemies(delta: float) -> void:
	if not world_enabled: super._update_enemies(delta)
	elif guardian.active:guardian.advance(self,delta)
	else:field_system.advance(self,delta)

func _try_move_player(motion: Vector2) -> void:
	if not world_enabled or not guardian.active: super._try_move_player(motion); return
	var steps := maxi(1, ceili(motion.length() / 6.0))
	for i in steps:
		var point := _move_actor(player_pos, motion / steps)
		var boss_position: Vector2 = guardian.actor["pos"]
		if point.distance_to(boss_position) >= 39 or point.distance_to(boss_position) > player_pos.distance_to(boss_position): player_pos = point

func _melee_attack() -> void:
	if game_state == "LAB": super._melee_attack(); return
	if not world_enabled: super._melee_attack(); return
	if dodge.active or player_attack_cooldown > 0: return
	player_attack_cooldown = CombatBalance.MELEE_INTERVAL
	if not guardian.active:
		var heading:=get_global_mouse_position()-player_pos
		for enemy in enemies:
			var offset:Vector2=enemy.pos-player_pos
			if enemy.hp>0 and offset.length()<=85 and not heading.is_zero_approx() and heading.normalized().dot(offset.normalized())>.3 and elemental_combat._clear_line(self,player_pos,enemy.pos):
				enemy.hp-=CombatBalance.melee_damage(body_talent);enemy["hit_flash"]=.15
		return
	var offset: Vector2 = guardian.actor["pos"] - player_pos
	var aim := get_global_mouse_position() - player_pos
	if offset.length() <= 85 and not aim.is_zero_approx() and aim.normalized().dot(offset.normalized()) > 0.3:
		elemental_combat.melee(self, guardian.actor, CombatBalance.melee_damage(body_talent))

func _interact() -> void:
	if game_state == "LAB": super._interact(); return
	if not world_enabled: super._interact(); return
	if game_state != "DUNGEON" or combat_input.mode != CombatInput.Mode.NORMAL: return
	var nearby := layout.nearest(player_pos)
	if nearby.is_empty(): _message("가까운 시설이 없습니다."); return
	if str(nearby["id"]).begins_with("mentor_"):
		_talk_to_mentor(str(nearby["id"]).trim_prefix("mentor_")); return
	match nearby["id"]:
		"laboratory": _enter_laboratory()
		"north_gate":_message("북문 너머의 이끼 들판으로 길이 이어집니다.")
		"library":
			_reset_combat_input(); world_dialog.popup_centered_clamped(Vector2i(920,570),.92)
		"smith":
			_reset_combat_input();_refresh_inventory();shop_dialog.popup_centered(Vector2i(560,350))
		"rest":
			_set_checkpoint("TOWN", player_pos)
		"checkpoint": _set_checkpoint("WILDS", Layout.CHECKPOINT)
		"arena":
			if victory_pending: _guardian_victory()
			else: _start_guardian()
		"rumor": _message("임시 문헌: 동방과 서방의 기록이 있다. 이 지역의 소속과 갈등의 원인은 아직 정해지지 않았다.")
		"gate": _message("성문 너머 탐험로가 동쪽의 폐허로 이어집니다. 직접 걸어서 이동하세요.")
		_: _message(nearby["name"])

func _start_guardian() -> bool:
	if not world_enabled or game_state != "DUNGEON" or guardian.active or not save_writable: return false
	_reset_combat_input()
	if not Layout.ARENA.grow(-30).has_point(player_pos): player_pos = Vector2(3070, 910)
	guardian.start(self); victory_pending = false
	_message("수호 기사의 전조를 읽으세요. 초록 윤곽은 반격 기회입니다. 사망하면 안전 위치에서 재도전합니다.")
	return true

func _guardian_victory() -> bool:
	if guardian.state != "VICTORY" or guardian.actor.is_empty() or guardian.actor["hp"] > 0: return false
	var previous := world_progress.to_data()
	var bank_before := bank_gold
	var id: String = guardian.definition["id"]
	if id not in world_progress.data["bosses"]: world_progress.data["bosses"].append(id)
	if "guardian_first_reward" not in world_progress.data["rewards"]:
		world_progress.data["rewards"].append("guardian_first_reward"); bank_gold += int(guardian.definition["reward_gold"])
	if not _save_character():
		world_progress.load_data(previous); bank_gold = bank_before; victory_pending = true
		_message("격파 기록 저장 실패 · 보상은 반영하지 않았습니다. 입구에서 E로 저장을 다시 시도하세요."); return false
	victory_pending = false; missiles.clear(); _reset_combat_input()
	_message("수호 기사 격파 기록 완료 · 최초 보상 60금 · 성문을 지나 마을로 귀환할 수 있습니다. 재도전 보상 중복 없음.")
	return true

func _build_library() -> void:
	world_dialog = AcceptDialog.new(); world_dialog.title = "도서관 · 오행 문헌"; world_dialog.theme = research_panel.opener.theme;world_dialog.unresizable=false
	add_child(world_dialog)
	var column := VBoxContainer.new(); world_dialog.add_child(column)
	var shelves := HBoxContainer.new(); column.add_child(shelves)
	for element in CharacterResearch.BaseElements.OHAENG:
		var button := Button.new(); button.name = "Book_" + element
		button.text = CharacterResearch.BaseElements.DEFINITIONS[element].display_name + " 문헌"
		button.focus_mode = Control.FOCUS_NONE; button.pressed.connect(_read_world_book.bind(element)); shelves.add_child(button)
	book_view = preload("res://scripts/world/book_view.gd").new(); column.add_child(book_view)
	library_text=book_view.text_label
	var pages := HBoxContainer.new(); column.add_child(pages)
	for step in [-1, 1]:
		var button := Button.new(); button.text = "이전 페이지" if step < 0 else "다음 페이지"
		button.pressed.connect(func(): book_view.page = posmod(book_view.page + step, 2); _update_book_page()); pages.add_child(button)
	world_dialog.visibility_changed.connect(func():
		if world_dialog.visible: _reset_combat_input(); _update_book_page())
	mentor_dialog = AcceptDialog.new(); mentor_dialog.title = "오행의 스승 · 연구 지도"
	mentor_dialog.theme = research_panel.opener.theme; add_child(mentor_dialog)
	mentor_text = Label.new(); mentor_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; mentor_text.custom_minimum_size = Vector2(680, 300); mentor_dialog.add_child(mentor_text)
	mentor_dialog.visibility_changed.connect(func():
		if mentor_dialog.visible: _reset_combat_input())

func _world_modal_open() -> bool:
	return (map_dialog!=null and map_dialog.visible) or (inventory_dialog!=null and inventory_dialog.visible) or (shop_dialog!=null and shop_dialog.visible) or (hit_screen!=null and hit_screen.settings.visible) or (world_dialog != null and world_dialog.visible) or (mentor_dialog != null and mentor_dialog.visible)

func _build_world_map()->void:
	map_dialog=AcceptDialog.new();map_dialog.title="여행자의 지도";map_dialog.theme=research_panel.opener.theme;add_child(map_dialog)
	map_view=preload("res://scripts/world/world_map.gd").new();map_view.game=self;map_dialog.add_child(map_view)
	map_dialog.window_input.connect(func(event):
		if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_M:map_dialog.hide();map_dialog.set_input_as_handled())

func _build_inventory()->void:
	inventory_dialog=AcceptDialog.new();inventory_dialog.title="여행 가방 · I로 닫기";inventory_dialog.theme=research_panel.opener.theme;add_child(inventory_dialog)
	inventory_dialog.window_input.connect(func(event):
		if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_I:inventory_dialog.hide();inventory_dialog.set_input_as_handled())
	var column=VBoxContainer.new();inventory_dialog.add_child(column)
	inventory_text=Label.new();column.add_child(inventory_text)
	for id in Inventory.ITEMS:
		var button=Button.new();button.text=Inventory.ITEMS[id].name+" 사용";button.pressed.connect(func():_use_potion(id));column.add_child(button)
	var slots=Label.new();slots.text="◇ 빈 주머니     ◇ 빈 주머니     ◇ 빈 주머니";column.add_child(slots)
	shop_dialog=AcceptDialog.new();shop_dialog.title="대장간 · 여행자의 보급품";shop_dialog.theme=research_panel.opener.theme;add_child(shop_dialog)
	var shop=VBoxContainer.new();shop_dialog.add_child(shop)
	shop_text=Label.new();shop.add_child(shop_text)
	shop_quantity=SpinBox.new();shop_quantity.min_value=1;shop_quantity.max_value=99;shop_quantity.value=1;shop.add_child(shop_quantity)
	for id in Inventory.ITEMS:
		var row=Inventory.ITEMS[id];var button=Button.new();button.text="%s · %d금 / 회복 %d · 구매"%[row.name,row.price,row.restore]
		button.pressed.connect(func():_buy_item(id,int(shop_quantity.value)));shop.add_child(button)
	_refresh_inventory()

func _refresh_inventory()->void:
	if inventory_text!=null:inventory_text.text="보관 골드  %d금\n\n1  체력 물약  × %d\n2  마나 물약  × %d"%[bank_gold,inventory.count("HP_POTION"),inventory.count("MANA_POTION")]
	if shop_text!=null:shop_text.text="보유 %d금 · 체력 물약 %d / 마나 물약 %d\n구매 수량"%[bank_gold,inventory.count("HP_POTION"),inventory.count("MANA_POTION")]

func _buy_item(id:String,quantity:int)->bool:
	if not save_writable or not Inventory.ITEMS.has(id) or quantity<1 or quantity>99:return false
	if not developer_mode and (not shop_dialog.visible or layout.nearest(player_pos).get("id")!="smith"):return false
	var cost:int=int(Inventory.ITEMS[id].price)*quantity
	if bank_gold<cost:_message("골드가 부족합니다.");return false
	var before:=inventory.to_data();var gold:=bank_gold
	bank_gold-=cost;inventory.add(id,quantity)
	if not _save_character():inventory.load_data(before);bank_gold=gold;return false
	_refresh_inventory();return true

func _use_potion(id:String)->bool:
	if not save_writable or not Inventory.ITEMS.has(id) or inventory.count(id)<=0:return false
	if game_state!="DUNGEON" or combat_input.mode!=CombatInput.Mode.NORMAL or _developer_menu_visible():return false
	var row:Dictionary=Inventory.ITEMS[id];var before:=inventory.to_data();var hp:=player_hp;var mana:=player_mana;var debt:=mana_debt
	if row.resource=="hp":
		if player_hp>=_max_hp():return false
		player_hp=minf(_max_hp(),player_hp+row.restore)
	else:
		if player_mana>=_max_mana() and mana_debt==0:return false
		_recover_mana(row.restore)
	inventory.add(id,-1)
	if not _save_character():inventory.load_data(before);player_hp=hp;player_mana=mana;mana_debt=debt;return false
	_refresh_inventory();return true

func _apply_temporary_document(data:Dictionary)->void:
	super._apply_temporary_document(data)
	inventory.load_data(data.get("inventory",{}));_refresh_inventory()

func _developer_action(action:String)->bool:
	if not developer_mode:return false
	if world_enabled and game_state=="DUNGEON" and action=="clear_enemies":
		field_system.suppressed=true
		for actor in field_system.actors:actor["debug_hidden"]=true
		for actor in enemies:actor["debug_hidden"]=true # Includes temporary ordinary QA targets.
	if world_enabled and game_state=="DUNGEON" and action=="spawn":
		var point:Vector2=player_pos+Vector2(100,0)
		if _is_blocked(point,14):return false
		var actor={"pos":point,"hp":100.0,"max_hp":100.0,"hurt_height":28.0,"type":"SHALE","state":"IDLE"}
		enemies.append(actor);var view=preload("res://scripts/world/field_monster_view.gd").new();view.actor=actor;actors.add_child(view);field_views.append(view);return _save_character()
	return super._developer_action(action)

func _rebuild_field()->void:
	for view in field_views:view.queue_free()
	field_views.clear();field_system.build(self)
	for actor in field_system.actors:
		var view=preload("res://scripts/world/field_monster_view.gd").new();view.actor=actor;actors.add_child(view);field_views.append(view)

func _field_spawn_visible(point:Vector2)->bool:
	var extent:=get_viewport_rect().size/world_camera.zoom+Vector2(160,160)
	return Rect2(player_pos-extent*.5,extent).has_point(point) or Rect2(world_camera.get_screen_center_position()-extent*.5,extent).has_point(point)

func _replace_field_view(old:Dictionary,next:Dictionary)->void:
	for view in field_views.duplicate():
		if view.actor==old:field_views.erase(view);view.queue_free()
	var view=preload("res://scripts/world/field_monster_view.gd").new();view.actor=next;actors.add_child(view);field_views.append(view)

func _update_book_page() -> void:
	var element: String = book_view.element
	library_text.text = preload("res://scripts/research_lore.gd").page(element,book_view.page,preload("res://scripts/research_visibility.gd").known(discovered)) + "\n\n" + ("[기록됨] 서적 단서" if research.has_clue(element, "book") else "상단에서 조사할 문헌을 선택하세요.")
	book_view.queue_redraw()

func _read_world_book(element: String) -> void:
	if not world_enabled or game_state != "DUNGEON" or not world_dialog.visible or layout.nearest(player_pos).get("id") != "library" or not save_writable: return
	var previous := research.to_data()
	var result := research.acquire_clue(element, "book", CharacterResearch.Rules.clue_id(element, "book"))
	if result == "recorded" and not _save_character(): research.load_data(previous); result = "save_failed"
	book_view.element = element; book_view.page = 0; _update_book_page()
	if result == "save_failed": library_text.text = "단서 저장 실패 · 원본 유지"

func _talk_to_mentor(element: String) -> void:
	var previous := research.to_data()
	var result := research.acquire_clue(element, "mentor", CharacterResearch.Rules.clue_id(element, "mentor"))
	if result == "recorded" and not _save_character(): research.load_data(previous); result = "save_failed"
	mentor_text.text = CharacterResearch.BaseElements.DEFINITIONS[element].display_name + "의 스승\n\n" + preload("res://scripts/research_lore.gd").mentor(element,research)
	if not formal_rules:
		mentor_text.text += "\n\n선택 속성 연구: " + laboratory_panel.awakening_panel.reason(research.ritual_eligibility(element))
		mentor_text.text += "\n안정 공명 %d회 · 간섭 안정화 %d회" % [research.stable_count(element),research.interference_count(element)]
	if result == "save_failed":_message("대화 기록 저장 실패 · 원본 유지")
	mentor_dialog.title = CharacterResearch.BaseElements.DEFINITIONS[element].display_name + "의 스승"
	mentor_dialog.popup_centered(Vector2i(740, 400))

func _set_checkpoint(region: String, point: Vector2) -> bool:
	if guardian.active: return false
	if region not in ["TOWN", "WILDS"] or layout.region(point) != region or layout.blocked(point, 13): return false
	var previous := world_progress.to_data()
	var vitals := Vector4(player_hp, player_mana, focus,mana_debt)
	world_progress.data["safe"] = {"region": region, "position": [point.x, point.y]}
	player_hp = _max_hp(); player_mana = _max_mana(); mana_debt=0.0; focus = 100
	if not _save_character():
		world_progress.load_data(previous); player_hp = vitals.x; player_mana = vitals.y; focus = vitals.z; mana_debt=vitals.w; return false
	_message("체크포인트 기록 · 회복 완료 · 사망하면 이 안전 위치에서 재도전합니다.")
	return true

func _die() -> void:
	if not world_enabled: super._die(); return
	if game_state=="LAB":laboratory_panel.close();game_state="DUNGEON"
	var previous := world_progress.to_data()
	world_progress.data["deaths"] = int(world_progress.data["deaths"]) + 1
	_reset_combat_input(); elemental_combat.clear(); missiles.clear(); enemies.clear()
	guardian.stop(); victory_pending = false
	_rebuild_field()
	player_pos = world_progress.safe_position()
	if layout.blocked(player_pos, 13): player_pos = Layout.SPAWN
	player_hp = _max_hp(); player_mana = _max_mana(); mana_debt=0.0; focus = 100
	world_camera.position = player_pos; world_camera.reset_smoothing()
	if not _save_character(): world_progress.load_data(previous)
	_message("쓰러졌습니다. 안전 위치에서 회복했습니다. 캐릭터·연구는 보존되며 다시 도전할 수 있습니다.")

func _enter_laboratory() -> void:
	if not world_enabled: super._enter_laboratory(); return
	if game_state != "DUNGEON" or player_pos.distance_to(Layout.LAB_DOOR) > 85 or not save_writable: return
	_lab_return = player_pos
	_save_character()
	game_state = "HUB"; super._enter_laboratory(); _sync_world_view()

func _leave_laboratory() -> void:
	if not world_enabled: super._leave_laboratory(); return
	if game_state != "LAB": return
	super._leave_laboratory()
	game_state = "DUNGEON"; research_panel.set_hub(false); player_pos = _lab_return
	world_camera.position = player_pos; world_camera.reset_smoothing(); _sync_world_view()
	_save_character()

func _enter_dungeon(kind: String) -> void:
	if not world_enabled: super._enter_dungeon(kind)

func _capture_world_developer_snapshot()->void:
	_world_developer_snapshot = {"world_enabled": world_enabled, "lab_return": _lab_return, "document": _character_document(), "progress": world_progress.to_data(), "last_region": _last_region, "save_timer": _save_timer, "guardian": guardian.snapshot(), "victory_pending": victory_pending,"field_actors":field_system.actors.duplicate(true),"field_suppressed":field_system.suppressed}

func _begin_current_development()->bool:
	if not OS.is_debug_build() or not developer_tools_enabled or not formal_rules or not save_writable:return false
	if current_world_development:return true
	if developer_mode:_end_developer_test()
	_capture_world_developer_snapshot()
	var result:=super._begin_current_development()
	_sync_world_view();return result

func _start_developer_test(element: String, location: String) -> bool:
	if not OS.is_debug_build() or not developer_tools_enabled or element not in DeveloperTestData.OPTIONS or location not in ["LAB", "DUNGEON", "WORLD"]: return false
	var first := not developer_mode
	if first:_capture_world_developer_snapshot()
	guardian.stop(); victory_pending = false
	world_enabled = false
	navigation = DestinationMovement.new()
	var result := super._start_developer_test(element, "DUNGEON" if location == "WORLD" else location)
	if first and result: _developer_snapshot["document"] = _world_developer_snapshot["document"].duplicate(true)
	if result and location == "WORLD":
		world_enabled = true; navigation = world_navigation; navigation.cancel(); world_progress = Progress.new()
		_rebuild_field()
		world_progress.data["safe"] = {"region": "WILDS", "position": [Layout.CHECKPOINT.x, Layout.CHECKPOINT.y]}
		player_pos = Vector2(3070, 910); dungeon_kind = "WORLD"; _start_guardian()
		world_camera.position = player_pos; world_camera.reset_smoothing()
	_sync_world_view()
	return result

func _end_developer_test() -> bool:
	if not developer_mode: return false
	var result := super._end_developer_test()
	world_enabled = _world_developer_snapshot.get("world_enabled", true)
	_lab_return = _world_developer_snapshot.get("lab_return", Layout.LAB_DOOR)
	world_progress.load_data(_world_developer_snapshot.get("progress", {}))
	_last_region = _world_developer_snapshot.get("last_region", "TOWN"); _save_timer = _world_developer_snapshot.get("save_timer", 0.0)
	guardian.restore(_world_developer_snapshot.get("guardian", {}), enemies)
	var original_field:Array=_world_developer_snapshot.get("field_actors",[])
	_rebuild_field()
	for actor in field_system.actors:
		for original in original_field:
			if actor.field_id==original.field_id:actor.merge(original,true)
	field_system.suppressed=_world_developer_snapshot.get("field_suppressed",false)
	if guardian.active:enemies.assign([guardian.actor])
	victory_pending = _world_developer_snapshot.get("victory_pending", false)
	navigation = world_navigation; navigation.cancel()
	_world_developer_snapshot = {}
	world_camera.position = player_pos; world_camera.reset_smoothing(); _sync_world_view()
	return result
