extends SceneTree

const JobData = preload("res://scripts/job_data.gd")

var pace := 0.6


func _initialize() -> void:
	var path := "res://data/campaign.json"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pace="):
			pace = a.substr(7).to_float()
	load("res://scripts/sfx.gd").default_settings_path = "user://speedrun_settings.json"
	var solutions = load("res://tests/solutions.gd").new(self, func(ok, msg): if not ok: print("  !! ", msg))
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	m.campaign = JobData.load_campaign(path)
	m.campaign.save = false
	m.start_game(false)
	await create_timer(pace).timeout
	var total := Time.get_ticks_msec()
	var n := 0
	for idx in m.campaign.jobs.size():
		var d = m.current
		for i in d.slots.size():
			d.select_job(i)
			var t0 := Time.get_ticks_msec()
			await create_timer(pace).timeout
			await solutions.solve(m, d, d.job)
			n += 1
			print("%2d. %-26s %5.1fs  %s" % [n, d.job.email.subject, (Time.get_ticks_msec() - t0) / 1000.0, "won" if d.finished else "NOT WON"])
		await create_timer(2.4 + pace).timeout
	print("all %d levels in %.1fs. ending screen: %s" % [n, (Time.get_ticks_msec() - total) / 1000.0, m.current.get_script().resource_path.get_file()])
	await create_timer(2.0).timeout
	quit()
