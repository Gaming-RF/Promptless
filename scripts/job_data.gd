extends RefCounted

const UIRef = preload("res://scripts/ui.gd")
const REQUIRED := [
	"client", "folder", "email", "texts", "pictures",
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
	if c.has("extends"):
		var base := load_json(c.extends)
		base.erase("jobs")
		c = merge(base, c)
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
	for e in validate(job):
		push_error("job %s: %s" % [job_path, e])
	return job


const KNOWN_KEYS := [
	"client", "folder", "email", "search_word", "texts", "pictures", "picture_dir", "answer",
	"target", "replies", "shell", "ui", "home", "users", "extra_files", "tools", "check",
	"overlay", "join", "ran", "remote", "single", "strikes", "shuffle", "sticky", "timed",
	"alt", "ending",
]
const CHECKS := ["stretch", "overlay", "join", "ran", "remote"]
const TOOLS := ["trace", "join", "textview"]
const FILE_TYPES := ["dir", "text", "picture", "script", "archive"]


static func validate(job: Dictionary) -> Array:
	var errs: Array = []
	for key in REQUIRED:
		if not job.has(key):
			errs.append("missing '%s'" % key)
	for key in job:
		if not key in KNOWN_KEYS:
			errs.append("unknown key '%s'" % key)
	if not errs.is_empty():
		return errs
	if not String(job.folder).begins_with("/"):
		errs.append("folder must be an absolute path")
	for k in ["from", "subject", "body"]:
		if not job.email.has(k):
			errs.append("email.%s missing" % k)
	for f in job.texts:
		if not job.texts[f] is Array:
			errs.append("texts.%s must be a list of lines" % f)
	for p in job.pictures:
		if not (p.has("file") and p.has("open_size") and p.open_size.size() == 2):
			errs.append("picture needs file + open_size [w, h]: %s" % str(p))
	for f in job.get("extra_files", []):
		if not (f.has("path") and f.get("type", "") in FILE_TYPES):
			errs.append("extra file needs path + type (%s): %s" % [", ".join(FILE_TYPES), str(f)])
	for t in job.get("tools", []):
		if not t in TOOLS:
			errs.append("unknown tool '%s'" % t)
	var kind: String = job.get("check", "stretch")
	if not kind in CHECKS:
		errs.append("unknown check '%s'" % kind)
	var need: Array = ["right"]
	match kind:
		"stretch":
			need += ["wrong_file", "wrong_shape", "wrong_size"]
			for k in ["answer", "target"]:
				if not job.has(k):
					errs.append("stretch needs '%s'" % k)
		"overlay":
			need += ["wrong_file", "wrong_shape"]
			if not (job.has("overlay") and job.overlay.has("top") and job.overlay.has("under")):
				errs.append("overlay needs overlay.top + overlay.under")
		"join":
			need += ["wrong_file", "wrong_shape"]
			if not (job.has("join") and job.join.get("order", []).size() >= 2):
				errs.append("join needs join.order with 2+ pages")
		"ran":
			if not (job.has("ran") and job.ran.has("path")):
				errs.append("ran needs ran.path")
		"remote":
			var r: Dictionary = job.get("remote", {})
			if not (r.has("user") and r.has("folder") and r.get("goal", {}).has("opened")):
				errs.append("remote needs remote.user, remote.folder, remote.goal.opened")
	if job.get("single", false):
		need.append("crowded")
	if job.has("strikes"):
		need.append("give_up")
	for k in need:
		if not job.replies.has(k):
			errs.append("replies.%s missing" % k)
	if job.get("shuffle", false):
		var uses := false
		for f in job.texts:
			for l in job.texts[f]:
				uses = uses or "{answer_n}" in l
		if not uses:
			errs.append("shuffle is on but no text uses {answer_n}")
	return errs


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
