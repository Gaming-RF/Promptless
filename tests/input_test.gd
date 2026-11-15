extends SceneTree

var fails := 0
var main


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func frames(n := 2) -> void:
	for i in n:
		await process_frame


func mouse(type: String, pos: Vector2) -> void:
	var e: InputEvent
	if type == "move":
		e = InputEventMouseMotion.new()
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if _held else 0
	else:
		e = InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = type == "down"
		_held = e.pressed
	e.position = pos
	e.global_position = pos
	root.push_input(e, true)
	await frames(1)

var _held := false


func click(pos: Vector2) -> void:
	await mouse("move", pos)
	await mouse("down", pos)
	await mouse("up", pos)


func key(code: Key, unicode := 0) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.unicode = unicode
		e.pressed = pressed
		root.push_input(e, true)
	await frames(1)


func type_text(t: String) -> void:
	for ch in t:
		var code := OS.find_keycode_from_string(ch.to_upper()) if ch != " " else KEY_SPACE
		if ch == ".":
			code = KEY_PERIOD
		elif ch == "_":
			code = KEY_UNDERSCORE
		await key(code, ch.unicode_at(0))


func term_text(desk) -> String:
	return desk.term.output.get_parsed_text()


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await frames(4)
	await key(KEY_ENTER)
	await frames(3)
	var desk = main.current
	check(desk.get_script().resource_path.ends_with("desktop.gd"), "Enter on title boots the desktop")

	await create_timer(0.6).timeout
	await click(Vector2(200, 114))
	check(desk.term.input.text == "grep Comets notes.txt", "email link pastes full command: '%s'" % desk.term.input.text)
	await key(KEY_ENTER)
	check("ball 3. Coach" in term_text(desk), "Enter runs grep")

	await type_text("open ball_")
	await key(KEY_TAB)
	check(desk.term.input.text == "open ball_" and desk.term.input.has_focus(), "Tab with 5 matches keeps focus, lists options")
	await type_text("3")
	await key(KEY_TAB)
	check(desk.term.input.text == "open ball_3.png ", "Tab completes the file name: '%s'" % desk.term.input.text)
	await key(KEY_ENTER)
	check(desk.pictures.has("ball_3.png"), "typed open makes a window")
	await key(KEY_UP)
	check(desk.term.input.text == "open ball_3.png ", "Up arrow recalls last command")
	await key(KEY_DOWN)
	check(desk.term.input.text == "", "Down arrow returns to empty line")
	await type_text("ls")
	await key(KEY_ENTER)
	check(term_text(desk).count("notes.txt") >= 2, "focus survived submit (typed ls ran)")

	var w = desk.pictures["ball_3.png"]
	var before: Vector2 = w.get_content_size()
	await key(KEY_DOWN)
	check(w.get_content_size() == before, "arrow keys don't resize while typing")

	var edge: Vector2 = w.position + Vector2(w.size.x - 2, w.size.y / 2)
	await mouse("move", edge)
	await mouse("down", edge)
	for i in range(1, 9):
		await mouse("move", edge + Vector2(8 * i, 0))
	await mouse("up", edge + Vector2(64, 0))
	check(w.get_content_size() == Vector2(160, 160), "edge drag stretches to %s" % w.get_content_size())

	await click(w.position + w.size / 2)
	await key(KEY_RIGHT)
	check(w.get_content_size() == Vector2(161, 160), "arrow resizes clicked picture")
	await key(KEY_LEFT)

	await click(desk.term.position + desk.term.size / 2)
	await type_text("x")
	check(desk.term.input.text == "x", "clicking terminal body returns typing to input")

	var snap: Control = w._buttons.get_child(0)
	await click(snap.get_global_rect().get_center())
	check(desk.attachment != null, "SNAP button attaches a snapshot")
	var send: Control
	for c in desk.email.content.get_children():
		if c is Button:
			send = c
	await click(send.get_global_rect().get_center())
	check(desk.finished, "Send button delivers the win: " + desk.email.last_reply)
	await create_timer(2.6).timeout
	check(desk.job.search_word == "Gold" and desk.term.input.has_focus(), "job 2 arrives, terminal still focused")
	print("\n%d failure(s)" % fails)
	quit(1 if fails else 0)
