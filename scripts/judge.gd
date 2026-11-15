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
	if top.tracing and top.z > under.z and lined_up:
		return "right"
	return "wrong_shape"


static func _join(record: Dictionary, job: Dictionary) -> String:
	var want: Array = job.join.order.map(func(f): return path_of(job, f))
	for f in want:
		if find(record, job, f) == null:
			return "wrong_file"
	var got: Array = record.get("order", [])
	return "right" if got == want else "wrong_shape"
