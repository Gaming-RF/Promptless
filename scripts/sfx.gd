extends Node
## Three sounds. Drop files at assets/sfx/type, mail, success (.wav/.ogg/.mp3).
## Missing files are simply silent.

const UI = preload("res://scripts/ui.gd")
const SOUNDS := {"type": "res://assets/sfx/type", "mail": "res://assets/sfx/mail", "success": "res://assets/sfx/success"}
const EXTS := [".wav", ".ogg", ".mp3"]

var _players := {}
var _last_type := 0


func _ready() -> void:
	for key in SOUNDS:
		var stream = UI.find(EXTS.map(func(e): return SOUNDS[key] + e))
		if stream:
			var p := AudioStreamPlayer.new()
			p.stream = stream
			p.max_polyphony = 4 if key == "type" else 1
			add_child(p)
			_players[key] = p


func play(key: String) -> void:
	if not _players.has(key):
		return
	var p: AudioStreamPlayer = _players[key]
	if key == "type":
		var now := Time.get_ticks_msec()
		if now - _last_type < 40:
			return
		_last_type = now
		p.pitch_scale = randf_range(0.9, 1.1)
	p.play()
