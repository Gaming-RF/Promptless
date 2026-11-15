extends Control

const CAMPAIGN_PATH := "res://data/campaign.json"
const UI = preload("res://scripts/ui.gd")
const JobData = preload("res://scripts/job_data.gd")
const Sfx = preload("res://scripts/sfx.gd")
const Desktop = preload("res://scripts/desktop.gd")
const TitleScreen = preload("res://scripts/title_screen.gd")
const EndScreen = preload("res://scripts/end_screen.gd")

var campaign: Dictionary
var job_index := 0
var sfx: Node
var current: Node


func _ready() -> void:
	theme = UI.make_theme()
	campaign = JobData.load_campaign(CAMPAIGN_PATH)
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
	t.setup(campaign)
	t.start.connect(start_game)
	_swap(t)


func start_game() -> void:
	sfx.start_music(campaign.get("music", ""))
	job_index = 0
	var d = Desktop.new()
	d.setup(campaign.jobs[0], sfx)
	d.job_won.connect(_on_job_won)
	_swap(d)


func _on_job_won(reply: String) -> void:
	job_index += 1
	if job_index < campaign.jobs.size():
		current.load_job(campaign.jobs[job_index])
	else:
		show_end(reply)


func show_end(reply: String) -> void:
	var e = EndScreen.new()
	e.setup(campaign, reply)
	e.again.connect(start_game)
	_swap(e)
