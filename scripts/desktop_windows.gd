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
var daemons := {}
var remote_shell
var remote_screen
var ending := ""
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


func bounce_in(w: Control, final_pos: Vector2) -> void:
	w.position = final_pos - Vector2(0, 28)
	var t := w.create_tween()
	t.tween_property(w, "position", final_pos, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func running_programs() -> Array:
	var list: Array = [
		{"pid": term.pid, "cmd": "sh", "protected": true},
		{"pid": email.pid, "cmd": "mail", "protected": true},
	]
	if sfx.music_on and sfx.music.stream != null:
		list.append({"pid": RADIO_PID, "cmd": "radio"})
	for pid in daemons:
		list.append({"pid": pid, "cmd": daemons[pid].cmd})
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
	if daemons.has(pid):
		daemons.erase(pid)
		return
	for key in pictures.keys():
		if pictures[key].pid == pid:
			var w = pictures[key]
			var parent: int = w.get_meta("parent", 0)
			_group.erase(w)
			w.queue_free()
			pictures.erase(key)
			if daemons.has(parent):
				var again = open_picture(daemons[parent].path, true)
				again.set_meta("parent", parent)
				term.print_line(job.shell.get("respawn", "{cmd}: a window closed. drawing another.").format({"cmd": daemons[parent].cmd}), Palette.DIM)
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
var key_mode := false


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
		Vector2(info.open_size[0], info.open_size[1]), job.ui.snap, info.get("placeholder", {}))
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
	var taken := capture(w)
	var rect := Rect2()
	for c in taken:
		rect = c.get_rect() if rect.size == Vector2.ZERO else rect.merge(c.get_rect())
	snapshot_rect(rect, w, taken)


func inside(rect: Rect2) -> Array:
	var grown := rect.grow(2)
	return pictures.values().filter(func(c): return grown.encloses(c.get_rect()))


func snapshot_rect(rect: Rect2, focus = null, only: Array = []) -> bool:
	var caught: Array = only.duplicate() if not only.is_empty() else inside(rect)
	if caught.is_empty():
		return false
	caught.sort_custom(func(a, b): return a.get_index() < b.get_index())
	snap_count += 1
	var wins: Array = []
	for c in caught:
		var cs: Vector2 = c.get_content_size()
		var cp: Vector2 = c.position + c.content.position
		wins.append({
			"file": c.file, "w": cs.x, "h": cs.y, "x": cp.x, "y": cp.y,
			"z": c.get_index(), "tracing": c.tracing, "group": _group.get(c, 0),
			"copies": pictures.values().filter(func(o): return o.file == c.file).size(),
		})
	var g: int = _group.get(focus, 0) if focus != null else 0
	if g == 0:
		var counts := {}
		for e in wins:
			if e.group != 0:
				counts[e.group] = counts.get(e.group, 0) + 1
		for k in counts:
			if g == 0 or counts[k] > counts[g]:
				g = k
	var joined := wins.filter(func(e): return e.group != 0 and e.group == g)
	joined.sort_custom(func(a, b): return a.x < b.x if absf(a.x - b.x) > SNAP_DIST else a.y < b.y)
	attachment = {
		"name": "snapshot_%d.png" % snap_count,
		"windows": wins,
		"order": joined.map(func(e): return e.file),
		"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
	}
	var main_w = focus if focus != null else caught.back()
	var ms: Vector2 = main_w.get_content_size()
	shell.fs.add_file(shell.fs.home + "/" + attachment.name, {
		"type": "picture",
		"open_size": [ms.x, ms.y],
		"asset": shell.fs.node(main_w.file).get("asset", ""),
		"placeholder": shell.fs.node(main_w.file).get("placeholder", {}),
	})
	for c in caught:
		c.flash()
	email.show_attachment(attachment.name)
	changed.emit()
	return true


var _snap_overlay: Control
var _snap_from := Vector2.ZERO
var _snap_btn := Button.new()


func start_snapshot_tool() -> void:
	if _snap_overlay:
		return
	_snap_overlay = Control.new()
	_snap_overlay.mouse_filter = MOUSE_FILTER_STOP
	_snap_overlay.mouse_default_cursor_shape = CURSOR_CROSS
	add_child(_snap_overlay)
	_snap_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_snap_overlay.set_meta("dragging", false)
	_snap_overlay.draw.connect(_draw_snap_overlay)
	_snap_overlay.gui_input.connect(_snap_input)
	get_viewport().gui_release_focus()


func cancel_snapshot_tool() -> void:
	if _snap_overlay:
		_snap_overlay.queue_free()
		_snap_overlay = null


func _snap_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_snap_from = e.position
			_snap_overlay.set_meta("to", e.position)
			_snap_overlay.set_meta("dragging", true)
		elif _snap_overlay.get_meta("dragging"):
			_snap_overlay.set_meta("to", e.position)
			var r := Rect2(_snap_from, Vector2.ZERO).expand(e.position)
			cancel_snapshot_tool()
			if not snapshot_rect(r):
				term.print_line(job.shell.get("snap_empty", "snapshot: no picture window fully inside that rectangle"), Palette.DIM)
	elif e is InputEventMouseMotion and _snap_overlay.get_meta("dragging"):
		_snap_overlay.set_meta("to", e.position)
		_snap_overlay.queue_redraw()


func _draw_snap_overlay() -> void:
	_snap_overlay.draw_rect(Rect2(Vector2.ZERO, _snap_overlay.size), Color(0, 0, 0, 0.15))
	if _snap_overlay.get_meta("dragging"):
		var r := Rect2(_snap_from, Vector2.ZERO).expand(_snap_overlay.get_meta("to"))
		_snap_overlay.draw_rect(r, Palette.CLICK, false, 1.0)


func _focus(w, take_keyboard := true) -> void:
	for c in get_children():
		if c is DeskWindow:
			c.active = c == w
	w.move_to_front()
	if w is PictureWindow and take_keyboard:
		get_viewport().gui_release_focus()
	elif w == term:
		key_mode = false
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
	if not key_mode and not _snap_overlay and not dirs.has(event.keycode):
		if event.keycode == KEY_ESCAPE:
			_focus(term)
			get_viewport().set_input_as_handled()
			return
		if event.unicode > 0 or event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_BACKSPACE, KEY_TAB]:
			_focus(term)
		return
	var step := 8.0 if event.shift_pressed else 1.0
	var handled := true
	match event.keycode:
		KEY_TAB:
			select_next_picture()
		KEY_ESCAPE:
			if _snap_overlay:
				cancel_snapshot_tool()
			else:
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


func send() -> void:
	pass


func _toggle_music() -> void:
	pass
