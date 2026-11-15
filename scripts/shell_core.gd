extends RefCounted

const VFS = preload("res://scripts/vfs.gd")
const COMMANDS := ["cd", "chmod", "cp", "grep", "kill", "ls", "man", "open", "sort", "su", "sudo", "unzip"]
const COURTESY := ["alias", "cat", "clear", "echo", "exit", "head", "help", "history", "less", "mv", "ps", "pwd", "whoami", "write"]
var job: Dictionary
var fs
var cwd := "/"
var history: Array = []
var pending := {}
var user_stack: Array = []
var _token_re := RegEx.new()


func _init(j: Dictionary) -> void:
	job = j
	fs = VFS.new(job)
	cwd = job.folder
	_token_re.compile("\"([^\"]*)\"|'([^']*)'|(\\S+)")


func add_job(j: Dictionary) -> void:
	fs.add_job(j)


func files() -> Array:
	return fs.children(cwd)


func new_result() -> Dictionary:
	return {"out": [], "hint": [], "open": "", "clear": false, "kill": 0, "launch": {}, "ask": "", "ran": {}, "write": {}}


func prompt() -> String:
	if fs.user == "root":
		return "#"
	if fs.user == fs.home.get_file():
		return job.shell.prompt
	return "%s%s" % [fs.user, job.shell.prompt]


func users() -> Dictionary:
	return job.get("users", {})


func tokenize_marked(line: String) -> Array:
	var out: Array = []
	for m in _token_re.search_all(line):
		for g in [1, 2, 3]:
			if m.get_start(g) != -1:
				out.append({"text": m.get_string(g), "quoted": g != 3})
				break
	return out


func expand(tokens: Array) -> Array:
	var out: Array = []
	for t in tokens:
		var text: String = t.text
		if t.quoted or not ("*" in text or "?" in text):
			out.append(text)
			continue
		var slash := text.rfind("/")
		var dir_part := text.substr(0, slash + 1)
		var pattern := text.substr(slash + 1)
		var dir: String = fs.absolute(cwd, dir_part) if dir_part != "" else cwd
		var hits: Array = []
		if fs.is_dir(dir) and fs.can_read(dir):
			for n in fs.children(dir, pattern.begins_with(".")):
				if n.match(pattern):
					hits.append(dir_part + n)
		if hits.is_empty():
			out.append(text)
		else:
			out.append_array(hits)
	return out


func complete(line: String) -> Dictionary:
	var cut := line.rfind(" ")
	var head := line.substr(0, cut + 1)
	var word := line.substr(cut + 1)
	var dir_part := ""
	var partial := word
	var pool: Array
	if cut == -1:
		pool = COMMANDS + COURTESY
	else:
		var slash := word.rfind("/")
		if slash != -1:
			dir_part = word.substr(0, slash + 1)
			partial = word.substr(slash + 1)
		var dir: String = fs.absolute(cwd, dir_part) if dir_part != "" else cwd
		pool = fs.children(dir, partial.begins_with("."))
		pool = pool.map(func(n): return n + "/" if fs.is_dir(fs.absolute(dir, n)) else n)
	var matches: Array = pool.filter(func(n): return n.begins_with(partial))
	if matches.is_empty():
		return {"line": line, "options": []}
	if matches.size() == 1:
		var m: String = matches[0]
		return {"line": head + dir_part + m + ("" if m.ends_with("/") else " "), "options": []}
	var prefix: String = matches[0]
	for m in matches:
		while not m.begins_with(prefix):
			prefix = prefix.left(-1)
	return {"line": head + dir_part + prefix, "options": matches if prefix == partial else []}


func tokenize(line: String) -> Array:
	var out: Array = []
	for m in _token_re.search_all(line):
		for g in [1, 2, 3]:
			if m.get_start(g) != -1:
				out.append(m.get_string(g))
				break
	return out


func resolve(name: String) -> String:
	var path: String = fs.absolute(cwd, name)
	return path if fs.exists(path) else ""


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


func _dispatch(_cmd: String, _args: Array, _res: Dictionary, _programs: Array) -> void:
	pass
