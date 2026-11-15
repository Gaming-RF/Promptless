extends Control

signal again

const Palette = preload("res://scripts/palette.gd")
const UI = preload("res://scripts/ui.gd")
const JobData = preload("res://scripts/job_data.gd")
const BounceBall = preload("res://scripts/bounce_ball.gd")

var campaign: Dictionary
var reply := ""


func setup(c: Dictionary, r: String) -> void:
	campaign = c
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
	var job: Dictionary = campaign.jobs[campaign.end.get("picture_job", 0)]
	var ball := BounceBall.new()
	ball.texture = JobData.picture_texture(job, job.answer)
	ball.variant = JobData.picture_index(job, job.answer)
	ball.custom_minimum_size = Vector2(240, 200)
	ball.size_flags_horizontal = SIZE_SHRINK_CENTER
	box.add_child(ball)
	var b := Button.new()
	b.text = campaign.end.again
	b.size_flags_horizontal = SIZE_SHRINK_CENTER
	b.pressed.connect(func(): again.emit())
	box.add_child(b)
	b.grab_focus.call_deferred()
