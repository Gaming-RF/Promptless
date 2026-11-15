extends "res://scripts/desk_window.gd"

signal command_entered(line)
signal typed
signal tab_requested(text)
signal escape_pressed

var output := RichTextLabel.new()
var input := LineEdit.new()
var prompt_label: Label
var _row: HBoxContainer
var _history: Array = []
var _history_pos := 0


func build(prompt_text: String, s: Vector2) -> void:
	set_title("terminal")
	set_content_size(s)
	var bg := ColorRect.new()
	bg.color = Palette.TERM_BG
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	content.add_child(bg)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	output.scroll_following = true
	output.focus_mode = FOCUS_NONE
	output.mouse_filter = MOUSE_FILTER_PASS
	output.add_theme_color_override("default_color", Palette.TERM_TEXT)
	content.add_child(output)
	var row := HBoxContainer.new()
	_row = row
	prompt_label = UI.label(prompt_text, UI.FONT_SIZE, Palette.TERM_TEXT)
	row.add_child(prompt_label)
	input.size_flags_horizontal = SIZE_EXPAND_FILL
	input.caret_blink = true
	if "keep_editing_on_text_submit" in input:
		input.set("keep_editing_on_text_submit", true)
	input.text_submitted.connect(_on_submit)
	input.text_changed.connect(func(_t): typed.emit())
	input.focus_entered.connect(func(): focused.emit(self))
	input.gui_input.connect(_on_input_key)
	row.add_child(input)
	content.add_child(row)
	_relayout()


func set_text_size(px: int) -> void:
	for c in [output, input, prompt_label]:
		c.add_theme_font_size_override("font_size", px)
		c.add_theme_font_size_override("normal_font_size", px)
	_relayout()


func _relayout() -> void:
	var s := get_content_size()
	_row.reset_size()
	var row_h := _row.get_combined_minimum_size().y
	_row.position = Vector2(2, s.y - row_h - 1)
	_row.size = Vector2(s.x - 4, row_h)
	output.position = Vector2(2, 1)
	output.size = Vector2(s.x - 4, s.y - row_h - 3)


func print_line(text: String, color := Palette.TERM_TEXT) -> void:
	output.push_color(color)
	output.add_text(text + "\n")
	output.pop()


func paste(text: String) -> void:
	input.text = text
	input.caret_column = text.length()
	focus_input()


func focus_input() -> void:
	input.grab_focus()
	if input.has_method("edit"):
		input.edit()


func set_line(t: String) -> void:
	input.text = t
	input.caret_column = t.length()


func _on_input_key(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed):
		return
	match e.keycode:
		KEY_TAB:
			tab_requested.emit(input.text)
		KEY_ESCAPE:
			escape_pressed.emit()
		KEY_UP:
			if _history.is_empty():
				return
			_history_pos = maxi(0, _history_pos - 1)
			set_line(_history[_history_pos])
		KEY_DOWN:
			_history_pos = mini(_history.size(), _history_pos + 1)
			set_line(_history[_history_pos] if _history_pos < _history.size() else "")
		_:
			return
	input.accept_event()


func _on_submit(t: String) -> void:
	if not t.strip_edges().is_empty() and not input.secret:
		_history.append(t)
	_history_pos = _history.size()
	input.clear()
	command_entered.emit(t)
	focus_input()


func set_prompt(t: String) -> void:
	prompt_label.text = t


func set_secret(on: bool) -> void:
	input.secret = on
