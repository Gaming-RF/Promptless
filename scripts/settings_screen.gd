extends Control

signal back
signal reset_progress

const Palette = preload("res://scripts/palette.gd")
const UI = preload("res://scripts/ui.gd")

var labels: Dictionary = {}
var sfx: Node
var rows := VBoxContainer.new()
var _confirm_reset := false


func setup(l: Dictionary, s: Node) -> void:
	labels = l
	sfx = s


func L(key: String, fallback: String) -> String:
	return String(labels.get(key, fallback))


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Palette.DESK
	add_child(bg)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.add_theme_constant_override("separation", 8)
	add_child(rows)
	rows.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	build()


func build() -> void:
	for c in rows.get_children():
		rows.remove_child(c)
		c.queue_free()
	var title := UI.label(L("title", "SETTINGS"), UI.FONT_SIZE * 2, Palette.TITLE_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(title)
	var st: Dictionary = sfx.settings
	_toggle_row(L("music", "music"), sfx.music_on, func(): sfx.set_music(not sfx.music_on))
	_number_row(L("music_vol", "music volume"), "music_vol")
	_number_row(L("sfx_vol", "sound volume"), "sfx_vol")
	_toggle_row(L("big_text", "big text"), st.big_text, func(): st.big_text = not st.big_text)
	_toggle_row(L("fullscreen", "fullscreen"), st.fullscreen, func(): st.fullscreen = not st.fullscreen)
	var r := Button.new()
	r.text = L("reset_confirm", "click again to erase progress") if _confirm_reset else L("reset", "reset progress")
	r.size_flags_horizontal = SIZE_SHRINK_CENTER
	r.pressed.connect(_on_reset)
	rows.add_child(r)
	var b := Button.new()
	b.text = L("back", "back")
	b.size_flags_horizontal = SIZE_SHRINK_CENTER
	b.pressed.connect(func(): back.emit())
	rows.add_child(b)
	b.grab_focus.call_deferred()


func _changed() -> void:
	sfx.save_settings()
	sfx.apply_settings()
	build()


func _toggle_row(name: String, on: bool, flip: Callable) -> void:
	var b := Button.new()
	b.text = "%s: %s" % [name, L("on", "on") if on else L("off", "off")]
	b.size_flags_horizontal = SIZE_SHRINK_CENTER
	b.pressed.connect(func():
		flip.call()
		_changed())
	rows.add_child(b)


func _number_row(name: String, key: String) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	var minus := Button.new()
	minus.text = "-"
	minus.pressed.connect(func():
		sfx.settings[key] = clampi(int(sfx.settings[key]) - 1, 0, 10)
		_changed())
	var lbl := UI.label("%s: %d" % [name, int(sfx.settings[key])], UI.FONT_SIZE, Palette.TITLE_TEXT)
	var plus := Button.new()
	plus.text = "+"
	plus.pressed.connect(func():
		sfx.settings[key] = clampi(int(sfx.settings[key]) + 1, 0, 10)
		_changed())
	row.add_child(minus)
	row.add_child(lbl)
	row.add_child(plus)
	rows.add_child(row)


func _on_reset() -> void:
	if _confirm_reset:
		reset_progress.emit()
		_confirm_reset = false
		labels["reset"] = L("reset_done", "progress erased")
	else:
		_confirm_reset = true
	build()
