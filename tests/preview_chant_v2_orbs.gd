extends SceneTree
const E=preload("res://scripts/chant_engine_v2.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
	root.size=Vector2i(1160,360)
	root.content_scale_size=Vector2i(1160,360)
	var background:=ColorRect.new();background.color=Color("101e2d");background.size=Vector2(1160,360);root.add_child(background)
	var heading:=Label.new();heading.text="동일한 시각 모델 · 대표 구조 5종 / 색 + 갈래·발광·침전·윤곽·파동";heading.position=Vector2(20,15);root.add_child(heading)
	var p=preload("res://scripts/chant_profile.gd").new();p.load_data(p.generate_current(1787453028))
	for i in 5:
		var row:Dictionary=E.CONFIG.spells[i];var simulation:Dictionary=E.resolve(p,E.inputs(p,row.actions),{"developer_all":true})
		var label:=Label.new();label.text=row.id+" · "+simulation.spell.display_name;label.position=Vector2(20+i*225,60);root.add_child(label)
		var orb=preload("res://scripts/mana_orb_view.gd").new();orb.position=Vector2(20+i*225,95);orb.size=Vector2(215,230);root.add_child(orb);orb.show_snapshot(simulation.final_state,.75,false)
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.task002_artifacts/phase4_qa_v2/five_element_orbs.png")
	print("FIVE ELEMENT ORBS: rendered using the production visual projection");quit()
