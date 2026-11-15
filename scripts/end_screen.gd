extends Control

signal again

const Palette = preload("res://scripts/palette.gd")
const UI = preload("res://scripts/ui.gd")
const JobData = preload("res://scripts/job_data.gd")
const BounceBall = preload("res://scripts/bounce_ball.gd")
const Juice = preload("res://scripts/juice.gd")

var campaign: Dictionary
var reply := ""


var bounced: Array = []


func setup(c: Dictionary, r: String, who: Array = []) -> void:
	campaign = c
	reply = r
	bounced = who


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
	var head := UI.label(campaign.end.get("headline", "THEY BOUNCED BACK"), UI.FONT_SIZE * 2, Palette.TITLE_TEXT)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	for n in bounced:
		var l := UI.label(String(campaign.end.get("bounced_line", "{name} bounced back.")).format({"name": n}), UI.FONT_SIZE, Palette.TITLE_TEXT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
	var b := Button.new()
	b.text = campaign.end.again
	b.size_flags_horizontal = SIZE_SHRINK_CENTER
	b.pressed.connect(func(): again.emit())
	box.add_child(b)
	b.grab_focus.call_deferred()
	Juice.confetti(self, Vector2(320, 150))
	get_tree().create_timer(0.7).timeout.connect(func(): Juice.confetti(self, Vector2(220, 170)); Juice.confetti(self, Vector2(420, 170)))
