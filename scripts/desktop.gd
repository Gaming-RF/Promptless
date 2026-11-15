extends Control

signal job_won(reply)

const Palette = preload("res://scripts/palette.gd")
const UI = preload("res://scripts/ui.gd")
const JobData = preload("res://scripts/job_data.gd")
const Shell = preload("res://scripts/shell.gd")
const Judge = preload("res://scripts/judge.gd")
const DeskWindow = preload("res://scripts/desk_window.gd")
const PictureWindow = preload("res://scripts/picture_window.gd")
const TerminalWindow = preload("res://scripts/terminal_window.gd")
const EmailWindow = preload("res://scripts/email_window.gd")
const TextWindow = preload("res://scripts/text_window.gd")
const StickyWindow = preload("res://scripts/sticky_window.gd")

const EMAIL_POS := Vector2(8, 8)

var job: Dictionary
var sfx: Node
var shell
var email
var term
var pictures := {}
var texts := {}
var attachment = null
var snap_count := 0
var finished := false
var strikes := 0
var base_job: Dictionary
var _music_btn := Button.new()
var sticky
var _group := {}
var _next_group := 1
const SNAP_DIST := 6.0
const RADIO_PID := 103


func setup(j: Dictionary, s: Node) -> void:
	job = j
	sfx = s


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Palette.DESK
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	email = EmailWindow.new()
	add_child(email)
	email.position = EMAIL_POS
	email.build(Vector2(302, 182))
	email.set_pid(102)
	email.command_clicked.connect(func(cmd): term.paste(cmd))
	email.send_pressed.connect(send)
	email.focused.connect(_focus)

	term = TerminalWindow.new()
	add_child(term)
	term.position = Vector2(8, 208)
	term.build(job.shell.prompt, Vector2(302, 132))
	term.set_pid(101)
	term.command_entered.connect(run_command)
	term.tab_requested.connect(_on_tab)
	term.typed.connect(func(): sfx.play("type"))
	term.focused.connect(_focus)

	sticky = StickyWindow.new()
	add_child(sticky)
	sticky.focused.connect(_focus)
	sticky.line_clicked.connect(func(t): term.paste(t))
	sticky.visible = false

	_music_btn.focus_mode = FOCUS_NONE
	_music_btn.pressed.connect(_toggle_music)
	add_child(_music_btn)
	_update_music_btn()

	load_job(job)


func load_job(j: Dictionary, avoid := "") -> void:
	base_job = j
	job = JobData.instantiate(j, avoid)
	strikes = 0
	var old_history: Array = shell.history if shell else []
	var old_home: Dictionary = shell.fs.export_under(shell.fs.home) if shell else {}
	shell = Shell.new(job)
	shell.history = old_history
	shell.fs.import_nodes(old_home)
	term.set_prompt(shell.prompt())
	term.set_secret(false)
	attachment = null
	finished = false
	for w in pictures.values():
		w.queue_free()
	pictures.clear()
	_group.clear()
	for w in texts.values():
		w.queue_free()
	texts.clear()
	email.show_job(job)
	bounce_in(email, EMAIL_POS)
	var note: Dictionary = job.get("sticky", {})
	sticky.visible = not note.is_empty()
	if sticky.visible:
		sticky.show_lines(job.ui.get("sticky_title", "note"), note.lines, note.get("paste", false))
		sticky.position = Vector2(640 - sticky.size.x - 6, 360 - 26 - sticky.size.y)
	term.print_line(job.shell.welcome.format({"folder": job.folder}), Palette.DIM)
	_focus(term)
	term.focus_input.call_deferred()
	sfx.play("mail")


func bounce_in(w: Control, final_pos: Vector2) -> void:
	w.position = final_pos - Vector2(0, 28)
	var t := w.create_tween()
	t.tween_property(w, "position", final_pos, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func run_command(line: String) -> void:
	if shell.pending.is_empty():
		term.print_line("%s %s" % [shell.prompt(), line], Palette.TITLE_TEXT)
	var r: Dictionary = shell.run(line, running_programs())
	if r.clear:
		term.output.clear()
	for l in r.out:
		term.print_line(l)
	for h in r.hint:
		term.print_line(h, Palette.DIM)
	if r.open != "":
		if shell.fs.node(r.open).get("type", "") == "text":
			open_text(r.open)
		else:
			open_picture(r.open)
	if r.ask != "":
		term.print_line(r.ask, Palette.TITLE_TEXT)
	term.set_secret(not shell.pending.is_empty())
	term.set_prompt(shell.prompt())
	if r.kill != 0:
		kill(r.kill)
	if not r.launch.is_empty():
		for i in r.launch.count:
			open_picture(r.launch.path, true)


func running_programs() -> Array:
	var list: Array = [
		{"pid": term.pid, "cmd": "sh", "protected": true},
		{"pid": email.pid, "cmd": "mail", "protected": true},
	]
	if sfx.music_on and sfx.music.stream != null:
		list.append({"pid": RADIO_PID, "cmd": "radio"})
	for key in pictures:
		var w = pictures[key]
		list.append({"pid": w.pid, "cmd": "%s %s" % [job.shell.viewer, w.file.get_file()]})
	for key in texts:
		list.append({"pid": texts[key].pid, "cmd": "%s %s" % [job.shell.get("text_viewer", "textview"), key.get_file()]})
	return list


func open_text(path: String):
	if texts.has(path):
		_focus(texts[path], false)
		return texts[path]
	var w = TextWindow.new()
	add_child(w)
	w.setup(path, shell.fs.node(path).lines, Vector2(150, 130))
	w.position = Vector2(326 + 12 * (texts.size() % 4), 196 + 8 * (texts.size() % 4))
	w.keep_on_screen()
	bounce_in(w, w.position)
	w.focused.connect(_focus)
	w.set_pid(_next_pid)
	_next_pid += 1
	texts[path] = w
	_focus(w, false)
	return w


func kill(pid: int) -> void:
	if pid == RADIO_PID:
		if sfx.music_on:
			_toggle_music()
		return
	for key in texts.keys():
		if texts[key].pid == pid:
			texts[key].queue_free()
			texts.erase(key)
			return
	for key in pictures.keys():
		if pictures[key].pid == pid:
			_group.erase(pictures[key])
			pictures[key].queue_free()
			pictures.erase(key)
			return


func has_tool(t: String) -> bool:
	return t in job.get("tools", [])


func group_of(w) -> Array:
	if not _group.has(w):
		return [w]
	var g: int = _group[w]
	return pictures.values().filter(func(o): return _group.get(o, -1) == g)


func _on_window_moved(w, delta: Vector2) -> void:
	for o in group_of(w):
		if o != w:
			o.position += delta


func _on_drag_finished(w) -> void:
	if has_tool("join"):
		try_join(w)


func try_join(w) -> bool:
	var mine := group_of(w)
	for o in pictures.values():
		if o in mine:
			continue
		var a: Rect2 = w.get_rect()
		var b: Rect2 = o.get_rect()
		var offset := Vector2.INF
		var overlap_y := a.position.y < b.end.y and b.position.y < a.end.y
		var overlap_x := a.position.x < b.end.x and b.position.x < a.end.x
		if overlap_y and absf(a.end.x - b.position.x) <= SNAP_DIST:
			offset = Vector2(b.position.x - a.end.x, 0)
		elif overlap_y and absf(b.end.x - a.position.x) <= SNAP_DIST:
			offset = Vector2(b.end.x - a.position.x, 0)
		elif overlap_x and absf(a.end.y - b.position.y) <= SNAP_DIST:
			offset = Vector2(0, b.position.y - a.end.y)
		elif overlap_x and absf(b.end.y - a.position.y) <= SNAP_DIST:
			offset = Vector2(0, b.end.y - a.position.y)
		if offset == Vector2.INF:
			continue
		if offset.x != 0 and absf(a.position.y - b.position.y) <= SNAP_DIST:
			offset.y = b.position.y - a.position.y
		elif offset.y != 0 and absf(a.position.x - b.position.x) <= SNAP_DIST:
			offset.x = b.position.x - a.position.x
		for m in mine:
			m.position += offset
		var g: int = _group.get(o, 0)
		if g == 0:
			g = _next_group
			_next_group += 1
		for m in mine + group_of(o):
			_group[m] = g
		return true
	return false


func capture(w) -> Array:
	var taken: Array = group_of(w).duplicate()
	if has_tool("trace"):
		var grew := true
		while grew:
			grew = false
			for o in pictures.values():
				if o in taken:
					continue
				for t in taken:
					if (o.tracing or t.tracing) and o.get_rect().intersects(t.get_rect()):
						taken.append(o)
						grew = true
						break
	return taken


var _next_pid := 140


func picture(name: String):
	var path: String = shell.fs.absolute(shell.cwd, name)
	if pictures.has(path):
		return pictures[path]
	for p in pictures:
		if pictures[p].file.get_file() == name:
			return pictures[p]
	return null


func open_picture(file: String, extra_copy := false):
	if pictures.has(file) and not extra_copy:
		_focus(pictures[file], false)
		return pictures[file]
	var info: Dictionary = shell.fs.node(file)
	var w = PictureWindow.new()
	add_child(w)
	var k := pictures.size() % 6
	var tex: Texture2D = UI.find([info.get("asset", "")])
	w.setup(file, tex, JobData.picture_index(job, file.get_file()),
		Vector2(info.open_size[0], info.open_size[1]), job.ui.snap)
	w.position = Vector2(326 + 18 * k, 10 + 14 * k)
	w.keep_on_screen()
	bounce_in(w, w.position)
	w.focused.connect(_focus)
	w.snapshot_requested.connect(snapshot)
	w.moved.connect(_on_window_moved)
	w.drag_finished.connect(_on_drag_finished)
	if has_tool("trace"):
		w.enable_trace(job.ui.get("trace", "TRACE"), job.ui.get("tracing", "TRACING"))
	w.set_pid(_next_pid)
	_next_pid += 1
	pictures[file if not pictures.has(file) else "%s#%d" % [file, w.pid]] = w
	_focus(w, false)
	return w


func snapshot(w) -> void:
	snap_count += 1
	var s: Vector2 = w.get_content_size()
	var wins: Array = []
	for c in capture(w):
		var cs: Vector2 = c.get_content_size()
		var cp: Vector2 = c.position + c.content.position
		wins.append({
			"file": c.file, "w": cs.x, "h": cs.y, "x": cp.x, "y": cp.y,
			"z": c.get_index(), "tracing": c.tracing, "group": _group.get(c, 0),
		})
	var joined := wins.filter(func(e): return e.group != 0 and e.group == _group.get(w, -1))
	joined.sort_custom(func(a, b): return a.x < b.x if absf(a.x - b.x) > SNAP_DIST else a.y < b.y)
	attachment = {
		"name": "snapshot_%d.png" % snap_count,
		"windows": wins,
		"order": joined.map(func(e): return e.file),
	}
	shell.fs.add_file(shell.fs.home + "/" + attachment.name, {
		"type": "picture",
		"open_size": [s.x, s.y],
		"asset": shell.fs.node(w.file).get("asset", ""),
	})
	w.flash()
	email.show_attachment(attachment.name)


func send() -> void:
	if finished:
		return
	var v: String = Judge.verdict(attachment, job)
	var reply: String = JobData.pick(job.replies[v], strikes)
	if v != "right" and v != "no_attachment":
		strikes += 1
		if job.has("strikes") and strikes >= int(job.strikes):
			email.add_reply(JobData.pick(job.replies.give_up, 0))
			finished = true
			sfx.play("mail")
			var old_answer: String = job.answer
			get_tree().create_timer(2.2).timeout.connect(func(): load_job(base_job, old_answer))
			return
	email.add_reply(reply)
	if v == "right":
		finished = true
		email.set_mood("calm")
		sfx.play("success")
		get_tree().create_timer(2.2).timeout.connect(func(): job_won.emit(reply))
		return
	sfx.play("mail")
	if v != "no_attachment":
		attachment = null
		email.clear_attachment()


func _on_tab(text: String) -> void:
	var r: Dictionary = shell.complete(text)
	if not r.options.is_empty():
		term.print_line("  ".join(r.options), Palette.DIM)
	term.set_line(r.line)


func _toggle_music() -> void:
	sfx.toggle_music()
	_update_music_btn()


func _update_music_btn() -> void:
	_music_btn.text = job.ui.music_on if sfx.music_on else job.ui.music_off
	_music_btn.reset_size()
	_music_btn.position = Vector2(640 - _music_btn.size.x - 6, 360 - _music_btn.size.y - 6)


func _focus(w, take_keyboard := true) -> void:
	for c in get_children():
		if c is DeskWindow:
			c.active = c == w
	w.move_to_front()
	if w is PictureWindow and take_keyboard:
		get_viewport().gui_release_focus()
	elif w == term:
		term.focus_input()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	var dirs := {KEY_LEFT: Vector2.LEFT, KEY_RIGHT: Vector2.RIGHT, KEY_UP: Vector2.UP, KEY_DOWN: Vector2.DOWN}
	if not dirs.has(event.keycode) or get_viewport().gui_get_focus_owner() != null:
		return
	for c in get_children():
		if c is PictureWindow and c.active:
			c.set_content_size(c.get_content_size() + dirs[event.keycode] * (8.0 if event.shift_pressed else 1.0))
			get_viewport().set_input_as_handled()
