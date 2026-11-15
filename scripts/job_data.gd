extends RefCounted
## Loads a job file. Everything themed (text, file names, answer, target, replies)
## lives in the JSON, never in code.

const REQUIRED := [
	"title", "client", "folder", "email", "notes_file", "notes", "pictures",
	"picture_dir", "answer", "target", "replies", "shell", "ui", "end",
]


static func load_job(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("job file %s is not valid JSON" % path)
		return {}
	for key in REQUIRED:
		if not data.has(key):
			push_error("job file %s is missing '%s'" % [path, key])
	return data


static func picture_info(job: Dictionary, file: String) -> Dictionary:
	for p in job.pictures:
		if p.file == file:
			return p
	return {}


static func picture_index(job: Dictionary, file: String) -> int:
	for i in job.pictures.size():
		if job.pictures[i].file == file:
			return i
	return 0


static func picture_texture(job: Dictionary, file: String) -> Texture2D:
	return UIRef.find([job.picture_dir + file])


const UIRef = preload("res://scripts/ui.gd")
