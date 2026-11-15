extends "res://scripts/desk_window.gd"

signal line_clicked(text)

const NOTE := Color("ffcd75")

var box := VBoxContainer.new()


func show_lines(title_text: String, lines: Array, can_paste: bool) -> void:
	set_title(title_text)
	for c in box.get_children():
		c.queue_free()
	if box.get_parent() == null:
		var bg := ColorRect.new()
		bg.color = NOTE
		bg.mouse_filter = MOUSE_FILTER_IGNORE
		content.add_child(bg)
		bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		box.position = Vector2(3, 2)
		box.add_theme_constant_override("separation", 1)
		content.add_child(box)
	var h := 4.0
	for l in lines:
		var row: Control
		if can_paste:
			var b := Button.new()
			b.text = "> " + l
			b.focus_mode = FOCUS_NONE
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_stylebox_override("normal", UI.flat(Color.TRANSPARENT, Palette.CLICK, 0, 1))
			b.add_theme_stylebox_override("hover", UI.flat(Palette.BUTTON, Palette.CLICK, 0, 1))
			b.add_theme_stylebox_override("pressed", UI.flat(Palette.BUTTON, Palette.CLICK, 0, 1))
			b.add_theme_color_override("font_color", Palette.CLICK)
			b.add_theme_color_override("font_hover_color", Palette.CLICK)
			b.pressed.connect(func(): line_clicked.emit(String(l).split(" ")[0] + " "))
			row = b
		else:
			row = UI.label(l)
		box.add_child(row)
		h += row.get_combined_minimum_size().y + 1
	var w := 40.0
	for l in lines:
		w = maxf(w, (String(l).length() + 2) * UI.FONT_SIZE + 10)
	set_content_size(Vector2(w, h))
	box.size = Vector2(w - 6, h - 4)
