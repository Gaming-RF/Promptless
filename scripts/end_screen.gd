extends Control

signal again

const Palette = preload("res://scripts/palette.gd")
const UI = preload("res://scripts/ui.gd")
const JobData = preload("res://scripts/job_data.gd")
const BounceBall = preload("res://scripts/bounce_ball.gd")

var job: Dictionary
var reply := ""


func setup(j: Dictionary, r: String) -> void:
	job = j
	reply = r


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Palette.DESK
	add_child(bg)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	box.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var ball := BounceBall.new()
	ball.texture = JobData.picture_texture(job, job.answer)
	ball.variant = JobData.picture_index(job, job.answer)
	ball.custom_minimum_size = Vector2(200, 140)
	ball.size_flags_horizontal = SIZE_SHRINK_CENTER
	box.add_child(ball)
	var quote := UI.label("\"%s\"" % reply, UI.FONT_SIZE * 2, Palette.TITLE_TEXT)
	quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quote.custom_minimum_size = Vector2(520, 0)
	quote.size_flags_horizontal = SIZE_SHRINK_CENTER
	box.add_child(quote)
	var sig := UI.label("- " + job.client.name, UI.FONT_SIZE, Palette.TITLE_TEXT)
	sig.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sig)
	var b := Button.new()
	b.text = job.end.again
	b.size_flags_horizontal = SIZE_SHRINK_CENTER
	b.pressed.connect(func(): again.emit())
	box.add_child(b)
	var credits := UI.label(job.end.credits, UI.FONT_SIZE, Palette.PANEL)
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(credits)
	b.grab_focus.call_deferred()
