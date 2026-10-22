extends "res://tests/preview_world_phase1.gd"
const OUT="res://.task002_artifacts/formal_world/"
const E=preload("res://scripts/chant_engine_v2.gd")
const Registry=preload("res://scripts/formal_spell_registry.gd")
const Perm=preload("res://tests/test_chant_v2.gd")
const Equal=preload("res://tests/test_chant.gd")
func set_chant(events:Array)->void:
	game._clear_chant();game.runes.assign(events.map(func(e):return str(e.key)));game.chant_inputs=events.duplicate(true)
	for event in game.chant_inputs:event.released=true
func shot(actions:Array)->void:
	await key(KEY_SHIFT,true)
	for event in E.inputs(game._active_profile(),actions):await tap(OS.find_keycode_from_string(event.key))
func capture(name:String,viewport:Viewport=null)->void:
	game._sync_world_view();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	(viewport if viewport!=null else root).get_texture().get_image().save_png(OUT+name+".png")
func run()->void:
	var path:=OUT+"phase9_%d.json"%Time.get_ticks_usec();A.write(path,F.fixture("WATER",8431))
	game=Scene.instantiate();game.save_path=path;root.add_child(game);game.set_process(false);await process_frame
	var original:Dictionary=game._character_document().duplicate(true);var bytes:=FileAccess.get_file_as_bytes(path)
	game._start_prototype_all("LAB");var arena=game.laboratory_panel.arena;arena.set_process(false)
	game.water_qa_active=true # Expanded high-water catalog needs a sufficient isolated test budget.
	for row in Registry.config().spells:
		game.prototype_target=row.id;arena.reset_targets();game.player_mana=game._max_mana();game.mana_debt=0;game.exhaustion_seconds=0
		var selected:Array=[]
		for order in Perm.permutations(row.actions):
			var resolution:=E.resolve(game._active_profile(),E.inputs(game._active_profile(),order),game._prototype_context())
			if resolution.get("spell")!=null and resolution.state=="ready":selected=order;break
		set_chant(E.inputs(game._active_profile(),selected));var preview:Dictionary=game._inspect_chant(true);var last_id:int=0 if game.journal.records().is_empty() else int(game.journal.records().back().id);var mana:float=game.player_mana
		game._cast_spell()
		check(preview.get("spell")!=null and game.developer_metrics.get("spell")==preview.spell.display_name and is_equal_approx(mana-game.player_mana,preview.mana_cost),"Actual lab manifestation and charge "+row.id)
		check(int(game.journal.records().back().id)==last_id+1 and game.journal.records().back().result.get("manifestation",{}).get("spell_id")==str(preview.spell.spell_id),"Actual persisted manifestation record "+row.id)
		var record:Dictionary=game.journal.records().back()
		var released:Dictionary=preview.final_state.duplicate(true);released.phase="RELEASE" # Journal adds the release event, retaining every simulated value.
		check(Equal.equal(record.result.terminal_snapshot,released) and Equal.equal(record.steps.back().after,preview.simulation.casting_steps.back().after),"Live prediction and saved replay retain all simulated values and original step snapshots "+row.id)
	check(game.research.validate_evidence(game.journal.records()).is_empty(),"Unified fusion and single observations retain valid evidence")
	game._developer_action("items");game._developer_action("gold");game._developer_action("learn");game._end_developer_test()
	check(Equal.equal(original,game._character_document()) and bytes==FileAccess.get_file_as_bytes(path),"Debug items, gold, discoveries and spells restore exact original document and disk")
	game.player_pos=game.Layout.LAB_DOOR;game._enter_laboratory();arena=game.laboratory_panel.arena;arena.set_process(false);game.lab_observation_target="WATER";game._reset_combat_input()
	if DisplayServer.get_name()!="headless":
		var count:int=game.journal.records().size();game.player_mana=game._max_mana()
		await shot(["ACCUMULATE","SHAPE","DIRECT"]);await key(KEY_SHIFT,false)
		check(game.journal.records().size()==count+1 and arena.missiles.size()==1,"Actual Shift release emits and records exactly once")
		await key(KEY_SHIFT,false);check(game.journal.records().size()==count+1,"Repeated Shift-up cannot duplicate a record")
		await tap(KEY_SHIFT);await tap(KEY_SHIFT);check(game.combat_input.mode==game.CombatInput.Mode.FOCUS_CAST and game.journal.records().size()==count+1,"Double Shift enters focus without intermediate discharge")
		var mana:float=game.player_mana;game._process(.25);check(is_equal_approx(game.player_mana,minf(game._max_mana(),mana+4)),"Laboratory focus keeps double regeneration")
		await tap(KEY_ESCAPE);check(game.combat_input.mode==game.CombatInput.Mode.NORMAL,"Esc exits focus safely")
		await shot(["ACCUMULATE","SHAPE","DIRECT"]);await capture("phase9_lab_live")
		var mana_before:float=game.player_mana;var missiles_before:int=arena.missiles.size()
		game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);await key(KEY_SHIFT,false)
		check(game.player_mana==mana_before and arena.missiles.size()==missiles_before and game.runes.is_empty(),"Focus loss cancels without automatic release or mana payment")
		game.laboratory_panel.show_trial();await capture("phase9_catalysts")
	# The current interpreter uses the existing overdraw transaction as well.
	game._reset_combat_input();game.exhaustion_seconds=0;game.player_mana=2;game.mana_debt=0
	set_chant(E.inputs(game._active_profile(),["ACCUMULATE","SHAPE","DIRECT"]));var predicted:Dictionary=game._inspect_chant(true)
	game._cast_spell();check(game.player_mana==0 and is_equal_approx(game.mana_debt,predicted.mana_cost-2),"Production spell automatically covers shortage with existing mental debt")
	game.player_mana=0;game.mana_debt=game.ManaOverdraw.limit(game._max_mana());set_chant(E.inputs(game._active_profile(),["ACCUMULATE","SHAPE","DIRECT"]))
	var missile_count:int=arena.missiles.size();game._cast_spell();check(arena.missiles.size()==missile_count and game.mana_debt==game.ManaOverdraw.limit(game._max_mana()),"Production over-limit spell neither manifests nor partially charges")
	game.combat_input.mode=game.CombatInput.Mode.NORMAL;check(is_equal_approx(game._movement_speed(),100),"Production maximum exhaustion retains half movement speed")
	game._recover_mana(game.mana_debt);check(game.mana_debt==0 and is_equal_approx(game._movement_speed(),200),"Recovery clears production exhaustion movement penalty")
	game._clear_chant()
	game._leave_laboratory();game.player_pos=Vector2(420,-220);game.player_hp=game._max_hp();game.player_mana=game._max_mana();game._reset_combat_input()
	var enemy:Dictionary=game.field_system.actors[0];enemy.pos=Vector2(480,-220);enemy.root_remaining=20
	game._sync_world_view();game.world_camera.reset_smoothing();game.world_camera.force_update_scroll()
	if DisplayServer.get_name()!="headless":
		var hp:float=enemy.hp;await click_world(enemy.pos,MOUSE_BUTTON_LEFT);check(enemy.hp<hp,"Actual LMB sword hits the field monster")
		enemy.hp=enemy.max_hp;enemy.pos=Vector2(590,-220);game.player_attack_cooldown=0
		await shot(["ACCUMULATE","SHAPE","DIRECT"]);await click_world(enemy.pos+Vector2(0,-25),MOUSE_BUTTON_LEFT);await key(KEY_SHIFT,false)
		check(not game.missiles.is_empty(),"Actual dungeon Shift/LMB produces elemental projectile")
		for i in 55:game._process(.016)
		check(enemy.hp<enemy.max_hp and enemy.pos.x>590,"Actual field projectile damages and pushes the same collision actor")
		await capture("phase9_field_combat")
	else:
		var definition=Registry.definition("OH-061");game.elemental_combat.hit_enemy(game,enemy,definition,Vector2.RIGHT);check(enemy.hp<enemy.max_hp and enemy.pos.x>480,"Field actor shares elemental damage and displacement")
	# Validate release denial independently of this debug executable's build flag.
	check(not preload("res://scripts/developer_access.gd").allowed(false,true,true,true),"Release builds deny developer panel even with all flags")
	game._save_character()
	FileAccess.open(OUT+"restart_manifest.json",FileAccess.WRITE).store_string(JSON.stringify({"path":path,"document":game._character_document()}))
	game.free();print("FORMAL PHASE9: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
