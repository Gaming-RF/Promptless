extends RefCounted


static func path_of(job: Dictionary, f: String) -> String:
	return f if f.begins_with("/") else job.folder + "/" + f


static func answer_path(job: Dictionary) -> String:
	return path_of(job, job.answer)


static func find(record: Dictionary, job: Dictionary, f: String):
	var want := path_of(job, f)
	for w in record.windows:
		if w.file == want or w.file == f:
			return w
	return null


static func verdict(record, job: Dictionary) -> String:
	if record == null or record.get("windows", []).is_empty():
		return "no_attachment"
	match job.get("check", "stretch"):
		"ran", "remote":
			return "no_attachment"
		"overlay":
			return _overlay(record, job)
		"join":
			return _join(record, job)
	return _stretch(record, job)


static func _stretch(record: Dictionary, job: Dictionary) -> String:
	var t: Dictionary = job.target
	var w = find(record, job, job.answer)
	if w == null:
		return "wrong_file"
	if job.get("single", false) and int(w.get("copies", 1)) > 1:
		return "crowded"
	if record.windows.size() > 1:
		return "wrong_file"
	if absf(w.w - t.w) <= t.tolerance and absf(w.h - t.h) <= t.tolerance:
		return "right"
	if absf(w.w - w.h) <= t.tolerance:
		return "wrong_size"
	return "wrong_shape"


static func _overlay(record: Dictionary, job: Dictionary) -> String:
	var o: Dictionary = job.overlay
	var top = find(record, job, o.top)
	var under = find(record, job, o.under)
	if top == null or under == null:
		return "wrong_file"
	var tol: float = o.get("align", 6)
	var lined_up: bool = absf(top.x - under.x) <= tol and absf(top.y - under.y) <= tol \
		and absf(top.w - under.w) <= tol and absf(top.h - under.h) <= tol
	if lined_up and top.tracing and top.z > under.z:
		return "right"
	if lined_up and o.get("either", false) and under.tracing and under.z > top.z:
		return "right"
	return "wrong_shape"


static func _join(record: Dictionary, job: Dictionary) -> String:
	var by_name: bool = job.join.get("by_name", false)
	var want: Array = job.join.order.map(func(f): return String(f).get_file() if by_name else path_of(job, f))
	var have: Array = record.windows.map(func(w): return String(w.file).get_file() if by_name else w.file)
	for f in want:
		if not f in have:
			return "wrong_file"
	var got: Array = record.get("order", [])
	if by_name:
		got = got.map(func(f): return String(f).get_file())
	return "right" if got == want else "wrong_shape"


static func ran_ok(job: Dictionary, ran: Dictionary) -> bool:
	if job.get("check", "") != "ran" or ran.is_empty():
		return false
	var want: Dictionary = job.ran
	if ran.path != path_of(job, want.path):
		return false
	return ran.user == "root" or not want.get("root", false)


static func remote_ok(job: Dictionary, rr: Dictionary) -> bool:
	if job.get("check", "") != "remote":
		return false
	var r: Dictionary = job.remote
	var g: Dictionary = r.goal
	var base := String(r.folder) + "/"
	if g.has("opened"):
		return rr.get("open", "") == base + String(g.opened)
	if g.has("ran"):
		return rr.get("ran", {}).get("path", "") == base + String(g.ran)
	if g.has("printed"):
		return rr.get("out", []).any(func(l): return String(l).contains(String(g.printed)))
	return false
