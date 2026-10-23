extends RefCounted
## Versionless v0 -> v1, preserving unknown fields and original bytes in a backup.
## Invalid/future saves are read-only: never silently replace a character.

const SCHEMA_VERSION := 6

static func load_file(path: String,free_attributes:=true) -> Dictionary:
	if not FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak") or FileAccess.file_exists(path + ".tmp"):
			return {"state": "error", "message": "저장 중단 흔적이 있습니다. 백업을 보존합니다."}
		return {"state": "missing"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"state": "error", "message": "저장 파일을 읽을 수 없습니다."}
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	if error != OK or not parser.data is Dictionary:
		return {"state": "error", "message": "저장 JSON이 손상되었습니다. 원본을 보존합니다."}
	var data: Dictionary = parser.data
	var version = data.get("schema_version", 0)
	if not (version is int or version is float) or version != int(version) or version < 0 or version > SCHEMA_VERSION:
		return {"state": "error", "message": "지원하지 않는 저장 버전입니다. 원본을 보존합니다."}
	if not valid_fusion_access(data): return {"state": "error", "message": "주속성이 빠졌거나 연구하지 않은 융합 기록입니다. 원본을 보존합니다."}
	var needs_loadout:bool=free_attributes and data.get("research",{}) is Dictionary and not data.get("research",{}).has("attribute_loadout_version")
	var upgraded:=preload("res://scripts/save_upgrade.gd").document(data,free_attributes) if version<SCHEMA_VERSION or needs_loadout else data
	if needs_loadout and not upgraded.get("research",{}).has("attribute_loadout_version"):return {"state":"error","message":"기존 속성 기록이 모순됩니다. 원본을 보존합니다."}
	if not valid_resources(upgraded):return {"state":"error","message":"마나·정신력 저장 정보가 잘못되었습니다. 원본을 보존합니다."}
	return {"state": "loaded", "data": upgraded, "version": int(version), "migrate": int(version) < SCHEMA_VERSION or needs_loadout}

static func backup_legacy(path: String, version := 0) -> Error:
	var backup := path + ".v%d.bak" % version
	if FileAccess.file_exists(backup): return OK
	return DirAccess.copy_absolute(path, backup)

static func write_file(path: String, data: Dictionary) -> Error:
	# A second authority check at the persistence boundary prevents aux-only fusion.
	if not valid_fusion_access(data) or not valid_resources(data): return ERR_INVALID_DATA
	# Stage and flush before moving the old file. Keep .bak for recovery.
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return error
	var backup := path + ".bak"
	var had_original := FileAccess.file_exists(path)
	if had_original:
		if FileAccess.file_exists(backup):
			error = DirAccess.remove_absolute(backup)
			if error != OK: return error
		error = DirAccess.rename_absolute(path, backup)
		if error != OK: return error
	error = DirAccess.rename_absolute(temporary, path)
	if error != OK and had_original:
		DirAccess.rename_absolute(backup, path)
	return error

static func valid_fusion_access(data: Dictionary) -> bool:
	var research = data.get("research", {})
	var book = data.get("spell_discoveries", {})
	if not research is Dictionary or not book is Dictionary or not book.get("spells", {}) is Dictionary: return false
	if research.has("attribute_loadout_version"):
		var loadout=preload("res://scripts/attribute_loadout.gd")
		if not loadout.valid(research):return false
		if not research.get("binding_studies",[]) is Array:return false
		for pair in research.get("binding_studies",[]):
			if not pair is String or pair not in preload("res://scripts/fusion_rules.gd").PHENOMENA or not loadout.owns_pair(Array(pair.split("+")),research.awakened_attributes):return false
		for id in book.spells:
			var entry=book.spells[id]
			if not entry is Dictionary or not entry.get("base_elements",[]) is Array:return false
			var lineage:Array=entry.get("base_elements",[])
			var fusion=preload("res://scripts/fusion_rules.gd")
			if fusion.SPELL_LINEAGES.has(id) and fusion.pair(lineage)!=fusion.pair(fusion.SPELL_LINEAGES[id]):return false
			if lineage.size()>1 and not loadout.owns_pair(lineage,research.awakened_attributes):return false
		return true
	if not research.get("inactive_attribute_history",{}) is Dictionary:return false
	var role_history:Dictionary=research.get("inactive_attribute_history",{})
	if not role_history.get("original_roles",{}) is Dictionary or not role_history.get("binding_studies",[]) is Array:return false
	if not research.get("binding_studies", []) is Array: return false
	var fusion = preload("res://scripts/fusion_rules.gd")
	for id in book.get("spells", {}):
		var entry = book["spells"][id]
		if not entry is Dictionary or not entry.get("base_elements", []) is Array: return false
		var lineage: Array = entry.get("base_elements", [])
		if fusion.SPELL_LINEAGES.has(id) and fusion.pair(lineage) != fusion.pair(fusion.SPELL_LINEAGES[id]): return false
		if lineage.size() > 1:
			var history:Dictionary=research.get("inactive_attribute_history",{})
			var historical_roles:Dictionary=history.get("original_roles",{})
			var roles=historical_roles.get("auxiliary_attributes",research.get("auxiliary_attributes",[]))
			var main=research.get("main_attribute")
			if not roles is Array or lineage.size()!=2 or main not in lineage or lineage[0]==lineage[1]:return false
			for element in lineage:
				if element not in fusion.ELEMENTS or (element!=main and element not in roles):return false
			# Preserve studies as history; awakened historical roles authorize discovery.
	return true

static func valid_resources(data:Dictionary) -> bool:
	# Optional foundation extension only: absent v6 data is never auto-populated.
	if data.has("magic_attunement") and not preload("res://scripts/magic_attunement.gd").valid(data.magic_attunement):return false
	if not preload("res://scripts/movement_research.gd").valid(data.get("research",{}).get("movement_research",{})):return false
	if not preload("res://scripts/world/inventory.gd").valid(data.get("inventory",{})):return false
	var world=data.get("world",{})
	if not world is Dictionary:return false
	if not preload("res://scripts/world/field_monsters.gd").valid(world.get("field",{})):return false
	if not world.has("vitals"):return true
	var vitals=world["vitals"]
	if not vitals is Dictionary:return false
	var mana=vitals.get("mana",0);var debt=vitals.get("mana_debt",0)
	var magic=data.get("magic",50);var injury=data.get("injury",0)
	for number in [mana,debt,magic,injury]:
		if not (number is int or number is float) or not is_finite(float(number)):return false
	var maximum:float=(45+float(magic)*1.1)*(1-.1*clampi(int(injury),0,3))
	return mana>=0 and debt>=0 and debt<=preload("res://scripts/mana_overdraw.gd").limit(maximum)+0.000001 and (debt==0 or mana==0)
