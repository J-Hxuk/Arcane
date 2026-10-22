extends "res://tests/current_options_helpers.gd"
const AUDIT="res://.task002_artifacts/formula_followup/"
func run()->void:
	fresh();await process_frame;game.research.developer_reset("all_elements","")
	var source:Dictionary=game.research.to_data();source.binding_studies=[];source.fusion_observations={};game.research.load_data(source)
	var observations:Array=[]
	for row in Registry.config().spells:
		if not row.has("elements"):continue
		for reversed in [false,true]:
			var main:String=row.elements[1] if reversed else row.elements[0];var aux:String=row.elements[0] if reversed else row.elements[1]
			game._change_active_attributes(main,aux);var context:Dictionary=game._prototype_context()
			check(context.binding_pairs.is_empty(),"No binding history in formal context "+row.id)
			var wrong:=0
			for order in Registry.permutations(row.actions):
				var result:=E.resolve(game._active_profile(),E.inputs(game._active_profile(),order),context)
				if result.get("spell")==null or result.identity!=row.id:wrong+=1
			check(wrong==0,"Every fusion order casts with awakened pair and zero research history "+row.id+str(reversed))
			var actions:Array=row.actions.duplicate();actions.erase("BIND")
			check(E.resolve(game._active_profile(),E.inputs(game._active_profile(),actions),context).identity!=row.id,"Missing BIND never manifests fusion")
			var forged:=context.duplicate(true);forged.awakened_attributes=[main]
			check(E.resolve(game._active_profile(),E.inputs(game._active_profile(),row.actions),forged).get("spell")==null,"Unawakened auxiliary is rejected even without research gates")
			game.player_pos=game.layout.LAB_DOOR;game._enter_laboratory();var arena=game.laboratory_panel.arena;arena.set_process(false);arena.reset_targets()
			game._reset_combat_input();game.player_mana=game._max_mana();game.mana_debt=0;game.exhaustion_seconds=0
			chant(row.actions);var result:Dictionary=game._inspect_chant(true);var mana:float=game.player_mana
			game._cast_spell()
			check(is_equal_approx(mana-game.player_mana,result.mana_cost) and arena.missiles.size()==1,"Real lab payment and executor accept history-free fusion")
			arena.enemies[0].pos=arena.player_pos+Vector2(110,0);arena.combat.update_missiles(arena,.5,1)
			check(arena.enemies[0].hp<200,"History-free fusion causes actual target damage")
			game._leave_laboratory();game.player_pos=Vector2(2200,900);game.missiles.clear();game.enemies.clear();game._reset_combat_input();game.player_mana=game._max_mana();game.mana_debt=0;game.exhaustion_seconds=0
			chant(row.actions);mana=game.player_mana;game._cast_spell()
			check(is_equal_approx(mana-game.player_mana,result.mana_cost) and game.missiles.size()==1,"Real world payment and executor accept history-free fusion")
			observations.append({"id":row.id,"main":main,"auxiliary":aux,"cost":result.mana_cost})
	var fusion_path:String=game.save_path;game._save_character()
	game.free();game=Scene.instantiate();game.save_path=fusion_path;root.add_child(game);game.set_process(false);await process_frame
	check(game.save_writable and game.research.to_data().binding_studies.is_empty() and game.discovered.to_data().spells.size()>=2,"New history-free fusion discoveries survive a real scene restart")
	game._clear_chant();game._change_active_attributes("WATER","METAL");game.missiles.clear();game.player_mana=0;game.mana_debt=game.ManaOverdraw.limit(game._max_mana())
	chant(Registry.config().spells.filter(func(row):return row.id=="ICE_CRYSTAL_NEEDLE")[0].actions);game._cast_spell()
	check(game.player_mana==0 and game.missiles.is_empty(),"History-free fusion still requires sufficient mana within the existing overdraw limit")
	game._clear_chant();game.player_mana=game._max_mana();game.mana_debt=0
	# A forged direct resource is blocked at the executor as well as the interpreter.
	game._change_active_attributes("WOOD","WATER");var definition=Registry.definition("ICE_CRYSTAL_NEEDLE")
	check(not game.elemental_combat.cast(game,definition,Vector2.RIGHT),"Direct executor rejects fusion that excludes active main")
	game._change_active_attributes("WATER",null)
	check(not game.elemental_combat.cast(game,definition,Vector2.RIGHT),"Direct executor rejects missing equipped auxiliary")
	# Preserve real historical bindings and original personal mapping through a copy save.
	var snapshot:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(AUDIT+"user_before.json"));var path:=fresh(snapshot);await process_frame
	var before:Dictionary=game._character_document();var original_binding:Variant=before.research.get("binding_studies",[])
	check(game._save_character(),"Actual-save COPY writes without changing schema")
	game.free();game=Scene.instantiate();game.save_path=path;root.add_child(game);game.set_process(false);await process_frame
	check(Equal.equal(original_binding,game.research.to_data().get("binding_studies",[])),"Restart preserves every historical binding record")
	check(Equal.equal(before.chant,game._character_document().chant) and Equal.equal(before.active_chant,game._active_profile().to_data()),"Restart preserves both original and active personal mappings")
	FileAccess.open(AUDIT+"fusion_access.json",FileAccess.WRITE).store_string(JSON.stringify(observations,"\t"))
	await finish("FOLLOWUP FUSION")
