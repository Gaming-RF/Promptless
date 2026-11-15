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
	for entry in c.get("jobs", []):
		if entry is Array:
			jobs.append(entry.map(func(p): return _load_job(c, p)))
		else:
			jobs.append(_load_job(c, entry))
	c.jobs = jobs
	return c


static func _load_job(c: Dictionary, job_path: String) -> Dictionary:
	var job := merge(c.get("defaults", {}), load_json(job_path))
	for key in REQUIRED:
		if not job.has(key):
			push_error("job %s is missing '%s'" % [job_path, key])
	return job


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


static func instantiate(job: Dictionary, avoid := "", force := "") -> Dictionary:
	var j := job.duplicate(true)
	if force != "":
		j.answer = force
	elif j.get("shuffle", false):
		var choices: Array = j.pictures.map(func(p): return p.file).filter(func(f): return f != avoid)
		if not choices.is_empty():
			j.answer = choices[randi() % choices.size()]
	var re := RegEx.new()
	re.compile("([0-9]+)[^0-9]*$")
	var m := re.search(String(j.answer).get_file())
	var n := str(m.get_string(1).to_int()) if m else ""
	for f in j.texts:
		j.texts[f] = j.texts[f].map(func(l): return String(l).replace("{answer_n}", n))
	j.email.body = String(j.email.body).replace("{answer_n}", n)
	return j


static func pick(reply, strike: int) -> String:
	if reply is Array:
		return reply[mini(strike, reply.size() - 1)]
	return reply
