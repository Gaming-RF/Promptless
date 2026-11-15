extends RefCounted

const COMMANDS := ["grep", "ls", "open"]
const COURTESY := ["alias", "cat", "clear", "echo", "head", "help", "history", "less", "mv", "ps", "pwd"]

var job: Dictionary
var history: Array = []
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


func run(line: String, programs: Array = []) -> Dictionary:
	var res := {"out": [], "hint": [], "open": "", "clear": false}
	line = line.strip_edges()
	if line.is_empty():
		return res
	history.append(line)
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
		"help":
			res.out.append_array(job.shell.help)
		"clear":
			res.clear = true
		"pwd":
			res.out.append(job.folder)
		"echo":
			res.out.append(" ".join(args))
		"history":
			for i in history.size():
				res.out.append("%4d  %s" % [i + 1, history[i]])
		"alias":
			res.out.append_array(job.shell.alias)
		"ps":
			res.out.append("  PID CMD")
			for p in programs:
				res.out.append("%5d %s" % [p.pid, p.cmd])
		"cat", "less":
			_print_text(cmd, args, res, -1)
		"head":
			var n := 10
			if args.size() >= 2 and args[0] == "-n":
				n = String(args[1]).to_int()
				args = args.slice(2)
			elif not args.is_empty() and args[0].begins_with("-") and args[0].substr(1).is_valid_int():
				n = args.pop_front().substr(1).to_int()
			_print_text(cmd, args, res, n)
		"mv":
			if args.size() < 2:
				res.out.append(job.shell.mv_usage)
			elif resolve(args[0]) == "":
				_missing("mv", args[0], res)
			else:
				res.out.append(job.shell.mv_readonly.format({"file": args[0]}))
		_:
			var s := closest(cmd, COMMANDS + COURTESY, 2)
			if s != "":
				res.out.append(job.shell.did_you_mean_cmd.format({"cmd": cmd, "s": s}))
			else:
				res.out.append(job.shell.unknown.format({"cmd": cmd}))
	return res


func complete(line: String) -> Dictionary:
	var cut := line.rfind(" ")
	var head := line.substr(0, cut + 1)
	var word := line.substr(cut + 1)
	var pool: Array = (COMMANDS + COURTESY) if cut == -1 else files()
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


func resolve(name: String) -> String:
	if name.begins_with("./"):
		name = name.substr(2)
	elif name.begins_with(job.folder + "/"):
		name = name.substr(job.folder.length() + 1)
	return name if name in files() else ""


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
	var d: Array = []
	for i in a.length() + 1:
		var row: Array = []
		row.resize(b.length() + 1)
		row[0] = i
		d.append(row)
	for j in b.length() + 1:
		d[0][j] = j
	for i in range(1, a.length() + 1):
		for j in range(1, b.length() + 1):
			var cost := int(a[i - 1] != b[j - 1])
			d[i][j] = mini(mini(d[i - 1][j] + 1, d[i][j - 1] + 1), d[i - 1][j - 1] + cost)
			if i > 1 and j > 1 and a[i - 1] == b[j - 2] and a[i - 2] == b[j - 1]:
				d[i][j] = mini(d[i][j], d[i - 2][j - 2] + 1)
	return d[a.length()][b.length()]


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
			continue
		for l in job.texts[name]:
			var hit: bool = l.to_lower().contains(word.to_lower()) if ignore_case else l.contains(word)
			if hit:
				res.out.append(("%s:%s" % [name, l]) if targets.size() > 1 else l)
				matched = true
	if not matched and not missing:
		res.hint.append(job.shell.grep_no_match)


func _print_text(cmd: String, args: Array, res: Dictionary, limit: int) -> void:
	if args.is_empty():
		res.out.append(job.shell.read_usage.format({"cmd": cmd}))
		return
	var name := resolve(args[0])
	if name == "":
		_missing(cmd, args[0], res)
	elif not job.texts.has(name):
		res.out.append(job.shell.cat_picture.format({"cmd": cmd, "file": name}))
	else:
		var lines: Array = job.texts[name]
		res.out.append_array(lines if limit < 0 else lines.slice(0, limit))


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
