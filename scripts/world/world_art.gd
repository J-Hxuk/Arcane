extends RefCounted
## Original replaceable placeholder art. All actors use ground/foot coordinates.
const TRAVELLER = preload("res://data/world_art/traveller.svg")
const GUARDIAN = preload("res://data/world_art/guardian.svg")
const TREE = preload("res://data/world_art/tree.svg")
const ROCK = preload("res://data/world_art/rock.svg")
const WALL_H = preload("res://data/world_art/wall_h.svg")
const WALL_V = preload("res://data/world_art/wall_v.svg")
const BUILDINGS := {
	"연구실": preload("res://data/world_art/laboratory.svg"),
	"도서관": preload("res://data/world_art/library.svg"),
	"대장간": preload("res://data/world_art/smith.svg"),
	"쉼터": preload("res://data/world_art/rest.svg"),
	"스승의 집": preload("res://data/world_art/rest.svg"),
}
const GRASS = preload("res://data/world_art/grass.svg")
const COBBLE = preload("res://data/world_art/cobble.svg")
const DIRT = preload("res://data/world_art/dirt.svg")
const RUIN = preload("res://data/world_art/ruin.svg")
const DIRECTIONS := [&"down", &"left", &"right", &"up"]

static func frames(texture: Texture2D) -> SpriteFrames:
	var result := SpriteFrames.new()
	result.remove_animation(&"default")
	for row in 4:
		var animation: StringName = DIRECTIONS[row]
		result.add_animation(animation)
		result.set_animation_speed(animation, 8)
		for column in [0, 1, 0, 2]:
			var cell := AtlasTexture.new()
			cell.atlas = texture
			cell.region = Rect2(column * 32, row * 40, 32, 40)
			result.add_frame(animation, cell)
	return result

static func direction(vector: Vector2) -> StringName:
	if absf(vector.x) > absf(vector.y): return &"right" if vector.x > 0 else &"left"
	return &"down" if vector.y >= 0 else &"up"

static func sprite(texture: Texture2D, at: Vector2, size: Vector2) -> Sprite2D:
	var result := Sprite2D.new()
	result.texture = texture
	result.centered = false
	result.position = at
	result.scale = size / texture.get_size()
	result.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return result
