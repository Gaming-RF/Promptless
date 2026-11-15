extends "res://scripts/desktop_windows.gd"

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
	term.escape_pressed.connect(func():
		key_mode = true
		select_next_picture())
	term.typed.connect(func(): sfx.play("type"))
	term.focused.connect(_focus)

	sticky = StickyWindow.new()
	add_child(sticky)
	sticky.focused.connect(_focus)
	sticky.line_clicked.connect(func(t): term.paste(t))
	sticky.visible = false

	_snap_btn.focus_mode = FOCUS_NONE
	_snap_btn.pressed.connect(start_snapshot_tool)
	add_child(_snap_btn)

	_help_btn.focus_mode = FOCUS_NONE
	_help_btn.pressed.connect(open_help)
	add_child(_help_btn)

	_text_btn.focus_mode = FOCUS_NONE
	_text_btn.pressed.connect(func(): set_big_text(not big_text))
	add_child(_text_btn)

	_music_btn.focus_mode = FOCUS_NONE
	_music_btn.pressed.connect(_toggle_music)
	add_child(_music_btn)
	_update_music_btn()

	load_jobs(initial if initial is Array else [initial])
	if sfx.settings.get("big_text", false):
		set_big_text(true)


func load_job(j: Dictionary, avoid := "", force := "") -> void:
	load_jobs([j], [force], avoid)


func load_jobs(list: Array, forces: Array = [], avoid := "", file_mail := true) -> void:
	slots = []
	for i in list.size():
		var f: String = forces[i] if i < forces.size() else ""
		slots.append({"base": list[i], "job": JobData.instantiate(list[i], avoid, f),
			"strikes": 0, "finished": false, "replies": []})
	cur = 0
	ending = ""
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
	daemons.clear()
	for w in texts.values():
		w.queue_free()
	texts.clear()
	if file_mail:
		for sl in slots:
			_file_mail(sl)
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
	_setup_remote()
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
		var parent_pid := 0
		if r.launch.get("parent", "") != "":
			parent_pid = _next_pid
			_next_pid += 1
			daemons[parent_pid] = {"cmd": r.launch.parent, "path": r.launch.path}
		for i in r.launch.count:
			var lw = open_picture(r.launch.path, true)
			if parent_pid:
				lw.set_meta("parent", parent_pid)
	if not r.write.is_empty():
		_remote(r.write.line)
	if not finished and Judge.ran_ok(job, r.ran):
		ending = job.get("ending", "main")
		_reply(JobData.pick(job.replies.right, 0))
		_win(job.replies.right)


func _setup_remote() -> void:
	if remote_screen:
		remote_screen.queue_free()
		remote_screen = null
	remote_shell = null
	if job.get("check", "") != "remote":
		return
	var r: Dictionary = job.remote
	var rj := job.duplicate(true)
	rj.folder = r.folder
	rj.home = r.folder
	rj.texts = r.get("texts", {})
	rj.pictures = r.get("pictures", [])
	rj.extra_files = r.get("extra_files", [])
	rj.users = {}
	rj.tools = []
	remote_shell = Shell.new(rj)
	remote_screen = TextWindow.new()
	add_child(remote_screen)
	remote_screen.setup(r.folder + "/" + job.ui.get("remote_title", "screen"), [], Vector2(200, 120))
	remote_screen.set_title(job.ui.get("remote_title", "{user}'s screen").format({"user": r.user}))
	remote_screen.position = Vector2(326, 12)
	remote_screen.focused.connect(_focus)
	remote_screen.set_pid(_next_pid)
	_next_pid += 1


func _remote(line: String) -> void:
	if remote_shell == null:
		return
	remote_screen.append_line("%s$ %s" % [job.remote.user, line])
	var rr: Dictionary = remote_shell.run(line)
	for l in rr.out + rr.hint:
		remote_screen.append_line(l)
	if rr.open != "":
		remote_screen.append_line(job.ui.get("remote_opened", "[{file} opens on their screen]").format({"file": rr.open.get_file()}))
	if not finished and Judge.remote_ok(job, rr):
		if job.remote.has("did_it"):
			remote_screen.append_line("%s: %s" % [job.remote.user, job.remote.did_it])
		var who := String(job.client.name)
		if not who in bounced:
			bounced.append(who)
		_reply(JobData.pick(job.replies.right, 0))
		_win(job.replies.right)


func _file_mail(sl: Dictionary) -> void:
	var dir: String = shell.fs.home + "/mail"
	var j: Dictionary = sl.job
	var stem := String(j.client.name).split(" ")[0].to_lower()
	var n: int = shell.fs.children(dir).size() + 1 if shell.fs.is_dir(dir) else 1
	sl.mail_path = "%s/%02d_%s.txt" % [dir, n, stem]
	var lines: Array = ["From: " + j.email.from, "Subject: " + j.email.subject, ""]
	lines.append_array(String(j.email.body).split("\n"))
	shell.fs.add_file(sl.mail_path, {"type": "text", "lines": lines})


func _reply(text: String) -> void:
	slots[cur].replies.append(text)
	email.add_reply(text)
	var path: String = slots[cur].get("mail_path", "")
	if path != "" and shell.fs.exists(path):
		var lines: Array = shell.fs.node(path).lines
		lines.append_array(["", "Re: " + job.email.subject, text])


func send() -> void:
	if finished:
		return
	var alt: Dictionary = job.get("alt", {})
	if attachment == null and alt.get("on", "") == "send_empty":
		ending = alt.get("ending", "alt")
		_reply(JobData.pick(alt.reply, 0))
		_win(alt.reply)
		return
	var v: String = Judge.verdict(attachment, job)
	var reply: String = JobData.pick(job.replies[v], strikes)
	if v != "right" and v != "no_attachment":
		strikes += 1
		if job.has("strikes") and strikes >= int(job.strikes):
			_reply(JobData.pick(job.replies.give_up, 0))
			finished = true
			sfx.play("mail")
			var old_answer: String = job.get("answer", "")
			var which := cur
			get_tree().create_timer(2.2).timeout.connect(func(): restart_slot(which, old_answer))
			return
	_reply(reply)
	if v == "right":
		_win(reply)
		return
	sfx.play("mail")
	if v != "no_attachment":
		attachment = null
		email.clear_attachment()


func _win(reply: String) -> void:
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
	if sfx.settings.big_text != on:
		sfx.settings.big_text = on
		sfx.save_settings()
	var px := UI.FONT_SIZE * (2 if on else 1)
	term.set_text_size(px)
	email.set_text_size(px)
	for w in texts.values():
		w.set_text_size(px)
	_update_music_btn()
	changed.emit()


var help_window
var _help_btn := Button.new()


func open_help() -> void:
	if help_window and is_instance_valid(help_window):
		_focus(help_window, false)
		return
	help_window = TextWindow.new()
	add_child(help_window)
	help_window.setup("help", job.ui.get("help_page", []), Vector2(300, 220))
	help_window.set_title(job.ui.get("help", "HELP"))
	help_window.add_title_button(job.ui.get("close", "CLOSE"), func():
		help_window.queue_free()
		help_window = null)
	help_window.position = Vector2(170, 40)
	if big_text:
		help_window.set_text_size(UI.FONT_SIZE * 2)
	help_window.focused.connect(_focus)
	_focus(help_window, false)


func _update_music_btn() -> void:
	_music_btn.text = job.ui.music_on if sfx.music_on else job.ui.music_off
	_music_btn.reset_size()
	_music_btn.position = Vector2(640 - _music_btn.size.x - 6, 360 - _music_btn.size.y - 6)
	_text_btn.text = job.ui.get("text_big", "text: big") if big_text else job.ui.get("text_normal", "text: normal")
	_text_btn.reset_size()
	_text_btn.position = Vector2(_music_btn.position.x - _text_btn.size.x - 4, _music_btn.position.y)
	_snap_btn.text = job.ui.get("snapshot_tool", "SNAPSHOT")
	_snap_btn.reset_size()
	_snap_btn.position = Vector2(_text_btn.position.x - _snap_btn.size.x - 4, _music_btn.position.y)
	_help_btn.text = job.ui.get("help", "HELP")
	_help_btn.reset_size()
	_help_btn.position = Vector2(_snap_btn.position.x - _help_btn.size.x - 4, _music_btn.position.y)


func export_state() -> Dictionary:
	var wins: Array = []
	for w in pictures.values():
		var cs: Vector2 = w.get_content_size()
		wins.append({"file": w.file, "x": w.position.x, "y": w.position.y, "w": cs.x, "h": cs.y, "tracing": w.tracing})
	return {
		"cur": cur,
		"bounced": bounced,
		"slots": slots.map(func(sl): return {"answer": sl.job.get("answer", ""), "strikes": sl.strikes, "finished": sl.finished, "replies": sl.replies, "mail_path": sl.get("mail_path", "")}),
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
	load_jobs(bases, saved.map(func(e): return e.get("answer", "")), "", saved.is_empty())
	for i in mini(saved.size(), slots.size()):
		slots[i].mail_path = saved[i].get("mail_path", "")
		slots[i].strikes = int(saved[i].get("strikes", 0))
		slots[i].finished = saved[i].get("finished", false)
		slots[i].replies = saved[i].get("replies", [])
	select_job(clampi(int(st.get("cur", 0)), 0, slots.size() - 1))
	bounced = st.get("bounced", bounced)
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
	_clock_label.position = Vector2(640 - _clock_label.size.x - 6, 360 - 2 * _clock_label.size.y - 12)
