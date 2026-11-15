extends Node

const UI = preload("res://scripts/ui.gd")
const SOUNDS := {"type": "res://assets/sfx/type", "mail": "res://assets/sfx/mail", "success": "res://assets/sfx/success"}
const EXTS := [".wav", ".ogg", ".mp3"]

var _players := {}
var _last_type := 0
var music := AudioStreamPlayer.new()
var music_on := true
static var default_settings_path := "user://settings.json"
var settings_path := default_settings_path
var settings := {"music": true, "music_vol": 7, "sfx_vol": 8, "big_text": false, "fullscreen": false}


func load_settings() -> void:
	if FileAccess.file_exists(settings_path):
		var d = JSON.parse_string(FileAccess.get_file_as_string(settings_path))
		if d is Dictionary:
			for k in d:
				if settings.has(k):
					settings[k] = d[k]
	music_on = settings.music
	apply_settings()


func save_settings() -> void:
	settings.music = music_on
	var f := FileAccess.open(settings_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))


static func vol_db(v: float, base: float) -> float:
	return base + linear_to_db(maxf(v, 0.0001) / 10.0) if v > 0 else -80.0


func apply_settings() -> void:
	music.volume_db = vol_db(float(settings.music_vol), -10.0)
	for k in _players:
		_players[k].volume_db = vol_db(float(settings.sfx_vol), 0.0)
	if not OS.has_feature("headless") and DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want and (settings.fullscreen or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN):
			DisplayServer.window_set_mode(want)


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
	music.volume_db = vol_db(float(settings.music_vol), -10.0)
	if not music.is_inside_tree():
		add_child(music)
	if music_on:
		music.play()


func set_music(on: bool) -> void:
	if on != music_on:
		toggle_music()


func toggle_music() -> bool:
	music_on = not music_on
	save_settings()
	if music.stream:
		if music_on:
			music.play()
		else:
			music.stop()
	return music_on
