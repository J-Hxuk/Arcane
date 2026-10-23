extends Node2D
## Arcane Legacy: minimal top-down action / research / death-loop prototype.
## Made with drawn primitives so no art assets are required.

const SAVE_PATH := "user://arcane_legacy_save.json"
const AREA := Rect2(96.0, 104.0, 800.0, 480.0)
const TILE := 40.0
const COLS := 20
const ROWS := 12
const START_POS := Vector2(196.0, 204.0)
const EXIT_POS := Vector2(796.0, 484.0)
const PLAYER_SPEED := 200.0
const MOBILE_CAST_SPEED_MULTIPLIER := 0.8
const FOCUS_MANA_REGEN_MULTIPLIER := 2.0
const ENEMY_SPEED := 85.0
const CombatInput = preload("res://scripts/combat_input.gd")
const SpellBook = preload("res://scripts/spell_book.gd")
const SpellDefinition = preload("res://scripts/spell_definition.gd")
const CharacterResearch = preload("res://scripts/character_research.gd")
const CharacterSave = preload("res://scripts/character_save.gd")
const ResearchPanel = preload("res://scripts/research_panel.gd")
const ChantProfile = preload("res://scripts/chant_profile.gd")
const ManaSimulator = preload("res://scripts/mana_simulator.gd")
const ExperimentJournal = preload("res://scripts/experiment_journal.gd")
const LaboratoryPanel = preload("res://scripts/laboratory_panel.gd")
const CombatSpellResolver = preload("res://scripts/combat_spell_resolver.gd")
const ElementalCombat = preload("res://scripts/elemental_combat.gd")
const SpellDiscoveries = preload("res://scripts/spell_discoveries.gd")
const SpellRecordHud = preload("res://scripts/spell_record_hud.gd")
const DestinationMovement = preload("res://scripts/destination_movement.gd")
const DodgeMotion = preload("res://scripts/dodge_motion.gd")
const DeveloperTestPanel = preload("res://scripts/developer_test_panel.gd")
const DeveloperTestData = preload("res://scripts/developer_test_data.gd")
const DeveloperAccess = preload("res://scripts/developer_access.gd")
const CombatBalance = preload("res://scripts/combat_balance.gd")
const ManaOverdraw = preload("res://scripts/mana_overdraw.gd")
var mana_exhaustion_view:CanvasLayer
var spell_audio: AudioStreamPlayer
var journal_manager: AcceptDialog
var _journal_undo := {"player": {}, "developer": {}}

@export_range(0.1, 0.6, 0.01) var shift_double_tap_window := 0.3
@export var legacy_wasd_enabled := false
var navigation := DestinationMovement.new()
var dodge := DodgeMotion.new()
var developer_tools_enabled: Variant = null # null: runtime policy; bool: isolated test preference.
var developer_mode := false
var developer_panel: DeveloperTestPanel
var developer_metrics: Dictionary = {}
var _developer_snapshot: Dictionary = {}
var _developer_document: Dictionary = {}
var combat_input := CombatInput.new()
var spell_book := SpellBook.new()
# Override before _ready() in tests to avoid touching the player's real save.
var save_path := SAVE_PATH
var research := CharacterResearch.new()
var research_panel: ResearchPanel
var save_writable := true
var save_error := ""
var _save_document: Dictionary = {}
var chant_profile := ChantProfile.new()
var journal := ExperimentJournal.new()
var laboratory_panel: LaboratoryPanel
var chant_inputs: Array = []
var chant_started_ms := 0
var _lab_release_consumed := false
var exhaustion_seconds := 0.0
var last_laboratory_result: Dictionary = {}
var pending_awakening_offer: Dictionary = {}
var elemental_combat := ElementalCombat.new()
var discovered := SpellDiscoveries.new()
var spell_record_hud: SpellRecordHud

var rng := RandomNumberGenerator.new()
var dungeon_rng := RandomNumberGenerator.new()
var game_state := "HUB"
var dungeon_kind := "FIXED"
var fixed_seed := 0
var map_seed := 0
var walls: Array[Vector2i] = []
var enemies: Array[Dictionary] = []
var missiles: Array[Dictionary] = []
var player_pos := START_POS
var player_hp := 100.0
var player_mana := 100.0
var mana_debt := 0.0
var focus := 100.0
var focus_active := false
var player_attack_cooldown := 0.0
var runes: Array[String] = []
var cast_feedback := "Hold Shift or double-tap Shift. Q > E > LMB: Mana Bolt."
var status_message := ""
var status_time := 0.0
var carried_gold := 0
var bank_gold := 100
var injury_stacks := 0
var armor_durability := 100
var magic_talent := 50
var body_talent := 50
var learned_spells: Array[String] = []
var hit_feedback:=preload("res://scripts/player_hit_feedback.gd").new()
var hit_screen
var prototype_enabled:=false
var formal_rules:=false
var lab_observation_target:="WOOD"
var movement_research_active:=false
var _chant_session_context:Dictionary={}
var current_world_development:=false
var _current_developer_base_research:Dictionary={}
var current_developer_options:Dictionary={"all_elements":false,"bindings":false,"blink":false}
var _prototype_all:=false
var prototype_target:=""
var _prototype_overflow:=false
var prototype_profile:=ChantProfile.new()
var prototype_confirmation:ConfirmationDialog
var signature_session:=preload("res://scripts/signature_session.gd").new()

func _prototype_active()->bool:return formal_rules or (prototype_enabled and research.ritual_target.is_empty())
func _active_profile():return prototype_profile if _prototype_active() else chant_profile
func _prototype_context()->Dictionary:
	if not _chant_session_context.is_empty():
		var frozen:=_chant_session_context.duplicate(true);frozen.focus_cast=combat_input.mode==CombatInput.Mode.FOCUS_CAST;return frozen
	var context:=research.simulation_context()
	context["discovered_spells"]=discovered.to_data().get("spells",{}).duplicate(true)
	context["learned_spells"]=learned_spells.duplicate()
	context.erase("innate_element")
	context["focus_cast"]=combat_input.mode==CombatInput.Mode.FOCUS_CAST
	context["developer_all"]=developer_mode and _prototype_all
	context["developer_target"]=prototype_target if developer_mode and _prototype_all else ""
	if formal_rules:
		context["formal_rules"]=true
		context["laboratory"]=game_state=="LAB"
		context["observation_element"]=research.ritual_target if not research.ritual_target.is_empty() else lab_observation_target
		context["research_only"]=game_state=="LAB" and (not research.ritual_target.is_empty() or (lab_observation_target!=research.main_attribute and not context.developer_all))
		context["movement_research"]=game_state=="LAB" and movement_research_active
	return context

func _capture_chant_attributes()->void:
	if formal_rules and _chant_session_context.is_empty():_chant_session_context=_prototype_context().duplicate(true)
func _attribute_session_locked()->bool:return not runes.is_empty() or not _chant_session_context.is_empty()
func _change_active_attributes(main:Variant,aux:Variant)->bool:
	if not formal_rules or _attribute_session_locked() or not save_writable:return false
	var previous:=research.to_data()
	if not research.set_active(main,aux):return false
	if not _save_character():research.load_data(previous);return false
	lab_observation_target=str(main) if main!=null else "WOOD"
	_update_laboratory_live();return true
func _cycle_active_attributes(direction:int)->bool:
	if not formal_rules or _attribute_session_locked() or not save_writable:return false
	var previous:=research.to_data()
	if not research.cycle_active(direction):return false
	if not _save_character():research.load_data(previous);return false
	lab_observation_target=str(research.main_attribute) if research.main_attribute!=null else "WOOD"
	return true
func _toggle_attribute_slot()->bool:
	if not formal_rules or not save_writable:return false
	var previous:=research.selected_attribute_slot
	research.selected_attribute_slot="auxiliary" if previous=="main" else "main"
	if not _save_character():research.selected_attribute_slot=previous;return false
	return true
func _select_lab_observation(element:String)->void:
	if _attribute_session_locked():_update_laboratory_live();return
	if element in research.awakened_attributes:
		var auxiliary=research.auxiliary_attributes[0] if not research.auxiliary_attributes.is_empty() else null
		if auxiliary==element:auxiliary=null
		_change_active_attributes(element,auxiliary)
	else:lab_observation_target=element;_update_laboratory_live()

func _select_lab_equipment(slot:String,element:Variant)->bool:
	if game_state!="LAB" or movement_research_active or not research.ritual_target.is_empty():return false
	var main=research.main_attribute;var auxiliary=research.auxiliary_attributes[0] if not research.auxiliary_attributes.is_empty() else null
	if slot=="main":main=element
	elif slot=="auxiliary":auxiliary=element
	else:return false
	var result:=_change_active_attributes(main,auxiliary)
	if laboratory_panel!=null:laboratory_panel.refresh_equipment()
	return result
func _legacy_simulation_context()->Dictionary:
	var context:=research.simulation_context()
	if developer_mode and _prototype_all:
		context["binding_pairs"]=["METAL+WATER","FIRE+WATER"]
		context["neutral_wave_unlocked"]=true
		# Compatibility reproduces each existing developer preset's historical
		# simulator context without changing the character or its affinity fields.
		var first:String=chant_profile.first_word(runes[0]) if not runes.is_empty() else ""
		context["innate_element"]="" if first=="VOID" else first
		if not first.is_empty():context["main_attribute"]=first
		context["auxiliary_attributes"]=["WATER"] if first in ["FIRE","METAL"] else (["METAL"] if first=="WATER" else [])
		if first=="WATER":
			for i in range(1,runes.size()):
				if chant_profile.manipulation(runes[i-1]) in ["STABILIZE","BIND"] and chant_profile.first_word(runes[i]) in ["FIRE","METAL"]:
					context["auxiliary_attributes"]=[chant_profile.first_word(runes[i])];break
	return context
func _enable_prototype(enabled:bool)->void:
	if formal_rules:
		research.use_current_rules=true
		prototype_enabled=true;combat_input.profile_version=2;return
	_reset_combat_input();prototype_enabled=enabled
	last_laboratory_result={}
	if enabled:prototype_profile.load_data(chant_profile.to_data() if chant_profile.version()==2 else ChantProfile.generate_current(int(chant_profile.to_data().get("character_seed",8431))))
	combat_input.profile_version=_active_profile().version()
	laboratory_panel.message.text="새 영창 시제품 · 원소 선언 없이 최대 5회 · 이번 실행에만 적용 · 기존 키표와 주문은 호환 모드로 보존" if enabled else "기존 영창 호환 모드 · 개인 키표 유지"
	_update_laboratory_live()
func _start_prototype_all(location:String,new_grammar:=true)->bool:
	if not _start_developer_test("WATER_METAL",location):return false
	_enable_prototype(new_grammar);_prototype_all=true;prototype_target=""
	if developer_panel!=null:developer_panel.refresh()
	return true

func _receive_player_damage(amount:float,strong:=false,direction:=Vector2.ZERO)->bool:
	if amount<=0 or not is_finite(amount) or player_hp<=0:return false
	player_hp=maxf(0,player_hp-amount)
	var audible:bool=hit_feedback.remaining<.08 or strong
	hit_feedback.receive(amount,strong,direction)
	if spell_audio!=null and audible:spell_audio.cue("PLAYER_HEAVY_HIT" if strong else "PLAYER_HIT","shockwave")
	_message(("강한 피격" if strong else "피격")+" · HP -%.0f"%amount)
	queue_redraw()
	return true
var corpse: Dictionary = {}
var corpse_pos := Vector2.ZERO

func _ready() -> void:
	hit_screen=preload("res://scripts/hit_screen_view.gd").new();add_child(hit_screen)
	mana_exhaustion_view=preload("res://scripts/mana_exhaustion_view.gd").new(); add_child(mana_exhaustion_view)
	spell_audio = preload("res://scripts/spell_audio.gd").new(); add_child(spell_audio)
	legacy_wasd_enabled = OS.is_debug_build() and (legacy_wasd_enabled or OS.get_cmdline_user_args().has("--legacy-wasd"))
	developer_tools_enabled = DeveloperAccess.allowed(OS.is_debug_build(), OS.has_feature("editor_runtime"), OS.get_cmdline_user_args().has("--dev-lab"), developer_tools_enabled)
	combat_input.legacy_wasd_enabled = legacy_wasd_enabled
	combat_input.double_tap_window = shift_double_tap_window
	combat_input.mode_changed.connect(_on_combat_mode_changed)
	combat_input.command_entered.connect(_on_command_entered)
	combat_input.attack_requested.connect(_melee_attack)
	combat_input.cast_requested.connect(_cast_spell)
	combat_input.cancel_requested.connect(_cancel_spell)
	combat_input.interact_requested.connect(_interact)
	combat_input.move_requested.connect(_request_destination)
	combat_input.dodge_requested.connect(_request_dodge)
	combat_input.mobile_session_finished.connect(_auto_release_laboratory_session)
	rng.randomize()
	_load_or_create_character()
	if formal_rules:
		research.use_current_rules=true
		var mapping=_save_document.get("active_chant",chant_profile.to_data() if chant_profile.version()==2 else ChantProfile.generate_current(int(chant_profile.to_data().get("character_seed",8431))))
		var mapping_error:=prototype_profile.load_data(mapping) if mapping is Dictionary else "영창 키표 형식이 손상되었습니다. 원본을 보존합니다."
		if not mapping_error.is_empty():_protect_save(mapping_error)
		lab_observation_target=str(research.main_attribute) if research.main_attribute!=null else "WOOD"
		if save_writable and not _save_document.has("active_chant"):
			if FileAccess.file_exists(save_path) and not FileAccess.file_exists(save_path+".formal.bak") and DirAccess.copy_absolute(save_path,save_path+".formal.bak")!=OK:_protect_save("영창 통합 백업 실패 · 원본 유지")
			else:_save_character()
	combat_input.profile_version = _active_profile().version()
	research_panel = ResearchPanel.new()
	add_child(research_panel)
	research_panel.setup(research)
	research_panel.writable = save_writable
	research_panel.commit_requested.connect(_confirm_element_research)
	research_panel.clue_requested.connect(_acquire_debug_clue)
	research_panel.laboratory_requested.connect(_enter_laboratory)
	research_panel.refresh()
	laboratory_panel = LaboratoryPanel.new()
	add_child(laboratory_panel)
	laboratory_panel.setup(journal, _active_profile(),formal_rules)
	laboratory_panel.movement_research_requested.connect(_begin_movement_research)
	prototype_confirmation=ConfirmationDialog.new();prototype_confirmation.title="새 영창 시제품 전환 확인";add_child(prototype_confirmation)
	prototype_confirmation.dialog_text="이번 실행에서만 별도 개인 12키 시험표와 원소 선언 없는 문법을 사용합니다.\n대표 단일 5종과 빙정침 1종만 연결되었습니다.\n원래 v1/v2 영창표·발견 기록은 덮어쓰지 않습니다. 기존 개화 의식은 호환 문법을 사용합니다."
	prototype_confirmation.confirmed.connect(func():_enable_prototype(true))
	laboratory_panel.prototype_requested.connect(func():
		_reset_combat_input()
		if prototype_enabled:_enable_prototype(false)
		else:prototype_confirmation.popup_centered())
	if formal_rules:prototype_confirmation.queue_free();prototype_confirmation=null
	laboratory_panel.setup_awakening(research)
	laboratory_panel.awakening_panel.visibility_changed.connect(func():
		if game_state == "LAB" and laboratory_panel.awakening_panel.visible: _reset_combat_input())
	laboratory_panel.awakening_panel.confirmation.visibility_changed.connect(func():
		if game_state == "LAB" and laboratory_panel.awakening_panel.confirmation.visible: combat_input.discard_mobile_session())
	get_viewport().gui_focus_changed.connect(func(control):
		if game_state == "LAB" and (control is LineEdit or control is TextEdit or control is SpinBox): _reset_combat_input())
	laboratory_panel.awakening_panel.clue_requested.connect(_collect_research_clue)
	laboratory_panel.awakening_panel.ritual_requested.connect(_begin_awakening)
	laboratory_panel.awakening_panel.ritual_cancelled.connect(_cancel_awakening)
	laboratory_panel.awakening_panel.confirmation_requested.connect(_confirm_element_research)
	laboratory_panel.awakening_panel.binding_study_requested.connect(func(element):
		var previous := research.to_data()
		var result := research.study_binding(element)
		if result == "binding_studied" and not _save_character(): research.load_data(previous); result = "save_failed"
		laboratory_panel.message.text = laboratory_panel.awakening_panel.reason(result) + " · 충분히 모은 흐름을 안정화한 직후 다른 선언을 실험하세요.")
	laboratory_panel.awakening_panel.neutral_transition_requested.connect(func():
		var previous := research.to_data()
		if research.acknowledge_neutral_transition() and not _save_character(): research.load_data(previous)
		laboratory_panel.awakening_panel.refresh())
	laboratory_panel.release_requested.connect(_cast_spell)
	laboratory_panel.exit_requested.connect(_leave_laboratory)
	laboratory_panel.recover_requested.connect(_laboratory_recover)
	laboratory_panel.note_requested.connect(_save_experiment_note)
	laboratory_panel.arena.controller = self
	laboratory_panel.awakening_panel.opened.connect(_reset_combat_input)
	journal_manager = preload("res://scripts/journal_manager.gd").new(); add_child(journal_manager); journal_manager.setup(self)
	laboratory_panel.manage_records_requested.connect(func(): journal_manager.popup_centered(Vector2i(950, 520)))
	laboratory_panel.first_word_requested.connect(_teach_mana_principle)
	combat_input.command_released.connect(_on_command_released)
	spell_record_hud = SpellRecordHud.new()
	add_child(spell_record_hud)
	spell_record_hud.setup(discovered, research_panel.opener.theme)
	spell_record_hud.preference_changed.connect(_change_spell_preference)
	if developer_tools_enabled:
		developer_panel = DeveloperTestPanel.new()
		add_child(developer_panel)
		developer_panel.setup(self, research_panel.opener.theme)
		developer_panel.start_requested.connect(_start_developer_test)
		developer_panel.end_requested.connect(_end_developer_test)
		developer_panel.close_requested.connect(_toggle_developer_menu)
	status_message = "Choose a dungeon: [1] Ruins (fixed)  [2] Flux Maze (shifting)" if save_error.is_empty() else save_error
	status_time = 6.0
	queue_redraw()

var water_qa_active:=false
var water_qa_cases:Dictionary={}
func _water_qa_start(location:="LAB")->bool:
	if not OS.is_debug_build() or not developer_tools_enabled:return false
	if not _start_developer_test("WATER","WORLD" if location=="FIELD" else location):return false
	water_qa_active=true
	if location=="FIELD" and get("guardian")!=null:
		get("guardian").stop();player_pos=Vector2(2200,900);enemies.clear()
		for i in 5:
			var actor={"pos":player_pos+Vector2(160+i*45,(i%2)*45),"hp":1000.0,"max_hp":1000.0,"shot":10.0,"hit_radius":18.0,"hurt_height":30.0,"type":"MOSS","state":"IDLE"}
			enemies.append(actor)
			var view=preload("res://scripts/world/field_monster_view.gd").new();view.actor=actor
			get("actors").add_child(view);get("field_views").append(view)
		get("field_system").suppressed=true;call("_sync_world_view")
	research.developer_reset("all_elements","");research.set_active("WATER",null)
	player_mana=_max_mana();mana_debt=0;player_hp=_max_hp()
	_water_qa_build_cases();developer_panel.refresh()
	if location=="LAB":laboratory_panel.show_trial()
	return true
func _water_qa_build_cases()->void:
	water_qa_cases.clear()
	var engine=preload("res://scripts/chant_engine_v2.gd")
	for row in preload("res://scripts/water_spell_catalog.gd").DATA.spells:
		var choices:Array=[];var seen:Dictionary={}
		for order in preload("res://scripts/formal_spell_registry.gd").permutations(row.actions):
			var signature:="|".join(order)
			if seen.has(signature):continue
			seen[signature]=true
			var r=engine.resolve(_active_profile(),engine.inputs(_active_profile(),order),_prototype_context())
			if r.get("spell")!=null:choices.append({"actions":order,"strength":r.spell.formula_effect.get("strength",0),"cost":r.mana_cost,"risk":r.get("risk","normal")})
		choices.sort_custom(func(a,b):return a.strength<b.strength)
		var stable:Array=choices.filter(func(c):return c.risk=="normal")
		if not choices.is_empty():water_qa_cases[row.id]={"off":stable.front() if not stable.is_empty() else choices.front(),"on":choices.back() if row.tier>=2 or stable.is_empty() else stable.back()}
func _water_qa_prepare(id:String,variant:String)->bool:
	if not developer_mode or not water_qa_active or not water_qa_cases.has(id):return false
	_reset_combat_input();research.set_active("WATER",null)
	if game_state=="LAB":laboratory_panel.show_trial()
	combat_input._set_mode(CombatInput.Mode.FOCUS_CAST)
	developer_panel.panel.hide()
	var events=preload("res://scripts/chant_engine_v2.gd").inputs(_active_profile(),water_qa_cases[id][variant].actions)
	runes.assign(events.map(func(e):return str(e.key)));chant_inputs=events
	for event in chant_inputs:event.released=true
	player_mana=_max_mana();mana_debt=0
	cast_feedback=id+" "+variant+" · "+str(water_qa_cases[id][variant].risk)+" · 조준 후 LMB 방출 / Esc 취소"
	_update_laboratory_live();return true

func _max_hp() -> float:
	return 100.0 * (1.0 - 0.12 * float(injury_stacks))

func _max_mana() -> float:
	if developer_mode and water_qa_active:return 1000.0
	return (45.0 + float(magic_talent) * 1.1) * (1.0 - 0.10 * float(injury_stacks))

func _load_or_create_character() -> void:
	var loaded := CharacterSave.load_file(save_path,formal_rules)
	if loaded["state"] == "error":
		_protect_save(loaded["message"])
		return
	if loaded["state"] == "loaded":
		var parsed: Dictionary = loaded["data"]
		_save_document = parsed.duplicate(true)
		# Validate before assigning gameplay fields; never reroll an existing file.
		for field in ["magic", "body", "bank", "injury", "armor", "fixed_seed"]:
			var value = parsed.get(field, 0)
			if not (value is int or value is float):
				_protect_save("Invalid character field: " + field)
				return
		if not parsed.get("corpse", {}) is Dictionary or not parsed.get("learned", []) is Array:
			_protect_save("Invalid character knowledge / corpse data.")
			return
		magic_talent = int(parsed.get("magic", 50))
		body_talent = int(parsed.get("body", 50))
		bank_gold = int(parsed.get("bank", 100))
		injury_stacks = clampi(int(parsed.get("injury", 0)), 0, 3)
		armor_durability = int(parsed.get("armor", 100))
		fixed_seed = int(parsed.get("fixed_seed", 12345))
		corpse = parsed.get("corpse", {}).duplicate(true)
		learned_spells.clear()
		for name in parsed.get("learned", []):
			learned_spells.append(str(name))
		player_hp = _max_hp()
		player_mana = _max_mana(); mana_debt=0.0
		var research_data = parsed.get("research", {})
		if not research_data is Dictionary or (loaded["version"] >= 1 and not parsed.has("research")):
			_protect_save("Invalid research save data. Original preserved.")
			return
		if loaded["version"] >= 1:
			var required := ["innate_affinity", "research_clues", "researched_base_elements"] if loaded["version"] < 3 else ["main_attribute", "auxiliary_attributes", "legacy_committed_attributes", "innate_affinity", "research_clues", "resonance_discoveries"]
			for field in required:
				if not research_data.has(field):
					_protect_save("Incomplete research save data. Original preserved.")
					return
		var error := research.load_data(research_data)
		if error.is_empty() and formal_rules:error=research.enable_free_attributes()
		if not error.is_empty():
			_protect_save(error)
			return
		if loaded["version"] >= 2 and (not parsed.has("chant") or not parsed.has("laboratory")):
			_protect_save("Incomplete chant / laboratory save. Original preserved.")
			return
		var chant_data = parsed["chant"] if parsed.has("chant") else ChantProfile.generate(rng.randi_range(1, 2147483647))
		var lab_data = parsed.get("laboratory", {})
		if not chant_data is Dictionary or not lab_data is Dictionary:
			_protect_save("Invalid chant / laboratory save. Original preserved.")
			return
		error = chant_profile.load_data(chant_data)
		if error.is_empty(): error = journal.load_data(lab_data)
		if error.is_empty(): error = research.validate_evidence(journal.records())
		if error.is_empty(): research.detach_evidence(journal.records())
		var discovery_data = parsed.get("spell_discoveries", {})
		if error.is_empty():
			if not discovery_data is Dictionary: error = "Invalid spell discoveries."
			else: error = discovered.load_data(discovery_data)
		if not error.is_empty():
			_protect_save(error)
			return
		if not parsed.has("spell_discoveries"): discovered.import_journal(journal.records())
		if loaded["migrate"]:
			if CharacterSave.backup_legacy(save_path, loaded["version"]) != OK:
				_protect_save("Legacy backup failed. Original preserved.")
				return
			_save_character()
		return
	var total := rng.randi_range(95, 105)
	magic_talent = rng.randi_range(15, total - 15)
	body_talent = total - magic_talent
	fixed_seed = rng.randi_range(1000, 9999999)
	# Only genuinely new characters receive affinity. These are provisional scores,
	# independent of magic/body talent and with no gameplay multiplier in Phase 2A.
	var affinity: Dictionary = {}
	var high_element: String = ChantProfile.OHAENG[rng.randi_range(0, 4)]
	for element in ChantProfile.OHAENG:
		affinity[element] = 85 if element == high_element else 25
	research.load_data({"innate_affinity": affinity})
	if formal_rules:research.enable_free_attributes()
	chant_profile.load_data(ChantProfile.generate_current(rng.randi_range(1, 2147483647)))
	player_hp = _max_hp()
	player_mana = _max_mana(); mana_debt=0.0
	_save_character()

func _protect_save(reason: String) -> void:
	save_writable = false
	save_error = reason
	_message(reason)

func _character_document() -> Dictionary:
	var save := _save_document.duplicate(true)
	if formal_rules and not prototype_profile.to_data().is_empty():save["active_chant"]=prototype_profile.to_data()
	save.merge({
		"schema_version": CharacterSave.SCHEMA_VERSION,
		"magic": magic_talent,
		"body": body_talent,
		"bank": bank_gold,
		"injury": injury_stacks,
		"armor": armor_durability,
		"fixed_seed": fixed_seed,
		"corpse": corpse.duplicate(true),
		"learned": learned_spells.duplicate(),
		"research": research.to_data(),
		"chant": chant_profile.to_data(),
		"laboratory": journal.to_data(),
		"spell_discoveries": discovered.to_data()
	}, true)
	return save

func _save_character() -> bool:
	if not save_writable: return false
	var save := _character_document()
	if developer_mode:
		_developer_document = save
		return true # Developer records never reach any player save or backup file.
	var error := CharacterSave.write_file(save_path, save)
	if error != OK:
		save_error = "Save failed: " + error_string(error)
		_message(save_error)
		return false
	_save_document = save
	save_error = ""
	return true

func _confirm_element_research(element: String, ticket: int = 0) -> String:
	if not save_writable: return "save_protected"
	if game_state != "LAB": return "ritual_location_required"
	var previous := research.to_data()
	var result := research.start_element_research(element, ticket)
	if result == "committed" and not _save_character():
		research.load_data(previous) # No permanent choice unless it reached disk.
		result = "save_failed"
	if research_panel != null:
		research_panel.feedback.text = "연구 영구 확정 완료: " + element if result == "committed" else "연구 요청: " + result
		research_panel.refresh()
	if laboratory_panel != null:
		laboratory_panel.message.text = "속성 영구 개화 완료: " + CharacterResearch.BaseElements.DEFINITIONS[element].display_name if result == "committed" else laboratory_panel.awakening_panel.reason(result)
		laboratory_panel.awakening_panel.refresh()
	pending_awakening_offer = {}
	_reset_combat_input()
	return result

func _collect_research_clue(element: String, source: String) -> void:
	if game_state != "LAB" or not save_writable or source not in ["book", "mentor", "environment"]: return
	var previous := research.to_data()
	var previous_journal:=journal.to_data()
	var duplicate:=research.has_clue(element,source)
	if formal_rules and source=="environment":
		var snapshot:Dictionary=_inspect_chant(true).simulation.final_state if not runes.is_empty() else last_laboratory_result.get("final_state",{})
		if runes.is_empty() and last_laboratory_result.get("observed_outcome","")!="released":snapshot={}
		var validation:=research.verify_catalyst(element,snapshot)
		laboratory_panel.arena.observe_catalyst(element)
		if validation!="verified":
			laboratory_panel.message.text="촉매가 응답했지만 공명은 이어지지 않았습니다. 실마리와 안정된 같은 속성의 관측을 살펴보세요."
			return
	var result := research.acquire_clue(element, source, CharacterResearch.Rules.clue_id(element, source))
	if source=="environment" and not duplicate:
		journal.append_environment(element,preload("res://scripts/research_lore.gd").DATA[element].catalyst,chant_profile.version())
		journal.trim_new_records(_journal_evidence_ids())
	if result == "recorded" and not _save_character():
		research.load_data(previous)
		journal.load_data(previous_journal)
		laboratory_panel.message.text = "단서 저장 실패: " + save_error
	elif source=="environment":
		laboratory_panel.arena.observe_catalyst(element)
		laboratory_panel.message.text=("이미 기록한 환경 단서 · " if duplicate else "환경 단서 획득 · ")+str(preload("res://scripts/research_lore.gd").DATA[element].catalyst)+" 단서/개화에서 연구 진행을 확인하세요."
	laboratory_panel.awakening_panel.refresh()
	_update_laboratory_live()

func _begin_awakening(element: String) -> String:
	if game_state != "LAB" or not save_writable: return "ritual_location_required"
	_reset_combat_input()
	pending_awakening_offer = {}
	var result := research.begin_ritual(element)
	laboratory_panel.message.text = "의식 진행: 직접 영창으로 목표의 안정 공명·형상·방향을 완성하세요." if result == "ritual_started" else laboratory_panel.awakening_panel.reason(result)
	if result == "ritual_started": laboratory_panel.awakening_panel.close()
	laboratory_panel.awakening_panel.refresh()
	_update_laboratory_live()
	return result

func _begin_movement_research()->bool:
	if not formal_rules or game_state!="LAB" or not save_writable:return false
	_reset_combat_input();research.cancel_request();pending_awakening_offer={}
	if research.blink_unlocked():laboratory_panel.message.text="이동술 연구를 이미 마쳤습니다. Ctrl로 점멸할 수 있습니다.";return false
	movement_research_active=true;laboratory_panel.awakening_panel.close()
	laboratory_panel.message.text="기초 이동술 연구 · 마나를 모으고 균형을 잡아 한 방향으로 길을 이으세요. 관측렌즈로 조작의 뜻을 살펴볼 수 있습니다."
	_update_laboratory_live();return true

func _cancel_awakening() -> void:
	_reset_combat_input()
	research.cancel_request()
	pending_awakening_offer = {}
	laboratory_panel.awakening_panel.cancel_confirmation()
	laboratory_panel.awakening_panel.refresh()
	laboratory_panel.message.text = "의식/확인을 취소했습니다. 주속성과 영구 슬롯은 바뀌지 않았습니다. 다른 대상을 계속 탐구할 수 있습니다."
	_update_laboratory_live()

func _finish_awakening_offer() -> void:
	if pending_awakening_offer.is_empty() or research.awakening_state != "confirmation_pending": return
	laboratory_panel.awakening_panel.offer(pending_awakening_offer)

func _acquire_debug_clue(element: String) -> void:
	if not save_writable: return
	var previous := research.to_data()
	var result := research.acquire_clue(element, "book", "debug_book_" + element)
	if result == "recorded" and not _save_character():
		research.load_data(previous)
		result = "save_failed"
	research_panel.feedback.text = "열람 / 단서: %s · 슬롯 소모 없음 · 기록 %d개" % [result, research.research_clues.size()]
	research_panel.refresh()

func _input(event: InputEvent) -> void:
	if hit_screen!=null and hit_screen.settings.visible:return
	combat_input.profile_version=_active_profile().version()
	if prototype_confirmation!=null and prototype_confirmation.visible:return
	if developer_tools_enabled and developer_panel != null:
		# F8 is intercepted by Godot's editor to stop the running project.
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2:
			_toggle_developer_menu()
			get_viewport().set_input_as_handled()
			return
		if developer_panel.panel.visible:
			if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: _toggle_developer_menu()
			return # GUI owns every input while this modal pauses the world.
	if game_state == "DUNGEON" and event is InputEventMouseButton and _pointer_over_game_ui(event.position):
		# Release can cross from world to HUD; clear held state without an action.
		if not event.pressed: combat_input.handle_event(event, float(Time.get_ticks_msec()) / 1000.0)
		return
	if game_state in ["DUNGEON", "LAB"] and spell_record_hud != null:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_J:
			spell_record_hud.toggle()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and spell_record_hud.owns_pointer(event.position): return
	if game_state == "LAB":
		if journal_manager != null and journal_manager.visible: return
		if laboratory_panel.awakening_panel.confirmation.visible: return
		if laboratory_panel.awakening_panel.visible:
			if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
				laboratory_panel.awakening_panel.close()
			return
		if event is InputEventMouseButton:
			if _controlled_trial() != null and laboratory_panel.arena.get_global_rect().has_point(event.position):
				combat_input.handle_event(event, float(Time.get_ticks_msec()) / 1000.0)
			return
		if laboratory_panel.is_editing():
			# Text/replay controls must never synthesize a cast or cancel a live one.
			if event is InputEventKey and not event.pressed:
				combat_input.handle_event(event, float(Time.get_ticks_msec()) / 1000.0)
			return
		# GUI buttons own LMB in the lab; no click-through cast while browsing logs.
		combat_input.handle_event(event, float(Time.get_ticks_msec()) / 1000.0)
		return
	if game_state == "HUB" and research_panel != null:
		if research_panel.confirmation.visible: return
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_B:
				if research_panel.is_open(): research_panel.close()
				else: research_panel.open()
				get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_ESCAPE and research_panel.is_open():
				research_panel.close()
				get_viewport().set_input_as_handled()
				return
		if research_panel.is_open(): return
	if event is InputEventKey and event.pressed and not event.echo:
		if game_state == "HUB":
			if event.keycode == KEY_1:
				_enter_dungeon("FIXED")
			elif event.keycode == KEY_2:
				_enter_dungeon("SHIFTING")
			elif event.keycode == KEY_H:
				_heal_injuries()
			elif event.keycode == KEY_L:
				_enter_laboratory()
	if game_state == "DUNGEON":
		combat_input.handle_event(event, float(Time.get_ticks_msec()) / 1000.0)

func _pointer_over_game_ui(point: Vector2) -> bool:
	if not AREA.has_point(get_canvas_transform().affine_inverse() * point): return true
	if spell_record_hud != null and spell_record_hud.owns_pointer(point): return true
	var hovered := get_viewport().gui_get_hovered_control()
	return hovered != null and hovered.is_visible_in_tree() and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE and hovered.get_global_rect().has_point(point)

func _request_destination(viewport_position: Vector2) -> void:
	var arena = _controlled_trial()
	if arena != null:
		if combat_input.mode != CombatInput.Mode.FOCUS_CAST and not arena.dodge.active:
			arena.navigation.request(arena, arena.screen_to_world(viewport_position))
		return
	if _developer_menu_visible() or game_state != "DUNGEON" or player_hp <= 0.0 or dodge.active or combat_input.mode == CombatInput.Mode.FOCUS_CAST: return
	var world := get_canvas_transform().affine_inverse() * viewport_position
	if not navigation.request(self, world): _message(navigation.feedback)

func _request_dodge() -> void:
	var arena = _controlled_trial()
	if arena != null:
		if combat_input.mode == CombatInput.Mode.FOCUS_CAST: return
		if research.blink_unlocked():_try_blink(arena,arena.dodge,arena.aim_world_position());return
		if arena.dodge.begin(arena.player_pos, DodgeMotion.cursor_heading(arena.player_pos, arena.aim_world_position())):
			arena.navigation.cancel()
			if combat_input.mode == CombatInput.Mode.MOBILE_CAST: _cancel_spell()
		return
	if _developer_menu_visible() or game_state != "DUNGEON" or player_hp <= 0.0 or combat_input.mode == CombatInput.Mode.FOCUS_CAST: return
	var heading := dodge.cursor_heading(player_pos, get_global_mouse_position())
	if research.blink_unlocked():_try_blink(self,dodge,get_global_mouse_position());return
	if not dodge.begin(player_pos, heading):
		_message("회피 대기 · %.1f초" % dodge.cooldown)
		return
	navigation.cancel()
	if combat_input.mode == CombatInput.Mode.MOBILE_CAST: _cancel_spell()

func _controlled_trial():
	if game_state != "LAB" or laboratory_panel == null or not laboratory_panel.trial_panel.visible or _developer_menu_visible(): return null
	if journal_manager != null and journal_manager.visible: return null
	if laboratory_panel.awakening_panel.visible or laboratory_panel.awakening_panel.confirmation.visible: return null
	return laboratory_panel.arena

func _blink_position_blocked(point:Vector2,radius:float)->bool:return _is_blocked(point,radius)

func _try_blink(actor,motion,cursor:Vector2)->bool:
	if not research.blink_unlocked() or motion.active or motion.cooldown>0 or combat_input.mode==CombatInput.Mode.FOCUS_CAST:return false
	var settings:Dictionary=preload("res://scripts/blink_motion.gd").CONFIG
	if player_mana<float(settings.blink_mana_cost) or mana_debt>0:return false
	var result:=preload("res://scripts/blink_motion.gd").destination(actor,cursor)
	if not result.allowed:return false
	var before:Vector2=actor.player_pos;var mana:=player_mana;var cooldown:float=motion.cooldown
	actor.player_pos=result.position;player_mana-=float(settings.blink_mana_cost);motion.cancel();motion.cooldown=motion.COOLDOWN
	if not _save_character():
		actor.player_pos=before;player_mana=mana;motion.cooldown=cooldown;return false
	actor.navigation.cancel()
	if combat_input.mode==CombatInput.Mode.MOBILE_CAST:_cancel_spell()
	var effects=actor.combat if actor!=self else elemental_combat
	for point in [before,actor.player_pos]:effects._visual({"pos":point,"to":actor.player_pos,"radius":28.0,"life":.3,"total":.3,"color":Color("cabce9"),"attribute":"BLINK"})
	preload("res://scripts/blink_modifier.gd").new().after_blink(actor,before,actor.player_pos)
	return true

func aim_world_position() -> Vector2:return get_global_mouse_position()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_reset_combat_input()

func _reset_combat_input() -> void:
	navigation.cancel()
	dodge.cancel()
	if laboratory_panel != null and laboratory_panel.arena != null:
		laboratory_panel.arena.navigation.cancel(); laboratory_panel.arena.dodge.cancel()
	if game_state == "LAB" and not runes.is_empty(): _record_cancelled_experiment()
	movement_research_active=false
	combat_input.reset()
	_clear_chant()
	focus_active = false
	cast_feedback = "Shift를 유지하며 영창을 엮으세요." if formal_rules else "Q > E > LMB: Mana Bolt (no element research needed)."
	_update_laboratory_live()

func _on_combat_mode_changed(_previous: CombatInput.Mode, current: CombatInput.Mode) -> void:
	if current!=CombatInput.Mode.NORMAL:_capture_chant_attributes()
	if current == CombatInput.Mode.FOCUS_CAST:
		navigation.cancel()
		dodge.cancel()
		if laboratory_panel != null and laboratory_panel.arena != null:
			laboratory_panel.arena.navigation.cancel(); laboratory_panel.arena.dodge.cancel()
	# The router submits genuine lab mobile sessions before switching to NORMAL.
	# Remaining buffers are explicit cancellations; dungeon release stays unchanged.
	if current == CombatInput.Mode.NORMAL:
		if game_state == "LAB" and not runes.is_empty() and not _lab_release_consumed: _record_cancelled_experiment()
		_clear_chant()
		cast_feedback = "마나가 잦아듭니다. 다음 영창을 시작할 수 있습니다." if formal_rules else "Q > E > LMB: Mana Bolt (hold Shift or double-tap Shift)."
	_update_laboratory_live()

func _auto_release_laboratory_session() -> void:
	if game_state != "LAB" or combat_input.mode != CombatInput.Mode.MOBILE_CAST or runes.is_empty() or _developer_menu_visible(): return
	if laboratory_panel.is_editing() or laboratory_panel.awakening_panel.visible or laboratory_panel.awakening_panel.confirmation.visible: return
	# The router consumes the session before this call. Manual release, reset and
	# cancellation also discard it, so neither repeated key-up nor UI can resubmit.
	last_laboratory_result = _inspect_chant(true)["simulation"]
	_cast_spell()
	_clear_chant() # Failure/insufficient mana must also leave a fresh input session.
	_update_laboratory_live()

func _on_command_entered(token: String) -> void:
	if dodge.active: return
	_capture_chant_attributes()
	if runes.size() >= (5 if _prototype_active() else spell_book.max_commands):
		if _prototype_active():_prototype_overflow=true
		cast_feedback = "Command buffer full. Esc to clear."
		return
	runes.append(token)
	_lab_release_consumed = false
	if game_state == "LAB" and runes.size() == 1: laboratory_panel.begin_attempt()
	var now_ms := roundi(combat_input.last_command_time * 1000.0)
	if chant_inputs.is_empty(): chant_started_ms = now_ms
	chant_inputs.append({"key": token, "at_ms": clampi(now_ms - chant_started_ms, 0, 60000), "hold_ms": 0,
		"started_ms": now_ms, "released": false})
	_show_rune_feedback()
	_update_laboratory_live()

func _on_command_released(token: String, held_ms: int) -> void:
	for index in range(chant_inputs.size() - 1, -1, -1):
		if chant_inputs[index]["key"] == token and not chant_inputs[index]["released"]:
			chant_inputs[index]["hold_ms"] = mini(held_ms, 60000)
			chant_inputs[index]["released"] = true
			_show_rune_feedback()
			_update_laboratory_live()
			return

func _clear_chant() -> void:
	_chant_session_context.clear()
	signature_session.end()
	_prototype_overflow=false
	combat_input.discard_mobile_session()
	_lab_release_consumed = false
	runes.clear()
	chant_inputs.clear()

func _simulation_inputs(finalize_holds := false) -> Array:
	var inputs: Array = []
	for index in range(runes.size()):
		var event := {"key": runes[index], "at_ms": index * 100, "hold_ms": 0}
		if index < chant_inputs.size() and chant_inputs[index]["key"] == runes[index]:
			var stored: Dictionary = chant_inputs[index]
			event = {"key": stored["key"], "at_ms": stored["at_ms"], "hold_ms": stored["hold_ms"]}
			if finalize_holds and not stored["released"]:
				event["hold_ms"] = clampi(Time.get_ticks_msec() - stored["started_ms"], 0, 60000)
		inputs.append(event)
	return inputs

func _cancel_spell() -> void:
	if game_state == "LAB" and not runes.is_empty(): _record_cancelled_experiment()
	movement_research_active=false
	_clear_chant()
	if game_state == "LAB" and not research.ritual_target.is_empty():
		research.cancel_request()
		pending_awakening_offer = {}
	cast_feedback = "영창을 거두었습니다." if formal_rules else "Cast cancelled. Enter Q > E again for Mana Bolt."
	_update_laboratory_live()

func _process(delta: float) -> void:
	hit_feedback.advance(delta)
	hit_screen.advance(player_hp,_max_hp(),delta,game_state in ["LAB","DUNGEON"])
	if hit_screen.settings.visible:return
	signature_session.advance(delta)
	if _developer_menu_visible():
		queue_redraw()
		return
	if spell_record_hud != null:
		spell_record_hud.visible = game_state == "DUNGEON" or _controlled_trial() != null
		spell_record_hud.layer = 27 # Remains sharp above the exhaustion screen pass.
		spell_record_hud.update_current(runes, cast_feedback)
	exhaustion_seconds = maxf(0.0, exhaustion_seconds - delta)
	if status_time > 0.0:
		status_time -= delta
	var mana_regen_multiplier := FOCUS_MANA_REGEN_MULTIPLIER if combat_input.mode == CombatInput.Mode.FOCUS_CAST else 1.0
	if game_state == "LAB":
		_recover_mana(8.0 * mana_regen_multiplier * delta)
		player_attack_cooldown = maxf(0, player_attack_cooldown - delta)
		_update_laboratory_live()
		if player_hp<=0:_die()
	if game_state == "DUNGEON":
		var axis := combat_input.movement_axis()
		var was_dodging := dodge.active
		dodge.advance(self, delta)
		if not was_dodging and axis != Vector2.ZERO:
			navigation.cancel()
			axis = axis.normalized()
			_try_move_player(axis * _movement_speed() * delta)
		elif not was_dodging and combat_input.mode != CombatInput.Mode.FOCUS_CAST:
			navigation.advance(self, delta, _movement_speed())
		player_attack_cooldown = maxf(0.0, player_attack_cooldown - delta)
		_recover_mana(3.0 * mana_regen_multiplier * delta)
		focus_active = combat_input.swift_sense_held and focus > 0.0 and _legacy_sense_available()
		if focus_active:
			focus = maxf(0.0, focus - 32.0 * delta)
		else:
			focus = minf(100.0, focus + 14.0 * delta)
		var enemy_time := (0.35 if focus_active else 1.0)*signature_session.enemy_multiplier()
		elemental_combat.update(self, delta)
		_update_enemies(delta * enemy_time)
		if game_state == "DUNGEON":
			_update_missiles(delta, enemy_time)
		if game_state=="DUNGEON" and player_hp<=0:_die()
	_update_mana_exhaustion(delta)
	queue_redraw()

func _message(s: String) -> void:
	status_message = s
	status_time = 3.5

func _legacy_sense_available() -> bool: return true # Legacy regression scene only.

func _movement_speed() -> float:
	if combat_input.mode==CombatInput.Mode.FOCUS_CAST:return 0.0
	var casting:float=MOBILE_CAST_SPEED_MULTIPLIER if combat_input.mode==CombatInput.Mode.MOBILE_CAST else 1.0
	return PLAYER_SPEED*casting*ManaOverdraw.speed(mana_debt,_max_mana())

func _recover_mana(amount:float) -> void:
	var recovered:=ManaOverdraw.recover(player_mana,mana_debt,_max_mana(),amount)
	player_mana=recovered.x;mana_debt=recovered.y

func _update_mana_exhaustion(delta:float) -> void:
	if mana_exhaustion_view!=null:
		mana_exhaustion_view.advance(mana_debt,_max_mana(),delta,game_state in ["DUNGEON","LAB"])

func _cast_transaction_state() -> Dictionary: return {}
func _restore_cast_transaction(_snapshot:Dictionary) -> void: pass

func _enter_dungeon(kind: String) -> void:
	dodge.reset()
	if game_state == "LAB": _leave_laboratory()
	if research_panel != null: research_panel.set_hub(false)
	game_state = "DUNGEON"
	if spell_record_hud != null:
		spell_record_hud.visible = true
		spell_record_hud.refresh()
	elemental_combat.clear()
	dungeon_kind = kind
	map_seed = fixed_seed if kind == "FIXED" else rng.randi_range(100, 999999999)
	_build_map(map_seed)
	player_pos = START_POS
	player_hp = _max_hp()
	player_mana = _max_mana(); mana_debt=0.0
	focus = 100.0
	carried_gold = 0
	missiles.clear()
	_reset_combat_input()
	_spawn_enemies()
	corpse_pos = Vector2.ZERO
	if not corpse.is_empty() and str(corpse.get("kind", "")) == kind:
		if kind == "FIXED":
			corpse_pos = Vector2(float(corpse.get("x", 0.0)), float(corpse.get("y", 0.0)))
		else:
			corpse_pos = _random_open_point()
	_message("Mana Bolt: hold Shift, type Q > E, then LMB. Double-tap Shift: stationary casting.")
	if research.main_attribute != null:
		_message("개화한 주속성의 짧은 구조를 시험하세요. 직접 영창 후 조준하여 LMB · 발견 영창은 J.")

func _build_map(seed_value: int) -> void:
	dungeon_rng.seed = seed_value
	walls.clear()
	for row in range(ROWS):
		for col in range(COLS):
			if row == 0 or row == ROWS - 1 or col == 0 or col == COLS - 1:
				walls.append(Vector2i(col, row))
			elif dungeon_rng.randf() < 0.13:
				# Preserve an always navigable route from spawn to the exit.
				if row == 2 or col == 17 or Vector2i(col, row).distance_to(Vector2i(2, 2)) < 2.5 or Vector2i(col, row).distance_to(Vector2i(17, 9)) < 2.5:
					continue
				walls.append(Vector2i(col, row))

func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(AREA.position + Vector2(cell) * TILE, Vector2(TILE, TILE))

func _is_blocked(point: Vector2, radius: float = 13.0) -> bool:
	if not AREA.grow(-radius).has_point(point):
		return true
	for cell in walls:
		if _cell_rect(cell).grow(radius).has_point(point):
			return true
	return elemental_combat.blocks(point, radius)

func _try_move_player(motion: Vector2) -> void:
	player_pos = _move_actor(player_pos, motion)

func _move_actor(position: Vector2, motion: Vector2) -> Vector2:
	# Small swept steps prevent temporary barriers being skipped during a slow frame.
	var steps := maxi(1, ceili(motion.length() / 6.0))
	var step := motion / steps
	for i in steps:
		# A clear diagonal must not be rejected by its artificial X-only midpoint.
		if not _is_blocked(position + step):
			position += step
			continue
		var px := position + Vector2(step.x, 0.0)
		if not _is_blocked(px): position.x = px.x
		var py := position + Vector2(0.0, step.y)
		if not _is_blocked(py): position.y = py.y
	return position

func _random_open_point() -> Vector2:
	for tries in range(150):
		var col := dungeon_rng.randi_range(2, COLS - 3)
		var row := dungeon_rng.randi_range(2, ROWS - 3)
		var candidate := AREA.position + (Vector2(float(col), float(row)) + Vector2(0.5, 0.5)) * TILE
		if not _is_blocked(candidate, 18.0) and candidate.distance_to(START_POS) > 140.0 and candidate.distance_to(EXIT_POS) > 80.0:
			return candidate
	return EXIT_POS - Vector2(80.0, 0.0)

func _spawn_enemies() -> void:
	enemies.clear()
	for i in range(5):
		enemies.append({"pos": _random_open_point(), "hp": 42.0, "shot": dungeon_rng.randf_range(1.0, 2.0)})

func _update_enemies(scaled_delta: float) -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var e := enemies[i]
		if float(e["hp"]) <= 0.0:
			carried_gold += 10
			enemies.remove_at(i)
			continue
		var pos: Vector2 = e["pos"]
		var offset := player_pos - pos
		if e.get("stagger_remaining", 0.0) > 0.0: continue
		if offset.length() > 50.0 and e.get("root_remaining", 0.0) <= 0.0:
			var movement := offset.normalized() * ENEMY_SPEED * scaled_delta * preload("res://scripts/combat_geometry.gd").slow_multiplier(e)
			pos = _move_actor(pos, movement)
			e["pos"] = pos
		elif offset.length() < 25.0:
			_receive_player_damage(19.0*scaled_delta,false,offset)
		e["shot"] = float(e["shot"]) - scaled_delta
		if float(e["shot"]) <= 0.0:
			e["shot"] = 2.7
			if offset.length() < 460.0:
				missiles.append({"pos": pos, "dir": offset.normalized(), "hostile": true, "life": 4.0, "dmg": 16.0})
		enemies[i] = e
	if player_hp <= 0.0:
		_die()

func _update_missiles(delta: float, enemy_time: float) -> void:
	elemental_combat.update_missiles(self, delta, enemy_time)

func _melee_attack() -> void:
	if _controlled_trial() != null:
		if player_attack_cooldown > 0 or laboratory_panel.arena.dodge.active: return
		player_attack_cooldown = CombatBalance.MELEE_INTERVAL
		laboratory_panel.arena.melee(CombatBalance.melee_damage(body_talent))
		return
	if game_state != "DUNGEON" or dodge.active: return
	if player_attack_cooldown > 0.0: return
	player_attack_cooldown = CombatBalance.MELEE_INTERVAL
	var aim := get_global_mouse_position() - player_pos
	if aim.length() < 1.0: return
	for e in enemies:
		var offset: Vector2 = e["pos"] - player_pos
		if offset.length() < 78.0 and aim.normalized().dot(offset.normalized()) > 0.30:
			e["hp"] = float(e["hp"]) - CombatBalance.melee_damage(body_talent)

func _show_rune_feedback() -> void:
	var result:=_inspect_chant()
	cast_feedback=str(_public_chant_preview(result)["text"])

func _public_chant_preview(result:Dictionary)->Dictionary:
	var projected:=result.duplicate(true)
	var cost:float=result.get("mana_cost",0)
	projected["resource_allowed"]=ManaOverdraw.quote(player_mana,_max_mana(),cost,mana_debt).get("allowed",false)
	projected["cast_blocked"]=exhaustion_seconds>0 or not save_writable
	return preload("res://scripts/spell_preview.gd").public_result(projected,preload("res://scripts/research_visibility.gd").known(discovered),laboratory_panel!=null and laboratory_panel.detailed_observation!=null and laboratory_panel.detailed_observation.button_pressed)

func _inspect_chant(finalize_holds := false) -> Dictionary:
	if _prototype_active():
		var inputs:=_simulation_inputs(finalize_holds)
		if _prototype_overflow:inputs.append({"key":"!","at_ms":60000,"hold_ms":0})
		return preload("res://scripts/chant_engine_v2.gd").resolve(prototype_profile,inputs,_prototype_context())
	var simulation := ManaSimulator.simulate(chant_profile, _simulation_inputs(finalize_holds), true, _legacy_simulation_context())
	var legacy := spell_book.inspect(runes, research.researched_base_elements)
	# Keep the taught QE formula and the existing Resource requirements contract.
	if legacy["state"] in ["ready", "locked", "invalid_data"] and not (legacy.get("spell") == spell_book.MANA_BOLT and simulation["state"] != "ready"):
		legacy["simulation"] = simulation
		return legacy
	var result := simulation.duplicate(true)
	if game_state in ["DUNGEON", "LAB"] and (not simulation["final_state"]["base_attributes"].is_empty() or simulation["final_state"].get("neutral_legacy", false)):
		var access:Dictionary=research.simulation_context()
		if developer_mode and _prototype_all:
			var lineage:Array=simulation.final_state.base_attributes
			if not lineage.is_empty():access["main_attribute"]=lineage[0]
			if lineage.size()==2:access["auxiliary_attributes"]=[lineage[1]];access["binding_pairs"]=[preload("res://scripts/fusion_rules.gd").pair(lineage)]
			access["neutral_wave_unlocked"]=true
		var combat := CombatSpellResolver.resolve(simulation, access.get("main_attribute"), access)
		# Unawakened/unfinished lab structures remain research phenomena. Only a
		# genuinely authorized complete combat structure enters the shared executor.
		if game_state == "DUNGEON" or combat.get("spell") != null: result = combat
		elif combat.get("state")=="locked":
			if simulation["state"]=="ready" and str(simulation["kind"]).ends_with("_resonance"):
				result["message"]="공명 관측만 기록합니다. 보조속성 단일마법은 발현할 수 없습니다."
			elif simulation["final_state"]["base_attributes"].size()==1 and preload("res://scripts/m1_spell_catalog.gd").select(simulation["final_state"],simulation["final_state"]["base_attributes"][0])!=null:result=combat
	result["simulation"] = simulation
	if simulation["kind"] == "mana_bolt": result["spell"] = spell_book.MANA_BOLT
	if not runes.is_empty() and runes[0] == "Q" and legacy["state"] == "invalid" and result["state"] != "ready":
		result["message"] = legacy["message"] + " " + simulation["observation"]
	return result

func _cast_spell() -> void:
	signature_session.end()
	combat_input.discard_mobile_session() # Explicit release also consumes auto-submit eligibility.
	if game_state == "LAB": _lab_release_consumed = true
	if dodge.active: return
	if not save_writable:
		cast_feedback = "Save protected: casting unavailable."
		return
	var result := _inspect_chant(true)
	if exhaustion_seconds > 0.0:
		cast_feedback = "영창 안정화 중 · 잠시 후 다시 시전하세요."
		_record_experiment(result["simulation"], "exhausted", 0.0)
		if game_state == "LAB": laboratory_panel.show_attempt_result("발현 보류 · 영창이 안정화된 뒤 다시 방출하세요.")
		return
	if result["state"] != "ready":
		cast_feedback = "Cast failed: " + str(result["message"])
		# A single Q is the existing tutorial's unfinished prefix; keep its behavior.
		var penalty := 0.0 if runes.is_empty() or runes == ["Q"] or result["state"] in ["locked", "invalid_data"] else minf(2.0, maxf(0,player_mana))
		if _prototype_active():penalty=minf(maxf(0,player_mana),float(preload("res://scripts/chant_engine_v2.gd").CONFIG.failure_cost.get("collapse" if result.get("failure_kind")=="collapse" else "misfire",0))) if result.state not in ["locked","ambiguous"] else 0.0
		if runes.is_empty():penalty=0.0
		player_mana -= penalty
		var prior_exhaustion := exhaustion_seconds
		if penalty > 0.0: exhaustion_seconds = 1.0
		if not _record_experiment(result["simulation"], "failed", penalty):
			player_mana += penalty
			exhaustion_seconds = prior_exhaustion
		if game_state == "LAB": laboratory_panel.show_attempt_result(("사용 불가 · " if result["state"]=="locked" else "구조 미완성 · ") + str(result["message"]))
		_update_laboratory_live()
		return
	var definition: SpellDefinition = result.get("spell")
	var cost: float = definition.mana_cost if definition != null else result["mana_cost"]
	if result.has("final_state") and definition != null: cost = result["mana_cost"]
	var payment:=ManaOverdraw.quote(player_mana,_max_mana(),cost,mana_debt)
	if not payment["allowed"]:
		cast_feedback = "마나 부족 · 더 이상 정신력으로 버틸 수 없습니다. 회복 후 다시 시도하세요."
		_record_experiment(result["simulation"], "insufficient_mana", 0.0)
		if game_state == "LAB": laboratory_panel.show_attempt_result("발현 실패 · 마나가 부족하고 정신력 초과 한도를 넘었습니다. 회복 후 다시 시험하세요.")
		return
	if definition == null:
		var previous_mana:=player_mana
		var previous_debt:=mana_debt
		player_mana = payment["next_mana"]
		mana_debt = payment["next_debt"]
		cast_feedback = result["message"]
		if not _record_experiment(result["simulation"], "released", cost):
			player_mana = previous_mana;mana_debt=previous_debt
		_update_mana_exhaustion(0)
		_clear_chant()
		_update_laboratory_live(result["simulation"])
		_finish_awakening_offer()
		return
	var dir := get_global_mouse_position() - player_pos
	if dir.length() < 1.0: dir = Vector2.RIGHT
	var arena = laboratory_panel.arena if game_state == "LAB" else self
	var runtime = laboratory_panel.arena.combat if game_state == "LAB" else elemental_combat
	var transaction:=_cast_transaction_state()
	var prior_effects := {"enemies": arena.enemies.duplicate(true), "missiles": arena.missiles.duplicate(true), "barriers": runtime.barriers.duplicate(true), "visuals": runtime.visuals.duplicate(true), "sequence": runtime._next_enemy_id}
	prior_effects["water_states"]=runtime.water_states.duplicate(true);prior_effects["water_metrics"]=runtime.water_metrics.duplicate(true)
	var executed := laboratory_panel.arena.manifest(definition) if game_state == "LAB" else elemental_combat.cast(self, definition, dir.normalized(), get_global_mouse_position())
	if not executed:
		cast_feedback = "방출 불가: 장애물/대상과 겹치지 않는 열린 공간을 조준하세요."
		_record_experiment(result["simulation"], "blocked", 0.0)
		if game_state == "LAB": laboratory_panel.show_attempt_result(cast_feedback)
		return
	var previous_mana:=player_mana
	var previous_debt:=mana_debt
	player_mana = payment["next_mana"]
	mana_debt=payment["next_debt"]
	var spell := str(definition.spell_id)
	var previous_discoveries := discovered.to_data()
	var previous_learned := learned_spells.duplicate()
	var previous_metrics := developer_metrics.duplicate(true)
	var inputs: Array = []
	for step in result["simulation"]["casting_steps"]: inputs.append(step["input"].duplicate(true))
	var changed:=discovered.record(spell, definition.display_name, inputs, int(result["simulation"]["rules_version"]), game_state, Array(definition.requires_elements),prototype_profile.to_data() if _prototype_active() else {})
	if not learned_spells.has(spell):
		learned_spells.append(spell)
		changed=true
	cast_feedback = "Released %s [%s]. Enter commands again to cast." % [definition.display_name, " > ".join(runes)]
	if developer_mode:
		var elapsed := 0
		for event in inputs: elapsed = maxi(elapsed, int(event["at_ms"] + event["hold_ms"]))
		developer_metrics = {"spell": definition.display_name, "input_count": inputs.size(), "elapsed_ms": elapsed, "mana_spent": cost, "impact_damage": definition.damage, "status_seconds": definition.duration}
	# Known positive-mana casts retain the existing autosave policy. Every mental
	# payment must persist even for an already known recipe, or roll back entirely.
	var must_save:bool=changed or payment["mental_spent"]>0
	var recorded := _record_experiment(result["simulation"], "released", cost, {"spell_id": spell, "catalog_id": str(definition.catalog_id), "english_name": definition.english_name, "name": definition.display_name, "base_elements": Array(definition.requires_elements), "new_spell": not previous_discoveries["spells"].has(spell), "damage": definition.damage, "duration": definition.duration, "range": definition.radius if definition.radius > 0 else definition.projectile_speed * definition.lifetime, "mana_cost": cost,"mental_spent":payment["mental_spent"], "variant_status": "prototype_v05"}) if game_state == "LAB" else (not must_save or _save_character())
	if not recorded:
		player_mana = previous_mana
		mana_debt=previous_debt
		arena.enemies = prior_effects["enemies"]
		arena.missiles = prior_effects["missiles"]
		runtime.barriers = prior_effects["barriers"]
		runtime.visuals = prior_effects["visuals"]
		runtime._next_enemy_id = prior_effects["sequence"]
		runtime.water_states=prior_effects.water_states;runtime.water_metrics=prior_effects.water_metrics
		_restore_cast_transaction(transaction)
		discovered.load_data(previous_discoveries)
		learned_spells = previous_learned
		developer_metrics = previous_metrics
		if game_state == "LAB": laboratory_panel.show_attempt_result("저장 실패 · 마나와 발현을 되돌렸습니다. 다시 입력해 시험하세요.")
		_update_laboratory_live(result["simulation"])
		return
	if game_state == "LAB": laboratory_panel.show_manifestation(definition.display_name+(" · 불안정한 발현" if result.get("risk")=="unstable" else ""), recorded)
	if payment["mental_spent"]>0:
		_message("정신력으로 마법을 유지했습니다. 시야가 흐려지고 몸이 무거워집니다.")
	_update_mana_exhaustion(0)
	spell_audio.cue(spell, str(definition.effect))
	if spell_record_hud != null: spell_record_hud.refresh()
	_clear_chant()
	var displayed: Dictionary = result["simulation"].duplicate(true)
	displayed["manifestation"] = definition.display_name
	displayed["resolution"]={"state":result.state,"risk":result.get("risk","normal")}
	_update_laboratory_live(displayed)
	_finish_awakening_offer()

func _enter_laboratory() -> void:
	if game_state != "HUB" or not save_writable: return
	research_panel.close()
	research_panel.set_hub(false)
	_reset_combat_input()
	game_state = "LAB"
	last_laboratory_result = {}
	laboratory_panel.open(research_panel.opener.theme)
	_update_laboratory_live()

func _leave_laboratory() -> void:
	if game_state != "LAB": return
	_reset_combat_input()
	research.cancel_request()
	pending_awakening_offer = {}
	game_state = "HUB"
	laboratory_panel.close()
	research_panel.set_hub(true)

func _laboratory_recover() -> void:
	if game_state != "LAB": return
	player_mana = _max_mana(); mana_debt=0.0
	exhaustion_seconds = 0.0
	laboratory_panel.arena.reset_targets()
	_update_laboratory_live()

func _record_experiment(simulation: Dictionary, outcome: String, spent: float, manifestation: Dictionary = {}) -> bool:
	if simulation.has("property_version") and not manifestation.is_empty():
		manifestation["property_version"]=simulation.property_version
		manifestation["formula_effect"]=simulation.get("final_state",{}).get("formula_effect",{}).duplicate(true)
	if game_state != "LAB" or runes.is_empty(): return true
	if int(simulation["rules_version"])>=8 and not manifestation.is_empty():
		manifestation["risk"]="unstable" if simulation.get("failure_kind")=="unstable" else "normal"
		manifestation["variant_status"]="chant_v2_"+str(manifestation["risk"])
	if manifestation.is_empty() and outcome in ["cancelled", "failed", "exhausted", "insufficient_mana"] and not journal.auto_failures(): return true
	var previous := journal.to_data()
	var previous_research := research.to_data()
	var inputs: Array = []
	for step in simulation["casting_steps"]: inputs.append(step["input"].duplicate(true))
	var elapsed := 0
	for event in inputs: elapsed = maxi(elapsed, event["at_ms"] + event["hold_ms"])
	var id := journal.append(simulation, outcome, spent, elapsed, _active_profile().version() if int(simulation["rules_version"])>=8 else chant_profile.version())
	if not manifestation.is_empty(): journal.mark_manifestation(id, manifestation)
	if outcome == "released":
		if formal_rules and movement_research_active:research.complete_movement_research(simulation,id)
		elif formal_rules:research.record_current_resonance(simulation,id)
		elif int(simulation["rules_version"])<8:research.record_resonance(chant_profile, inputs, id)
	journal.trim_new_records(_journal_evidence_ids())
	var written := _save_character()
	if not written:
		journal.load_data(previous)
		research.load_data(previous_research)
		pending_awakening_offer = {}
		laboratory_panel.message.text = "기록 저장 실패: " + save_error
	else:
		laboratory_panel.message.text = "실험 자동 기록 완료. 단계와 두 기록을 자유롭게 비교하세요."
		simulation["observed_outcome"]=outcome;last_laboratory_result=simulation.duplicate(true)
		if not manifestation.is_empty(): laboratory_panel.message.text = "발현 성공 · " + str(manifestation.get("name", ""))
		elif outcome == "released": laboratory_panel.show_attempt_result("공명 성공 · 전투마법은 아직 발현되지 않았습니다.")
		if outcome=="released" and movement_research_active and research.blink_unlocked():
			movement_research_active=false;laboratory_panel.show_attempt_result("이동술 연구 완료 · Ctrl이 점멸로 바뀝니다. 마나 5를 사용해 커서까지 이동합니다.")
		if outcome == "released" and not research.ritual_target.is_empty():
			var proof := research.complete_ritual(_active_profile(), inputs,formal_rules)
			if proof["state"] == "confirmation_required":
				pending_awakening_offer = proof
				laboratory_panel.message.text = "개화 의식 성공. 최종 영구 확정 확인을 기다립니다."
			else: laboratory_panel.message.text = laboratory_panel.awakening_panel.reason(proof["state"])
	laboratory_panel.refresh(not manifestation.get("new_spell",false),manifestation.get("new_spell",false))
	laboratory_panel.awakening_panel.refresh()
	return written

func _journal_evidence_ids() -> Array:
	research.detach_evidence(journal.records())
	return [] # Earned research and spell favorites never lock a user observation.

func _teach_mana_principle()->void:
	if not save_writable:return
	var previous:=_save_document.duplicate(true)
	var lesson:int=clampi(_save_document.get("mentor_lessons",0),0,4)
	laboratory_panel.message.text=preload("res://scripts/mentor_advice.gd").LESSONS[lesson]
	_save_document["mentor_lessons"]=mini(4,lesson+1)
	if not _save_character():_save_document=previous

func _preview_journal_retention()->Dictionary:
	if not developer_mode and not FileAccess.file_exists(save_path+".journal_retention.bak"):
		if DirAccess.copy_absolute(save_path,save_path+".journal_retention.bak")!=OK:return {}
	return journal.trim_preview(_journal_evidence_ids())

func _confirm_journal_retention(expected:Array)->bool:
	if not save_writable or journal.trim_preview(_journal_evidence_ids()).remove!=expected:return false
	var preview:=_preview_journal_retention()
	if preview.is_empty():return false
	var previous:=journal.to_data()
	journal.confirm_retention(_journal_evidence_ids())
	if not _save_character():journal.load_data(previous);return false
	_journal_undo["developer" if developer_mode else "player"]=previous
	laboratory_panel.refresh();return true

func _delete_journal_records(ids: Array) -> int:
	if not save_writable: return 0
	var previous := journal.to_data()
	var allowed := journal.eligible_ids(ids, _journal_evidence_ids())
	if allowed.is_empty(): return 0
	if not developer_mode and (not FileAccess.file_exists(save_path) or DirAccess.copy_absolute(save_path, save_path + ".journal_delete.bak") != OK):
		laboratory_panel.message.text = "삭제 백업 실패 · 원본을 유지합니다."; return 0
	var count := journal.remove_records(allowed, _journal_evidence_ids())
	if not _save_character(): journal.load_data(previous); return 0
	_journal_undo["developer" if developer_mode else "player"] = previous
	laboratory_panel.refresh()
	return count

func _restore_journal_delete() -> bool:
	if not save_writable: return false
	var saved: Dictionary = _journal_undo["developer" if developer_mode else "player"]
	if saved.is_empty() and not developer_mode:
		var backup := CharacterSave.load_file(save_path + ".journal_delete.bak")
		if backup.get("state") == "loaded": saved = backup["data"].get("laboratory", {})
	if saved.is_empty(): return false
	var previous := journal.to_data(); var merged := previous.duplicate(true)
	var by_id := {}
	for record in saved["records"] + previous["records"]: by_id[int(record["id"])] = record
	merged["records"] = by_id.values(); merged["records"].sort_custom(func(a, b): return a["id"] < b["id"])
	merged["next_id"] = maxi(saved["next_id"], previous["next_id"])
	if not journal.load_data(merged).is_empty(): return false
	if not _save_character(): journal.load_data(previous); return false
	laboratory_panel.refresh(); return true

func _protect_journal_records(ids: Array, enabled: bool) -> void:
	var previous := journal.to_data()
	for id in ids: journal.protect(int(id), enabled)
	if not _save_character(): journal.load_data(previous)

func _set_journal_auto_failures(enabled: bool) -> void:
	var previous := journal.to_data(); journal.set_auto_failures(enabled)
	if not _save_character(): journal.load_data(previous)
	journal_manager.failures.set_pressed_no_signal(journal.auto_failures())

func _observe_first_word() -> void:
	if game_state != "LAB" or runes.size() != 1 or not save_writable:
		laboratory_panel.message.text = "시동어 관찰: Shift를 유지하고 첫 키 하나만 입력한 뒤 관측하세요."; return
	var element := chant_profile.first_word(runes[0])
	if element.is_empty():
		laboratory_panel.message.text = "관측할 오행 시동어가 아닙니다. 다른 첫 입력의 반응을 비교하세요."
		return
	var previous := journal.to_data()
	if journal.observe_first_word(runes[0], element) and not _save_character(): journal.load_data(previous); return
	laboratory_panel.message.text = "관측한 시동어 %s — %s · 슬롯과 친화성은 변하지 않습니다." % [runes[0], CharacterResearch.BaseElements.DEFINITIONS[element].display_name if element in CharacterResearch.BaseElements.OHAENG else "중립 시작 (이전 호환)"]
	combat_input.discard_mobile_session(); _clear_chant(); _update_laboratory_live()

func _change_spell_preference(id: String, favorite: bool, representative: int) -> void:
	if not save_writable: return
	var previous := discovered.to_data()
	discovered.set_favorite(id, favorite)
	discovered.choose_recipe(id, representative)
	if not _save_character(): discovered.load_data(previous)
	spell_record_hud.refresh()

func _developer_menu_visible() -> bool:
	return developer_panel != null and developer_panel.panel.visible

func _toggle_developer_menu() -> void:
	if not developer_tools_enabled or developer_panel == null: return
	var opening := not developer_panel.panel.visible
	if opening:
		# Developer browsing is a safe pause, never an automatic journal/save action.
		_clear_chant()
		combat_input.reset()
		navigation.cancel()
		dodge.cancel()
		developer_panel.refresh()
	developer_panel.panel.visible = opening
	if game_state == "LAB": laboratory_panel.arena.set_process(not opening)
	get_viewport().gui_release_focus()

func _apply_temporary_document(data: Dictionary) -> void:
	research.use_current_rules=formal_rules
	if mana_exhaustion_view!=null:mana_exhaustion_view.reset()
	for pair in [["magic", "magic_talent"], ["body", "body_talent"], ["bank", "bank_gold"], ["injury", "injury_stacks"], ["armor", "armor_durability"], ["fixed_seed", "fixed_seed"]]:
		set(pair[1], int(data[pair[0]]))
	corpse = data["corpse"].duplicate(true)
	var restored_learned:Array[String]=[]
	for spell in data["learned"]: restored_learned.append(str(spell))
	learned_spells=restored_learned
	research.load_data(data["research"])
	if formal_rules:research.enable_free_attributes()
	chant_profile.load_data(data["chant"])
	combat_input.profile_version = chant_profile.version()
	journal.load_data(data["laboratory"])
	if laboratory_panel != null: laboratory_panel.reset_record_selection()
	discovered.load_data(data.get("spell_discoveries", {}))
	pending_awakening_offer = {}

func _capture_developer_snapshot()->void:
	if _developer_snapshot.is_empty():
		var runtime: Dictionary = {}
		for field in ["game_state", "dungeon_kind", "map_seed", "player_pos", "player_hp", "player_mana", "mana_debt", "focus", "player_attack_cooldown", "exhaustion_seconds", "carried_gold", "corpse_pos", "status_message", "status_time", "enemies", "missiles", "walls", "last_laboratory_result","prototype_enabled","_prototype_all","prototype_target","lab_observation_target"]:
			var value = get(field)
			runtime[field] = value.duplicate(true) if value is Array or value is Dictionary else value
		_developer_snapshot = {"document": _character_document(), "save_document": _save_document.duplicate(true), "runtime": runtime,
			"save_path": save_path, "writable": save_writable, "error": save_error, "rng_state": dungeon_rng.state, "world_rng_state": rng.state,
			"barriers": elemental_combat.barriers.duplicate(true), "visuals": elemental_combat.visuals.duplicate(true), "visual_time": elemental_combat.visual_time,
			"dodge_cooldown": dodge.cooldown, "enemy_sequence": elemental_combat._next_enemy_id}
		_developer_snapshot["water_states"]=elemental_combat.water_states.duplicate(true);_developer_snapshot["water_metrics"]=elemental_combat.water_metrics.duplicate(true)

func _begin_current_development()->bool:
	if not OS.is_debug_build() or not developer_tools_enabled or not formal_rules or not save_writable:return false
	if current_world_development:return true
	if developer_mode:_end_developer_test()
	_reset_combat_input();_capture_developer_snapshot()
	developer_mode=true;current_world_development=true;_prototype_all=false;prototype_target=""
	_current_developer_base_research=research.to_data();current_developer_options={"all_elements":false,"bindings":false,"blink":false}
	return true

func _set_current_developer_option(option:String,enabled:bool)->bool:
	if option not in current_developer_options or not _begin_current_development():return false
	_reset_combat_input();current_developer_options[option]=enabled
	var model=CharacterResearch.new();model.use_current_rules=true
	if not model.load_data(_current_developer_base_research).is_empty():return false
	if current_developer_options.all_elements:model.developer_reset("all_elements","")
	var data:Dictionary=model.to_data()
	if current_developer_options.bindings:
		for pair in CharacterResearch.Fusion.PHENOMENA:
			if CharacterResearch.Loadout.owns_pair(Array(pair.split("+")),model.awakened_attributes) and pair not in data.binding_studies:data.binding_studies.append(pair)
	model.load_data(data)
	if current_developer_options.blink:model.developer_blink(true)
	var current_main=research.main_attribute;var current_aux=research.auxiliary_attributes[0] if not research.auxiliary_attributes.is_empty() else null
	model.set_active(current_main,current_aux) # Preserve equipment whenever it remains qualified after removing an override.
	research.load_data(model.to_data());lab_observation_target=str(research.main_attribute) if research.main_attribute!=null else "WOOD"
	_save_character();research_panel.refresh();laboratory_panel.refresh();laboratory_panel.awakening_panel.refresh();developer_panel.refresh()
	_message("현재 월드 설정 적용 · 개화 %d/5 · Tab 대상·Alt+1~6 속성 · 종료하면 원래 진행 복구"%research.awakened_attributes.size())
	_update_laboratory_live();return true

func _developer_current_action(action:String)->bool:
	if not developer_mode and not _begin_current_development():return false
	if current_world_development:
		if action=="research_all_elements":return _set_current_developer_option("all_elements",true)
		if action=="blink_unlock":return _set_current_developer_option("blink",true)
	var result:=_developer_action(action)
	if result and current_world_development and action.begins_with("research_"):
		_current_developer_base_research=research.to_data();current_developer_options={"all_elements":false,"bindings":false,"blink":false};developer_panel.refresh()
	return result

func _developer_current_force_loadout(main:Variant,auxiliary:Variant)->bool:
	if not developer_mode and not _begin_current_development():return false
	return _developer_force_loadout(main,auxiliary)

func _start_developer_test(element: String, location: String) -> bool:
	if not OS.is_debug_build() or not developer_tools_enabled or element not in DeveloperTestData.OPTIONS or location not in ["LAB", "DUNGEON"]: return false
	water_qa_active=false
	if not developer_mode:_capture_developer_snapshot()
	current_world_development=false;_current_developer_base_research.clear();current_developer_options={"all_elements":false,"bindings":false,"blink":false}
	developer_mode = true # Set before any reset/death/clue/note could attempt a write.
	prototype_enabled=false;_prototype_all=false;prototype_target=""
	_clear_chant()
	if game_state == "LAB": _leave_laboratory()
	_reset_combat_input()
	research_panel.close()
	laboratory_panel.close()
	var mapping := chant_profile.to_data()
	if mapping.is_empty(): mapping = ChantProfile.generate(8431) # Isolated damaged-save fallback only.
	var temporary := DeveloperTestData.character(mapping, element)
	_apply_temporary_document(temporary)
	if formal_rules:lab_observation_target=str(research.main_attribute) if research.main_attribute!=null else "WOOD"
	_save_document = temporary.duplicate(true)
	_developer_document = temporary
	developer_metrics = {}
	save_writable = true
	save_error = ""
	game_state = "HUB"
	carried_gold = 0
	player_hp = _max_hp()
	player_mana = _max_mana(); mana_debt=0.0
	last_laboratory_result = {}
	if developer_panel != null: developer_panel.panel.hide()
	if location == "LAB": _enter_laboratory()
	else: _enter_dungeon("FIXED")
	spell_record_hud.refresh()
	get_viewport().gui_release_focus()
	return true

func _end_developer_test() -> bool:
	if not developer_mode or _developer_snapshot.is_empty(): return false
	water_qa_active=false
	_clear_chant()
	if game_state == "LAB": _leave_laboratory()
	_reset_combat_input()
	laboratory_panel.close()
	_apply_temporary_document(_developer_snapshot["document"])
	_save_document = _developer_snapshot["save_document"].duplicate(true)
	save_path = _developer_snapshot["save_path"]
	save_writable = _developer_snapshot["writable"]
	save_error = _developer_snapshot["error"]
	for field in _developer_snapshot["runtime"]: set(field, _developer_snapshot["runtime"][field])
	dungeon_rng.state = _developer_snapshot["rng_state"]
	rng.state = _developer_snapshot["world_rng_state"]
	elemental_combat.barriers = _developer_snapshot["barriers"]
	elemental_combat.visuals = _developer_snapshot["visuals"]
	elemental_combat.visual_time = _developer_snapshot["visual_time"]
	elemental_combat._next_enemy_id = _developer_snapshot["enemy_sequence"]
	elemental_combat.water_states=_developer_snapshot.get("water_states",[]);elemental_combat.water_metrics=_developer_snapshot.get("water_metrics",{}).duplicate(true)
	dodge.cooldown = _developer_snapshot["dodge_cooldown"]
	developer_mode = false
	current_world_development=false;_current_developer_base_research.clear();current_developer_options={"all_elements":false,"bindings":false,"blink":false}
	_developer_snapshot = {}
	_developer_document = {}
	developer_metrics = {}
	developer_panel.panel.hide()
	research_panel.set_hub(game_state == "HUB")
	research_panel.refresh()
	spell_record_hud.refresh()
	spell_record_hud.visible = game_state == "DUNGEON"
	if game_state == "LAB":
		laboratory_panel.open(research_panel.opener.theme)
		_update_laboratory_live()
	get_viewport().gui_release_focus()
	return true

func _record_cancelled_experiment() -> void:
	var simulation:Dictionary=_inspect_chant(true)["simulation"]
	last_laboratory_result = simulation
	_record_experiment(simulation, "cancelled", 0.0)

func _save_experiment_note(id: int, value: String) -> void:
	if game_state != "LAB" or not save_writable: return
	var previous := journal.to_data()
	if not journal.note(id, value): return
	if not _save_character():
		journal.load_data(previous)
		laboratory_panel.message.text = "메모 저장 실패: " + save_error
	else: laboratory_panel.message.text = "메모를 저장했습니다."
	laboratory_panel.refresh()

func _update_laboratory_live(last_result: Dictionary = {}) -> void:
	if game_state != "LAB" or laboratory_panel == null: return
	if not last_result.is_empty(): last_laboratory_result = last_result
	var result:Dictionary=last_laboratory_result if runes.is_empty() and not last_laboratory_result.is_empty() else _inspect_chant(true)["simulation"]
	var mode_label: String = CombatInput.Mode.keys()[combat_input.mode]
	if not formal_rules:mode_label+=(" · 새 문법 시험 · 전속성" if developer_mode and _prototype_all else " · 새 문법 시험") if _prototype_active() else " · 기존 문법"
	if not research.ritual_target.is_empty(): mode_label += " · 의식: " + CharacterResearch.BaseElements.DEFINITIONS[research.ritual_target].display_name
	var debug_state: Dictionary = result["final_state"].duplicate(true)
	debug_state["research_context"] = _prototype_context() if _prototype_active() else research.simulation_context()
	debug_state["research_context"]["discovered_entries"]=preload("res://scripts/research_visibility.gd").known(discovered)
	var evaluated:Dictionary=_inspect_chant(true)
	debug_state["research_context"]["resolution"]=result.get("resolution",{"state":evaluated.get("state",""),"risk":evaluated.get("risk","normal")}) if runes.is_empty() else {"state":evaluated.get("state",""),"risk":evaluated.get("risk","normal")}
	debug_state["spell_preview"]=_public_chant_preview(_inspect_chant(true))
	if runes.is_empty() and result.has("manifestation"):debug_state["spell_preview"]={"text":"관측 · 발현한 구조의 잔상 / "+preload("res://scripts/research_visibility.gd").observed(result.final_state)}
	if not result.get("casting_steps", []).is_empty():
		var last: Dictionary = result["casting_steps"].back()
		debug_state["last_change"] = preload("res://scripts/mana_visual_model.gd").transition(last["before"], last["after"], research.simulation_context())["text"]
		if formal_rules:debug_state["lens_before"]=last["before"].duplicate(true)
	if not research.ritual_target.is_empty(): debug_state["target_conditions"] = CharacterResearch.Rules.requirements(research.ritual_target, research.simulation_context())
	var stage: String = {"weak": "약한 징후", "partial": "부분 공명", "unstable": "불안정", "failed": "붕괴", "ready": "안정 구조"}.get(result["state"], "준비 / 관찰")
	if not result["final_state"]["base_attributes"].is_empty() and result["state"] == "ready": stage = "공명 성공 · 전투 발현과 별개"
	if int(result.get("rules_version",0))>=8:stage={"ready":"구조 유지 · 방출 전 관측","unstable":"윤곽 흔들림 · 불안정한 발현 징후","failed":"구조 붕괴","locked":"연구 권한 부족"}.get(result["state"],"마나 구조 관측")
	if result.has("manifestation"): stage = "전투 발현 완료 · " + str(result["manifestation"])
	laboratory_panel.show_live(runes, stage + " · " + result["observation"], player_mana, exhaustion_seconds, debug_state, mode_label)
	laboratory_panel.observe_simulation(result,not runes.is_empty())

func _interact() -> void:
	if _controlled_trial() != null:
		var element: String = laboratory_panel.arena.nearest_catalyst()
		if not element.is_empty():
			_collect_research_clue(element, "environment")
			laboratory_panel.observation_hint.text=laboratory_panel.message.text
		return
	if game_state != "DUNGEON": return
	if corpse_pos != Vector2.ZERO and player_pos.distance_to(corpse_pos) < 49.0:
		carried_gold += int(corpse.get("gold", 0))
		corpse.clear()
		corpse_pos = Vector2.ZERO
		_save_character()
		_message("Recovered the belongings from your last death.")
		return
	if player_pos.distance_to(EXIT_POS) < 60.0:
		bank_gold += carried_gold
		carried_gold = 0
		game_state = "HUB"
		elemental_combat.clear()
		missiles.clear()
		if research_panel != null: research_panel.set_hub(true)
		_reset_combat_input()
		_save_character()
		_message("Returned safely. Your carried gold has been banked.")
		return
	_message("Nothing nearby to interact with.")

func _die() -> void:
	if game_state=="LAB":laboratory_panel.close();game_state="DUNGEON"
	if game_state != "DUNGEON": return
	var retrievable := int(round(float(carried_gold) * 0.7))
	corpse = {"kind": dungeon_kind, "x": player_pos.x, "y": player_pos.y, "gold": retrievable}
	carried_gold = 0
	injury_stacks = mini(3, injury_stacks + 1)
	armor_durability = maxi(0, armor_durability - 15)
	player_hp = _max_hp()
	player_mana = _max_mana(); mana_debt=0.0
	game_state = "HUB"
	elemental_combat.clear()
	missiles.clear()
	if research_panel != null: research_panel.set_hub(true)
	_reset_combat_input()
	_save_character()
	_message("DEATH: +1 injury, -15 armor. Return to your dungeon to recover 70% of carried gold.")

func _heal_injuries() -> void:
	if injury_stacks <= 0:
		_message("No injuries to heal.")
		return
	var price := injury_stacks * 15
	if bank_gold < price:
		_message("Need %d banked gold to heal." % price)
		return
	bank_gold -= price
	injury_stacks = 0
	player_hp = _max_hp()
	player_mana = _max_mana(); mana_debt=0.0
	_save_character()
	_message("Injuries healed. Knowledge and talents remain unchanged.")

func _label_at(pos: Vector2, label: String, font_size: int = 16, color: Color = Color.WHITE) -> void:
	draw_string(ThemeDB.fallback_font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _spell_summary() -> String:
	var result := ""
	for name in learned_spells:
		if result != "": result += ", "
		result += preload("res://scripts/spell_names.gd").label(name)
	return result if result != "" else "none"

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1160.0, 720.0)), Color("111522"))
	if formal_rules:
		_label_at(Vector2(35,52),"ARCANE LEGACY · 연구실의 공명진",24,Color("e1d6af"))
		_label_at(Vector2(35,80),"흐름을 바꾸고, 남은 형상을 비교하세요.",15)
		return
	draw_rect(Rect2(25.0, 28.0, 1100.0, 65.0), Color("252d3d"))
	_label_at(Vector2(45.0, 55.0), "ARCANE LEGACY  /  PROTOTYPE", 23, Color("ffe5ab"))
	_label_at(Vector2(46.0, 80.0), "Single character  |  talent: magic %d / body %d  |  discoveries: %s" % [magic_talent, body_talent, _spell_summary()], 13, Color("b9d4e2"))
	if developer_mode: _label_at(Vector2(420, 53), "DEVELOPER TEST · 임시 %s · 실제 저장과 분리" % (str(research.main_attribute) if research.main_attribute != null else "PURE MANA"), 17, Color("ffc58a"))
	if game_state == "HUB":
		_draw_hub()
	elif game_state == "DUNGEON":
		_draw_dungeon()
	if game_state != "DUNGEON": _label_at(Vector2(65.0, 707.0), "활성 연구: %d/2개  [%s]" % [research.active_elements.size(), ", ".join(research.active_elements)], 14, Color("b9d4e2"))
	if not save_writable:
		_label_at(Vector2(65.0, 601.0), "SAVE PROTECTED: " + save_error, 14, Color("ffcd91"))
	if game_state == "HUB" and status_time > 0.0 and not research_panel.is_open():
		draw_rect(Rect2(60.0, 634.0, 1040.0, 48.0), Color("33425b"))
		_label_at(Vector2(75.0, 665.0), status_message, 16, Color("ffffff"))

func _draw_hub() -> void:
	_label_at(Vector2(100.0, 167.0), "THE REFUGE  /  The same character survives every expedition", 22)
	_label_at(Vector2(110.0, 230.0), "[1] Enter the RUINS  -  fixed layout, corpse stays at the place of death", 18)
	_label_at(Vector2(110.0, 270.0), "[2] Enter the FLUX MAZE  -  layout reshuffles, corpse moves to a new room", 18)
	_label_at(Vector2(110.0, 330.0), "[H] Heal all injuries: 15 gold per stack", 18, Color("a8d6b5"))
	_label_at(Vector2(110.0, 388.0), "Banked gold: %d  |  injury stacks: %d/3  |  armor: %d/100" % [bank_gold, injury_stacks, armor_durability], 18)
	if not corpse.is_empty():
		_label_at(Vector2(110.0, 447.0), "Your belongings remain in: %s (recoverable gold: %d)" % [str(corpse.get("kind", "")), int(corpse.get("gold", 0))], 18, Color("ffcd91"))
	_label_at(Vector2(110.0, 545.0), "개발 시험 · 메모리 기록만 사용 / F2로 메뉴 열기" if developer_mode else "Save file: user://arcane_legacy_save.json", 14, Color("9caec4"))
	_label_at(Vector2(110.0, 580.0), "[L] Laboratory - chant, observe, replay and compare", 18, Color("a8d6b5"))

func _draw_dungeon() -> void:
	draw_rect(AREA, Color("202938"))
	for col in range(COLS + 1):
		var px := AREA.position.x + float(col) * TILE
		draw_line(Vector2(px, AREA.position.y), Vector2(px, AREA.end.y), Color("303744"), 1.0)
	for row in range(ROWS + 1):
		var py := AREA.position.y + float(row) * TILE
		draw_line(Vector2(AREA.position.x, py), Vector2(AREA.end.x, py), Color("303744"), 1.0)
	for cell in walls:
		draw_rect(_cell_rect(cell), Color("596176"))
	if navigation.active:
		draw_arc(navigation.destination, 7.0, 0, TAU, 20, Color("a8deb0"), 2.0)
		draw_line(navigation.destination - Vector2(11, 0), navigation.destination + Vector2(11, 0), Color("a8deb0"))
		draw_line(navigation.destination - Vector2(0, 11), navigation.destination + Vector2(0, 11), Color("a8deb0"))
	# Gold gate
	draw_circle(EXIT_POS, 19.0, Color("f2c777"))
	draw_circle(EXIT_POS, 12.0, Color("64501f"))
	if corpse_pos != Vector2.ZERO:
		draw_circle(corpse_pos, 17.0, Color("f59e69"))
		draw_circle(corpse_pos, 9.0, Color("80433a"))
	for e in enemies:
		draw_circle(Vector2(e["pos"]), 15.0, Color("dd6670"))
	elemental_combat.draw(self)
	if dodge.active:
		draw_line(dodge.origin, player_pos, Color("8eaacc"), 5.0)
		draw_arc(player_pos, 18.0, 0, TAU, 24, Color("d6f4ff"), 2.0)
	if combat_input.mode == CombatInput.Mode.FOCUS_CAST:
		draw_arc(player_pos, 23.0, 0.0, TAU, 40, Color("ffe5ab"), 2.0)
	if focus_active:
		draw_circle(player_pos, 27.0, Color(0.3, 0.78, 1.0, 0.3))
		draw_circle(player_pos + Vector2(-19.0, 4.0), 11.0, Color(0.2, 0.6, 1.0, 0.2))
	draw_circle(player_pos, 13.0, Color("6ed8e9"))
	var direction := get_global_mouse_position() - player_pos
	if direction.length() > 0.1:
		draw_line(player_pos, player_pos + direction.normalized() * 30.0, Color("f5f7ff"), 2.5)
	draw_rect(Rect2(915.0, 105.0, 227.0, 485.0), Color("252d3d"))
	_label_at(Vector2(932.0, 130.0), "DUNGEON", 17, Color("ffe5ab"))
	_label_at(Vector2(932.0, 153.0), dungeon_kind, 15)
	_label_at(Vector2(932.0, 198.0), "HP: %d / %d" % [roundi(player_hp), roundi(_max_hp())], 17)
	_label_at(Vector2(932.0, 230.0), "Mana: %d / %d" % [roundi(player_mana), roundi(_max_mana())], 17)
	_label_at(Vector2(932.0, 262.0), "Focus: %d / 100" % roundi(focus), 17)
	_label_at(Vector2(932.0, 294.0), "Gold: %d" % carried_gold, 17)
	_label_at(Vector2(932.0, 326.0), "Enemies: %d" % enemies.size(), 17)
	var mode_name: String = CombatInput.Mode.keys()[combat_input.mode]
	_label_at(Vector2(932.0, 357.0), mode_name, 17, Color("ffe5ab"))
	_label_at(Vector2(932.0, 384.0), "WASD: " + ("commands" if combat_input.mode == CombatInput.Mode.FOCUS_CAST else ("dev move" if legacy_wasd_enabled else "off / RMB move")), 14, Color("b9d4e2"))
	_label_at(Vector2(932.0, 408.0), "Shift: cast / move 80%", 14, Color("b9d4e2"))
	_label_at(Vector2(932.0, 432.0), "Shift x2: focus toggle", 14, Color("b9d4e2"))
	_label_at(Vector2(932.0, 456.0), "LMB: sword / release", 14, Color("b9d4e2"))
	_label_at(Vector2(932.0, 480.0), "RMB: move / Esc: cancel", 14, Color("b9d4e2"))
	_label_at(Vector2(932.0, 504.0), "Alt hold: swift sense", 14, Color("b9d4e2"))
	_label_at(Vector2(932.0, 528.0), "F: interact / command", 14, Color("b9d4e2"))
	_label_at(Vector2(932.0, 550.0), "Ctrl dodge: " + ("ready" if dodge.cooldown <= 0 else "%.1fs" % dodge.cooldown), 14, Color("ffe5ab"))
	_label_at(Vector2(932.0, 576.0), "Mana Bolt: Q > E", 14, Color("ffe5ab"))
	_draw_cast_hud()

func _draw_cast_hud() -> void:
	if spell_record_hud != null and spell_record_hud.expanded: return
	# Two rows keep all 32 buffer tokens visible instead of overflowing the sidebar.
	draw_rect(Rect2(60.0, 594.0, 1040.0, 92.0), Color("33425b"))
	_label_at(Vector2(75.0, 615.0), "Commands: " + ("(empty)" if runes.is_empty() else " > ".join(runes.slice(0, 16))), 15, Color("ffe5ab"))
	if runes.size() > 16:
		_label_at(Vector2(165.0, 635.0), " > ".join(runes.slice(16)), 15, Color("ffe5ab"))
	_label_at(Vector2(75.0, 658.0), cast_feedback, 14)
	if status_time > 0.0:
		_label_at(Vector2(75.0, 680.0), status_message, 13, Color("b9d4e2"))

func _developer_action(action:String)->bool:
	if not developer_mode or not developer_tools_enabled:return false
	if action.begins_with("research_"):
		_reset_combat_input();_prototype_all=false;prototype_target=""
		var kind:=action.trim_prefix("research_")
		var element:String=DeveloperTestData.OPTIONS[developer_panel.elements.selected]
		if not research.developer_reset(kind,element):return false
		if kind=="all":
			journal.load_data({"version":1,"next_id":1,"records":[]});discovered.load_data({"version":1,"spells":{}});learned_spells.clear();laboratory_panel.reset_record_selection()
		lab_observation_target=str(research.main_attribute) if research.main_attribute!=null else "WOOD"
		laboratory_panel.refresh();laboratory_panel.awakening_panel.refresh();spell_record_hud.refresh();developer_panel.refresh();return _save_character()
	match action:
		"loadout_check":
			var checks:Array=[]
			for main in CharacterResearch.Loadout.ORDER:
				for aux in [null]+CharacterResearch.Loadout.ORDER:
					if aux==main:continue
					var context:=research.simulation_context();context.merge({"formal_rules":true,"awakened_attributes":CharacterResearch.Loadout.ORDER.duplicate(),"active_main_attribute":main,"active_auxiliary_attribute":aux,"main_attribute":main,"auxiliary_attributes":[] if aux==null else [aux]},true)
					var matches:Array=[]
					for row in preload("res://scripts/formal_spell_registry.gd").config().spells:
						var outcome=preload("res://scripts/chant_engine_v2.gd").resolve(_active_profile(),preload("res://scripts/chant_engine_v2.gd").inputs(_active_profile(),row.actions),context)
						if outcome.get("spell")!=null and outcome.identity not in matches:matches.append(outcome.identity)
					checks.append({"main":main,"auxiliary":aux,"manifestable":matches})
			developer_metrics["loadout_combinations"]=checks;developer_panel.refresh();return true
		"blink_unlock":research.developer_blink(true);developer_panel.refresh()
		"resources":player_hp=_max_hp();player_mana=_max_mana();mana_debt=0
		"low_hp":player_hp=_max_hp()*.15
		"empty_mana":player_mana=0;mana_debt=0
		"gold":bank_gold+=100
		"items":
			if get("inventory")!=null:get("inventory").add("HP_POTION",5);get("inventory").add("MANA_POTION",5);call("_refresh_inventory")
		"reset":return _start_developer_test(DeveloperTestData.OPTIONS[developer_panel.elements.selected],"LAB" if developer_panel.location.selected==0 else ("WORLD" if get("world_enabled")!=null else "DUNGEON"))
		"clear_enemies":
			if game_state=="LAB":laboratory_panel.arena.enemies.clear()
			else:enemies.clear()
		"spawn":
			var actor={"pos":player_pos+Vector2(120,0),"hp":100.0,"max_hp":100.0,"hurt_height":30.0}
			if game_state=="LAB":actor.pos=laboratory_panel.arena.player_pos+Vector2(120,0);laboratory_panel.arena.enemies.append(actor)
			else:enemies.append(actor)
		"learn":
			var registry=preload("res://scripts/formal_spell_registry.gd")
			for row in registry.config().spells:
				var definition=registry.definition(row.id)
				discovered.record(str(definition.spell_id),definition.display_name,preload("res://scripts/chant_engine_v2.gd").inputs(prototype_profile,row.actions),8,"LAB",Array(definition.requires_elements),prototype_profile.to_data())
				if not learned_spells.has(str(definition.spell_id)):learned_spells.append(str(definition.spell_id))
			spell_record_hud.refresh()
		_:return false
	return _save_character()

func _developer_force_loadout(main:Variant,aux:Variant)->bool:
	if not developer_mode or not developer_tools_enabled:return false
	_reset_combat_input();_prototype_all=false;prototype_target=""
	var result:=_change_active_attributes(main,aux)
	if result:developer_panel.refresh();laboratory_panel.refresh()
	return result
