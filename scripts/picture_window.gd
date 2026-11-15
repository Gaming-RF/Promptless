extends "res://scripts/desk_window.gd"

signal snapshot_requested(win)

const PictureView = preload("res://scripts/picture_view.gd")

var file := ""
var view := PictureView.new()
var _flash := ColorRect.new()
var _readout: Label
var _readout_id := 0


func setup(file_name: String, tex: Texture2D, variant: int, open_size: Vector2, snap_text: String) -> void:
	file = file_name
	resizable = true
	set_title(file_name.get_file())
	view.texture = tex
	view.variant = variant
	view.mouse_filter = MOUSE_FILTER_IGNORE
	content.add_child(view)
	view.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = MOUSE_FILTER_IGNORE
	content.add_child(_flash)
	_flash.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_readout = UI.label("", UI.FONT_SIZE, Palette.TITLE_TEXT)
	var bg := UI.flat(Palette.FRAME, Color.TRANSPARENT, 0, 2)
	bg.content_margin_top = 1
	bg.content_margin_bottom = 1
	_readout.add_theme_stylebox_override("normal", bg)
	_readout.visible = false
	content.add_child(_readout)
	add_title_button(snap_text, func(): snapshot_requested.emit(self))
	set_content_size(open_size)


func set_content_size(s: Vector2) -> void:
	super.set_content_size(s)
	if _readout == null or not is_inside_tree():
		return
	var c := get_content_size()
	_readout.text = "%dx%d" % [c.x, c.y]
	_readout.reset_size()
	_readout.position = Vector2(1, c.y - _readout.size.y - 1)
	_readout.visible = true
	_readout_id += 1
	var my_id := _readout_id
	get_tree().create_timer(0.9).timeout.connect(func():
		if my_id == _readout_id and is_instance_valid(_readout):
			_readout.visible = false)


func flash() -> void:
	_flash.color.a = 0.9
	create_tween().tween_property(_flash, "color:a", 0.0, 0.25)
