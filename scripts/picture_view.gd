extends Control

const Palette = preload("res://scripts/palette.gd")

const TRACE_SHADER := """
shader_type canvas_item;
uniform float threshold = 0.45;
void fragment() {
	vec4 c = COLOR;
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	if (l > threshold) {
		c.a = 0.0;
	}
	COLOR = c;
}
"""

var texture: Texture2D
var variant := 0
var placeholder := {}
var tracing := false:
	set(v):
		tracing = v
		if v:
			var sh := Shader.new()
			sh.code = TRACE_SHADER
			var m := ShaderMaterial.new()
			m.shader = sh
			material = m
		else:
			material = null
		queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	paint(self, Rect2(Vector2.ZERO, size), texture, variant, not tracing, placeholder)


static func paint(ci: CanvasItem, r: Rect2, tex: Texture2D, v: int, with_bg: bool, ph := {}) -> void:
	if tex:
		ci.draw_texture_rect(tex, r, false)
		return
	if with_bg:
		ci.draw_rect(r, Palette.PHOTO_BG)
	match String(ph.get("kind", "ball")):
		"ring":
			_ring(ci, r, v)
		"grid":
			_grid(ci, r)
		"lines":
			_lines(ci, r)
		"mark":
			_mark(ci, r, int(ph.get("row", 2)))
		"half":
			_half(ci, r, String(ph.get("side", "left")))
		"label":
			_label(ci, r, String(ph.get("text", "?")))
		_:
			_ball(ci, r, v)


static func at(r: Rect2, u: float, w: float) -> Vector2:
	return r.position + Vector2(u, w) * r.size


static func _ring(ci: CanvasItem, r: Rect2, v: int) -> void:
	var lake := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		var wob := 0.22 + 0.06 * sin(a * (3 + v % 3)) + 0.03 * cos(a * 5 + v)
		lake.append(at(r, 0.5 + cos(a) * wob, 0.5 + sin(a) * wob * 0.8))
	ci.draw_colored_polygon(lake, Color("41a6f6"))
	var ring := ellipse(r.get_center(), r.size * 0.42, 48)
	ring.append(ring[0])
	ci.draw_polyline(ring, Palette.FRAME, 2.0)
	for i in 4:
		var a := TAU * i / 4.0
		ci.draw_line(at(r, 0.5 + cos(a) * 0.38, 0.5 + sin(a) * 0.38), at(r, 0.5 + cos(a) * 0.46, 0.5 + sin(a) * 0.46), Palette.FRAME, 2.0)


static func _grid(ci: CanvasItem, r: Rect2) -> void:
	for i in 5:
		var t := 0.1 + 0.2 * i
		ci.draw_line(at(r, t, 0.1), at(r, t, 0.9), Palette.DIM, 1.0)
		ci.draw_line(at(r, 0.1, t), at(r, 0.9, t), Palette.DIM, 1.0)
	var bars := [0.3, 0.55, 0.45, 0.7]
	for i in bars.size():
		var x0 := 0.13 + 0.2 * i
		ci.draw_rect(Rect2(at(r, x0, 0.9 - bars[i] * 0.8), Vector2(0.14, bars[i] * 0.8) * r.size), Color("b13e53"))


static func _lines(ci: CanvasItem, r: Rect2) -> void:
	for i in 7:
		var w := 0.75 if i % 3 != 2 else 0.5
		ci.draw_rect(Rect2(at(r, 0.1, 0.12 + i * 0.11), Vector2(w, 0.04) * r.size), Palette.DIM)


static func _mark(ci: CanvasItem, r: Rect2, row: int) -> void:
	var c := at(r, 0.45, 0.14 + row * 0.11)
	var ring := ellipse(c, r.size * Vector2(0.42, 0.06), 32)
	ring.append(ring[0])
	ci.draw_polyline(ring, Palette.FRAME, 2.0)


static func _half(ci: CanvasItem, r: Rect2, side: String) -> void:
	var xs := [0.3] if side == "left" else [0.7]
	for x in xs:
		ci.draw_colored_polygon(ellipse(at(r, x, 0.35), r.size * Vector2(0.09, 0.09), 20), Palette.FRAME)
		ci.draw_rect(Rect2(at(r, x - 0.12, 0.47), Vector2(0.24, 0.4) * r.size), Palette.FRAME)


static func _label(ci: CanvasItem, r: Rect2, text: String) -> void:
	ci.draw_rect(r.grow(-2), Palette.FRAME, false, 1.0)
	var font := ThemeDB.fallback_font
	var fs := 16
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_string(font, r.get_center() + Vector2(-w / 2, fs / 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.FRAME)


static func _ball(ci: CanvasItem, r: Rect2, v: int) -> void:
	var c := r.get_center()
	var rad := r.size * 0.42
	var outline := ellipse(c, rad, 40)
	ci.draw_colored_polygon(outline, Palette.BALLS[v % Palette.BALLS.size()])
	ci.draw_polyline(ellipse(c, Vector2(rad.x * 0.45, rad.y), 40), Palette.BALL_DARK, 1.0)
	ci.draw_line(c - Vector2(rad.x, 0), c + Vector2(rad.x, 0), Palette.BALL_DARK, 1.0)
	ci.draw_colored_polygon(ellipse(c + rad * Vector2(-0.45, -0.5), rad * 0.14, 16), Palette.PHOTO_BG)
	outline.append(outline[0])
	ci.draw_polyline(outline, Palette.FRAME, 1.0)


static func ellipse(c: Vector2, r: Vector2, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts
