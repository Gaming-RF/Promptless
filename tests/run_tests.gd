extends SceneTree
## Headless checks: godot --headless --path . -s tests/run_tests.gd

const JobData = preload("res://scripts/job_data.gd")
const Shell = preload("res://scripts/shell.gd")
const Judge = preload("res://scripts/judge.gd")

var fails := 0


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func rec(file: String, w: float, h: float) -> Dictionary:
	return {"name": "s.png", "windows": [{"file": file, "w": w, "h": h}]}


func _initialize() -> void:
	var job := JobData.load_job("res://data/job_bounce_back.json")
	var sh = Shell.new(job)

	check(job.notes.size() == 30, "notes file has 30 lines")
	var r: Dictionary = sh.run("ls")
	check(r.out.size() == 1 and r.out[0].split("  ").size() == 6, "ls lists six files: " + str(r.out))
	r = sh.run("grep Comets notes.txt")
	check(r.out.size() == 1 and "ball 3" in r.out[0], "grep Comets prints exactly one line naming ball 3")
	r = sh.run("grep comets notes.txt")
	check(r.out.is_empty() and r.hint.size() == 1, "grep is case-sensitive (+ hint)")
	r = sh.run("grep -i comets notes.txt")
	check(r.out.size() == 1, "grep -i works")
	r = sh.run("grep \"Comets game\" ./notes.txt")
	check(r.out.size() == 1, "quoted word + ./ path")
	r = sh.run("grep Comets nope.txt")
	check("No such file" in r.out[0], "grep missing file")
	r = sh.run("open notes.txt")
	check(r.out == [job.shell.open_notes] and r.open == "", "open notes.txt -> chaos line")
	r = sh.run("open /clients/dex/ball_3.png")
	check(r.open == "ball_3.png", "open full path picture")
	r = sh.run("cat notes.txt")
	check(r.out[0].begins_with("cat:"), "unknown command funny line")
	r = sh.run("ls | grep x")
	check(r.out == [job.shell.pipes], "pipes not supported")

	check(Judge.verdict(null, job) == "no_attachment", "no attachment")
	check(Judge.verdict(rec("ball_3.png", 154, 166), job) == "right", "154x166 passes")
	check(Judge.verdict(rec("ball_3.png", 166, 154), job) == "right", "166x154 passes")
	check(Judge.verdict(rec("ball_3.png", 153, 160), job) == "wrong_shape", "153 fails")
	check(Judge.verdict(rec("ball_3.png", 160, 167), job) == "wrong_shape", "167 fails")
	check(Judge.verdict(rec("ball_3.png", 96, 160), job) == "wrong_shape", "unstretched -> egg")
	check(Judge.verdict(rec("ball_1.png", 160, 160), job) == "wrong_file", "wrong ball round -> wrong ball")
	check(Judge.verdict(rec("ball_1.png", 96, 160), job) == "wrong_file", "wrong ball squashed -> wrong ball wins")

	# Integration: drive the real desktop.
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.start_game()
	await process_frame
	var desk = main.current
	desk.run_command("open ball_3.png")
	desk.run_command("open ball_1.png")
	await process_frame
	var w3 = desk.pictures["ball_3.png"]
	var w1 = desk.pictures["ball_1.png"]
	check(w3.get_content_size() == Vector2(96, 160), "ball 3 opens at 96x160")
	check(w3.position.x + w3.size.x <= 640 and w3.position.y + w3.size.y <= 360, "ball 3 window on screen")
	desk.send()
	check(desk.email.last_reply == job.replies.no_attachment, "send with nothing")
	desk.snapshot(w3)
	desk.send()
	check(desk.email.last_reply == job.replies.wrong_shape, "desktop: squashed -> egg reply")
	w1.set_content_size(Vector2(160, 160))
	desk.snapshot(w1)
	desk.send()
	check(desk.email.last_reply == job.replies.wrong_file, "desktop: wrong ball reply")
	w3.set_content_size(Vector2(160, 160))
	desk.snapshot(w3)
	desk.send()
	check(desk.email.last_reply == job.replies.right and desk.finished, "desktop: win")
	await create_timer(2.5).timeout
	check(main.current.get_script().resource_path.ends_with("end_screen.gd"), "end screen shown")
	print("\n%d failure(s)" % fails)
	quit(1 if fails else 0)
