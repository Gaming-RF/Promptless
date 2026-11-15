extends RefCounted
## The pretend shell. Reads one typed line and returns what to print.
## It never touches windows: it returns {"open": file} and the desktop does the rest.

var job: Dictionary
var _token_re := RegEx.new()


func _init(j: Dictionary) -> void:
	job = j
	_token_re.compile("\"([^\"]*)\"|'([^']*)'|(\\S+)")


func files() -> Array:
	var names: Array = [job.notes_file]
	for p in job.pictures:
		names.append(p.file)
	names.sort()
	return names


## Returns {"out": [lines], "hint": [dim lines], "open": file or ""}.
func run(line: String) -> Dictionary:
	var res := {"out": [], "hint": [], "open": ""}
	line = line.strip_edges()
	if line.is_empty():
		return res
	if "|" in line or ">" in line:
		res.out.append(job.shell.pipes)
		return res
	var args := tokenize(line)
	var cmd: String = args.pop_front()
	match cmd:
		"ls":
			res.out.append("  ".join(files()))
		"grep":
			_grep(args, res)
		"open":
			_open(args, res)
		_:
			res.out.append(job.shell.unknown.format({"cmd": cmd}))
	return res


func tokenize(line: String) -> Array:
	var out: Array = []
	for m in _token_re.search_all(line):
		for g in [1, 2, 3]:
			if m.get_start(g) != -1:
				out.append(m.get_string(g))
				break
	return out


## Accepts "notes.txt", "./notes.txt" or the full "/clients/x/notes.txt".
func resolve(name: String) -> String:
	if name.begins_with("./"):
		name = name.substr(2)
	elif name.begins_with(job.folder + "/"):
		name = name.substr(job.folder.length() + 1)
	return name if name in files() else ""


func _grep(args: Array, res: Dictionary) -> void:
	var ignore_case := false
	var rest: Array = []
	for a in args:
		if a == "-i":
			ignore_case = true
		elif not a.begins_with("-"):
			rest.append(a)
	if rest.size() < 2:
		res.out.append(job.shell.grep_usage)
		return
	var word: String = rest[0]
	var targets := rest.slice(1)
	var matched := false
	var missing := false
	for f in targets:
		var name := resolve(f)
		if name == "":
			res.out.append("grep: %s: No such file or directory" % f)
			missing = true
			continue
		if name != job.notes_file:
			continue # pictures hold no text lines
		for l in job.notes:
			var hit: bool = l.to_lower().contains(word.to_lower()) if ignore_case else l.contains(word)
			if hit:
				res.out.append(("%s:%s" % [name, l]) if targets.size() > 1 else l)
				matched = true
	if not matched and not missing:
		res.hint.append(job.shell.grep_no_match)


func _open(args: Array, res: Dictionary) -> void:
	if args.is_empty():
		res.out.append(job.shell.open_usage)
		return
	var name := resolve(args[0])
	if name == "":
		res.out.append("open: %s: No such file or directory" % args[0])
	elif name == job.notes_file:
		res.out.append(job.shell.open_notes)
	else:
		res.open = name
