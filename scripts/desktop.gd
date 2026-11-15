extends Control

signal job_won(reply)
signal changed

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
var initial
var slots: Array = []
var cur := 0
var sfx: Node
var shell
var email
var term
var pictures := {}
var texts := {}
var attachment = null
var snap_count := 0
var finished: bool:
	get:
		return slots[cur].finished if not slots.is_empty() else false
	set(v):
		if not slots.is_empty():
			slots[cur].finished = v
var strikes: int:
	get:
		return slots[cur].strikes if not slots.is_empty() else 0
	set(v):
		if not slots.is_empty():
			slots[cur].strikes = v
var base_job: Dictionary:
	get:
		return slots[cur].base if not slots.is_empty() else {}
var _music_btn := Button.new()
var _text_btn := Button.new()
var big_text := false
var sticky
var _group := {}
var _next_group := 1
const SNAP_DIST := 6.0
const RADIO_PID := 103


func setup(j, s: Node) -> void:
	initial = j
	job = j[0] if j is Array else j
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
	email.inbox_selected.connect(select_job)
	email.focused.connect(_focus)

	term = TerminalWindow.new()
	add_child(term)
	term.position = Vector2(8, 208)
	term.build(job.shell.prompt, Vector2(302, 132))
	term.set_pid(101)
	term.command_entered.connect(run_command)
	term.tab_requested.connect(_on_tab)
	term.escape_pressed.connect(select_next_picture)
	term.typed.connect(func(): sfx.play("type"))
	term.focused.connect(_focus)

	sticky = StickyWindow.new()
	add_child(sticky)
	sticky.focused.connect(_focus)
	sticky.line_clicked.connect(func(t): term.paste(t))
	sticky.visible = false

	_text_btn.focus_mode = FOCUS_NONE
	_text_btn.pressed.connect(func(): set_big_text(not big_text))
	add_child(_text_btn)

	_music_btn.focus_mode = FOCUS_NONE
	_music_btn.pressed.connect(_toggle_music)
	add_child(_music_btn)
	_update_music_btn()

	load_jobs(initial if initial is Array else [initial])


func load_job(j: Dictionary, avoid := "", force := "") -> void:
	load_jobs([j], [force], avoid)


func load_jobs(list: Array, forces: Array = [], avoid := "") -> void:
	slots = []
	for i in list.size():
		var f: String = forces[i] if i < forces.size() else ""
		slots.append({"base": list[i], "job": JobData.instantiate(list[i], avoid, f),
			"strikes": 0, "finished": false, "replies": []})
	cur = 0
	job = slots[0].job
	var old_history: Array = shell.history if shell else []
	var old_home: Dictionary = shell.fs.export_under(shell.fs.home) if shell else {}
	shell = Shell.new(job)
	for i in range(1, slots.size()):
		shell.add_job(slots[i].job)
	shell.history = old_history
	shell.fs.import_nodes(old_home)
	term.set_prompt(shell.prompt())
	term.set_secret(false)
	attachment = null
	for w in pictures.values():
		w.queue_free()
	pictures.clear()
	_group.clear()
	for w in texts.values():
		w.queue_free()
	texts.clear()
	select_job(0)
	bounce_in(email, EMAIL_POS)
	term.print_line(job.shell.welcome.format({"folder": job.folder}), Palette.DIM)
	for i in range(1, slots.size()):
		term.print_line(job.shell.get("more_files", "more files in {folder}").format({"folder": slots[i].job.folder}), Palette.DIM)
	_focus(term)
	term.focus_input.call_deferred()
	sfx.play("mail")
	changed.emit()


func select_job(i: int) -> void:
	cur = i
	job = slots[i].job
	shell.job = job
	email.show_job(job)
	for r in slots[i].replies:
		email.add_reply(r)
	if slots[i].finished:
		email.set_mood("calm")
	if attachment != null:
		email.show_attachment(attachment.name)
	email.set_inbox(slots.map(func(sl): return sl.job.client.name), cur, slots.map(func(sl): return sl.finished))
	var note: Dictionary = job.get("sticky", {})
	sticky.visible = not note.is_empty()
	if sticky.visible:
		sticky.show_lines(job.ui.get("sticky_title", "note"), note.lines, note.get("paste", false))
		sticky.position = Vector2(640 - sticky.size.x - 6, 360 - 26 - sticky.size.y)


func restart_slot(i: int, avoid: String) -> void:
	var sl: Dictionary = slots[i]
	sl.job = JobData.instantiate(sl.base, avoid)
	sl.strikes = 0
	sl.finished = false
	sl.replies = []
	shell.add_job(sl.job)
	for key in pictures.keys():
		if shell.fs.under(pictures[key].file, sl.job.folder):
			_group.erase(pictures[key])
			pictures[key].queue_free()
			pictures.erase(key)
	for key in texts.keys():
		if shell.fs.under(key, sl.job.folder):
			texts[key].queue_free()
			texts.erase(key)
	if i == cur:
		select_job(i)
	sfx.play("mail")
	changed.emit()


func bounce_in(w: Control, final_pos: Vector2) -> void:
	w.position = final_pos - Vector2(0, 28)
	var t := w.create_tween()
	t.tween_property(w, "position", final_pos, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func run_command(line: String) -> void:
	changed.emit.call_deferred()
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
	if big_text:
		w.set_text_size(UI.FONT_SIZE * 2)
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
	changed.emit()
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


func open_picture(file: String, extra_copy := false, animate := true):
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
	if animate:
		bounce_in(w, w.position)
	w.focused.connect(_focus)
	w.snapshot_requested.connect(snapshot)
	w.moved.connect(_on_window_moved)
	w.resized.connect(func(): changed.emit())
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
	changed.emit()


func _reply(text: String) -> void:
	slots[cur].replies.append(text)
	email.add_reply(text)


func send() -> void:
	if finished:
		return
	var v: String = Judge.verdict(attachment, job)
	var reply: String = JobData.pick(job.replies[v], strikes)
	if v != "right" and v != "no_attachment":
		strikes += 1
		if job.has("strikes") and strikes >= int(job.strikes):
			_reply(JobData.pick(job.replies.give_up, 0))
			finished = true
			sfx.play("mail")
			var old_answer: String = job.answer
			var which := cur
			get_tree().create_timer(2.2).timeout.connect(func(): restart_slot(which, old_answer))
			return
	_reply(reply)
	if v == "right":
		if _clock_start >= 0 and _clock_end < 0:
			_clock_end = clock_seconds()
		finished = true
		email.set_mood("calm")
		sfx.play("success")
		attachment = null
		email.clear_attachment()
		email.set_inbox(slots.map(func(sl): return sl.job.client.name), cur, slots.map(func(sl): return sl.finished))
		if slots.all(func(sl): return sl.finished and sl.replies.size() > 0 and not _gave_up(sl)):
			get_tree().create_timer(2.2).timeout.connect(func(): job_won.emit(reply))
		changed.emit()
		return
	sfx.play("mail")
	if v != "no_attachment":
		attachment = null
		email.clear_attachment()


func _gave_up(sl: Dictionary) -> bool:
	return sl.job.has("replies") and sl.job.replies.has("give_up") and sl.replies.back() == JobData.pick(sl.job.replies.give_up, 0)


func _on_tab(text: String) -> void:
	var r: Dictionary = shell.complete(text)
	if not r.options.is_empty():
		term.print_line("  ".join(r.options), Palette.DIM)
	term.set_line(r.line)


func _toggle_music() -> void:
	sfx.toggle_music()
	_update_music_btn()
	changed.emit()


func set_big_text(on: bool) -> void:
	big_text = on
	var px := UI.FONT_SIZE * (2 if on else 1)
	term.set_text_size(px)
	email.set_text_size(px)
	for w in texts.values():
		w.set_text_size(px)
	_update_music_btn()
	changed.emit()


func _update_music_btn() -> void:
	_music_btn.text = job.ui.music_on if sfx.music_on else job.ui.music_off
	_music_btn.reset_size()
	_music_btn.position = Vector2(640 - _music_btn.size.x - 6, 360 - _music_btn.size.y - 6)
	_text_btn.text = job.ui.get("text_big", "text: big") if big_text else job.ui.get("text_normal", "text: normal")
	_text_btn.reset_size()
	_text_btn.position = Vector2(_music_btn.position.x - _text_btn.size.x - 4, _music_btn.position.y)


func _focus(w, take_keyboard := true) -> void:
	for c in get_children():
		if c is DeskWindow:
			c.active = c == w
	w.move_to_front()
	if w is PictureWindow and take_keyboard:
		get_viewport().gui_release_focus()
	elif w == term:
		term.focus_input()


func active_picture():
	for c in get_children():
		if c is PictureWindow and c.active:
			return c
	return null


func select_next_picture() -> void:
	var list: Array = pictures.values()
	if list.is_empty():
		return
	var cur = active_picture()
	var i := (list.find(cur) + 1) % list.size() if cur != null else list.size() - 1
	_focus(list[i])


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	if get_viewport().gui_get_focus_owner() != null:
		return
	var w = active_picture()
	var dirs := {KEY_LEFT: Vector2.LEFT, KEY_RIGHT: Vector2.RIGHT, KEY_UP: Vector2.UP, KEY_DOWN: Vector2.DOWN}
	var step := 8.0 if event.shift_pressed else 1.0
	var handled := true
	match event.keycode:
		KEY_TAB:
			select_next_picture()
		KEY_ESCAPE:
			_focus(term)
		KEY_ENTER, KEY_KP_ENTER:
			send()
		KEY_S:
			if w:
				snapshot(w)
		KEY_T:
			if w and w._trace_btn:
				w.set_tracing(not w.tracing)
		_:
			if w and dirs.has(event.keycode):
				var d: Vector2 = dirs[event.keycode] * step
				if event.ctrl_pressed:
					w.position += d
					w.keep_on_screen()
					_on_window_moved(w, d)
					if has_tool("join"):
						try_join(w)
				else:
					w.set_content_size(w.get_content_size() + d)
			else:
				handled = false
	if handled:
		get_viewport().set_input_as_handled()


func export_state() -> Dictionary:
	var wins: Array = []
	for w in pictures.values():
		var cs: Vector2 = w.get_content_size()
		wins.append({"file": w.file, "x": w.position.x, "y": w.position.y, "w": cs.x, "h": cs.y, "tracing": w.tracing})
	return {
		"cur": cur,
		"slots": slots.map(func(sl): return {"answer": sl.job.answer, "strikes": sl.strikes, "finished": sl.finished, "replies": sl.replies}),
		"snap_count": snap_count,
		"home": shell.fs.export_under(shell.fs.home),
		"history": shell.history,
		"cwd": shell.cwd,
		"windows": wins,
		"texts": texts.keys(),
		"radio": sfx.music_on,
		"big_text": big_text,
	}


func import_state(st: Dictionary) -> void:
	var bases: Array = slots.map(func(sl): return sl.base)
	var saved: Array = st.get("slots", [])
	load_jobs(bases, saved.map(func(e): return e.get("answer", "")))
	for i in mini(saved.size(), slots.size()):
		slots[i].strikes = int(saved[i].get("strikes", 0))
		slots[i].finished = saved[i].get("finished", false)
		slots[i].replies = saved[i].get("replies", [])
	select_job(clampi(int(st.get("cur", 0)), 0, slots.size() - 1))
	snap_count = int(st.get("snap_count", 0))
	shell.fs.import_nodes(st.get("home", {}))
	shell.history = st.get("history", [])
	var cwd: String = st.get("cwd", shell.cwd)
	if shell.fs.is_dir(cwd) and shell.fs.can_read(cwd):
		shell.cwd = cwd
	for e in st.get("windows", []):
		if not shell.fs.exists(e.file):
			continue
		var w = open_picture(e.file, pictures.has(e.file), false)
		w.set_content_size(Vector2(e.w, e.h))
		w.position = Vector2(e.x, e.y)
		if e.get("tracing", false) and w._trace_btn:
			w.set_tracing(true)
	for t in st.get("texts", []):
		if shell.fs.exists(t):
			open_text(t)
	if st.get("radio", true) != sfx.music_on:
		_toggle_music()
	set_big_text(st.get("big_text", false))


var _clock_start := -1.0
var _clock_end := -1.0
var _clock_label: Label


func start_clock() -> void:
	_clock_start = Time.get_ticks_msec() / 1000.0
	_clock_label = UI.label("", UI.FONT_SIZE, Palette.TITLE_TEXT)
	var bg := UI.flat(Palette.FRAME, Color.TRANSPARENT, 0, 3)
	_clock_label.add_theme_stylebox_override("normal", bg)
	add_child(_clock_label)
	_tick_clock()


func clock_seconds() -> float:
	if _clock_end >= 0:
		return _clock_end
	return Time.get_ticks_msec() / 1000.0 - _clock_start if _clock_start >= 0 else 0.0


func _process(_delta: float) -> void:
	if _clock_label and not finished:
		_tick_clock()


func _tick_clock() -> void:
	var t := int(clock_seconds())
	_clock_label.text = job.ui.get("clock", "time {t}").format({"t": "%d:%02d" % [t / 60, t % 60]})
	_clock_label.reset_size()
	_clock_label.position = Vector2(318, 360 - _clock_label.size.y - 6)
