extends RefCounted
## Small feedback effects. Pure decoration: nothing here changes game state.

const Palette = preload("res://scripts/palette.gd")


## A wrong answer makes the window recoil, like a message bouncing back.
static func recoil(w: Control) -> void:
	var x := w.position.x
	var t := w.create_tween()
	for dx in [-6.0, 4.0, -2.0, 0.0]:
		t.tween_property(w, "position:x", x + dx, 0.05)
	t.tween_property(w, "position:x", x, 0.01)


## The client's portrait hops on a win, with a bouncing landing.
static func hop(c: Control) -> void:
	var y := c.position.y
	var t := c.create_tween()
	t.tween_property(c, "position:y", y - 10.0, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(c, "position:y", y, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)


## A one-shot burst of palette-coloured squares.
static func confetti(parent: Node, at: Vector2) -> void:
	for col in [Palette.BALLS[0], Palette.BUTTON_HOVER, Palette.TITLE_ON, Palette.TERM_TEXT]:
		var p := CPUParticles2D.new()
		p.position = at
		p.one_shot = true
		p.explosiveness = 0.9
		p.amount = 14
		p.lifetime = 1.1
		p.direction = Vector2(0, -1)
		p.spread = 70.0
		p.initial_velocity_min = 90.0
		p.initial_velocity_max = 190.0
		p.gravity = Vector2(0, 360)
		p.scale_amount_min = 1.5
		p.scale_amount_max = 3.0
		p.color = col
		p.z_index = 100
		parent.add_child(p)
		p.emitting = true
		p.finished.connect(p.queue_free)
