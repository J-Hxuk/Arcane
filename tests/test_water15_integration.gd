extends "res://tests/current_options_helpers.gd"
const WATER=preload("res://scripts/water_spell_catalog.gd")
const VARIATION=preload("res://scripts/mana_variation.gd")
const AUDIT="res://.task002_artifacts/water15_integration/"
var report:Array=[]
func snap_water(name:String,arena=null)->void:
	if DisplayServer.get_name()=="headless":return
	if arena!=null:arena._update_views();arena.camera.reset_smoothing();arena.camera.force_update_scroll()
	game._sync_world_view();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(AUDIT+name+".png")
func target(p:Vector2,hp:=10000.0)->Dictionary:return {"pos":p,"home":p,"hp":hp,"max_hp":hp,"shot":INF,"hit_radius":22.0,"collision_radius":15.0,"hurt_height":0.0}
func run()->void:
	DirAccess.make_dir_recursive_absolute(AUDIT);root.size=Vector2i(1160,720);var path:=fresh();await process_frame
	var original:Dictionary=game._character_document().duplicate(true);var bytes:=FileAccess.get_file_as_bytes(path)
	check(E.CONFIG.tuning.order_residual_mode=="raw" and E.CONFIG.tuning.order_gain==.8,"Formal production adopts raw residual gain 0.8")
	check(Registry.config().spells.size()==28,"Official registry has original16 plus12 water identities, no PX duplicates")
	check(game._water_qa_start("LAB"),"F5 scene exposes isolated water QA through existing developer guard")
	var arena=game.laboratory_panel.arena;arena.set_process(false)
	var ctx:Dictionary=game._prototype_context();var sum_orders:=0
	for item in WATER.DATA.spells:
		var seen:Dictionary={};var states:Array=[];var counts={"stable":0,"unstable":0,"collapse":0,"incomplete":0}
		var identity_ok:=true;var deterministic:=true;var finite:=true
		for order in Registry.permutations(item.actions):
			var signature:="|".join(order)
			if seen.has(signature):continue
			seen[signature]=true;sum_orders+=1
			var events:=E.inputs(game._active_profile(),order);var r:=E.resolve(game._active_profile(),events,ctx)
			identity_ok=identity_ok and r.identity==item.id
			deterministic=deterministic and r.final_state==E.resolve(game._active_profile(),events,ctx).final_state
			if r.get("spell")!=null:
				counts["stable" if r.risk=="normal" else "unstable"]+=1
				states.append({"order":order,"spell":r.spell,"state":r.final_state,"risk":r.risk,"keys":events.map(func(e):return e.key)})
				finite=finite and is_finite(r.mana_cost) and r.mana_cost>0 and r.spell.damage>=0
			elif r.get("failure_kind")=="collapse":counts.collapse+=1
			else:counts.incomplete+=1
		check(item.actions.size()<=5 and identity_ok and deterministic and finite,item.id+" every unique permutation preserves ID, finite state and determinism")
		check(counts.stable>0,item.id+" has stable manifestation")
		states.sort_custom(func(a,b):return a.spell.formula_effect.strength<b.spell.formula_effect.strength)
		var min_a:float=states.front().spell.formula_effect.strength;var max_a:float=states.back().spell.formula_effect.strength
		if item.tier>=2:check(min_a<.01 and max_a>.01,item.id+" has actual state-derived phenomenon OFF and ON")
		var cases:Array=[];var numerical:Array=[]
		for sample in states:
			var spell=sample.spell
			numerical.append({"order":sample.order,"keys":sample.keys,"risk":sample.risk,"damage":spell.damage,"cost":spell.mana_cost,"speed":spell.projectile_speed,"range":spell.projectile_speed*spell.lifetime,"radius":spell.radius,"core":spell.projectile_radius,"duration":spell.duration,"push":spell.knockback,"status_strength":spell.status_strength,"stability":sample.state.stability,"special":spell.formula_effect.strength})
		for variant in ["off","on"]:
			game._water_qa_prepare(item.id,variant)
			var result:Dictionary=game._inspect_chant(true);var definition=result.spell
			arena.reset_targets();arena.player_pos=Vector2(180,210)
			var center:Vector2=arena.player_pos+Vector2.RIGHT*definition.placement_distance
			var hit_pos:Vector2=center if definition.effect==&"point" else arena.player_pos+Vector2(100,0)
			if definition.effect==&"projectile":hit_pos=arena.player_pos+Vector2(350,0)
			if item.id=="OH-070":hit_pos+=Vector2.RIGHT.orthogonal()*40*definition.formula_effect.strength*sin(PI*350/(definition.projectile_speed*definition.lifetime))
			arena.enemies.assign([target(hit_pos),target(center+Vector2(40,35) if definition.effect!=&"projectile" else Vector2(1400,800))])
			var journal_count:int=game.journal.to_data().next_id;var mana:float=game.player_mana
			# Deterministic API combat test uses the journal's right-facing preview.
			# Separate input suite exercises cursor/Shift/LMB in the visible arena.
			game.laboratory_panel.trial_panel.hide();game.laboratory_panel.panel.show()
			# The real release transaction, including automatic discovery and journal.
			game._cast_spell()
			check(game.player_mana<mana and game.discovered.to_data().spells.has(item.id),item.id+" "+variant+" real mana payment and automatic discovery")
			check(game.journal.to_data().next_id==journal_count+1,item.id+" "+variant+" one saved experiment")
			var record:Dictionary=game.journal.records().back()
			check(Equal.equal(record.result.terminal_snapshot.get("formula_effect",{}),result.final_state.formula_effect),item.id+" "+variant+" journal retains exact computed phenomenon snapshot")
			var hp0:float=arena.enemies[0].hp;var pos0:Vector2=arena.enemies[0].pos
			var before_contacts:int=arena.combat.water_metrics.shield_contacts
			if item.id in ["OH-066","OH-067"]:
				arena.missiles.append({"pos":arena.player_pos+Vector2(160,0),"dir":Vector2.LEFT,"hostile":true,"life":2.0,"speed":180.0,"dmg":20.0})
			for frame in 10:arena.advance(1.0/60)
			if variant=="on":
				game.laboratory_panel.show_trial(false);await snap_water(item.id+"_lab",arena)
			for frame in 480:arena.advance(1.0/60)
			if item.id in ["OH-066","OH-067"]:check(arena.combat.water_metrics.shield_contacts>before_contacts and arena.combat.barriers.is_empty(),item.id+" fluid defense contacts actual hostile projectile without solid obstacle")
			else:check(arena.enemies[0].hp<10000,item.id+" "+variant+" actual target HP decreases")
			check(arena.missiles.is_empty() and arena.combat.water_states.is_empty(),item.id+" "+variant+" no expired projectile/field residue")
			cases.append({"variant":variant,"keys":E.inputs(game._active_profile(),game.water_qa_cases[item.id][variant].actions).map(func(e):return e.key),"damage":definition.damage,"cost":definition.mana_cost,"speed":definition.projectile_speed,"range":definition.projectile_speed*definition.lifetime,"radius":definition.radius,"duration":definition.duration,"strength":definition.formula_effect.strength,"hp_loss":10000-arena.enemies[0].hp,"displacement":arena.enemies[0].pos-pos0,"metrics":arena.combat.water_metrics.duplicate(true)})
		report.append({"id":item.id,"name":item.name,"actions":item.actions,"orders":seen.size(),"counts":counts,"min_strength":min_a,"max_strength":max_a,"cases":cases,"permutation_metrics":numerical})
	check(sum_orders==1014,"All1014 unique water permutations checked")
	game._end_developer_test()
	check(Equal.equal(original,game._character_document()) and FileAccess.get_file_as_bytes(path)==bytes,"QA restores original document, keys, journal, world and exact save bytes")
	FileAccess.open(AUDIT+"water15_"+("auto" if DisplayServer.get_name()=="headless" else "window")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	await finish("WATER15 INTEGRATION")
