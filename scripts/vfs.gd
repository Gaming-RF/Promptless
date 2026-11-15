extends RefCounted

var nodes := {}
var home := "/home/you"
var client_user := "client"
var user := "you"
var homes := {}


func _init(job: Dictionary) -> void:
	home = job.get("home", home)
	user = home.get_file()
	homes[user] = home
	client_user = String(job.client.get("user", job.client.name)).to_lower()
	add_dir("/")
	add_dir(home)
	add_job(job)


func add_job(job: Dictionary) -> void:
	for u in job.get("users", {}):
		if u != user and not homes.has(u):
			homes[u] = job.users[u].get("home", "/home/" + u)
			add_dir(homes[u])
	add_dir(job.folder)
	for name in job.texts:
		add_file(job.folder + "/" + name, {"type": "text", "lines": job.texts[name]})
	for p in job.pictures:
		add_file(job.folder + "/" + p.file, {
			"type": "picture",
			"open_size": p.open_size,
			"asset": p.get("asset", job.picture_dir + p.file),
		})
	for f in job.get("extra_files", []):
		var path: String = f.path if f.path.begins_with("/") else job.folder + "/" + f.path
		if f.type == "dir":
			add_dir(path)
			for k in f:
				if k != "path":
					nodes[norm(path)][k] = f[k]
		else:
			var data: Dictionary = f.duplicate()
			data.erase("path")
			if data.type == "picture" and not data.has("asset"):
				data.asset = job.picture_dir + path.get_file()
			add_file(path, data)


func add_dir(path: String) -> void:
	path = norm(path)
	if path != "/":
		add_dir(path.get_base_dir())
	if not nodes.has(path):
		nodes[path] = {"type": "dir"}


func add_file(path: String, data: Dictionary) -> void:
	path = norm(path)
	add_dir(path.get_base_dir())
	nodes[path] = data


func remove(path: String) -> void:
	nodes.erase(norm(path))


func move(src: String, dest: String) -> void:
	var moved := {}
	for path in nodes.keys():
		if path == src or path.begins_with(src + "/"):
			moved[dest + path.substr(src.length())] = nodes[path]
			nodes.erase(path)
	import_nodes(moved)


static func norm(path: String) -> String:
	var parts: Array = []
	for p in path.split("/", false):
		if p == ".":
			continue
		if p == "..":
			if not parts.is_empty():
				parts.pop_back()
			continue
		parts.append(p)
	return "/" + "/".join(parts)


func absolute(cwd: String, p: String) -> String:
	if p == "~":
		return home
	if p.begins_with("~/"):
		return norm(home + "/" + p.substr(2))
	if p.begins_with("/"):
		return norm(p)
	return norm(cwd + "/" + p)


func exists(path: String) -> bool:
	return nodes.has(path)


func is_dir(path: String) -> bool:
	return nodes.has(path) and nodes[path].type == "dir"


func node(path: String) -> Dictionary:
	return nodes.get(path, {})


func home_of(u: String) -> String:
	return homes.get(u, "/root")


func under(path: String, dir: String) -> bool:
	return path == dir or path.begins_with(dir + "/")


func writable(path: String) -> bool:
	return user == "root" or under(path, home_of(user))


func owner(path: String) -> String:
	for u in homes:
		if under(path, homes[u]):
			return u
	return client_user


func can_read(path: String) -> bool:
	if user == "root":
		return true
	if not node(path).get("r", true):
		return false
	var p := path
	while true:
		if node(p).get("private", false) and owner(p) != user:
			return false
		if p == "/":
			break
		p = p.get_base_dir()
	return true


func can_exec(path: String) -> bool:
	var n := node(path)
	if n.get("type", "") == "dir":
		return can_read(path)
	return n.get("x", false) and can_read(path)


func mode_string(path: String) -> String:
	var n := node(path)
	var r := "r" if can_read(path) else "-"
	var w := "w" if writable(path) else "-"
	var x := "x" if can_exec(path) else "-"
	return ("d" if n.get("type", "") == "dir" else "-") + r + w + x + r + "-" + x + r + "-" + x


func children(dir: String, show_hidden := false) -> Array:
	var out: Array = []
	var prefix := dir if dir.ends_with("/") else dir + "/"
	for path in nodes:
		if path == dir or not path.begins_with(prefix):
			continue
		var rest: String = path.substr(prefix.length())
		if "/" in rest:
			continue
		if show_hidden or not rest.begins_with("."):
			out.append(rest)
	out.sort()
	return out


func export_under(dir: String) -> Dictionary:
	var out := {}
	for path in nodes:
		if path.begins_with(dir + "/"):
			out[path] = nodes[path]
	return out


func import_nodes(more: Dictionary) -> void:
	for path in more:
		add_dir(path.get_base_dir())
		nodes[path] = more[path]
