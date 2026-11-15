extends RefCounted
## The pretend shell. Reads one typed line and returns what to print.
## It never touches windows: it returns {"open": file} and the desktop does the rest.

const COMMANDS := ["grep", "ls", "open"]

var job: Dictionary
var _token_re := RegEx.new()


func _init(j: Dictionary) -> void:
	job = j
	_token_re.compile("\"([^\"]*)\"|'([^']*)'|(\\S+)")


func files() -> Array:
	var names: Array = job.texts.keys()
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
			var s := closest(cmd, COMMANDS, 2)
			if s != "":
				res.out.append(job.shell.did_you_mean_cmd.format({"cmd": cmd, "s": s}))
			else:
				res.out.append(job.shell.unknown.format({"cmd": cmd}))
	return res


## Tab completion: completes the command, then file names. Returns
## {"line": completed text, "options": [names to list when ambiguous]}.
func complete(line: String) -> Dictionary:
	var cut := line.rfind(" ")
	var head := line.substr(0, cut + 1)
	var word := line.substr(cut + 1)
	var pool: Array = COMMANDS if cut == -1 else files()
	var matches: Array = pool.filter(func(n): return n.begins_with(word))
	if matches.is_empty():
		return {"line": line, "options": []}
	if matches.size() == 1:
		return {"line": head + matches[0] + " ", "options": []}
	var prefix: String = matches[0]
	for m in matches:
		while not m.begins_with(prefix):
			prefix = prefix.left(-1)
	return {"line": head + prefix, "options": matches if prefix == word else []}


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


## Best file for a mistyped name; "ball 3" (typed as two words) -> "ball_3.png".
func suggest_file(typed: String) -> String:
	var norm := typed.strip_edges().replace(" ", "_").to_lower()
	for f in files():
		if f.to_lower() == norm or f.get_basename().to_lower() == norm:
			return f
	var bases: Array = files().map(func(f): return f.get_basename())
	var s := closest(norm, files(), 3)
	if s == "":
		var b := closest(norm, bases, 2)
		if b != "":
			s = files()[bases.find(b)]
	return s


static func closest(word: String, pool: Array, max_dist: int) -> String:
	var best := ""
	var best_d := max_dist + 1
	for p in pool:
		var d := distance(word.to_lower(), p.to_lower())
		if d < best_d:
			best = p
			best_d = d
	return best


static func distance(a: String, b: String) -> int:
	var prev: Array = range(b.length() + 1)
	for i in a.length():
		var cur: Array = [i + 1]
		for j in b.length():
			cur.append(mini(mini(cur[j] + 1, prev[j + 1] + 1), prev[j] + int(a[i] != b[j])))
		prev = cur
	return prev[b.length()]


func _missing(cmd: String, typed: String, res: Dictionary, whole := "") -> void:
	res.out.append("%s: %s: No such file or directory" % [cmd, typed])
	var s := suggest_file(whole if whole != "" else typed)
	if s != "":
		res.hint.append(job.shell.did_you_mean_file.format({"s": s}))


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
			_missing("grep", f, res)
			missing = true
			continue
		if not job.texts.has(name):
			continue # pictures hold no text lines
		for l in job.texts[name]:
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
		_missing("open", args[0], res, " ".join(args))
	elif job.texts.has(name):
		res.out.append(job.shell.open_text.format({"n": job.texts[name].size()}))
	else:
		res.open = name
