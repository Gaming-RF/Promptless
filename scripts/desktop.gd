extends Control
## The pretend desktop: mail + terminal + picture windows.
## Owns the job runner: snapshot record -> attachment -> Judge -> client reply.
## load_job() swaps in the next job's email and folder without clearing the terminal.

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

const EMAIL_POS := Vector2(8, 8)

var job: Dictionary
var sfx: Node
var shell
var email
var term
var pictures := {} # file -> PictureWindow
var attachment = null # snapshot record, or null
var snap_count := 0
var finished := false
var _music_btn := Button.new()


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
	email.command_clicked.connect(func(cmd): term.paste(cmd))
	email.send_pressed.connect(send)
	email.focused.connect(_focus)

	term = TerminalWindow.new()
	add_child(term)
	term.position = Vector2(8, 208)
	term.build(job.shell.prompt, Vector2(302, 132))
	term.command_entered.connect(run_command)
	term.tab_requested.connect(_on_tab)
	term.typed.connect(func(): sfx.play("type"))
	term.focused.connect(_focus)

	_music_btn.focus_mode = FOCUS_NONE
	_music_btn.pressed.connect(_toggle_music)
	add_child(_music_btn)
	_update_music_btn()

	load_job(job)


func load_job(j: Dictionary) -> void:
	job = j
	shell = Shell.new(job)
	attachment = null
	finished = false
	for w in pictures.values():
		w.queue_free()
	pictures.clear()
	email.show_job(job)
	bounce_in(email, EMAIL_POS)
	term.print_line(job.shell.welcome.format({"folder": job.folder}), Palette.DIM)
	_focus(term)
	term.focus_input.call_deferred()
	sfx.play("mail")


## New windows drop in and bounce. Only position moves: sizes are what snapshots read.
func bounce_in(w: Control, final_pos: Vector2) -> void:
	w.position = final_pos - Vector2(0, 28)
	var t := w.create_tween()
	t.tween_property(w, "position", final_pos, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func run_command(line: String) -> void:
	term.print_line("%s %s" % [job.shell.prompt, line], Palette.TITLE_TEXT)
	var r: Dictionary = shell.run(line)
	for l in r.out:
		term.print_line(l)
	for h in r.hint:
		term.print_line(h, Palette.DIM)
	if r.open != "":
		open_picture(r.open)


func open_picture(file: String):
	if pictures.has(file):
		_focus(pictures[file], false)
		return pictures[file]
	var info := JobData.picture_info(job, file)
	var w = PictureWindow.new()
	add_child(w)
	var k := pictures.size() % 6
	w.setup(file, JobData.picture_texture(job, file), JobData.picture_index(job, file),
		Vector2(info.open_size[0], info.open_size[1]), job.ui.snap)
	w.position = Vector2(326 + 18 * k, 10 + 14 * k)
	w.keep_on_screen()
	bounce_in(w, w.position)
	w.focused.connect(_focus)
	w.snapshot_requested.connect(snapshot)
	pictures[file] = w
	_focus(w, false) # opened from the terminal: keep typing in the terminal
	return w


## Contract message 7: a snapshot was taken, with the windows inside it and their sizes.
func snapshot(w) -> void:
	snap_count += 1
	var s: Vector2 = w.get_content_size()
	attachment = {
		"name": "snapshot_%d.png" % snap_count,
		"windows": [{"file": w.file, "w": s.x, "h": s.y}],
	}
	w.flash()
	email.show_attachment(attachment.name)


func send() -> void:
	if finished:
		return
	var v: String = Judge.verdict(attachment, job)
	var reply: String = job.replies[v]
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


## Keyboard resizing: arrows resize the selected picture 1px (Shift: 8px).
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
