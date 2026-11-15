extends Control
## Title -> desktop (the job) -> end screen. The job lives in one JSON file.

const JOB_PATH := "res://data/job_bounce_back.json"
const UI = preload("res://scripts/ui.gd")
const JobData = preload("res://scripts/job_data.gd")
const Sfx = preload("res://scripts/sfx.gd")
const Desktop = preload("res://scripts/desktop.gd")
const TitleScreen = preload("res://scripts/title_screen.gd")
const EndScreen = preload("res://scripts/end_screen.gd")

var job: Dictionary
var sfx: Node
var current: Node


func _ready() -> void:
	theme = UI.make_theme()
	job = JobData.load_job(JOB_PATH)
	sfx = Sfx.new()
	add_child(sfx)
	show_title()


func _swap(n: Node) -> void:
	if current:
		current.queue_free()
	current = n
	add_child(n)


func show_title() -> void:
	var t = TitleScreen.new()
	t.setup(job)
	t.start.connect(start_game)
	_swap(t)


func start_game() -> void:
	var d = Desktop.new()
	d.setup(job, sfx)
	d.won.connect(show_end)
	_swap(d)


func show_end(reply: String) -> void:
	var e = EndScreen.new()
	e.setup(job, reply)
	e.again.connect(start_game)
	_swap(e)
