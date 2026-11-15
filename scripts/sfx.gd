extends Node

const UI = preload("res://scripts/ui.gd")
const SOUNDS := {"type": "res://assets/sfx/type", "mail": "res://assets/sfx/mail", "success": "res://assets/sfx/success"}
const EXTS := [".wav", ".ogg", ".mp3"]

var _players := {}
var _last_type := 0
var music := AudioStreamPlayer.new()
var music_on := true


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


func start_music(path: String) -> void:
	if music.playing or not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if "loop" in stream:
		stream.loop = true
	music.stream = stream
	music.volume_db = -10.0
	if not music.is_inside_tree():
		add_child(music)
	if music_on:
		music.play()


func toggle_music() -> bool:
	music_on = not music_on
	if music.stream:
		if music_on:
			music.play()
		else:
			music.stop()
	return music_on
