extends RefCounted
## Win check. Reads the snapshot record only; nothing is measured from pixels.
## A record is {"name": "snapshot_1.png", "windows": [{"file", "w", "h"}]}
## (w/h = the picture's size inside its window, in game pixels).
## Wrong file is checked before shape: any ball can be stretched round.


static func verdict(record, job: Dictionary) -> String:
	if record == null or record.get("windows", []).is_empty():
		return "no_attachment"
	var t: Dictionary = job.target
	for w in record.windows:
		if w.file != job.answer:
			continue
		if absf(w.w - t.w) <= t.tolerance and absf(w.h - t.h) <= t.tolerance:
			return "right"
		return "wrong_shape"
	return "wrong_file"
