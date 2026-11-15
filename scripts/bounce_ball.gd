extends Control

const PictureView = preload("res://scripts/picture_view.gd")
const Palette = preload("res://scripts/palette.gd")

var texture: Texture2D
var variant := 0
var ball := 56.0
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var p := fmod(_t, 0.9) / 0.9
	var h := 4.0 * p * (1.0 - p)
	var squash := clampf(1.0 - h * 6.0, 0.0, 1.0)
	var w := ball * (1.0 + 0.25 * squash)
	var hh := ball * (1.0 - 0.25 * squash)
	var ground := size.y - 4.0
	var y := ground - hh - h * (size.y - ball - 8.0)
	var sw := w * (0.5 + 0.5 * (1.0 - h))
	draw_colored_polygon(PictureView.ellipse(Vector2(size.x / 2, ground), Vector2(sw / 2, 3), 20), Palette.FRAME)
	PictureView.paint(self, Rect2(size.x / 2 - w / 2, y, w, hh).abs(), texture, variant, false)
