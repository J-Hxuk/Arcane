extends "res://tests/followup_helpers.gd"
func run()->void:
	fresh();await process_frame;game._start_prototype_all("LAB")
	game.water_qa_active=true # Sufficient isolated budget for the expanded high-water registry.
	var arena=game.laboratory_panel.arena;arena.set_process(false)
	var sword:float=game.CombatBalance.melee_damage(50);check(sword==10 and game.CombatBalance.MELEE_INTERVAL==.8,"Sword stays 10 per swing / 12.5 theoretical DPS at body 50")
	var measurements:Array=[]
	for row in Registry.config().spells:
		game.prototype_target=row.id;arena.reset_targets();game.player_mana=game._max_mana();game.mana_debt=0;game.exhaustion_seconds=0
		var actions:=normal_order(row,game._prototype_context());chant(actions);var preview:Dictionary=game._inspect_chant(true);var spell=preview.spell
		for enemy in arena.enemies:enemy.hp=1000;enemy.max_hp=1000
		var target:Dictionary=arena.enemies[0]
		if spell.effect in [&"cone",&"shockwave"]:target.pos=arena.player_pos+Vector2(60,0)
		elif spell.effect==&"point":target.pos=arena.player_pos+Vector2(spell.placement_distance,0)
		var original_controller=arena.controller;arena.controller=null # Fixed rightward aim; real cursor inputs are covered below and in formal9.
		var mana:float=game.player_mana;game._cast_spell();arena.controller=original_controller
		check(is_equal_approx(mana-game.player_mana,preview.mana_cost) and game.journal.records().back().result.get("manifestation",{}).get("spell_id")==str(spell.spell_id),"Real executor charges and records "+row.id)
		var dealt:=0.0
		if spell.effect==&"barrier":
			check(arena.combat.barriers.size()==1 and arena.combat.blocks(arena.combat.barriers[0].pos,10),"Stoneward blocks actor paths")
			var barrier:Dictionary=arena.combat.barriers[0];arena.missiles.append({"pos":barrier.pos+Vector2(120,0),"dir":Vector2.LEFT,"hostile":true,"life":2.0,"dmg":10.0,"speed":500.0})
			arena.combat.update_missiles(arena,.4,1);check(arena.missiles.is_empty(),"Stoneward also intercepts hostile projectiles")
		else:
			if spell.effect==&"projectile":arena.combat.update_missiles(arena,2.0 if row.id=="OH-069" else .6,1)
			dealt=1000-target.hp;check(is_equal_approx(dealt,spell.damage),"Actual impact equals projected damage "+row.id)
			if spell.status_effect!=&"":check(target.get(str(spell.status_effect)+"_remaining",0)>0,"Actual status applied "+row.id)
			if spell.knockback>0:check(target.pos.x>arena.player_pos.x+60,"Actual control displaces target "+row.id)
			if spell.pierce_targets>1:check(arena.enemies[1].hp<1000,"Actual piercing hits a second body "+row.id)
			if spell.status_effect==&"burn":
				var hp:float=target.hp;arena.combat.update(arena,1);check(target.hp<hp,"Actual burn continues damage "+row.id)
		var advantages:=0
		if spell.damage>=sword*1.5:advantages+=1
		if (spell.projectile_speed*spell.lifetime if spell.effect==&"projectile" else spell.placement_distance if spell.effect==&"point" else spell.radius)>85:advantages+=1
		if spell.radius>85 and spell.effect in [&"cone",&"shockwave"]:advantages+=1
		if spell.status_effect!=&"" and spell.duration>.45:advantages+=1
		if spell.knockback>50:advantages+=1
		if spell.pierce_targets>1:advantages+=1
		if spell.effect==&"barrier":advantages=2
		if row.id in ["OH-066","OH-067"]:
			arena.missiles.append({"pos":arena.player_pos+Vector2(160,0),"dir":Vector2.LEFT,"hostile":true,"life":2.0,"dmg":10.0,"speed":180.0})
			arena.combat.update_missiles(arena,1.2,1)
			check(arena.combat.water_metrics.shield_contacts>0 and arena.combat.barriers.is_empty(),"Fluid defense provides actual projectile mitigation without solid collision "+row.id)
			advantages=2 # Mitigation plus mobile/flow defense; not a sword damage comparison.
		check(advantages>=2,"Role provides at least two advantages over sword "+row.id)
		measurements.append({"id":row.id,"actual_damage":dealt,"damage":spell.damage,"mana":preview.mana_cost,"inputs":actions.size(),"advantages":advantages,"illustrative_expected_dps":spell.damage*.8/(actions.size()*.15+.25)})
		await process_frame # Each real cast occurs in its own engine frame, including audio retirement.
	FileAccess.open(OUT+"combat_measurements.json",FileAccess.WRITE).store_string(JSON.stringify(measurements,"\t"))
	if DisplayServer.get_name()!="headless":
		game.prototype_target="OH-061";game.laboratory_panel.show_trial();arena.reset_targets();await capture("balance_trial")
	await finish("FOLLOWUP BALANCE")
