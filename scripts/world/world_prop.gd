extends Node2D
## Visuals project upward from unchanged collision footprints. Long walls sort per segment.
const Art = preload("res://scripts/world/world_art.gd")
var data: Dictionary = {}
func configure(value: Dictionary) -> void:
	data = value
	position = data["pos"]
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if data["kind"] == "mentor":
		var view := preload("res://scripts/world/mentor_view.gd").new()
		view.element = data["element"]; add_child(view); return
	if data["kind"] == "tree":
		add_child(Art.sprite(Art.TREE, Vector2(-72, -184), Vector2(144, 200)))
		return
	var rect: Rect2 = data["rect"]
	if data["kind"] == "building":
		var texture: Texture2D = Art.BUILDINGS[data["name"]]
		add_child(Art.sprite(texture, Vector2(-rect.size.x * 0.5 - 16, -rect.size.y - 104), texture.get_size() * 2))
	elif data["kind"] in ["wall", "ruin"]:
		y_sort_enabled = true
		var vertical := rect.size.y > rect.size.x
		var length := rect.size.y if vertical else rect.size.x
		for start in range(0, ceili(length), 64):
			var span := minf(64, length - start)
			var section := Node2D.new()
			section.name = "WallSection"
			var size := Vector2(rect.size.x, span) if vertical else Vector2(span, rect.size.y)
			section.position = Vector2(0, -rect.size.y + start + span) if vertical else Vector2(-rect.size.x * 0.5 + start + span * 0.5, 0)
			section.add_child(Art.sprite(Art.WALL_V if vertical else Art.WALL_H, Vector2(-size.x * 0.5, -size.y - 48), Vector2(size.x, size.y + 48)))
			if data["kind"] == "ruin": section.modulate = Color("9eada2")
			add_child(section)
	else:
		add_child(Art.sprite(Art.ROCK, Vector2(-rect.size.x * 0.5 - 6, -rect.size.y - 26), rect.size + Vector2(12, 32)))
