extends RefCounted

const Palette = preload("res://scripts/palette.gd")
const FONT_SIZE := 8
const FONT_PATHS := ["res://assets/font.ttf", "res://assets/font.otf", "res://assets/font.fnt"]


static func find(paths: Array) -> Resource:
	for p in paths:
		if ResourceLoader.exists(p):
			return load(p)
	return null


static func flat(bg: Color, border := Color.TRANSPARENT, border_w := 0, margin_x := 2.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.content_margin_left = margin_x
	sb.content_margin_right = margin_x
	sb.content_margin_top = border_w
	sb.content_margin_bottom = border_w
	return sb


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT_SIZE
	var font = find(FONT_PATHS)
	if font is FontFile:
		font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		font.hinting = TextServer.HINTING_NONE
		font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	if font:
		t.default_font = font
	t.set_stylebox("normal", "Button", flat(Palette.BUTTON, Palette.FRAME, 1, 3))
	t.set_stylebox("hover", "Button", flat(Palette.BUTTON_HOVER, Palette.FRAME, 1, 3))
	t.set_stylebox("pressed", "Button", flat(Palette.PANEL, Palette.FRAME, 1, 3))
	t.set_stylebox("focus", "Button", flat(Color.TRANSPARENT, Palette.CLICK, 1, 3))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", Palette.TEXT)
	t.set_stylebox("normal", "LineEdit", flat(Palette.TERM_BG, Color.TRANSPARENT, 0, 1))
	t.set_stylebox("focus", "LineEdit", StyleBoxEmpty.new())
	t.set_color("font_color", "LineEdit", Palette.TERM_TEXT)
	t.set_color("caret_color", "LineEdit", Palette.TERM_TEXT)
	t.set_color("font_color", "Label", Palette.TEXT)
	t.set_color("default_color", "RichTextLabel", Palette.TEXT)
	t.set_constant("line_separation", "RichTextLabel", 3)
	t.set_constant("line_spacing", "Label", 3)
	t.set_stylebox("focus", "RichTextLabel", StyleBoxEmpty.new())
	return t


static func label(text: String, font_size := FONT_SIZE, color := Palette.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
