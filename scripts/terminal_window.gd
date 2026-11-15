extends "res://scripts/desk_window.gd"
## Terminal window: output scrollback + one input line. Emits the typed line.

signal command_entered(line)
signal typed

var output := RichTextLabel.new()
var input := LineEdit.new()


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
	output.mouse_filter = MOUSE_FILTER_PASS # clicks fall through to the window -> focus input
	output.add_theme_color_override("default_color", Palette.TERM_TEXT)
	content.add_child(output)
	var row := HBoxContainer.new()
	row.add_child(UI.label(prompt_text, UI.FONT_SIZE, Palette.TERM_TEXT))
	input.size_flags_horizontal = SIZE_EXPAND_FILL
	input.caret_blink = true
	if "keep_editing_on_text_submit" in input:
		input.set("keep_editing_on_text_submit", true)
	input.text_submitted.connect(_on_submit)
	input.text_changed.connect(func(_t): typed.emit())
	input.focus_entered.connect(func(): focused.emit(self))
	row.add_child(input)
	content.add_child(row)
	var row_h := row.get_combined_minimum_size().y
	row.position = Vector2(2, s.y - row_h - 1)
	row.size = Vector2(s.x - 4, row_h)
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


func _on_submit(t: String) -> void:
	input.clear()
	command_entered.emit(t)
	focus_input()
