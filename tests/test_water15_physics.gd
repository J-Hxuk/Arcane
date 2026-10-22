extends "res://tests/test_water15_integration.gd"
const WCOMBAT=preload("res://scripts/water_combat.gd")
func definition(id:String,variant:="on"):
	game._water_qa_prepare(id,variant)
	return game._inspect_chant(true).spell
func reset(arena)->void:
	arena.reset_targets();arena.player_pos=Vector2(180,210);arena.enemies.assign([target(Vector2(330,210))]);game.player_hp=100;arena.player_hp=100
func seconds(arena,time:float)->void:
	for i in ceili(time*120):arena.combat.update(arena,1.0/120);arena.combat.update_missiles(arena,1.0/120,1)
func qualitative_sample(arena,d)->Dictionary:
	reset(arena)
	var id:=str(d.spell_id);var center:Vector2=arena.player_pos+Vector2.RIGHT*d.placement_distance
	if id in ["OH-068","OH-071","OH-073"]:arena.enemies[0].pos=center+Vector2(65,0)
	if id=="OH-072":arena.enemies[0].pos=center
	if id in ["OH-069","OH-070","OH-075"]:arena.enemies.clear()
	arena.combat.cast(arena,d,Vector2.RIGHT)
	if id=="OH-067":arena.missiles.append({"pos":Vector2(340,210),"dir":Vector2.LEFT,"hostile":true,"speed":180.0,"life":2.0,"dmg":20.0})
	seconds(arena,.5 if id=="OH-067" else (.4 if id=="OH-074" else .2))
	var positions:Array=[];var directions:Array=[]
	for m in arena.missiles:positions.append([m.pos.x,m.pos.y]);directions.append([m.dir.x,m.dir.y])
	var early:Vector2=arena.enemies[0].pos if not arena.enemies.is_empty() else Vector2.ZERO
	if id=="OH-071":seconds(arena,.25)
	if id=="OH-072":seconds(arena,d.duration+.1)
	if id=="OH-074":seconds(arena,.5)
	return {"missile_positions":positions,"directions":directions,"early":[early.x,early.y],"enemy_pos":[arena.enemies[0].pos.x,arena.enemies[0].pos.y] if not arena.enemies.is_empty() else [],"deflections":arena.combat.water_metrics.deflections,"release_rings":arena.combat.water_metrics.release_rings,"delayed_hits":arena.combat.water_metrics.delayed_hits}
func run()->void:
	root.size=Vector2i(1160,720);fresh();await process_frame;game._water_qa_start("LAB");var arena=game.laboratory_panel.arena;arena.set_process(false)
	for id in ["OH-066","OH-067"]:
		for variant in ["off","on"]:
			var d=definition(id,variant);reset(arena)
			check(arena.combat.cast(arena,d,Vector2.RIGHT),id+" shield casts")
			arena.missiles.append({"pos":Vector2(340,210),"dir":Vector2.LEFT,"hostile":true,"speed":180.0,"life":2.0,"dmg":20.0})
			seconds(arena,1.5)
			var expected:float=14 if id=="OH-066" else 9
			check(is_equal_approx(100-game.player_hp,expected) if variant=="off" or id=="OH-066" else game.player_hp>=91,id+" actual projectile damage reduction/deflection "+variant)
			check(not arena.combat.blocks(Vector2(255,210),13),id+" water wall does not block actor navigation")
			if id=="OH-067":check(arena.combat.water_metrics.deflections==int(variant=="on"),"Eddywall deflects first projectile only in ON")
	for id in ["OH-069","OH-075"]:
		for variant in ["off","on"]:
			var d=definition(id,variant);reset(arena);arena.enemies[0].hit_radius=90
			arena.combat.cast(arena,d,Vector2.RIGHT)
			var count:int=3 if id=="OH-069" else 7
			check(arena.missiles.size()==count,id+" actual independent stream count "+variant)
			if id=="OH-069":check(arena.missiles[0].launch_delay==0 and arena.missiles[2].launch_delay>arena.missiles[1].launch_delay,"Trident preserves source fixed-order sequential launch")
			var budget:=0.0
			for m in arena.missiles:budget+=m.definition.damage
			check(is_equal_approx(budget,d.damage),id+" total damage divided across streams")
			seconds(arena,2)
			check(is_equal_approx(10000-arena.enemies[0].hp,d.damage),id+" each stream hits once, total budget preserved "+variant)
	for id in ["OH-068","OH-071"]:
		var samples:Array=[]
		for variant in ["off","on"]:
			var d=definition(id,variant);reset(arena);var center:Vector2=arena.player_pos+Vector2.RIGHT*d.placement_distance
			arena.enemies[0].pos=center+Vector2(70,0);arena.combat.cast(arena,d,Vector2.RIGHT)
			seconds(arena,.3);var first:Vector2=arena.enemies[0].pos;seconds(arena,.2);var second:Vector2=arena.enemies[0].pos
			samples.append({"first":first,"second":second,"center":center,"strength":d.formula_effect.strength})
		if id=="OH-068":check(absf(samples[1].second.y-samples[1].center.y)>absf(samples[0].second.y-samples[0].center.y)+1,"Undertow integrates real tangential orbit")
		else:check(samples[1].second.distance_to(samples[1].first)<samples[0].second.distance_to(samples[0].first),"Confluence ON has a real pause between two inward pulses")
	var jet=definition("OH-070");reset(arena);arena.enemies.clear();arena.combat.cast(arena,jet,Vector2.RIGHT);arena.combat.update_missiles(arena,.2,1)
	var missile:Dictionary=arena.missiles[0];var expected:Vector2=missile.origin+Vector2.RIGHT*jet.projectile_speed*.2+Vector2.RIGHT.orthogonal()*40*jet.formula_effect.strength*sin(PI*.2/jet.lifetime)
	check(Vector2(missile.pos).distance_to(expected)<.01,"Razorflow actual swept position follows cast-frozen curve")
	var saved:Vector2=missile.launch_dir;arena.enemies.append(target(Vector2(200,400)));arena.combat.update_missiles(arena,.1,1)
	check(arena.missiles[0].launch_dir==saved,"Curved jet never homes toward a moved/new target")
	var prison=definition("OH-072");reset(arena);arena.enemies[0].pos=arena.player_pos+Vector2.RIGHT*prison.placement_distance
	arena.combat.cast(arena,prison,Vector2.RIGHT);var hp:float=arena.enemies[0].hp;var p:Vector2=arena.enemies[0].pos;seconds(arena,prison.duration+.1)
	check(arena.combat.water_metrics.release_rings==1 and arena.enemies[0].pos.distance_to(p)>0,"Abyssal Lock releases one displacement ring at expiration")
	check(arena.enemies[0].hp==hp,"Release ring adds no HP damage or stagger")
	var sea=definition("OH-073");reset(arena);arena.enemies[0].pos=arena.player_pos+Vector2.RIGHT*sea.placement_distance
	arena.combat.cast(arena,sea,Vector2.RIGHT);seconds(arena,sea.duration+.1)
	check(absf((10000-arena.enemies[0].hp)-(sea.damage+sea.damage_per_second*sea.duration))<.01,"Thalassa initial and scheduled fractional-tail DoT obey exact damage budget")
	var hadal=definition("OH-074");reset(arena);arena.combat.cast(arena,hadal,Vector2.RIGHT);seconds(arena,2)
	check(arena.combat.water_metrics.delayed_hits==1 and absf((10000-arena.enemies[0].hp)-hadal.damage)<.01,"Hadal delayed pressure splits, never adds to, original158-derived budget")
	# Collision-safe orbit/push and original boss resistance/root cap.
	var e=target(Vector2(650,385));arena.enemies.assign([e]);WCOMBAT.move_enemy(arena.combat,arena,e,Vector2(200,0))
	check(e.pos.x<680 and not arena._is_blocked(e.pos,15),"Water displacement sweeps stop at actual obstacle boundary")
	game._water_qa_start("WORLD");var boss:Dictionary=game.guardian.actor;boss.pos=Vector2(3250,910);boss.hp=10000;game.enemies.assign([boss]);game.guardian.state="RECOVERY"
	var before:float=boss.poise
	var root_spell=definition("OH-072");game.elemental_combat.hit_enemy(game,boss,root_spell,Vector2.RIGHT)
	check(boss.root_remaining<=1.5 and boss.root_remaining>0,"Boss root keeps confirmed1.5s cap and resistance")
	var first_root:float=boss.root_remaining;boss.root_remaining=0;game.elemental_combat.hit_enemy(game,boss,root_spell,Vector2.RIGHT)
	check(boss.root_remaining<first_root,"Boss root retains existing reapplication diminishing returns")
	var origin:Vector2=boss.pos;WCOMBAT.move_enemy(game.elemental_combat,game,boss,Vector2(50,0))
	check(boss.pos.distance_to(origin)<=10.01,"Boss mass5/displacement resistance reduces flow to20percent")
	game.guardian.state="ACTIVE";game.guardian.pattern="CHARGE";origin=boss.pos;WCOMBAT.move_enemy(game.elemental_combat,game,boss,Vector2(50,0))
	check(boss.pos==origin,"New flow cannot move or cancel active boss charge")
	check(boss.poise==before,"New water phenomena do not add unapproved boss poise damage")
	game._water_qa_start("LAB");arena=game.laboratory_panel.arena;arena.set_process(false)
	var ablations:Array=[]
	for item in WATER.DATA.spells:
		if item.tier<2:continue
		game._water_qa_prepare(item.id,"on");var result:Dictionary=game._inspect_chant(true);var on=result.spell
		var base=VARIATION.tune(WATER.definition(item.id),result.final_state,E.CONFIG)
		var off_result:=qualitative_sample(arena,base)
		await snap_water(item.id+"_effect_off",arena)
		var on_result:=qualitative_sample(arena,on)
		await snap_water(item.id+"_effect_on",arena)
		check(off_result!=on_result,item.id+" identical raw state with F disabled/enabled changes actual qualitative physics")
		check(is_equal_approx(on.mana_cost,base.mana_cost*(1+.1*on.formula_effect.strength)),item.id+" one continuous qualitative cost surcharge, no old numerical F double charge")
		ablations.append({"id":item.id,"strength":on.formula_effect.strength,"off":off_result,"on":on_result,"base_cost":base.mana_cost,"on_cost":on.mana_cost})
	FileAccess.open(AUDIT+"phenomena_ablation.json",FileAccess.WRITE).store_string(JSON.stringify(ablations,"\t"))
	game._end_developer_test();await finish("WATER15 PHYSICS")
