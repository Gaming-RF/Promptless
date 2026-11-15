extends RefCounted

const VFS = preload("res://scripts/vfs.gd")
const COMMANDS := ["cd", "chmod", "cp", "grep", "kill", "ls", "man", "open", "sort", "su", "sudo", "unzip"]
const COURTESY := ["alias", "cat", "clear", "echo", "exit", "head", "help", "history", "less", "mv", "ps", "pwd", "whoami"]

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
	return {"out": [], "hint": [], "open": "", "clear": false, "kill": 0, "launch": {}, "ask": ""}


func prompt() -> String:
	if fs.user == "root":
		return "#"
	if fs.user == fs.home.get_file():
		return job.shell.prompt
	return "%s%s" % [fs.user, job.shell.prompt]


func users() -> Dictionary:
	return job.get("users", {})


func run(line: String, programs: Array = []) -> Dictionary:
	if not pending.is_empty():
		return _answer(line, programs)
	var res := new_result()
	line = line.strip_edges()
	if line.is_empty():
		return res
	history.append(line)
	if "|" in line or ">" in line:
		res.out.append(job.shell.pipes)
		return res
	var args := tokenize(line)
	var cmd: String = args.pop_front()
	_dispatch(cmd, args, res, programs)
	return res


func _dispatch(cmd: String, args: Array, res: Dictionary, programs: Array) -> void:
	if "/" in cmd:
		_exec(cmd, res)
		return
	match cmd:
		"sort":
			_sort(args, res)
		"unzip":
			_unzip(args, res)
		"su":
			_su(args, res)
		"sudo":
			_sudo(args, res)
		"whoami":
			res.out.append(fs.user)
		"exit":
			if user_stack.is_empty():
				res.out.append(job.shell.exit_last)
			else:
				var back: Dictionary = user_stack.pop_back()
				fs.user = back.user
				cwd = back.cwd
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
		elif not fs.can_read(path):
			res.out.append("ls: cannot open directory '%s': Permission denied" % t)
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
	var path: String = fs.home_of(fs.user) if target == "~" else resolve(target)
	if path == "":
		res.out.append("cd: %s: No such file or directory" % target)
	elif not fs.is_dir(path):
		res.out.append("cd: %s: Not a directory" % target)
	elif not fs.can_read(path):
		res.out.append("cd: %s: Permission denied" % target)
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
		if "textview" in job.get("tools", []):
			res.open = path
		else:
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


func _sort(args: Array, res: Dictionary) -> void:
	var reverse := false
	var numeric := false
	var files_in: Array = []
	for a in args:
		if a.begins_with("-"):
			reverse = reverse or "r" in a
			numeric = numeric or "n" in a
		else:
			files_in.append(a)
	if files_in.is_empty():
		res.out.append(job.shell.sort_usage)
		return
	var lines: Array = []
	for f in files_in:
		var path := resolve(f)
		if path == "":
			_missing("sort", f, res)
			return
		var n: Dictionary = fs.node(path)
		if n.type != "text":
			res.out.append("sort: %s: %s" % [f, "Is a directory" if n.type == "dir" else "not a text file"])
			return
		if not fs.can_read(path):
			res.out.append("sort: cannot read: %s: Permission denied" % f)
			return
		lines.append_array(n.lines)
	if numeric:
		lines.sort_custom(func(a, b): return _lead_num(a) < _lead_num(b))
	else:
		lines.sort_custom(func(a, b): return a.nocasecmp_to(b) < 0)
	if reverse:
		lines.reverse()
	res.out.append_array(lines)


static func _lead_num(t: String) -> float:
	var re := RegEx.new()
	re.compile("^\\s*(-?[0-9]+(\\.[0-9]+)?)")
	var m := re.search(t)
	return m.get_string(1).to_float() if m else 0.0


func _unzip(args: Array, res: Dictionary) -> void:
	var src_arg := ""
	var dest_arg := ""
	var i := 0
	while i < args.size():
		if args[i] == "-d" and i + 1 < args.size():
			dest_arg = args[i + 1]
			i += 2
			continue
		if src_arg == "":
			src_arg = args[i]
		i += 1
	if src_arg == "":
		res.out.append(job.shell.unzip_usage)
		return
	var src := resolve(src_arg)
	if src == "":
		res.out.append("unzip:  cannot find or open %s" % src_arg)
		return
	var n: Dictionary = fs.node(src)
	if n.type != "archive":
		res.out.append("unzip:  %s is not a zip archive" % src_arg)
		return
	if not fs.can_read(src):
		res.out.append("unzip:  cannot find or open %s: Permission denied" % src_arg)
		return
	var dest: String = cwd if dest_arg == "" else fs.absolute(cwd, dest_arg)
	if not fs.writable(dest):
		res.out.append(job.shell.unzip_readonly.format({"dir": dest}))
		return
	res.out.append("Archive:  %s" % src_arg)
	if n.has("password"):
		var first: String = n.contents[0].path if not n.contents.is_empty() else src_arg
		pending = {"kind": "unzip", "src": src, "dest": dest}
		res.ask = job.shell.unzip_password.format({"file": src_arg, "entry": first})
		return
	_extract(src, dest, res)


func _extract(src: String, dest: String, res: Dictionary) -> void:
	fs.add_dir(dest)
	for c in fs.node(src).contents:
		var data: Dictionary = c.duplicate(true)
		var rel: String = data.path
		data.erase("path")
		var target: String = dest + "/" + rel
		if data.type == "dir":
			fs.add_dir(target)
			res.out.append("   creating: %s/" % rel)
			continue
		if data.type == "picture" and not data.has("asset"):
			data.asset = job.picture_dir + rel.get_file()
		fs.add_file(target, data)
		res.out.append("  inflating: %s" % rel)


func _su(args: Array, res: Dictionary) -> void:
	var target: String = "root" if args.is_empty() else args[args.size() - 1]
	if not users().has(target):
		res.out.append("su: user %s does not exist" % target)
		return
	pending = {"kind": "su", "target": target}
	res.ask = job.shell.su_password


func _sudo(args: Array, res: Dictionary) -> void:
	if args.is_empty():
		res.out.append(job.shell.sudo_usage)
		return
	var me: Dictionary = users().get(fs.user, {})
	if fs.user == "root":
		var inner: Array = args.duplicate()
		_dispatch(inner.pop_front(), inner, res, [])
		return
	if not me.get("sudo", false):
		res.out.append(job.shell.sudo_denied.format({"user": fs.user}))
		return
	pending = {"kind": "sudo", "args": args}
	res.ask = job.shell.sudo_password.format({"user": fs.user})


func _answer(line: String, programs: Array) -> Dictionary:
	var res := new_result()
	var p := pending
	pending = {}
	match p.kind:
		"unzip":
			if line == String(fs.node(p.src).password):
				_extract(p.src, p.dest, res)
			else:
				res.out.append(job.shell.unzip_wrong)
		"su":
			if line == String(users()[p.target].get("password", "")):
				user_stack.append({"user": fs.user, "cwd": cwd})
				fs.user = p.target
				cwd = fs.home_of(p.target)
				fs.add_dir(cwd)
			else:
				res.out.append(job.shell.su_wrong)
		"sudo":
			if line == String(users().get(fs.user, {}).get("password", "")):
				var saved: String = fs.user
				fs.user = "root"
				var inner: Array = p.args.duplicate()
				_dispatch(inner.pop_front(), inner, res, programs)
				fs.user = saved
			else:
				res.out.append(job.shell.sudo_wrong)
	return res
