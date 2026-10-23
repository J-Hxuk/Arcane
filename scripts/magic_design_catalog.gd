extends RefCounted
## Read-only design catalog. A design match NEVER yields a SpellDefinition.
const Schools = preload("res://scripts/magic_schools.gd")
const Attunement = preload("res://scripts/magic_attunement.gd")
const PATH = "res://Arcane_Legacy_Codex_Magic_270/data/spells_270_for_codex.csv"
const TIERS = ["기초", "하급", "중급", "상급", "고위"]
const ELEMENT_LABELS = {"木":"WOOD", "火":"FIRE", "土":"EARTH", "金":"METAL", "水":"WATER", "불":"FIRE", "물":"WATER", "바람":"AIR", "땅":"EARTH"}
const REQUIRED = ["spell_id", "region", "school", "base_element", "nature_or_fusion", "tier", "name_en", "legacy_spell_id", "design_mp", "design_direct_damage", "chant_multiset", "focus_order_example", "spread_order_example", "design_approval_status", "runtime_stability_verification", "cast_activation", "current_rule_override"]

static func actions(text: String, separator := "·") -> Array:
	var result: Array = []
	for part in text.split(separator): result.append(part.strip_edges())
	return result

static func load_file(path := PATH) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"ok":false, "errors":["Design CSV unavailable: " + path], "warnings":[], "rows":[]}
	var headers := file.get_csv_line()
	if headers.is_empty(): return {"ok":false, "errors":["Missing CSV header"], "warnings":[], "rows":[]}
	headers[0] = headers[0].trim_prefix("\ufeff")
	var header_set: Dictionary = {}
	for header in headers:
		if header.is_empty() or header_set.has(header): return {"ok":false, "errors":["Duplicate/empty CSV header"], "warnings":[], "rows":[]}
		header_set[header] = true
	for name in REQUIRED:
		if name not in headers: return {"ok":false, "errors":["Missing CSV column: " + name], "warnings":[], "rows":[]}
	var rows: Array = []
	while not file.eof_reached():
		var cells := file.get_csv_line()
		if cells.size() == 1 and cells[0].is_empty(): continue
		if cells.size() != headers.size(): return {"ok":false, "errors":["CSV column count at row " + str(rows.size()+2)], "warnings":[], "rows":[]}
		var row: Dictionary = {}
		for index in headers.size(): row[headers[index]] = cells[index]
		rows.append(row)
	return validate(rows)

static func validate(rows: Array) -> Dictionary:
	var errors: Array = Array(Schools.validate()); var warnings: Array = []
	var by_id: Dictionary = {}; var by_identity: Dictionary = {}; var legacy: Dictionary = {}
	var counts: Dictionary = {}; var tiers: Dictionary = {}; var normalized: Array = []
	for source in rows:
		if not source is Dictionary: errors.append("Invalid design row"); continue
		var complete := true
		for field in REQUIRED:
			if not source.get(field) is String: complete = false
		if not complete: errors.append("Missing/invalid row fields"); continue
		var row: Dictionary = source.duplicate(true)
		var school := Schools.by_name(row.region, row.school)
		if school.is_empty(): errors.append("Unknown school for " + row.spell_id); continue
		row["school_id"] = school.id
		row["actions"] = actions(row.chant_multiset)
		row["runtime_implemented"] = false
		var key := Schools.identity_key(school.id, row.actions)
		if key.is_empty(): errors.append("Invalid 1..5 operator multiset: " + row.spell_id)
		if row.spell_id.is_empty() or by_id.has(row.spell_id): errors.append("Duplicate/empty spell ID: " + row.spell_id)
		if by_identity.has(key): errors.append("Identity collision: " + row.spell_id)
		var labels := actions(row.base_element, "+"); var elements: Array = []
		for label in labels: elements.append(ELEMENT_LABELS.get(label, ""))
		elements.sort(); var expected: Array = school.elements.duplicate(); expected.sort()
		if elements != expected: errors.append("Element lineage mismatch: " + row.spell_id)
		var nature: String = "陽" if school.nature == "YANG" else "陰" if school.nature == "YIN" else ""
		if school.world_system == "EAST":
			if row.nature_or_fusion != nature: errors.append("Nature mismatch: " + row.spell_id)
		elif row.nature_or_fusion != ("융합" if expected.size()==2 else "기본"):
			errors.append("Western kind mismatch: " + row.spell_id)
		if school.world_system == "WEST" and expected.size()==2 and "BIND" not in row.actions: errors.append("Fusion requires BIND: " + row.spell_id)
		if school.world_system == "EAST" and "BIND" in row.actions: errors.append("Eastern dual-element fusion is not supported: " + row.spell_id)
		for field in ["focus_order_example", "spread_order_example"]:
			if Schools.identity_key(school.id, actions(row[field], "→")) != key: errors.append("Example multiset mismatch: " + row.spell_id)
		for field in ["design_mp", "design_direct_damage"]:
			var value: String = row[field]
			if not value.is_valid_float() or not is_finite(value.to_float()) or value.to_float()<0: errors.append("Invalid design number: " + row.spell_id)
		if row.tier not in TIERS: errors.append("Unknown tier: " + row.spell_id)
		counts[school.id] = int(counts.get(school.id, 0))+1
		var tier_key: String = school.id + ":" + row.tier
		tiers[tier_key] = int(tiers.get(tier_key, 0))+1
		if row.legacy_spell_id.begins_with("OH-"):
			if legacy.has(row.legacy_spell_id): errors.append("Duplicate legacy OH alias: " + row.legacy_spell_id)
			legacy[row.legacy_spell_id] = row.spell_id
		elif row.legacy_spell_id not in ["", "—"]: errors.append("Unknown legacy alias: " + row.spell_id)
		if row.school == "모래": warnings.append(row.spell_id + ": 구형 스택/그로기 문구 대신 최신 피해량 비례 마모 규칙 우선; 전투 미구현")
		if "키다운" in row.cast_activation: warnings.append(row.spell_id + ": HOLD 수치 및 적중 정책 미확정; 전투 미구현")
		by_id[row.spell_id] = row
		by_identity[key] = row.spell_id
		normalized.append(row)
	if rows.size() != 270: errors.append("Expected 270 design rows")
	for school in Schools.all():
		var per_tier := 2 if school.world_system == "WEST" and school.elements.size()==2 else 3
		if counts.get(school.id, 0) != per_tier*5: errors.append("Missing school rows: " + school.id)
		for tier in TIERS:
			if tiers.get(school.id+":"+tier, 0) != per_tier: errors.append("Missing tier rows: " + school.id+":"+tier)
	for index in range(1,76):
		if not legacy.has("OH-%03d" % index): errors.append("Missing legacy OH alias: OH-%03d" % index)
	return {"ok":errors.is_empty(), "errors":errors, "warnings":warnings, "rows":normalized, "by_id":by_id, "by_identity":by_identity, "legacy_ids":legacy, "school_counts":counts}

static func identify(catalog: Dictionary, school_id: String, sequence: Array, context: Dictionary) -> Dictionary:
	if not catalog.get("ok", false): return {"state":"invalid_catalog", "castable":false}
	if not Attunement.context_valid(context) or context.magic_school_id != school_id: return {"state":"locked", "castable":false}
	var key := Schools.identity_key(school_id, sequence)
	if key.is_empty(): return {"state":"invalid_input", "castable":false}
	var id: String = catalog.by_identity.get(key, "")
	return {"state":"design_only" if not id.is_empty() else "unregistered", "identity":id, "castable":false, "message":"기획 식별만 지원 · 신규 계열 물성/전투 미구현"}
