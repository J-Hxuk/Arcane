extends RefCounted
## Versionless v0 -> v1, preserving unknown fields and original bytes in a backup.
## Invalid/future saves are read-only: never silently replace a character.

const SCHEMA_VERSION := 3

static func load_file(path: String) -> Dictionary:
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
	return {"state": "loaded", "data": data, "version": int(version), "migrate": int(version) < SCHEMA_VERSION}

static func backup_legacy(path: String, version := 0) -> Error:
	var backup := path + ".v%d.bak" % version
	if FileAccess.file_exists(backup): return OK
	return DirAccess.copy_absolute(path, backup)

static func write_file(path: String, data: Dictionary) -> Error:
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
