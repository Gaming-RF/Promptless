extends Control

signal start(resume)
signal replay(index)

const Palette = preload("res://scripts/palette.gd")
const UI = preload("res://scripts/ui.gd")
const JobData = preload("res://scripts/job_data.gd")
const PictureView = preload("res://scripts/picture_view.gd")

var campaign: Dictionary
var can_continue := false
var replay_list: Array = []


func setup(c: Dictionary, resume_ok := false, replays: Array = []) -> void:
	campaign = c
	can_continue = resume_ok
	replay_list = replays


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Palette.DESK
	add_child(bg)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	box.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var job: Dictionary = campaign.jobs[campaign.end.get("picture_job", 0)]
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(110, 80)
	holder.size_flags_horizontal = SIZE_SHRINK_CENTER
	box.add_child(holder)
	var ball := PictureView.new()
	ball.texture = JobData.picture_texture(job, job.answer)
	ball.variant = JobData.picture_index(job, job.answer)
	ball.custom_minimum_size = Vector2(104, 36)
	holder.add_child(ball)
	var t := ball.create_tween().set_loops()
	t.tween_interval(0.5)
	t.tween_property(ball, "custom_minimum_size", Vector2(72, 72), 0.9).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_interval(1.2)
	t.tween_property(ball, "custom_minimum_size", Vector2(104, 36), 0.12).set_ease(Tween.EASE_IN)
	for spec in [[campaign.title, UI.FONT_SIZE * 3, Palette.TITLE_TEXT], [campaign.get("tagline", ""), UI.FONT_SIZE, Palette.TITLE_TEXT]]:
		var l := UI.label(spec[0], spec[1], spec[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
	var first: Button
	if can_continue:
		first = _button(box, campaign.get("continue_button", "continue"), true)
		_button(box, campaign.get("new_game_button", "new game"), false)
	else:
		first = _button(box, campaign.get("boot_button", "start"), false)
	for r in replay_list:
		var text: String = campaign.get("replay_button", "replay: {subject}").format({"subject": r.subject})
		if r.best >= 0:
			text += "  " + campaign.get("best_label", "best {t}").format({"t": "%d:%02d" % [int(r.best) / 60, int(r.best) % 60]})
		var b := Button.new()
		b.text = text
		b.size_flags_horizontal = SIZE_SHRINK_CENTER
		var idx: int = r.index
		b.pressed.connect(func(): replay.emit(idx))
		box.add_child(b)
	first.grab_focus.call_deferred()


func _button(box: Container, text: String, resume: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = SIZE_SHRINK_CENTER
	b.pressed.connect(func(): start.emit(resume))
	box.add_child(b)
	return b
