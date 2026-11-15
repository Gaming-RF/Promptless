extends "res://scripts/desk_window.gd"
## Picture viewer window. Resizing stretches the picture; SNAP snapshots this window.

signal snapshot_requested(win)

const PictureView = preload("res://scripts/picture_view.gd")

var file := ""
var view := PictureView.new()
var _flash := ColorRect.new()


func setup(file_name: String, tex: Texture2D, variant: int, open_size: Vector2, snap_text: String) -> void:
	file = file_name
	resizable = true
	set_title(file_name)
	view.texture = tex
	view.variant = variant
	view.mouse_filter = MOUSE_FILTER_IGNORE
	content.add_child(view)
	view.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = MOUSE_FILTER_IGNORE
	content.add_child(_flash)
	_flash.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_title_button(snap_text, func(): snapshot_requested.emit(self))
	set_content_size(open_size)


func flash() -> void:
	_flash.color.a = 0.9
	create_tween().tween_property(_flash, "color:a", 0.0, 0.25)
