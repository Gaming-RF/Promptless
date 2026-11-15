extends Control

signal back

const Palette = preload("res://scripts/palette.gd")
const UI = preload("res://scripts/ui.gd")

var lines: Array = []
var back_text := "back"


func setup(page: Array, back_label: String) -> void:
	lines = page
	back_text = back_label


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Palette.DESK
	add_child(bg)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var body := RichTextLabel.new()
	body.add_theme_color_override("default_color", Palette.TITLE_TEXT)
	body.focus_mode = FOCUS_NONE
	body.position = Vector2(16, 12)
	body.size = Vector2(608, 312)
	body.text = "\n".join(lines)
	add_child(body)
	var b := Button.new()
	b.text = back_text
	b.pressed.connect(func(): back.emit())
	add_child(b)
	b.reset_size()
	b.position = Vector2(320 - b.size.x / 2, 334)
	b.grab_focus.call_deferred()
