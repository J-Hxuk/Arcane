extends "res://tests/preview_world_phase1.gd"
# Historical interpreter/UI fixture. Production acceptance is test_formal_phase1..9.
const Rules=preload("res://scripts/mana_overdraw.gd")
const H=preload("res://tests/test_chant.gd")
const Progress=preload("res://scripts/world/world_progress.gd")
const DIR:="res://.task002_artifacts/mana_overdraw/"
var serial:=0
func fresh(element:="WATER") -> void:
	if is_instance_valid(game):game.free()
	serial+=1
	var data:=F.fixture(element,1787453028);data["magic"]=50
	var path:=DIR+"unit_%d.json"%serial;A.write(path,data)
	game=Scene.instantiate();game.formal_rules=false;game.save_path=path;root.add_child(game);game.set_process(false)
func enter(actions:Array=["ACCUMULATE","ACCUMULATE","DIRECT","DIRECT"],element:="WATER") -> void:
	A.enter_keys(game,D.inputs(game.chant_profile,element,actions).map(func(input):return input["key"]))
func run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for p in [0.0,0.0001,0.25,0.5,0.75,1.0]:
		check(is_equal_approx(Rules.ratio(30*p,100),p),"Continuous debt ratio "+str(p))
		check(is_equal_approx(Rules.speed(30*p,100),1-0.5*p),"Continuous speed multiplier "+str(p))
		check(is_equal_approx(Rules.blur(30*p,100),0 if p==0 else 0.075+0.425*p),"Continuous blur target "+str(p))
	check(Rules.quote(0,100,30)["allowed"] and not Rules.quote(0,100,30.001)["allowed"],"Exactly 30% debt is allowed; exceeding it is rejected")
	check(not Rules.quote(5,100,36)["allowed"] and Rules.quote(5,100,35)["allowed"],"Total post-cast debt, not spell cost alone, determines the limit")
	check(not Rules.quote(NAN,100,9)["allowed"] and not Rules.quote(5,100,-1)["allowed"],"Invalid resource requests cannot bypass the boundary")
	fresh();game.player_pos=game.layout.LAB_DOOR;game._enter_laboratory();game.laboratory_panel.arena.set_process(false)
	game.player_mana=5;var focus_before:float=game.focus;enter();game._cast_spell()
	check(game.player_mana==0 and game.mana_debt==4 and game.laboratory_panel.arena.missiles.size()==1,"Mana shortage automatically manifests once and enters internal mana debt")
	check(game.focus==focus_before and game.journal.records()[-1]["result"]["manifestation"]["mental_spent"]==4,"Existing legacy focus is preserved; mental spending derives from the single mana balance")
	check(game.mana_exhaustion_view.entry_count==1 and game.mana_exhaustion_view.entry_warning>0 and game.mana_exhaustion_view.displayed_blur>=0.075,"Successful first debt entry immediately triggers the edge warning")
	game.player_mana=0;game.mana_debt=21;enter();game._cast_spell()
	game.combat_input._set_mode(game.CombatInput.Mode.NORMAL)
	check(game.player_mana==0 and game.mana_debt==30 and is_equal_approx(game._movement_speed(),100),"An exact-boundary spell works and maximum exhaustion gives 50% movement")
	var missile_count:int=game.laboratory_panel.arena.missiles.size();enter();game._cast_spell()
	check(game.player_mana==0 and game.mana_debt==30 and game.laboratory_panel.arena.missiles.size()==missile_count and game.journal.records()[-1]["result"]["energy_spent"]==0,"Over-limit release changes neither mana nor combat effects; failure record spends zero")
	game._reset_combat_input();game.player_mana=0;game.mana_debt=10;A.enter_keys(game,["X"]);game._cast_spell()
	check(game.player_mana==0 and game.mana_debt==10 and game.exhaustion_seconds==0,"Ordinary invalid chanting cannot heal debt through a invalid failure cost")
	fresh();game.player_pos=game.layout.LAB_DOOR;game._enter_laboratory();game.laboratory_panel.arena.set_process(false);game.player_mana=5
	var before_journal:Dictionary=game.journal.to_data();var before_research:Dictionary=game.research.to_data()
	DirAccess.make_dir_absolute(game.save_path+".tmp");enter();game._cast_spell()
	check(game.player_mana==5 and game.laboratory_panel.arena.missiles.is_empty() and game.journal.to_data()==before_journal and game.research.to_data()==before_research,"Save failure rolls back internal debt payment, effect, journal and research")
	check(game.mana_exhaustion_view.entry_count==0,"Rolled-back payment produces no false first-debt warning")
	DirAccess.remove_absolute(game.save_path+".tmp")
	fresh("EARTH");game.player_pos=game.layout.LAB_DOOR;game._enter_laboratory();game.laboratory_panel.arena.controller=null
	game.laboratory_panel.arena.combat.barriers.append({"pos":Vector2(275,210),"radius":22.0,"life":5.0,"color":Color.WHITE})
	game.player_mana=5;enter(preload("res://scripts/m1_spell_catalog.gd").PROFILES["examples"]["OH-031"],"EARTH");game._cast_spell()
	check(game.player_mana==5 and game.laboratory_panel.arena.combat.barriers.size()==1,"Blocked manifestation never consumes mana or mental reserve")
	fresh();game.player_pos=Vector2(2600,1000);game.player_mana=0;game.mana_debt=30;game.navigation.request(game,Vector2(2800,1000));game._process(0.1)
	check(is_equal_approx(game.player_pos.x,2610) and is_equal_approx(game.mana_debt,29.7),"Actual ordinary movement uses 100px/s at the cap while mana recovers continuously")
	game.player_mana=0;game.mana_debt=30;game.combat_input._set_mode(game.CombatInput.Mode.FOCUS_CAST);var position:Vector2=game.player_pos;game._process(0.5)
	check(game.player_pos==position and game._movement_speed()==0 and game.player_mana==0 and game.mana_debt==27,"Focus immobility takes priority and world recovery stays doubled at 6/s")
	game.combat_input._set_mode(game.CombatInput.Mode.NORMAL);game.player_mana=0;game.mana_debt=0.5;game._process(1)
	check(game.player_mana==2.5 and game._movement_speed()==200 and not game.mana_exhaustion_view.overlay.visible,"Recovery above zero fully removes movement and visual penalties")
	game.player_mana=0;game.mana_debt=30;game.dodge.reset();game.dodge.begin(game.player_pos,Vector2.RIGHT);position=game.player_pos;game.dodge.advance(game,0.18)
	check(game.player_pos.distance_to(position+Vector2(108,0))<0.02 and is_equal_approx(game.dodge.cooldown,0.72),"Exhaustion preserves physical dodge distance, duration and cooldown")
	game.player_pos=game.layout.LAB_DOOR;game._enter_laboratory();game.player_mana=0;game.mana_debt=30;game.combat_input._set_mode(game.CombatInput.Mode.FOCUS_CAST);game._process(0.5)
	check(game.player_mana==0 and game.mana_debt==22 and game._movement_speed()==0,"Laboratory focus recovery stays doubled at 16/s")
	game.combat_input._set_mode(game.CombatInput.Mode.NORMAL);game.player_mana=0;game.mana_debt=30;game._process(0.5)
	check(game.player_mana==0 and game.mana_debt==26,"Ordinary laboratory recovery remains 8/s")
	var view=game.mana_exhaustion_view;view.reset();var entries:int=view.entry_count;view.advance(0.01,100,0)
	for i in 120:view.advance(0 if i%2==0 else 0.01,100,1.0/60)
	check(view.entry_count==entries+1 and view.displayed_blur<0.08,"Near-zero oscillation does not retrigger edge warnings every frame")
	view.advance(0,100,0.25);check(not view.overlay.visible,"Zero mana clears every visual effect after the bounded recovery transition")
	view.advance(0.01,100,0);check(view.entry_count==entries+2,"A later genuinely fresh debt event rearms the entry warning")
	game._leave_laboratory();game.player_mana=0;game.mana_debt=30;game._save_character();var path:String=game.save_path;var mapping:Dictionary=game.chant_profile.to_data();game.free()
	game=Scene.instantiate();game.formal_rules=false;game.save_path=path;root.add_child(game);game.set_process(false)
	check(game.save_writable and game.player_mana==0 and game.mana_debt==30 and game.chant_profile.to_data()==mapping,"Schema v5 reload preserves internal mana debt and the exact personal key table")
	var invalid:=F.fixture("WATER");invalid["magic"]=50;invalid["world"]=Progress.defaults();invalid["world"]["vitals"]={"hp":100,"mana":-31,"focus":100}
	var invalid_path:=DIR+"invalid_debt.json";A.write(invalid_path,invalid);var bytes:=FileAccess.get_file_as_bytes(invalid_path);game.free()
	game=Scene.instantiate();game.formal_rules=false;game.save_path=invalid_path;root.add_child(game);game.set_process(false)
	check(not game.save_writable and FileAccess.get_file_as_bytes(invalid_path)==bytes,"Malformed over-limit saved debt is protected without overwriting the source")
	fresh();game._start_guardian();game.player_pos=game.guardian.actor["pos"]-Vector2(65,0);game.player_mana=5;enter(preload("res://scripts/m1_spell_catalog.gd").PROFILES["examples"]["OH-063"])
	# Use WATER radial effects to exercise immediate boss mutation and rollback.
	var boss_before:Dictionary=game.guardian.snapshot();var hp:float=game.guardian.actor["hp"]
	DirAccess.make_dir_absolute(game.save_path+".tmp");game._cast_spell()
	check(game.player_mana==5 and game.guardian.actor["hp"]==hp and H.equal(game.guardian.snapshot(),boss_before),"World save failure restores the immediate boss damage, posture and resource transaction")
	check(is_same(game.enemies[0],game.guardian.actor),"Rollback preserves the live guardian actor reference")
	DirAccess.remove_absolute(game.save_path+".tmp");game.free()
	fresh();game.player_mana=5;enter();game._cast_spell();game.player_mana=5;game.mana_debt=0
	var existing_count:int=game.missiles.size();var existing_book:Dictionary=game.discovered.to_data()
	DirAccess.make_dir_absolute(game.save_path+".tmp");enter();game._cast_spell()
	check(game.player_mana==5 and game.missiles.size()==existing_count and game.discovered.to_data()==existing_book,"Already-known repeated spells also roll back mental payment when persistence fails")
	DirAccess.remove_absolute(game.save_path+".tmp");game.free()
	print("MANA OVERDRAW AUTOMATIC: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
