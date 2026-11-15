extends RefCounted

const PATH := "user://save.json"
const VERSION := 1


static func write(data: Dictionary, path := PATH) -> void:
	data.v = VERSION
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


static func read(path := PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY or int(data.get("v", 0)) != VERSION:
		return {}
	return data


static func clear(path := PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
