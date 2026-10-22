extends "res://tests/current_options_helpers.gd"
const PROTO=preload("res://scripts/mana_formula_prototypes.gd")
const Score=preload("res://scripts/mana_effect_score.gd")
const AUDIT="res://.task002_artifacts/mana_formula_audit/"
var comparison:Array=[]
func fresh_formula()->void:
	if is_instance_valid(game):game.free()
	var path:=AUDIT+"combat_%d_%d.json"%[OS.get_process_id(),Time.get_ticks_usec()]
	A.write(path,JSON.parse_string(FileAccess.get_file_as_string(AUDIT+"user_before.json")))
	game=preload("res://tests/formula_world_fixture.gd").new();game.save_path=path;root.add_child(game);game.set_process(false)
func shot_formula(actions:Array)->void:
	game._reset_combat_input()
	await key(KEY_SHIFT,true)
	for event in E.inputs(game._active_profile(),actions):await tap(OS.find_keycode_from_string(event.key))
func capture_formula(name:String)->void:
	if DisplayServer.get_name()=="headless":return
	game.queue_redraw();game.laboratory_panel.arena._update_views();game._sync_world_view()
	game.world_camera.reset_smoothing();game.world_camera.force_update_scroll()
	game.laboratory_panel.arena.camera.reset_smoothing();game.laboratory_panel.arena.camera.force_update_scroll()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(AUDIT+name+".png")
func run()->void:
	root.size=Vector2i(1160,720);fresh_formula();await process_frame
	check(Registry.config().spells.size()==28,"Production registry has28 spells while historical PX tests replace only their three official aliases")
	var context:Dictionary=game._prototype_context();var profile=game._active_profile()
	for row in PROTO.DATA.spells:
		var selections:Array=[]
		for order in Registry.permutations(row.actions):
			var result:=E.resolve(profile,E.inputs(profile,order),context)
			if result.get("spell")!=null:selections.append({"order":order,"result":result})
		selections.sort_custom(func(a,b):return a.result.spell.formula_effect.strength<b.result.spell.formula_effect.strength)
		check(not selections.is_empty(),row.id+" has manifestable permutations")
		if selections.is_empty():continue
		var pair:Array=[selections.front(),selections.back()]
		check(pair[0].result.spell.formula_effect.strength==0 and pair[1].result.spell.formula_effect.strength>.1,row.id+" actual state produces effect OFF and ON")
		var outcomes:Array=[]
		for index in 2:
			fresh_formula();await process_frame
			game.player_pos=game.layout.LAB_DOOR;game._enter_laboratory();var arena=game.laboratory_panel.arena;arena.set_process(false)
			game._reset_combat_input();var order:Array=pair[index].order
			chant(order);var live:Dictionary=game._inspect_chant(true);var spell=live.spell
			check(live.identity==row.id and live.final_state==pair[index].result.final_state,row.id+" identical lab/world interpreter state "+str(index))
			arena.reset_targets();arena.enemies.resize(1);arena.target_views.resize(1)
			var center:Vector2=arena.player_pos+Vector2.RIGHT*spell.placement_distance
			var start:Vector2=arena.player_pos+Vector2(110,0) if spell.effect==&"projectile" else center+Vector2(105,0) if row.score_axis=="circulation" else center+Vector2(25,10)
			arena.enemies[0].pos=start;arena.enemies[0].hp=500.0
			if row.score_axis=="pressure":arena.enemies[0].formula_guard=.5
			game.player_mana=game._max_mana();game.mana_debt=0;game.exhaustion_seconds=0
			var mana:float=game.player_mana;var records:int=game.journal.to_data().next_id
			# Synthetic input follows the real Shift session/automatic release path.
			if DisplayServer.get_name()!="headless":await shot_formula(order);await key(KEY_SHIFT,false)
			else:game._cast_spell()
			check(game.journal.to_data().next_id==records+1 and is_equal_approx(mana-game.player_mana,spell.mana_cost),row.id+" real release charges actual tuned cost exactly once "+str(index))
			game.laboratory_panel.show_trial();arena.set_process(false)
			game.laboratory_panel._lens_changed(true)
			var keys:Array=E.inputs(game._active_profile(),order).map(func(event):return event.key)
			game.laboratory_panel._update_lens(keys,live.final_state)
			check(game.laboratory_panel.lens_trial_readout.text.contains(Score.explain(spell.formula_effect)),"Actual observation lens displays the state-based physical cause")
			if spell.effect==&"projectile":arena.combat.update_missiles(arena,.1,1)
			arena.combat.visual_time=.2
			await capture_formula(row.id+"_"+str(index)+"_lab")
			if spell.effect==&"projectile":arena.combat.update_missiles(arena,.4,1)
			var target:Dictionary=arena.enemies[0]
			check(target.hp<500,row.id+" actual lab damage "+str(index))
			if row.score_axis=="circulation":check(Vector2(target.pos).distance_to(center)<start.distance_to(center),"Vortex pulls towards its own center, not backwards along aim")
			if row.score_axis=="pressure":check(is_equal_approx(500-target.hp,spell.damage*lerpf(.5,1,spell.formula_effect.armor_ignore)),"Pressure bypass changes real guarded target damage")
			if row.score_axis=="confinement":check(is_equal_approx(target.get("root_remaining",0),spell.duration),"Pressure prison keeps timed root distinct from stagger")
			var record:Dictionary=game.journal.records().back();var expected:Dictionary=live.final_state.duplicate(true);expected.phase="RELEASE"
			check(Equal.equal(record.result.terminal_snapshot,expected),"Stored replay retains the released state without resimulation")
			check(not Score.explain(spell.formula_effect).is_empty(),"Observation lens has a physical cause for this result")
			game.cast_feedback=spell.display_name+" / "+("특수 현상 ON" if index==1 else "기본 변형")+" · "+Score.explain(spell.formula_effect)
			outcomes.append({"order":order,"keys":E.inputs(game._active_profile(),order).map(func(event):return event.key),"cost":spell.mana_cost,"damage":500-target.hp,"displacement":start.distance_to(target.pos),"duration":target.get("root_remaining",target.get("slow_remaining",0)),"radius":spell.radius,"projectile_radius":spell.projectile_radius,"speed":spell.projectile_speed,"range":spell.projectile_speed*spell.lifetime,"state":live.final_state,"effect":spell.formula_effect,"explanation":Score.explain(spell.formula_effect)})
			if index==1:
				# Ablation: identical S and order, with only the NEW F disabled.
				var baseline=preload("res://scripts/mana_variation.gd").tune(PROTO.definition(row.id),live.final_state,E.CONFIG)
				arena.reset_targets();arena.enemies.resize(1);arena.enemies[0].pos=start;arena.enemies[0].hp=500.0
				if row.score_axis=="pressure":arena.enemies[0].formula_guard=.5
				check(arena.combat.cast(arena,baseline,Vector2.RIGHT),"Identical-state baseline executes without the new effect")
				if baseline.effect==&"projectile":arena.combat.update_missiles(arena,.4,1)
				var control:Dictionary=arena.enemies[0]
				var ablation:Dictionary={"damage":500-control.hp,"displacement":start.distance_to(control.pos),"duration":control.get("root_remaining",control.get("slow_remaining",0)),"cost":baseline.mana_cost,"radius":baseline.radius}
				outcomes.back()["same_state_without_special"]=ablation
				check(spell.mana_cost>baseline.mana_cost and (not is_equal_approx(outcomes.back().damage,ablation.damage) or not is_equal_approx(outcomes.back().displacement,ablation.displacement)),"Special effect changes real combat independently of base order variation "+row.id)
			# The actual world boss uses its existing guard, mass and root caps.
			game._leave_laboratory();game.player_pos=Vector2(3200,910);game.guardian.start(game);var boss:Dictionary=game.guardian.actor;boss.guarded=true
			var old_hp:float=boss.hp;var old_pos:Vector2=boss.pos
			game.elemental_combat.hit_enemy(game,boss,spell,Vector2.RIGHT)
			check(boss.hp<old_hp and boss.get("stagger_remaining",0)==0 and game.guardian.metrics.poise_breaks==0,"World boss receives physical effect without unapproved stagger/poise")
			if row.score_axis=="confinement":check(boss.root_remaining<=1.5,"Existing boss root cap remains 1.5 seconds")
			if row.score_axis=="circulation":check(old_pos.distance_to(boss.pos)<=absf(spell.knockback),"Boss displacement resistance is retained")
			if row.score_axis=="pressure":
				var expected_damage:float=spell.damage*lerpf(float(boss.traits.guard_damage_factor),1,spell.formula_effect.armor_ignore)
				check(is_equal_approx(old_hp-boss.hp,expected_damage),"World steel guard applies continuous defense bypass")
			# Capture the actual cast as well as the boss hit adapter.
			game.missiles.clear();game.elemental_combat.visuals.clear()
			if spell.effect!=&"projectile":game.player_pos=Vector2(boss.pos)-Vector2.RIGHT*spell.placement_distance
			game._reset_combat_input();game.player_mana=game._max_mana();game.mana_debt=0;game.exhaustion_seconds=0;chant(order)
			var world_mana:float=game.player_mana
			game._sync_world_view();game.world_camera.reset_smoothing();game.world_camera.force_update_scroll();await process_frame
			await aim(boss.pos)
			if DisplayServer.get_name()!="headless":
				await shot_formula(order)
				await click_world(boss.pos,MOUSE_BUTTON_LEFT);await key(KEY_SHIFT,false)
			else:game._cast_spell()
			check(is_equal_approx(world_mana-game.player_mana,spell.mana_cost),"World release uses the same tuned cost through real payment transaction")
			if spell.effect==&"projectile":game.elemental_combat.update_missiles(game,.15,1)
			await capture_formula(row.id+"_"+str(index)+"_world")
		check(outcomes[0].damage!=outcomes[1].damage or outcomes[0].displacement!=outcomes[1].displacement or outcomes[0].duration!=outcomes[1].duration,"Same spell has measurably different actual combat outcomes "+row.id)
		comparison.append({"id":row.id,"source_id":row.source_id,"pair":outcomes})
	# Exercise proposal costs through the existing payment/rollback transaction.
	fresh_formula();await process_frame;game.player_pos=game.layout.LAB_DOOR;game._enter_laboratory();game.laboratory_panel.arena.set_process(false)
	var recipe:Array=PROTO.DATA.spells[1].actions;chant(recipe)
	var required:float=game._inspect_chant(true).mana_cost
	game.player_mana=0;game.mana_debt=game.ManaOverdraw.limit(game._max_mana())
	game._cast_spell();check(game.player_mana==0 and game.laboratory_panel.arena.missiles.is_empty(),"Overdraw rejection emits no projectile and consumes no mana")
	game.player_mana=game._max_mana();game.mana_debt=0;chant(recipe)
	var before_mana:float=game.player_mana;var before_journal:Dictionary=game.journal.to_data()
	DirAccess.make_dir_absolute(game.save_path+".tmp");game._cast_spell()
	check(game.player_mana==before_mana and game.laboratory_panel.arena.missiles.is_empty() and Equal.equal(before_journal,game.journal.to_data()),"Proposal save failure rolls back mana, effects and journal")
	DirAccess.remove_absolute(game.save_path+".tmp")
	chant(recipe);game._cast_spell()
	check(game.journal.records().back().result.terminal_snapshot.get("formula_effect",{}).get("prototype",false),"Saved terminal snapshot includes original effect score for replay")
	# Verify no research/learning permission was needed and save data still reloads.
	var written:Dictionary=game._character_document();check(game._save_character(),"Isolated fixture save writes successfully")
	var saved_profile:Dictionary=game._active_profile().to_data();var path:String=game.save_path
	game.free();game=preload("res://tests/formula_world_fixture.gd").new();game.save_path=path;root.add_child(game);game.set_process(false);await process_frame
	check(game.save_writable and Equal.equal(game._active_profile().to_data(),saved_profile),"Isolated restart preserves personal key mapping")
	for field in ["research","chant","spell_discoveries","laboratory"]:check(Equal.equal(written[field],game._character_document()[field]),"Isolated restart preserves "+field)
	FileAccess.open(AUDIT+"combat_"+("auto" if DisplayServer.get_name()=="headless" else "window")+".json",FileAccess.WRITE).store_string(JSON.stringify(comparison,"\t"))
	await finish("MANA FORMULA COMBAT")
