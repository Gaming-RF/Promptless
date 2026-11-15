extends RefCounted

const VFS = preload("res://scripts/vfs.gd")
const COMMANDS := ["cd", "chmod", "cp", "grep", "kill", "ls", "man", "open"]
const COURTESY := ["alias", "cat", "clear", "echo", "head", "help", "history", "less", "mv", "ps", "pwd"]

var job: Dictionary
var fs
var cwd := "/"
var history: Array = []
var _token_re := RegEx.new()


func _init(j: Dictionary) -> void:
	job = j
	fs = VFS.new(job)
	cwd = job.folder
	_token_re.compile("\"([^\"]*)\"|'([^']*)'|(\\S+)")


func files() -> Array:
	return fs.children(cwd)


func run(line: String, programs: Array = []) -> Dictionary:
	var res := {"out": [], "hint": [], "open": "", "clear": false, "kill": 0, "launch": {}}
	line = line.strip_edges()
	if line.is_empty():
		return res
	history.append(line)
	if "|" in line or ">" in line:
		res.out.append(job.shell.pipes)
		return res
	var args := tokenize(line)
	var cmd: String = args.pop_front()
	if "/" in cmd:
		_exec(cmd, res)
		return res
	match cmd:
		"cp":
			_cp(args, res)
		"chmod":
			_chmod(args, res)
		"kill":
			_kill(args, res, programs)
		"ls":
			_ls(args, res)
		"cd":
			_cd(args, res)
		"man":
			_man(args, res)
		"grep":
			_grep(args, res)
		"open":
			_open(args, res)
		"help":
			res.out.append_array(job.shell.help)
		"clear":
			res.clear = true
		"pwd":
			res.out.append(cwd)
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
			_mv(args, res)
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


func _ls(args: Array, res: Dictionary) -> void:
	var show_hidden := false
	var long := false
	var targets: Array = []
	for a in args:
		if a.begins_with("-"):
			show_hidden = show_hidden or "a" in a
			long = long or "l" in a
		else:
			targets.append(a)
	if targets.is_empty():
		targets = ["."]
	for t in targets:
		var path := resolve(t)
		if path == "":
			res.out.append("ls: cannot access '%s': No such file or directory" % t)
		elif not fs.is_dir(path):
			res.out.append(t)
		else:
			if targets.size() > 1:
				res.out.append(t + ":")
			var names: Array = fs.children(path, show_hidden)
			if show_hidden:
				names = [".", ".."] + names
			if long:
				for n in names:
					var p: String = fs.absolute(path, n)
					res.out.append("%s %-6s %s" % [fs.mode_string(p), fs.owner(p), n])
			elif not names.is_empty():
				res.out.append("  ".join(names))


func _cd(args: Array, res: Dictionary) -> void:
	var target: String = "~" if args.is_empty() else args[0]
	var path := resolve(target)
	if path == "":
		res.out.append("cd: %s: No such file or directory" % target)
	elif not fs.is_dir(path):
		res.out.append("cd: %s: Not a directory" % target)
	else:
		cwd = path


func _man(args: Array, res: Dictionary) -> void:
	if args.is_empty():
		res.out.append(job.shell.man_usage)
		return
	var pages: Dictionary = job.shell.get("man", {})
	if pages.has(args[0]):
		res.out.append_array(pages[args[0]])
	else:
		res.out.append("No manual entry for %s" % args[0])


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
		var path := resolve(f)
		if path == "":
			_missing("grep", f, res)
			missing = true
			continue
		var n: Dictionary = fs.node(path)
		if n.type == "dir":
			res.out.append("grep: %s: Is a directory" % f)
			missing = true
			continue
		if not fs.can_read(path):
			res.out.append("grep: %s: Permission denied" % f)
			missing = true
			continue
		if n.type != "text":
			continue
		for l in n.lines:
			var hit: bool = l.to_lower().contains(word.to_lower()) if ignore_case else l.contains(word)
			if hit:
				res.out.append(("%s:%s" % [f, l]) if targets.size() > 1 else l)
				matched = true
	if not matched and not missing:
		res.hint.append(job.shell.grep_no_match)


func _print_text(cmd: String, args: Array, res: Dictionary, limit: int) -> void:
	if args.is_empty():
		res.out.append(job.shell.read_usage.format({"cmd": cmd}))
		return
	var path := resolve(args[0])
	if path == "":
		_missing(cmd, args[0], res)
		return
	var n: Dictionary = fs.node(path)
	if n.type == "dir":
		res.out.append("%s: %s: Is a directory" % [cmd, args[0]])
	elif not fs.can_read(path):
		res.out.append("%s: %s: Permission denied" % [cmd, args[0]])
	elif n.type != "text":
		res.out.append(job.shell.cat_picture.format({"cmd": cmd, "file": args[0]}))
	else:
		res.out.append_array(n.lines if limit < 0 else n.lines.slice(0, limit))


func _open(args: Array, res: Dictionary) -> void:
	if args.is_empty():
		res.out.append(job.shell.open_usage)
		return
	var path := resolve(args[0])
	if path == "":
		_missing("open", args[0], res, " ".join(args))
		return
	var n: Dictionary = fs.node(path)
	if n.type == "dir":
		res.out.append("open: %s: Is a directory" % args[0])
	elif not fs.can_read(path):
		res.out.append("open: %s: Permission denied" % args[0])
	elif n.type == "script":
		res.out.append(job.shell.open_script.format({"file": args[0]}))
	elif n.type == "text":
		res.out.append(job.shell.open_text.format({"n": n.lines.size()}))
	else:
		res.open = path


func _mv(args: Array, res: Dictionary) -> void:
	if args.size() < 2:
		res.out.append(job.shell.mv_usage)
		return
	var src := resolve(args[0])
	if src == "":
		_missing("mv", args[0], res)
		return
	var dest: String = fs.absolute(cwd, args[1])
	if fs.is_dir(dest):
		dest = dest + "/" + src.get_file()
	if not fs.writable(src) or not fs.writable(dest.get_base_dir()):
		res.out.append(job.shell.mv_readonly.format({"file": args[0]}))
		return
	if not fs.is_dir(dest.get_base_dir()):
		res.out.append("mv: cannot move '%s': No such file or directory" % args[0])
		return
	if dest == src or dest.begins_with(src + "/"):
		res.out.append("mv: cannot move '%s' into itself" % args[0])
		return
	fs.move(src, dest)


func _cp(args: Array, res: Dictionary) -> void:
	if args.size() < 2:
		res.out.append(job.shell.cp_usage)
		return
	var src := resolve(args[0])
	if src == "":
		_missing("cp", args[0], res)
		return
	if fs.is_dir(src):
		res.out.append("cp: -r not specified; omitting directory '%s'" % args[0])
		return
	if not fs.can_read(src):
		res.out.append("cp: cannot open '%s' for reading: Permission denied" % args[0])
		return
	var dest: String = fs.absolute(cwd, args[1])
	if fs.is_dir(dest):
		dest = dest + "/" + src.get_file()
	if not fs.is_dir(dest.get_base_dir()):
		res.out.append("cp: cannot create '%s': No such file or directory" % args[1])
	elif not fs.writable(dest.get_base_dir()):
		res.out.append("cp: cannot create '%s': Permission denied" % args[1])
	else:
		fs.add_file(dest, fs.node(src).duplicate(true))


func _chmod(args: Array, res: Dictionary) -> void:
	if args.size() < 2:
		res.out.append(job.shell.chmod_usage)
		return
	var mode: String = args[0]
	var path := resolve(args[1])
	if path == "":
		res.out.append("chmod: cannot access '%s': No such file or directory" % args[1])
		return
	var re := RegEx.new()
	re.compile("^[ugoa]*([+-])([rwx]+)$")
	var m := re.search(mode)
	var octal := mode.is_valid_int() and mode.length() == 3
	if m == null and not octal:
		res.out.append("chmod: invalid mode: '%s'" % mode)
		return
	if not fs.writable(path):
		res.out.append("chmod: changing permissions of '%s': Operation not permitted" % args[1])
		return
	var n: Dictionary = fs.node(path)
	if octal:
		var d := int(mode[0])
		n.r = d & 4 != 0
		n.x = d & 1 != 0
	else:
		var on := m.get_string(1) == "+"
		for ch in m.get_string(2):
			if ch == "r":
				n.r = on
			elif ch == "x":
				n.x = on


func _kill(args: Array, res: Dictionary, programs: Array) -> void:
	var nums := args.filter(func(a): return not a.begins_with("-"))
	if nums.is_empty():
		res.out.append(job.shell.kill_usage)
		return
	var pid := String(nums[0]).to_int()
	if not String(nums[0]).is_valid_int():
		res.out.append("kill: %s: arguments must be process numbers" % nums[0])
		return
	for p in programs:
		if p.pid == pid:
			if p.get("protected", false):
				res.out.append(job.shell.kill_protected.format({"pid": pid, "cmd": p.cmd}))
			else:
				res.kill = pid
			return
	res.out.append("kill: (%d) - No such process" % pid)


func _exec(cmd: String, res: Dictionary) -> void:
	var path := resolve(cmd)
	if path == "":
		res.out.append("sh: %s: No such file or directory" % cmd)
		return
	var n: Dictionary = fs.node(path)
	if n.type == "dir":
		res.out.append("sh: %s: Is a directory" % cmd)
	elif not fs.can_exec(path) or not fs.can_read(path):
		res.out.append("sh: %s: Permission denied" % cmd)
	elif n.type != "script":
		res.out.append("sh: %s: cannot execute binary file" % cmd)
	else:
		res.out.append_array(n.get("prints", []))
		if n.has("opens"):
			var target: String = n.opens if String(n.opens).begins_with("/") else job.folder + "/" + n.opens
			res.launch = {"path": target, "count": 1 + int(n.get("copies", 0))}
