extends Control

const CAMPAIGN_PATH := "res://data/campaign.json"
var campaign_path := CAMPAIGN_PATH
const UI = preload("res://scripts/ui.gd")
const JobData = preload("res://scripts/job_data.gd")
const Sfx = preload("res://scripts/sfx.gd")
const Desktop = preload("res://scripts/desktop.gd")
const TitleScreen = preload("res://scripts/title_screen.gd")
const EndScreen = preload("res://scripts/end_screen.gd")
const SaveFile = preload("res://scripts/save_file.gd")

var campaign: Dictionary
var job_index := 0
var sfx: Node
var current: Node
var save_path := SaveFile.PATH
var records_path := "user://records.json"
var replay_index := -1
var _dirty := false
var _save_timer := Timer.new()


func _ready() -> void:
	theme = UI.make_theme()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--campaign="):
			campaign_path = a.substr(11)
	campaign = JobData.load_campaign(campaign_path)
	sfx = Sfx.new()
	add_child(sfx)
	_save_timer.wait_time = 2.0
	_save_timer.timeout.connect(save_now)
	add_child(_save_timer)
	_save_timer.start()
	show_title()


func saving() -> bool:
	return campaign.get("save", false)


func can_continue() -> bool:
	return saving() and not SaveFile.read(save_path).is_empty()


func save_now(force := false) -> void:
	if not saving() or not (_dirty or force) or not current or not current.has_method("export_state"):
		return
	_dirty = false
	SaveFile.write({"job_index": job_index, "desk": current.export_state()}, save_path)


func _swap(n: Node) -> void:
	if current:
		current.queue_free()
	current = n
	add_child(n)


func show_title() -> void:
	var t = TitleScreen.new()
	t.setup(campaign, can_continue(), replays())
	t.start.connect(start_game)
	t.replay.connect(start_replay)
	_swap(t)


func records() -> Dictionary:
	var r := SaveFile.read(records_path)
	if r.is_empty():
		r = {"done": [], "best": {}}
	return r


func replays() -> Array:
	var r := records()
	var out: Array = []
	for i in campaign.jobs.size():
		var e = campaign.jobs[i]
		if e is Dictionary and e.get("timed", false) and i in r.done.map(func(x): return int(x)):
			out.append({"index": i, "subject": e.email.subject, "best": r.best.get(str(i), -1.0)})
	return out


static func clock_text(seconds: float) -> String:
	var t := int(seconds)
	return "%d:%02d" % [t / 60, t % 60]


func start_replay(i: int) -> void:
	sfx.start_music(campaign.get("music", ""))
	replay_index = i
	job_index = i
	var d = Desktop.new()
	d.setup(campaign.jobs[i], sfx)
	d.job_won.connect(_on_job_won)
	_swap(d)
	d.start_clock()


func start_game(resume := false) -> void:
	replay_index = -1
	sfx.start_music(campaign.get("music", ""))
	var st := SaveFile.read(save_path) if resume and saving() else {}
	job_index = clampi(int(st.get("job_index", 0)), 0, campaign.jobs.size() - 1)
	if not resume and saving():
		SaveFile.clear(save_path)
	var d = Desktop.new()
	d.setup(campaign.jobs[job_index], sfx)
	d.job_won.connect(_on_job_won)
	d.changed.connect(func(): _dirty = true)
	_swap(d)
	if not st.is_empty():
		d.import_state(st.get("desk", {}))
	_dirty = false


var endings: Array = []


func _on_job_won(reply: String) -> void:
	if current.has_method("export_state") and current.ending != "":
		endings.append(current.ending)
		var rec := records()
		rec["endings"] = rec.get("endings", []) + [current.ending]
		SaveFile.write(rec, records_path)
	var entry_won = campaign.jobs[job_index]
	if entry_won is Dictionary and entry_won.get("timed", false):
		var r := records()
		if not job_index in r.done.map(func(x): return int(x)):
			r.done.append(job_index)
		if replay_index >= 0:
			var t: float = current.clock_seconds()
			var key := str(job_index)
			if not r.best.has(key) or t < float(r.best[key]):
				r.best[key] = t
		SaveFile.write(r, records_path)
	if replay_index >= 0:
		replay_index = -1
		show_title()
		return
	job_index += 1
	if job_index < campaign.jobs.size():
		var entry = campaign.jobs[job_index]
		current.load_jobs(entry if entry is Array else [entry])
		save_now(true)
	else:
		if saving():
			SaveFile.clear(save_path)
		show_end(reply)


func show_end(reply: String) -> void:
	var e = EndScreen.new()
	e.setup(campaign, reply)
	e.again.connect(func(): start_game(false))
	_swap(e)
