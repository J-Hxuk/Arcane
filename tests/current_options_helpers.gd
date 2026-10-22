extends "res://tests/preview_world_phase1.gd"
const OUT="res://.task002_artifacts/current_world_options/"
const E=preload("res://scripts/chant_engine_v2.gd")
const Registry=preload("res://scripts/formal_spell_registry.gd")
const Equal=preload("res://tests/test_chant.gd")
func fresh(data:Dictionary={})->String:
	if is_instance_valid(game):game.free()
	var path:=OUT+"fixture_%d_%d.json"%[OS.get_process_id(),Time.get_ticks_usec()];A.write(path,F.fixture("WATER",8431) if data.is_empty() else data)
	game=Scene.instantiate();game.save_path=path;root.add_child(game);game.set_process(false)
	return path
func chant(actions:Array)->Array:
	var events:=E.inputs(game._active_profile(),actions);game._clear_chant();game.runes.assign(events.map(func(e):return str(e.key)));game.chant_inputs=events.duplicate(true)
	for event in game.chant_inputs:event.released=true
	return events
func normal_order(row:Dictionary,context:Dictionary)->Array:
	var fallback:Array=[]
	for order in [row.actions]+Registry.permutations(row.actions):
		var result:=E.resolve(game._active_profile(),E.inputs(game._active_profile(),order),context)
		if result.state!="ready" or result.get("spell")==null or result.identity!=row.id:continue
		fallback=order
		if result.risk=="normal":return order
	return fallback
func enter_keys(actions:Array)->void:
	await key(KEY_SHIFT,true)
	for event in E.inputs(game._active_profile(),actions):await tap(OS.find_keycode_from_string(event.key))
func capture(name:String,viewport:Viewport=null)->void:
	if DisplayServer.get_name()=="headless":return
	game.queue_redraw();game._sync_world_view();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	(viewport if viewport!=null else root).get_texture().get_image().save_png(OUT+name+".png")
func restart_fixture(label:String)->void:
	game._save_character()
	FileAccess.open(OUT+"restart_"+label+".json",FileAccess.WRITE).store_string(JSON.stringify({"path":game.save_path,"expected":game._character_document()}))
func finish(label:String)->void:
	if is_instance_valid(game):
		game.spell_audio.stop();game.spell_audio.stream=null
		await create_timer(.1).timeout # Let the audio mixer release transient one-shot playbacks before process exit.
		game.queue_free()
	await process_frame;await create_timer(.05).timeout;print(label+": %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
