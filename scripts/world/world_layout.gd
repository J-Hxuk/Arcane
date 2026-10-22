extends RefCounted
## Hand-authored, contiguous prototype. No continent, faction or history is fixed.
const BOUNDS := Rect2(0, -960, 3840, 2880)
const SPAWN := Vector2(780, 760)
const LAB_DOOR := Vector2(540, 550)
const CHECKPOINT := Vector2(2530, 930)
const ARENA := Rect2(3010, 500, 700, 820)
var props: Array[Dictionary] = []
var solids: Array[Dictionary] = []
var interactions: Array[Dictionary] = []
var _buckets: Dictionary = {}

func _init() -> void:
	_building("laboratory", "연구실", Rect2(370, 260, 340, 240), LAB_DOOR, "597787")
	_building("library", "도서관", Rect2(850, 260, 300, 220), Vector2(1000, 530), "76748b")
	_building("smith", "대장간", Rect2(1000, 900, 300, 230), Vector2(1150, 1180), "876556")
	_building("rest", "스승의 집", Rect2(280, 920, 300, 220), Vector2(430, 1190), "668376")
	interactions.back()["name"] = "공용 휴식석 · 회복/체크포인트"
	var mentor_positions := [Vector2(220,1230), Vector2(350,1260), Vector2(500,1260), Vector2(640,1230), Vector2(700,1130)]
	for i in 5:
		var element: String = ["WOOD", "FIRE", "EARTH", "METAL", "WATER"][i]
		props.append({"kind":"mentor", "element":element, "pos":mentor_positions[i]})
		interactions.append({"id":"mentor_"+element, "name":["木","火","土","金","水"][i]+"의 스승", "pos":mentor_positions[i]})
	for rect in [Rect2(80, 80, 40, 1320), Rect2(80, 80, 630, 40),Rect2(870,80,750,40), Rect2(80, 1360, 1540, 40), Rect2(1580, 80, 40, 720), Rect2(1580, 1000, 40, 400)]:
		_rect_prop("wall", rect, "687580")
	for rect in [Rect2(2960, 460, 800, 40), Rect2(2960, 1320, 800, 40), Rect2(3720, 460, 40, 900), Rect2(2960, 460, 40, 360), Rect2(2960, 1000, 40, 360)]:
		_rect_prop("ruin", rect, "626a73")
	for rect in [Rect2(2040, 780, 120, 260), Rect2(2440, 450, 180, 100), Rect2(2660, 1230, 130, 140), Rect2(3200, 570, 70, 100), Rect2(3500, 1160, 70, 100)]:
		_rect_prop("rock", rect, "6b7377")
	for point in [Vector2(230, 310), Vector2(1350, 350), Vector2(1380, 1170), Vector2(1850, 530), Vector2(1940, 660), Vector2(2280, 600), Vector2(2330, 1180), Vector2(1770, 1240), Vector2(2850, 650), Vector2(2810, 1130), Vector2(1900, 1450), Vector2(2500, 1510), Vector2(2860, 380), Vector2(2240, 310)]:
		props.append({"kind": "tree", "pos": point, "radius": 17.0})
		solids.append({"circle": point, "radius": 17.0})
	interactions.append({"id": "gate", "name": "성문 · 성벽 밖 탐험로", "pos": Vector2(1595, 900)})
	interactions.append({"id": "checkpoint", "name": "여행자 휴식석", "pos": CHECKPOINT})
	interactions.append({"id": "arena", "name": "폐허의 수호 기사 · 도전", "pos": Vector2(2910, 910)})
	interactions.append({"id": "rumor", "name": "대륙에 관한 임시 문헌", "pos": Vector2(1000, 620)})
	interactions.append({"id":"north_gate","name":"북문 · 이끼 들판","pos":Vector2(790,105)})
	for point in [Vector2(230,-160),Vector2(540,-420),Vector2(870,-650),Vector2(1180,-180),Vector2(1460,-520),Vector2(1900,-400),Vector2(2600,-700),Vector2(3300,-200)]:
		props.append({"kind":"tree","pos":point,"radius":17.0});solids.append({"circle":point,"radius":17.0})
	_rect_prop("rock",Rect2(300,-540,85,65),"6b7377")
	_rect_prop("rock",Rect2(1200,-730,110,70),"6b7377")
	_index_solids()

func _building(id: String, title: String, rect: Rect2, door: Vector2, color: String) -> void:
	props.append({"kind": "building", "rect": rect, "name": title, "color": Color(color), "pos": Vector2(rect.get_center().x, rect.end.y)})
	# Top-down footprint is the collision; the marked threshold is outside it.
	solids.append({"rect": rect})
	interactions.append({"id": id, "name": title, "pos": door})

func _rect_prop(kind: String, rect: Rect2, color: String) -> void:
	props.append({"kind": kind, "rect": rect, "pos": Vector2(rect.get_center().x, rect.end.y), "color": Color(color)})
	solids.append({"rect": rect})

func _index_solids() -> void:
	for index in solids.size():
		var shape: Dictionary = solids[index]
		var bounds: Rect2 = shape.get("rect", Rect2(shape.get("circle", Vector2.ZERO) - Vector2.ONE * 17, Vector2.ONE * 34))
		bounds = bounds.grow(64)
		for y in range(floori(bounds.position.y / 128), floori(bounds.end.y / 128) + 1):
			for x in range(floori(bounds.position.x / 128), floori(bounds.end.x / 128) + 1):
				var cell := Vector2i(x, y)
				if not _buckets.has(cell): _buckets[cell] = []
				_buckets[cell].append(index)

func blocked(point: Vector2, radius: float) -> bool:
	if not BOUNDS.grow(-radius).has_point(point): return true
	# Actor radii in this prototype are <= 32. Larger editor queries still work.
	var indices: Array = _buckets.get(Vector2i(floori(point.x / 128), floori(point.y / 128)), []) if radius <= 64 else range(solids.size())
	for index in indices:
		var shape: Dictionary = solids[index]
		if shape.has("rect"):
			var rect: Rect2 = shape["rect"]
			var nearest := point.clamp(rect.position, rect.end)
			if point.distance_to(nearest) <= radius: return true
		elif point.distance_to(shape["circle"]) <= radius + float(shape["radius"]): return true
	return false

func nearest(point: Vector2, distance := 80.0) -> Dictionary:
	var found: Dictionary = {}
	for entry in interactions:
		var length := point.distance_to(entry["pos"])
		if length < distance: distance = length; found = entry
	return found

func region(point: Vector2) -> String:
	if point.y<80:return "NORTH"
	if point.x < 1620: return "TOWN"
	if point.x < 2960: return "WILDS"
	return "RUINS"
