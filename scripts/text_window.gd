extends "res://scripts/desk_window.gd"

var file := ""
var body := RichTextLabel.new()


func setup(path: String, lines: Array, open_size: Vector2) -> void:
	file = path
	resizable = true
	min_content = Vector2(80, 40)
	max_content = Vector2(300, 300)
	set_title(path.get_file())
	var bg := ColorRect.new()
	bg.color = Palette.BUTTON
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	content.add_child(bg)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	body.focus_mode = FOCUS_NONE
	body.add_theme_color_override("default_color", Palette.TEXT)
	body.text = "\n".join(lines)
	content.add_child(body)
	body.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	body.offset_left = 2
	body.offset_right = -2
	set_content_size(open_size)


func set_text_size(px: int) -> void:
	body.add_theme_font_size_override("normal_font_size", px)
