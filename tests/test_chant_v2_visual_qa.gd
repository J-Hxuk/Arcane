extends "res://tests/preview_world_phase1.gd"
# Historical interpreter/UI fixture. Production acceptance is test_formal_phase1..9.
const OUT="res://.task002_artifacts/chant_v2_visual_qa/"
const E=preload("res://scripts/chant_engine_v2.gd")
const Perm=preload("res://tests/test_chant_v2.gd")
const Lore=preload("res://scripts/research_lore.gd")
const Coach=preload("res://scripts/mentor_advice.gd")
const Preview=preload("res://scripts/spell_preview.gd")
const Research=preload("res://scripts/character_research.gd")
const Equal=preload("res://tests/test_chant.gd")
func run()->void:
	root.size=Vector2i(1160,720)
	var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"user_before.json"))
	var path:=OUT+"automatic_%d.json"%Time.get_ticks_usec();A.write(path,source)
	game=Scene.instantiate();game.formal_rules=false;game.save_path=path;root.add_child(game);game.set_process(false);await process_frame
	var bytes:=FileAccess.get_file_as_bytes(path);var original:Dictionary=game._character_document().duplicate(true)
	check(game.save_writable and game.journal.records().size()==source.laboratory.records.size(),"Latest v5 loads without pruning or disk migration writes")
	check(FileAccess.get_file_as_bytes(path)==bytes,"Evidence separation on load does not write player bytes")
	var evidence:Dictionary=game.research.to_data().get("permanent_evidence",{})
	check(not evidence.is_empty(),"Existing resonance/fusion proof captured outside observations")
	for proof in evidence.values():check(not proof.has("steps") and not proof.has("grammar_profile") and not proof.has("note"),"Detached proof contains only minimal earned evidence")
	var ids:Array=game.journal.records().map(func(r):return r.id)
	for id in ids:game.journal.protect(int(id),false)
	check(game._delete_journal_records(ids)==ids.size(),"Even discovery, awakening and favorite-spell observations can be deleted")
	check(game.journal.records().is_empty() and game.research.validate_evidence([]).is_empty(),"Deleting all observations retains valid permanent research")
	for field in ["learned","chant","research","spell_discoveries"]:check(Equal.equal(original[field],game._character_document()[field]),"Full observation deletion preserves "+field)
	var restored=Research.new();check(restored.load_data(game.research.to_data()).is_empty() and restored.validate_evidence([]).is_empty(),"Detached proof reloads without journal")
	var reloaded=Scene.instantiate();reloaded.save_path=path;root.add_child(reloaded);reloaded.set_process(false)
	check(reloaded.save_writable and reloaded.journal.records().is_empty() and Equal.equal(reloaded.learned_spells,game.learned_spells) and reloaded.research.validate_evidence([]).is_empty(),"Actual scene restart accepts fully deleted observations and unchanged progression")
	reloaded.free()
	var bad:Dictionary=game.research.to_data();bad.permanent_evidence.values()[0].result.outcome="failed"
	var damaged=Research.new();damaged.load_data(bad);check(not damaged.validate_evidence([]).is_empty(),"Corrupt permanent evidence rejected")
	check(game._restore_journal_delete() and game.journal.records().size()==ids.size(),"Atomic delete backup restores observations without replacing permanent progress")
	var prior:Dictionary=game.journal.to_data();game.save_path=OUT+"missing_parent/failure.json"
	check(game._delete_journal_records(ids)==0 and game.journal.to_data()==prior,"Failed delete backup retains observations")
	game.save_path=path
	var known:Array=[];var pages:Dictionary={}
	for element in Lore.DATA:
		var row:Dictionary=Lore.DATA[element]
		check(row.pages.size()==2 and row.pages[0]!=row.pages[1],element+" has two unique manuscript pages")
		for i in 2:
			var page:=Lore.page(element,i,[]);check(not page.contains(row.name) and not page.contains(row.spell) and not pages.has(page),"Undiscovered manuscript unique and anonymous "+element+str(i));pages[page]=true
		known=[{"spell_id":row.spell,"name":row.name}]
		check(Lore.page(element,1,known).contains(row.name),"Discovered manuscript can be identified "+element)
		check(row.mentor.values().size()==5 and row.mentor.oral!=row.mentor.seeking,"Element-specific awakening and oral lore are distinct "+element)
	check(pages.size()==10 and E.CONFIG.spells.size()==6,"Ten book pages added without registering unapproved spells")
	check(preload("res://scripts/experiment_journal.gd").title({"result":{"manifestation":{"english_name":"","name":"빙정침","new_spell":true}}})=="마법 발견 — 빙정침","Legacy/fusion records with an empty English field still have a meaningful title")
	var isolation_bytes:=FileAccess.get_file_as_bytes(path);var isolation_doc:Dictionary=game._character_document().duplicate(true)
	game._start_prototype_all("LAB");var arena=game.laboratory_panel.arena;arena.set_process(false)
	var metrics:Array=[]
	for row in E.CONFIG.spells:
		for order in Perm.permutations(row.actions):
			arena.player_pos=Vector2(180,210);arena.reset_targets();arena.enemies.resize(1);arena.enemies[0].pos=Vector2(400,210)
			var result:=E.resolve(game.prototype_profile,E.inputs(game.prototype_profile,order),game._prototype_context())
			var spell=result.spell
			var resolution:Dictionary={"state":result.state,"risk":result.risk}
			var advice:=Coach.evaluate(result.final_state,row.get("element","WATER"),resolution)
			check(advice.branch==("ready_unstable" if result.risk=="unstable" else "ready"),"Mentor honors shared resolver "+row.id+str(order))
			check(Preview.public_result(result,[]).get("known")==false and not Preview.public_result(result,[]).text.contains(spell.display_name),"Unknown preview hides identity")
			var public:=Preview.public_result(result,[{"spell_id":str(spell.spell_id)}])
			check(not public.text.contains("피해 ") and not public.text.contains("px") and Preview.public_result(result,[{"spell_id":str(spell.spell_id)}],true).text.contains("피해 "),"Known metrics require explicit detailed observation")
			check(arena.combat.cast(arena,spell,Vector2.RIGHT),"Actual executor accepts shared tuned resource")
			if spell.effect==&"projectile":
				check(is_equal_approx(arena.missiles[0].collision_radius,spell.projectile_radius) and arena.missiles[0].definition==spell,"Visible core and actual collision use one radius")
				arena.combat.update_missiles(arena,1.5,1)
				check(arena.enemies[0].hp<200,"Swept projectile produces actual damage")
			else:check(is_equal_approx(arena.combat.barriers[0].radius,spell.radius) and is_equal_approx(arena.combat.barriers[0].life,spell.duration),"Barrier size and duration change in physical executor")
			metrics.append({"id":row.id,"order":order,"damage":spell.damage,"cost":spell.mana_cost,"speed":spell.projectile_speed,"visual_radius":spell.projectile_radius if spell.effect==&"projectile" else spell.radius,"collision_radius":spell.projectile_radius if spell.effect==&"projectile" else spell.radius,"range":spell.projectile_speed*spell.lifetime if spell.effect==&"projectile" else spell.radius,"knockback":spell.knockback,"duration":spell.duration,"stability":result.final_state.stability,"glow":spell.visual_glow,"density":spell.visual_density,"trail":spell.visual_trail})
	check(metrics.size()==54,"All 54 permutations exercised in physical executor")
	var observation:=E.resolve(game.prototype_profile,E.inputs(game.prototype_profile,E.CONFIG.spells[4].actions),game._prototype_context())
	var recorded:int=game.journal.append(observation.simulation,"released",observation.mana_cost,150,2)
	game.journal.mark_manifestation(recorded,{"spell_id":"WATER_PUSH","name":"Tidebolt","damage":observation.spell.damage})
	var record:Dictionary=game.journal.records().back();var ui=game.laboratory_panel
	check(not ui._step_text(record.steps[0],record).contains("당시 발현: 피해"),"Stored discovery replay also hides performance by default")
	ui.detailed_observation.button_pressed=true
	check(ui._step_text(record.steps[0],record).contains("당시 발현: 피해"),"Explicit detailed observation reveals stored performance without resimulation")
	ui.detailed_observation.button_pressed=false
	for item in metrics:
		if item.id=="OH-031":item.speed=0.0
	game.laboratory_panel.show_journal();var selected:Variant=game.laboratory_panel.selectors[0].selected;var last:Dictionary=game.last_laboratory_result.duplicate(true)
	game.laboratory_panel.show_manifestation("Tidebolt")
	check(game.laboratory_panel.panel.visible and not game.laboratory_panel.trial_panel.visible and selected==game.laboratory_panel.selectors[0].selected and last==game.last_laboratory_result,"Discovery notification preserves research screen, replay and state")
	game.laboratory_panel.show_trial()
	var rdata:Dictionary=game.research.to_data();rdata.research_clues=[];game.research.load_data(rdata)
	var before:int=game.journal.records().size();game._collect_research_clue("WOOD","environment")
	check(game.research.has_clue("WOOD","environment") and game.journal.records().size()==before+1 and arena.catalyst_reaction=="WOOD","Catalyst creates earned clue, visible reaction and observation")
	game._collect_research_clue("WOOD","environment")
	check(game.journal.records().size()==before+1 and game.laboratory_panel.message.text.contains("이미"),"Duplicate catalyst reports prior collection without duplicate observation")
	for zoom in [.65,1.0,1.6]:
		arena.camera.zoom=Vector2.ONE*zoom;arena.player_pos+=Vector2(50,10);arena._update_views();arena.camera.force_update_scroll()
		var world:=Vector2(490,180);check(arena.screen_to_world(arena.world_to_screen(world)).distance_to(world)<.001,"Camera/zoom projection round trip "+str(zoom))
	var pos:Vector2=game.player_pos
	game.hit_feedback.receive(10,false,Vector2.RIGHT);var normal:float=game.hit_feedback.shake_peak
	for i in 100:game.hit_feedback.receive(30,true,Vector2.LEFT)
	check(game.hit_feedback.shake_peak>normal and game.hit_feedback.shake_peak<=5 and game.player_pos==pos,"Heavy shake stronger, bounded and presentation only")
	check(game.hit_feedback.camera_offset(0)==Vector2.ZERO,"Camera shake setting supports off")
	for hp in [30.0,20.0,5.0]:
		for i in 100:game.hit_screen.advance(hp,100,.016)
		check(absf(game.hit_screen.intensity-maxf(0,1-hp/30))<.001,"Continuous low HP warning "+str(hp))
	for i in 180:game.hit_screen.advance(31,100,.016)
	check(game.hit_screen.intensity<.001,"Recovery smoothly removes low HP warning")
	for i in 30:game.hit_screen.advance(29.99 if i%2 else 30.01,100,.016)
	check(game.hit_screen.intensity<.001,"Threshold jitter does not produce flashing")
	FileAccess.open(OUT+"physical_permutations.json",FileAccess.WRITE).store_string(JSON.stringify(metrics,"\t"))
	game._end_developer_test();check(FileAccess.get_file_as_bytes(path)==isolation_bytes and Equal.equal(game._character_document(),isolation_doc),"Developer session restores exact original data and never writes its disk")
	game.free();print("CHANT V2 VISUAL QA: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
