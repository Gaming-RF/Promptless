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
	paint(self, Rect2(Vector2.ZERO, size), texture, variant, not tracing)


static func paint(ci: CanvasItem, r: Rect2, tex: Texture2D, v: int, with_bg: bool) -> void:
	if tex:
		ci.draw_texture_rect(tex, r, false)
		return
	if with_bg:
		ci.draw_rect(r, Palette.PHOTO_BG)
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
