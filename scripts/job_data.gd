extends RefCounted

const UIRef = preload("res://scripts/ui.gd")
const REQUIRED := [
	"client", "folder", "email", "search_word", "texts", "pictures",
	"picture_dir", "answer", "target", "replies", "shell", "ui",
]


static func load_json(path: String) -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("%s is not valid JSON" % path)
		return {}
	return data


static func load_campaign(path: String) -> Dictionary:
	var c := load_json(path)
	var jobs: Array = []
	for job_path in c.get("jobs", []):
		var job := merge(c.get("defaults", {}), load_json(job_path))
		for key in REQUIRED:
			if not job.has(key):
				push_error("job %s is missing '%s'" % [job_path, key])
		jobs.append(job)
	c.jobs = jobs
	return c


static func merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate(true)
	for k in b:
		if out.has(k) and out[k] is Dictionary and b[k] is Dictionary:
			out[k] = merge(out[k], b[k])
		else:
			out[k] = b[k]
	return out


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
