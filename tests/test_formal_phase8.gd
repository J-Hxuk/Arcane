extends "res://tests/preview_world_phase1.gd"
const OUT="res://.task002_artifacts/formal_world/"
func run()->void:
	var fonts=[load("res://assets/fonts/NotoSerifKR.ttf"),load("res://assets/fonts/NotoSansKR.ttf")]
	for font in fonts:
		font.allow_system_fallback=false;var missing:=0
		for code in range(0xAC00,0xD7A4):
			if not font.has_char(code):missing+=1
		check(missing==0,"Bundled font covers all 11,172 modern Hangul syllables: "+font.get_font_name())
	var family=preload("res://scripts/ui_fonts.gd");var tag:=TextServerManager.get_primary_interface().name_to_tag("wght")
	check(family.UI.variation_opentype.get(tag)==500 and family.BOOK.variation_opentype.get(tag)==450,"Readable font weights use the actual supported OpenType axis tag")
	var path:=OUT+"phase8_%d.json"%Time.get_ticks_usec();A.write(path,F.fixture("WATER",8431))
	game=Scene.instantiate();game.save_path=path;root.add_child(game);game.set_process(false);await process_frame
	game.player_pos=Vector2(1000,530);game._interact();await process_frame
	for element in game.CharacterResearch.BaseElements.OHAENG:
		game._read_world_book(element)
		for page in 2:
			game.book_view.page=page;game._update_book_page();await process_frame;await process_frame
			check(game.library_text.text.length()>150 and game.library_text.size.x<=game.book_view.scroller.size.x+1,"Ten original pages wrap inside scroll column "+element+str(page))
	var source:String=game.library_text.text;game.library_text.text=(source+"\n\n").repeat(8)
	await process_frame;await process_frame
	check(game.library_text.size.y>game.book_view.scroller.size.y,"Long book content scrolls instead of overlapping page controls")
	check(game.library_text.get_theme_font("font").base_font==fonts[0],"Book uses Korean serif independently from HUD sans")
	if DisplayServer.get_name()!="headless":
		game.library_text.text=source;await process_frame;await RenderingServer.frame_post_draw;game.world_dialog.get_viewport().get_texture().get_image().save_png(OUT+"phase8_book.png")
		game.world_dialog.size=Vector2i(730,460);await process_frame;await process_frame
		check(game.library_text.size.x<=game.book_view.scroller.size.x+1,"Narrow resized book maintains wrapping")
		await RenderingServer.frame_post_draw;game.world_dialog.get_viewport().get_texture().get_image().save_png(OUT+"phase8_book_narrow.png")
	game.free();print("FORMAL PHASE8: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
