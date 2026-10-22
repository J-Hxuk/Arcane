extends RefCounted
## Optional v4 extension. Unknown fields are preserved; malformed progress is protected.
const Layout = preload("res://scripts/world/world_layout.gd")
var data: Dictionary = defaults()
static func defaults() -> Dictionary:
	return {"version": 1, "region": "TOWN", "position": [780.0, 760.0], "safe": {"region": "TOWN", "position": [780.0, 760.0]}, "bosses": [], "rewards": [], "deaths": 0, "encounter": null}
static func valid_point(value: Variant) -> bool:
	if not value is Array or value.size() != 2: return false
	for number in value:
		if not (number is int or number is float) or not is_finite(float(number)): return false
	return Layout.BOUNDS.grow(-13).has_point(Vector2(value[0], value[1]))
static func region_of(point: Array) -> String:
	if point[1]<80:return "NORTH"
	return "TOWN" if point[0] < 1620 else "WILDS" if point[0] < 2960 else "RUINS"
func load_data(value: Variant) -> String:
	if not value is Dictionary: return "월드 진행 형식이 잘못되었습니다. 원본 저장을 보존합니다."
	var result := defaults(); result.merge(value.duplicate(true), true)
	if result["version"] != 1 or result["region"] not in ["TOWN", "WILDS", "RUINS","NORTH"] or not valid_point(result["position"]): return "지원하지 않는 월드 위치입니다."
	if not preload("res://scripts/world/field_monsters.gd").valid(result.get("field",{})):return "들판 기록이 손상되었습니다. 원본을 보존합니다."
	if region_of(result["position"]) != result["region"]: return "월드 지역과 위치가 일치하지 않습니다."
	var safe = result["safe"]
	if not safe is Dictionary or safe.get("region") not in ["TOWN", "WILDS"] or not valid_point(safe.get("position")): return "안전 위치가 손상되었습니다."
	if region_of(safe["position"]) != safe["region"]: return "안전 지역과 위치가 일치하지 않습니다."
	if result["encounter"] != null and result["encounter"] != "RUIN_GUARDIAN": return "지원하지 않는 진행 중 전투입니다."
	for name in ["bosses", "rewards"]:
		if not result[name] is Array: return "진행 기록이 손상되었습니다."
		var seen: Array = []
		for id in result[name]:
			if not id is String or id.is_empty() or id in seen: return "중복되거나 잘못된 진행 기록입니다."
			seen.append(id)
	var deaths = result["deaths"]
	if not (deaths is int or deaths is float) or not is_finite(float(deaths)) or deaths != int(deaths) or deaths < 0: return "사망 횟수가 잘못되었습니다."
	if result.has("vitals"):
		if not result["vitals"] is Dictionary: return "월드 자원 형식이 잘못되었습니다."
		for field in ["hp", "mana", "focus"]:
			var amount = result["vitals"].get(field)
			if not (amount is int or amount is float) or not is_finite(float(amount)) or amount<0: return "월드 자원이 잘못되었습니다."
		var debt=result["vitals"].get("mana_debt",0)
		if not (debt is int or debt is float) or not is_finite(float(debt)) or debt<0:return "정신력 회복 정보가 잘못되었습니다."
		if debt>0 and result["vitals"]["mana"]>0:return "정신력 회복 중에는 일반 마나가 먼저 증가할 수 없습니다."
	data = result
	return ""
func to_data() -> Dictionary: return data.duplicate(true)
func position_value() -> Vector2: return Vector2(data["position"][0], data["position"][1])
func safe_position() -> Vector2: return Vector2(data["safe"]["position"][0], data["safe"]["position"][1])
