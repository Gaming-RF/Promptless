extends RefCounted


static func answer_path(job: Dictionary) -> String:
	var a: String = job.answer
	return a if a.begins_with("/") else job.folder + "/" + a


static func verdict(record, job: Dictionary) -> String:
	if record == null or record.get("windows", []).is_empty():
		return "no_attachment"
	var t: Dictionary = job.target
	var want := answer_path(job)
	for w in record.windows:
		if w.file != want and w.file != job.answer:
			continue
		if absf(w.w - t.w) <= t.tolerance and absf(w.h - t.h) <= t.tolerance:
			return "right"
		if absf(w.w - w.h) <= t.tolerance:
			return "wrong_size"
		return "wrong_shape"
	return "wrong_file"
