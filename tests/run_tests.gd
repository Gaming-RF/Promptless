extends SceneTree

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


func words(t: String) -> int:
	return t.split(" ", false).size()


func check_job_data(job: Dictionary) -> void:
	var tag: String = "[%s] " % job.folder
	var word: String = job.search_word
	var hits := 0
	for f in job.texts:
		for l in job.texts[f]:
			if l.contains(word):
				hits += 1
	check(hits == 1, tag + "exactly one text line contains '%s' (found %d)" % [word, hits])
	check(job.email.body.contains(word), tag + "email spells the search word the same way")
	check(words(job.email.body) < 60, tag + "email under 60 words (%d)" % words(job.email.body))
	for k in ["right", "wrong_file", "wrong_shape", "wrong_size", "no_attachment"]:
		check(job.replies.has(k) and words(job.replies[k]) < 30, tag + "reply '%s' exists, under 30 words" % k)
	var t: Dictionary = job.target
	for p in job.pictures:
		var sz: Array = p.open_size
		check(absf(sz[0] - t.w) <= t.tolerance or absf(sz[1] - t.h) <= t.tolerance,
			tag + "%s opens with one side at target" % p.file)
	var answer_ok := false
	for p in job.pictures:
		answer_ok = answer_ok or p.file == job.answer
	check(answer_ok, tag + "answer file exists")
	var sh = Shell.new(job)
	var key_line := ""
	for f in job.texts:
		var r: Dictionary = sh.run("grep %s %s" % [word, f])
		if r.out.size() == 1:
			key_line = r.out[0]
	var n: int = String(job.answer).get_basename().get_slice("_", 1).to_int()
	check(key_line != "" and key_line.contains(str(n)), tag + "grep line names the answer number")
	var w: float = t.w
	var h: float = t.h
	check(Judge.verdict(rec(job.answer, w, h), job) == "right", tag + "target size wins")
	check(Judge.verdict(rec(job.answer, w - t.tolerance, h + t.tolerance), job) == "right", tag + "edge of tolerance wins")
	check(Judge.verdict(rec(job.answer, w - t.tolerance - 1, h), job) == "wrong_shape", tag + "just outside tolerance = egg")
	check(Judge.verdict(rec(job.answer, 100, 100), job) == "wrong_size", tag + "round but too small = wrong size")
	check(Judge.verdict(rec(job.answer, w + 20, h + 20), job) == "wrong_size", tag + "round but too big = wrong size")
	check(Judge.verdict(rec(job.answer, 100, h), job) == "wrong_shape", tag + "squashed = egg, not wrong size")
	var other: String = job.pictures[0].file if job.pictures[0].file != job.answer else job.pictures[1].file
	check(Judge.verdict(rec(other, w, h), job) == "wrong_file", tag + "wrong picture at target = wrong file")


func _initialize() -> void:
	var c := JobData.load_campaign("res://data/campaign.json")
	check(c.jobs.size() == 2, "campaign has 2 jobs")
	for j in c.jobs:
		check_job_data(j)

	var job: Dictionary = c.jobs[0]
	var sh = Shell.new(job)
	check(job.texts["notes.txt"].size() == 30, "job 1 notes has 30 lines")
	var r: Dictionary = sh.run("ls")
	check(r.out[0].split("  ").size() == 6, "ls lists six files")
	r = sh.run("grep comets notes.txt")
	check(r.out.is_empty() and r.hint.size() == 1, "grep is case-sensitive (+ hint)")
	r = sh.run("grep -i comets notes.txt")
	check(r.out.size() == 1, "grep -i works")
	r = sh.run("grep \"Comets game\" ./notes.txt")
	check(r.out.size() == 1, "quoted word + ./ path")
	r = sh.run("open notes.txt")
	check(r.out == ["30 lines of chaos. Try grep."], "open notes.txt -> chaos line: " + str(r.out))
	r = sh.run("open /clients/dex/ball_3.png")
	check(r.open == "ball_3.png", "open full path picture")
	r = sh.run("open ball 3")
	check(r.open == "" and r.hint.size() == 1 and "ball_3.png" in r.hint[0], "open ball 3 -> did you mean ball_3.png")
	r = sh.run("open bal_3.png")
	check(r.hint.size() == 1 and "ball_3.png" in r.hint[0], "typo file -> did you mean")
	r = sh.run("gerp Comets notes.txt")
	check("did you mean grep" in r.out[0], "gerp -> did you mean grep")
	r = sh.run("frobnicate")
	check(r.out == ["frobnicate: command not found. try help"], "unknown command line")
	r = sh.run("cat notes.txt")
	check(r.out.size() == 30, "cat prints the whole file")
	r = sh.run("head -n 3 notes.txt")
	check(r.out.size() == 3 and sh.run("head -5 notes.txt").out.size() == 5 and sh.run("head notes.txt").out.size() == 10, "head -n N / -N / default 10")
	r = sh.run("cat ball_3.png")
	check("picture" in r.out[0], "cat on a picture")
	r = sh.run("mv ball_3.png ball_9.png")
	check("Read-only" in r.out[0], "mv: client folder is read-only")
	check(sh.run("pwd").out == ["/clients/dex"], "pwd")
	check(sh.run("echo hi there").out == ["hi there"], "echo")
	check("pixview" in sh.run("alias").out[0], "alias reveals open = pixview")
	check(sh.run("clear").clear, "clear")
	r = sh.run("history")
	check(r.out.size() == sh.history.size() and r.out[-1].ends_with("history"), "history lists commands")
	r = sh.run("ps", [{"pid": 101, "cmd": "sh"}, {"pid": 140, "cmd": "pixview ball_3.png"}])
	check(r.out.size() == 3 and "pixview ball_3.png" in r.out[2], "ps lists programs from the desktop")
	check(sh.run("hlep").out[0].contains("did you mean help"), "typo of courtesy command")
	r = sh.run("ls | grep x")
	check(r.out == [job.shell.pipes], "pipes not supported")
	check(sh.complete("gr").line == "grep ", "tab: command")
	check(sh.complete("hi").line == "history ", "tab: courtesy command")
	check(sh.complete("grep Comets no").line == "grep Comets notes.txt ", "tab: file")
	var amb: Dictionary = sh.complete("open ba")
	check(amb.line == "open ball_" and amb.options.is_empty(), "tab: common prefix")
	amb = sh.complete("open ball_")
	check(amb.options.size() == 5, "tab: lists options when stuck")
	var sh2 = Shell.new(c.jobs[1])
	r = sh2.run("grep Gold notes.txt")
	check(r.out.is_empty(), "job 2: notes.txt only has lowercase gold")
	r = sh2.run("grep Gold coach.txt notes.txt")
	check(r.out.size() == 1 and r.out[0].begins_with("coach.txt:"), "job 2: multi-file grep prefixes names")

	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.start_game()
	await process_frame
	var desk = main.current
	check(main.sfx.music.playing and main.sfx.music.stream.loop, "music plays and loops after boot")
	main.sfx.toggle_music()
	check(not main.sfx.music.playing, "music toggle off stops it")
	main.sfx.toggle_music()
	check(main.sfx.music.playing, "music toggle on restarts it")
	desk.run_command("open ball_3.png")
	desk.run_command("open ball_1.png")
	await process_frame
	var w3 = desk.pictures["ball_3.png"]
	var w1 = desk.pictures["ball_1.png"]
	check(w3.get_content_size() == Vector2(96, 160), "ball 3 opens at 96x160")
	desk.send()
	check(desk.email.last_reply == job.replies.no_attachment, "send with nothing")
	desk.snapshot(w3)
	desk.send()
	check(desk.email.last_reply == job.replies.wrong_shape, "squashed -> egg reply")
	w1.set_content_size(Vector2(160, 160))
	desk.snapshot(w1)
	desk.send()
	check(desk.email.last_reply == job.replies.wrong_file, "wrong ball reply")
	w3.set_content_size(Vector2(160, 160))
	desk.snapshot(w3)
	desk.send()
	check(desk.email.last_reply == job.replies.right and desk.finished, "job 1 won")
	await create_timer(2.6).timeout
	check(main.current == desk and desk.job == c.jobs[1], "job 2 loads on the same desktop")
	check(desk.pictures.is_empty() and not desk.finished, "job 2 starts clean")
	var job2: Dictionary = c.jobs[1]
	desk.run_command("open " + job2.answer)
	await process_frame
	var wa = desk.pictures[job2.answer]
	wa.set_content_size(Vector2(job2.target.w, job2.target.h))
	desk.snapshot(wa)
	desk.send()
	check(desk.email.last_reply == job2.replies.right, "job 2 won")
	await create_timer(2.6).timeout
	check(main.current.get_script().resource_path.ends_with("end_screen.gd"), "end screen after last job")
	main.current.again.emit()
	await process_frame
	check(main.current.job == c.jobs[0] and main.current.pictures.is_empty(), "play again restarts at job 1, clean")
	var r2: Dictionary = Shell.new(c.jobs[1]).run("grep Gold notes.txt")
	check(r2.hint == ["(nothing in that file. Coach keeps his own notes.)"], "job 2 overrides the no-match hint")
	print("\n%d failure(s)" % fails)
	quit(1 if fails else 0)
