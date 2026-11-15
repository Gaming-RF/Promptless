extends Control

signal focused(win)

const Palette = preload("res://scripts/palette.gd")
const UI = preload("res://scripts/ui.gd")
const TITLE_H := 10
const GRIP := 5

var resizable := false
var min_content := Vector2(24, 24)
var max_content := Vector2(192, 200)
var content := Control.new()
var active := false:
	set(v):
		active = v
		queue_redraw()

var _title_label := Label.new()
var _buttons := HBoxContainer.new()
var _grip := Control.new()
var _mode := ""
var _drag_offset := Vector2.ZERO
var _edges := Vector2.ZERO
var _start_mouse := Vector2.ZERO
var _start_size := Vector2.ZERO


func _init() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	_title_label.position = Vector2(3, 1)
	_title_label.add_theme_color_override("font_color", Palette.TITLE_TEXT)
	_title_label.mouse_filter = MOUSE_FILTER_IGNORE
	_title_label.clip_text = true
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_constant_override("line_spacing", 0)
	add_child(_title_label)
	content.position = Vector2(1, TITLE_H + 1)
	content.clip_contents = true
	content.mouse_filter = MOUSE_FILTER_PASS
	add_child(content)
	_buttons.add_theme_constant_override("separation", 1)
	add_child(_buttons)
	_grip.mouse_filter = MOUSE_FILTER_IGNORE
	_grip.size = Vector2(GRIP, GRIP)
	_grip.draw.connect(_draw_grip)
	add_child(_grip)
	resized.connect(_layout)


var pid := 0
var _base_title := ""


func set_title(t: String) -> void:
	_base_title = t
	_title_label.text = ("[%d] %s" % [pid, t]) if pid > 0 else t


func set_pid(p: int) -> void:
	pid = p
	set_title(_base_title)


func set_content_size(s: Vector2) -> void:
	if resizable:
		s = s.clamp(min_content, max_content)
	s = s.round()
	content.size = s
	size = s + Vector2(2, TITLE_H + 2)
	_layout()


func get_content_size() -> Vector2:
	return content.size


func add_title_button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = FOCUS_NONE
	b.add_theme_stylebox_override("normal", UI.flat(Palette.BUTTON, Palette.CLICK, 1, 2))
	b.add_theme_stylebox_override("hover", UI.flat(Palette.BUTTON_HOVER, Palette.CLICK, 1, 2))
	b.add_theme_stylebox_override("pressed", UI.flat(Palette.PANEL, Palette.CLICK, 1, 2))
	b.custom_minimum_size.y = TITLE_H
	b.add_theme_color_override("font_color", Palette.CLICK)
	b.add_theme_color_override("font_hover_color", Palette.CLICK)
	b.pressed.connect(on_press)
	_buttons.add_child(b)
	_layout()
	return b


func keep_on_screen() -> void:
	var area := get_parent_area_size()
	position.x = clampf(position.x, 24 - size.x, area.x - 24)
	position.y = clampf(position.y, 0, area.y - TITLE_H - 2)


func _layout() -> void:
	_buttons.reset_size()
	_buttons.position = Vector2(size.x - _buttons.size.x - 2, 1)
	_title_label.size = Vector2(maxf(0, _buttons.position.x - 4), TITLE_H)
	_grip.position = size - Vector2(GRIP + 1, GRIP + 1)
	_grip.visible = resizable
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.FRAME)
	draw_rect(Rect2(1, 1, size.x - 2, TITLE_H), Palette.TITLE_ON if active else Palette.TITLE_OFF)
	draw_rect(Rect2(1, TITLE_H + 1, size.x - 2, size.y - TITLE_H - 2), Palette.PANEL)


func _draw_grip() -> void:
	for i in 3:
		var o := float(i * 2)
		_grip.draw_line(Vector2(GRIP, o), Vector2(o, GRIP), Palette.FRAME, 1.0)


func _edges_at(p: Vector2) -> Vector2:
	if not resizable or p.y <= TITLE_H + 1:
		return Vector2.ZERO
	return Vector2(1.0 if p.x >= size.x - GRIP else 0.0, 1.0 if p.y >= size.y - GRIP else 0.0)


func _cursor_for(e: Vector2) -> CursorShape:
	if e == Vector2.ONE:
		return CURSOR_FDIAGSIZE
	if e.x > 0:
		return CURSOR_HSIZE
	if e.y > 0:
		return CURSOR_VSIZE
	return CURSOR_ARROW


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			focused.emit(self)
			_edges = _edges_at(event.position)
			if _edges != Vector2.ZERO:
				_mode = "resize"
				_start_mouse = event.global_position
				_start_size = content.size
			elif event.position.y <= TITLE_H + 1:
				_mode = "move"
				_drag_offset = event.position
			accept_event()
		else:
			_mode = ""
	elif event is InputEventMouseMotion:
		match _mode:
			"move":
				position = (event.global_position - get_parent().global_position - _drag_offset).round()
				keep_on_screen()
			"resize":
				var d: Vector2 = event.global_position - _start_mouse
				set_content_size(_start_size + d * _edges)
			_:
				mouse_default_cursor_shape = _cursor_for(_edges_at(event.position))
