extends SceneTree

const JobData = preload("res://scripts/job_data.gd")
const Shell = preload("res://scripts/shell.gd")
const Judge = preload("res://scripts/judge.gd")

var fails := 0
var medal: Dictionary


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func rec(file: String, w: float, h: float) -> Dictionary:
	return {"name": "s.png", "windows": [{"file": file, "w": w, "h": h}]}


func words(t: String) -> int:
	return t.split(" ", false).size()


func reply_words_ok(r) -> bool:
	if r is Array:
		return r.all(func(x): return words(x) < 30)
	return words(r) < 30


func check_job_data(job: Dictionary) -> void:
	var tag: String = "[%s] " % job.folder
	var errs: Array = JobData.validate(job)
	check(errs.is_empty(), tag + "job file is valid " + str(errs))
	var kind: String = job.get("check", "stretch")
	if job.has("search_word"):
		var word: String = job.search_word
		var hits := 0
		for f in job.texts:
			for l in job.texts[f]:
				if l.contains(word):
					hits += 1
		check(hits == 1, tag + "exactly one text line contains '%s' (found %d)" % [word, hits])
		check(job.email.body.contains(word), tag + "email spells the search word the same way")
	check(words(job.email.body) < 60, tag + "email under 60 words (%d)" % words(job.email.body))
	var need: Array = ["right", "no_attachment"]
	if kind in ["stretch", "overlay", "join"]:
		need += ["wrong_file", "wrong_shape"]
	if kind == "stretch":
		need.append("wrong_size")
	if job.get("single", false):
		need.append("crowded")
	if job.has("strikes"):
		need.append("give_up")
	for k in need:
		check(job.replies.has(k) and reply_words_ok(job.replies[k]), tag + "reply '%s' exists, under 30 words" % k)
	if kind != "stretch" or job.pictures.is_empty():
		return
	var t: Dictionary = job.target
	for p in job.pictures:
		var sz: Array = p.open_size
		check(absf(sz[0] - t.w) <= t.tolerance or absf(sz[1] - t.h) <= t.tolerance,
			tag + "%s opens with one side at target" % p.file)
	var j := JobData.instantiate(job)
	if not j.has("search_word"):
		check(Judge.verdict(rec(j.answer, t.w, t.h), j) == "right", tag + "target size wins")
		return
	var sh = Shell.new(j)
	var key_line := ""
	for f in j.texts:
		var r: Dictionary = sh.run("grep %s %s" % [j.search_word, f])
		if r.out.size() == 1:
			key_line = r.out[0]
	var n: int = String(j.answer).get_basename().get_slice("_", 1).to_int()
	check(key_line != "" and key_line.contains(str(n)), tag + "grep line names the answer number")
	var w: float = t.w
	var h: float = t.h
	check(Judge.verdict(rec(j.answer, w, h), j) == "right", tag + "target size wins")
	check(Judge.verdict(rec(j.answer, w - t.tolerance, h + t.tolerance), j) == "right", tag + "edge of tolerance wins")
	check(Judge.verdict(rec(j.answer, w - t.tolerance - 1, h), j) == "wrong_shape", tag + "just outside tolerance = egg")
	check(Judge.verdict(rec(j.answer, 100, 100), j) == "wrong_size", tag + "round but too small = wrong size")
	var other: String = j.pictures[0].file if j.pictures[0].file != j.answer else j.pictures[1].file
	check(Judge.verdict(rec(other, w, h), j) == "wrong_file", tag + "wrong picture at target = wrong file")


func check_file_system(base: Dictionary) -> void:
	var job := JobData.merge(base, {"extra_files": [
		{"path": ".album", "type": "dir"},
		{"path": ".album/faded_1.png", "type": "picture", "open_size": [120, 90], "asset": "res://assets/ball_1.png"},
		{"path": ".album/readme.txt", "type": "text", "lines": ["two copies. lay one over the other."]},
	]})
	var sh = Shell.new(job)
	check(not ".album" in sh.run("ls").out[0], "fs: hidden folder not in ls")
	check(".album" in sh.run("ls -a").out[0] and sh.run("ls -a").out[0].begins_with(".  .."), "fs: ls -a shows hidden + . ..")
	sh.run("cd .album")
	check(sh.cwd == "/clients/dex/.album" and sh.run("pwd").out == ["/clients/dex/.album"], "fs: cd into hidden folder, pwd")
	check(sh.run("ls").out == ["faded_1.png  readme.txt"], "fs: ls inside folder")
	check(sh.run("cat readme.txt").out.size() == 1 and sh.run("grep copies ../.album/readme.txt").out.size() == 1, "fs: relative paths, ..")
	check(sh.run("open faded_1.png").open == "/clients/dex/.album/faded_1.png", "fs: open in subfolder")
	sh.run("cd ..")
	check(sh.cwd == "/clients/dex", "fs: cd ..")
	sh.run("cd")
	check(sh.cwd == "/home/you", "fs: cd alone = home")
	sh.run("cd ~")
	check(sh.cwd == "/home/you", "fs: cd ~")
	check(sh.run("cd /nope").out[0] == "cd: /nope: No such file or directory", "fs: cd missing")
	check(sh.run("cd /clients/dex/notes.txt").out[0].ends_with("Not a directory"), "fs: cd into a file")
	check(sh.run("cat /clients/dex").out[0].ends_with("Is a directory"), "fs: cat a folder")
	check(sh.run("grep x /clients").out[0].ends_with("Is a directory"), "fs: grep a folder")
	check("Read-only" in sh.run("mv /clients/dex/notes.txt ~/n.txt").out[0], "fs: client folder read-only")
	sh.fs.add_file("/home/you/snap.png", {"type": "picture", "open_size": [10, 10]})
	sh.run("mkdir x")
	sh.fs.add_dir("/home/you/keep")
	check(sh.run("mv snap.png keep").out.is_empty() and sh.fs.exists("/home/you/keep/snap.png"), "fs: mv into folder in home")
	sh.run("mv keep stuff")
	check(sh.fs.exists("/home/you/stuff/snap.png") and not sh.fs.exists("/home/you/keep"), "fs: mv a folder moves contents")
	check(sh.run("mv stuff stuff/inner").out[0].contains("into itself"), "fs: mv folder into itself refused")
	check(sh.run("man ls").out[0] == "LS(1)" and sh.run("man").out == [job.shell.man_usage], "man page + usage")
	check(sh.run("man frob").out == ["No manual entry for frob"], "man unknown")
	sh.run("cd /clients/dex")
	check(sh.complete("cd .al").line == "cd .album/", "tab: hidden folder gets a slash, no space")
	check(sh.complete("open .album/fa").line == "open .album/faded_1.png ", "tab: completes inside a folder path")


func tobi_job(base: Dictionary) -> Dictionary:
	return JobData.merge(base, {"extra_files": [
		{"path": "chart.sh", "type": "script", "x": false, "opens": "chart.png", "copies": 3, "prints": ["drawing chart..."]},
		{"path": "chart.png", "type": "picture", "open_size": [160, 90], "asset": "res://assets/ball_1.png"},
		{"path": "secret.txt", "type": "text", "r": false, "lines": ["hidden"]},
	]})


func check_permissions(base: Dictionary) -> void:
	var sh = Shell.new(tobi_job(base))
	check(sh.run("./chart.sh").out == ["sh: ./chart.sh: Permission denied"], "perm: script without +x refused")
	check("Operation not permitted" in sh.run("chmod +x chart.sh").out[0], "perm: chmod on a client file refused")
	check(sh.run("cp chart.sh ~").out.is_empty() and sh.fs.exists("/home/you/chart.sh"), "perm: cp to home")
	check(sh.run("cp chart.sh /clients/x.sh").out[0].ends_with("Permission denied") or sh.run("cp chart.sh /clients/x.sh").out[0].contains("No such"), "perm: cp into a client folder refused")
	sh.run("cd ~")
	check(sh.run("ls -l").out[0].begins_with("-rw-r--r-- you"), "perm: ls -l before chmod: " + str(sh.run("ls -l").out))
	check(sh.run("chmod +x chart.sh").out.is_empty(), "perm: chmod +x on own file")
	check(sh.run("ls -l").out[0].begins_with("-rwxr-xr-x you"), "perm: ls -l after chmod")
	var r: Dictionary = sh.run("./chart.sh")
	check(r.out == ["drawing chart..."] and r.launch.count == 4 and r.launch.path == "/clients/dex/chart.png", "perm: script runs and launches 4 windows")
	check(sh.run("chmod -x chart.sh").out.is_empty() and "Permission denied" in sh.run("./chart.sh").out[0], "perm: chmod -x stops it again")
	check(sh.run("chmod 755 chart.sh").out.is_empty() and sh.run("./chart.sh").launch.count == 4, "perm: octal chmod")
	check("invalid mode" in sh.run("chmod lol chart.sh").out[0], "perm: bad mode")
	check(sh.run("open chart.sh").out[0].contains("./chart.sh"), "perm: open on a script points at ./")
	sh.run("cd /clients/dex")
	check(sh.run("cat secret.txt").out == ["cat: secret.txt: Permission denied"], "perm: unreadable file")
	check("Permission denied" in sh.run("grep hidden secret.txt").out[0], "perm: grep unreadable")
	check("Permission denied" in sh.run("cp secret.txt ~").out[0], "perm: cp unreadable")
	check(sh.run("kill").out == [base.shell.kill_usage], "kill usage")
	check(sh.run("kill 999", [{"pid": 101, "cmd": "sh", "protected": true}]).out[0] == "kill: (999) - No such process", "kill missing pid")
	check("holding this whole machine" in sh.run("kill 101", [{"pid": 101, "cmd": "sh", "protected": true}]).out[0], "kill protected program")
	check(sh.run("kill 140", [{"pid": 140, "cmd": "pixview x"}]).kill == 140, "kill a viewer")


func pic(path: String, w: int, h: int, asset: String) -> Dictionary:
	return {"path": path, "type": "picture", "open_size": [w, h], "asset": asset}


func overlay_job(base: Dictionary) -> Dictionary:
	return JobData.merge(base, {"tools": ["trace"], "check": "overlay",
		"overlay": {"top": "note.png", "under": "memo.png", "align": 6},
		"extra_files": [pic("memo.png", 120, 120, "res://assets/ball_2.png"), pic("note.png", 120, 120, "res://assets/ball_1.png")]})


func join_job(base: Dictionary) -> Dictionary:
	return JobData.merge(base, {"tools": ["join"], "check": "join",
		"join": {"order": ["p1.png", "p2.png", "p3.png"]},
		"extra_files": [pic("p1.png", 80, 120, "res://assets/ball_1.png"), pic("p2.png", 80, 120, "res://assets/ball_2.png"), pic("p3.png", 80, 120, "res://assets/ball_3.png")]})


func check_window_tools(d, base: Dictionary) -> void:
	d.load_job(base)
	var b3 = d.open_picture("/clients/dex/ball_3.png", false, false)
	var b1 = d.open_picture("/clients/dex/ball_1.png", false, false)
	b1.position = b3.position
	d.snapshot(b1)
	check(d.attachment.windows.size() == 1, "jam jobs: overlapping windows are not captured together")
	check(not b1._buttons.get_children().any(func(x): return x.text == "TRACE"), "jam jobs: no TRACE button")
	b1.position = b3.position + Vector2(110, 0)
	var got: bool = d.snapshot_rect(Rect2(0, 0, 640, 360))
	check(got and d.attachment.windows.size() == 2, "rect: a big rectangle catches every window inside")
	check(Judge.verdict(d.attachment, base) == "wrong_file", "rect: a collage doesn't count as the ball photo")
	check(not d.snapshot_rect(Rect2(0, 0, 20, 20)), "rect: an empty rectangle snaps nothing")
	check(d.snapshot_rect(b3.get_rect()) and d.attachment.windows.size() == 1 and d.attachment.windows[0].file.ends_with("ball_3.png"), "rect: a rectangle around one window")
	b3.set_content_size(Vector2(160, 160))
	b1.set_content_size(Vector2(40, 40))
	b1.position = b3.position + Vector2(20, 30)
	b3.move_to_front()
	d.snapshot(b3)
	check(d.attachment.windows.size() == 1 and Judge.verdict(d.attachment, base) == "right", "SNAP button: a smaller picture hidden behind doesn't spoil it")

	var oj := overlay_job(base)
	d.load_job(oj)
	var memo = d.open_picture("/clients/dex/memo.png")
	var note = d.open_picture("/clients/dex/note.png")
	note.position = memo.position
	d.snapshot(note)
	check(d.attachment.windows.size() == 1 and Judge.verdict(d.attachment, oj) == "wrong_file", "overlay: SNAP on an untraced note records just the note")
	note.set_tracing(true)
	check(note.see_through and note.view.material != null and note._trace_btn.text == "TRACING", "overlay: tracing mode on")
	d.snapshot(note)
	check(d.attachment.windows.size() == 2 and Judge.verdict(d.attachment, oj) == "right", "overlay: traced + aligned = right")
	note.position = memo.position + Vector2(20, 0)
	d.snapshot(note)
	check(Judge.verdict(d.attachment, oj) == "wrong_shape", "overlay: misaligned = wrong shape")
	note.position = memo.position
	memo.move_to_front()
	d.snapshot(note)
	check(Judge.verdict(d.attachment, oj) == "wrong_shape", "overlay: tracing sheet underneath = wrong shape")

	var jj := join_job(base)
	d.load_job(jj)
	var p1 = d.open_picture("/clients/dex/p1.png")
	var p2 = d.open_picture("/clients/dex/p2.png")
	var p3 = d.open_picture("/clients/dex/p3.png")
	p1.position = Vector2(330, 40)
	p2.position = p1.position + Vector2(p1.size.x + 4, 3)
	d._on_drag_finished(p2)
	check(p2.position == p1.position + Vector2(p1.size.x, 0), "join: snaps flush and aligned (%s)" % p2.position)
	check(d.group_of(p1).size() == 2, "join: two windows grouped")
	p1.position += Vector2(5, 5)
	d._on_window_moved(p1, Vector2(5, 5))
	check(p2.position == p1.position + Vector2(p1.size.x, 0), "join: group moves as one")
	p3.position = p2.position + Vector2(p2.size.x - 3, 200)
	d._on_drag_finished(p3)
	check(d.group_of(p3).size() == 1, "join: far window doesn't snap")
	p3.position = p2.position + Vector2(p2.size.x - 3, -2)
	d._on_drag_finished(p3)
	check(d.group_of(p1).size() == 3, "join: chain of three")
	d.snapshot(p2)
	check(d.attachment.order == ["/clients/dex/p1.png", "/clients/dex/p2.png", "/clients/dex/p3.png"], "join: record holds page order")
	check(Judge.verdict(d.attachment, jj) == "right", "join: right order = right")
	d.load_job(jj)
	p1 = d.open_picture("/clients/dex/p1.png")
	p2 = d.open_picture("/clients/dex/p2.png")
	p2.position = Vector2(330, 40)
	p1.position = p2.position + Vector2(p2.size.x + 2, 0)
	d._on_drag_finished(p1)
	d.snapshot(p1)
	check(Judge.verdict(d.attachment, jj) == "wrong_file", "join: missing page = wrong file")
	p3 = d.open_picture("/clients/dex/p3.png")
	p3.position = p1.position + Vector2(p1.size.x + 2, 0)
	d._on_drag_finished(p3)
	d.snapshot(p1)
	check(Judge.verdict(d.attachment, jj) == "wrong_shape", "join: wrong order = wrong shape")


func late_job(base: Dictionary) -> Dictionary:
	return JobData.merge(base, {
		"users": {"you": {"password": "hunter2", "sudo": false}, "marta": {"password": "lighthouse", "sudo": true}},
		"extra_files": [
			{"path": "index.txt", "type": "text", "lines": ["page 3: rent", "Page 1: wages", "page 2: coal", "10 boxes", "9 boxes"]},
			{"path": "ledger.zip", "type": "archive", "password": "1953", "contents": [
				{"path": "scans", "type": "dir"},
				{"path": "scans/p1.png", "type": "picture", "open_size": [80, 120]},
				{"path": "scans/notes.txt", "type": "text", "lines": ["in order please"]}]},
			{"path": "open.zip", "type": "archive", "contents": [{"path": "a.txt", "type": "text", "lines": ["hi"]}]},
			{"path": "/home/marta/drill.txt", "type": "text", "private": true, "lines": ["the switch is here"]},
			{"path": "/home/marta/off.sh", "type": "script", "x": true, "prints": ["ok"]},
			{"path": "/home/marta/.drill", "type": "dir", "private": true},
		]})


func check_late_commands(base: Dictionary) -> void:
	var job := late_job(base)
	var sh = Shell.new(job)
	check(sh.run("sort index.txt").out == ["10 boxes", "9 boxes", "Page 1: wages", "page 2: coal", "page 3: rent"], "sort: alphabetical, ignores capitals")
	check(sh.run("sort -r index.txt").out[0] == "page 3: rent", "sort -r")
	check(sh.run("sort -n index.txt").out.slice(-2) == ["9 boxes", "10 boxes"], "sort -n by leading number")
	check(sh.run("sort").out == [job.shell.sort_usage], "sort usage")
	var r: Dictionary = sh.run("unzip ledger.zip")
	check(r.out[0].contains("Read-only"), "unzip: refuses to write into the client folder")
	r = sh.run("unzip ledger.zip -d ~")
	check(r.ask.contains("password") and not sh.pending.is_empty(), "unzip: locked archive asks for a password")
	r = sh.run("nope")
	check(r.out == [job.shell.unzip_wrong] and not sh.fs.exists("/home/you/scans/p1.png"), "unzip: wrong password extracts nothing")
	check(sh.history.back() == "unzip ledger.zip -d ~", "password answers stay out of history")
	sh.run("unzip ledger.zip -d ~")
	r = sh.run("1953")
	check(sh.fs.exists("/home/you/scans/p1.png") and sh.fs.node("/home/you/scans/p1.png").asset.ends_with("p1.png") and r.out.size() == 3, "unzip: right password inflates files and folders")
	check(sh.run("unzip open.zip -d ~").ask == "" and sh.fs.exists("/home/you/a.txt"), "unzip: unlocked archive needs no password")
	check(sh.run("cat /home/marta/drill.txt").out[0].ends_with("Permission denied"), "private file of another user")
	check(sh.run("ls /home/marta/.drill").out == ["ls: cannot open directory '/home/marta/.drill': Permission denied"], "ls a private folder refused")
	check(sh.run("cd /home/marta/.drill").out == ["cd: /home/marta/.drill: Permission denied"], "cd into a private folder refused")
	check(sh.run("su ghost").out[0].contains("does not exist"), "su: unknown user")
	sh.run("su marta")
	check(sh.run("wrong").out == [job.shell.su_wrong] and sh.fs.user == "you", "su: wrong password")
	sh.run("su marta")
	sh.run("lighthouse")
	check(sh.fs.user == "marta" and sh.cwd == "/home/marta" and sh.prompt() == "marta$", "su: becomes marta, in her home, prompt shows it")
	check(sh.run("whoami").out == ["marta"] and sh.run("cat drill.txt").out == ["the switch is here"], "su: can read her private files")
	check(sh.run("./off.sh").out == ["ok"], "su: marta runs her script")
	check(sh.run("cd .drill").out.is_empty() and sh.cwd == "/home/marta/.drill", "su: owner can enter her private folder")
	sh.run("cd ~")
	sh.run("exit")
	check(sh.fs.user == "you" and sh.prompt() == "$", "exit: back to you")
	check(sh.run("exit").out == [job.shell.exit_last], "exit with nowhere to go")
	check(sh.run("sudo cat /home/marta/drill.txt").out[0].contains("sudoers"), "sudo: you aren't allowed")
	sh.run("su marta")
	sh.run("lighthouse")
	r = sh.run("sudo cat /clients/dex/notes.txt")
	check(r.ask == "[sudo] password for marta:", "sudo: asks for your own password")
	r = sh.run("lighthouse")
	check(r.out.size() == 30 and sh.fs.user == "marta", "sudo: runs one command, then back to marta")
	sh.run("sudo mv /clients/dex/notes.txt /clients/dex/n.txt")
	sh.run("lighthouse")
	check(sh.fs.exists("/clients/dex/n.txt"), "sudo: root can change client folders")
	sh.run("sudo ls")
	check(sh.run("bad").out == [job.shell.sudo_wrong], "sudo: wrong password")


func check_runner(d, base: Dictionary) -> void:
	d.load_job(base)
	check(not d.sticky.visible, "jam: no sticky note")
	d.run_command("open notes.txt")
	check(d.texts.is_empty(), "jam: no text viewer")
	d.load_job(JobData.merge(base, {"tools": ["textview"]}))
	d.run_command("open notes.txt")
	check(d.texts.size() == 1 and d.texts.values()[0].body.get_parsed_text().contains("Comets game ball"), "textview: open shows the file")
	check(d.texts.values()[0]._title_label.text.ends_with("notes.txt"), "textview: titled with PID + name")
	check(d.running_programs().any(func(p): return p.cmd == "textview notes.txt"), "textview: in ps")
	d.run_command("kill %d" % d.texts.values()[0].pid)
	check(d.texts.is_empty(), "textview: kill closes it")

	d.load_job(JobData.merge(base, {"sticky": {"lines": ["ls", "grep WORD FILE", "open FILE"], "paste": true}}))
	check(d.sticky.visible and d.sticky.box.get_child_count() == 3, "sticky: shows learned commands")
	d.sticky.box.get_child(1).pressed.emit()
	check(d.term.input.text == "grep ", "sticky: click pastes the command")
	d.load_job(JobData.merge(base, {"sticky": {"lines": ["ls", "cd FOLDER"], "paste": false}}))
	await process_frame
	check(d.sticky.box.get_children().filter(func(c): return not c.is_queued_for_deletion()).all(func(c): return c is Label), "sticky: read-only later")

	var sj := JobData.merge(base, {"strikes": 3, "shuffle": true,
		"texts": {"notes.txt": ["junk", "Comets game ball = ball {answer_n}."]},
		"replies": {"wrong_file": ["that's not it. is it?", "not that one either??", "no"], "give_up": "ok i'll ask someone else"}})
	d.load_job(sj)
	var first: String = d.job.answer
	var n1 := first.get_basename().get_slice("_", 1)
	check(d.shell.run("grep Comets notes.txt").out == ["Comets game ball = ball %s." % n1], "shuffle: notes name the current answer")
	var wrong: String = "ball_1.png" if first != "ball_1.png" else "ball_2.png"
	var ww = d.open_picture(d.job.folder + "/" + wrong)
	var replies: Array = []
	for i in 3:
		d.snapshot(ww)
		d.send()
		replies.append(d.email.last_reply)
	check(replies == ["that's not it. is it?", "not that one either??", "ok i'll ask someone else"], "strikes: shorter, more panicked, then gives up: " + str(replies))
	d.send()
	check(d.email.last_reply == "ok i'll ask someone else", "strikes: no more sends after giving up")
	await create_timer(2.4).timeout
	check(d.job.answer != first and d.strikes == 0 and not d.finished and d.pictures.is_empty(), "strikes: job restarts with a new answer")
	var n2 := String(d.job.answer).get_basename().get_slice("_", 1)
	check(d.shell.run("grep Comets notes.txt").out == ["Comets game ball = ball %s." % n2], "shuffle: notes updated after restart")
	check(Judge.verdict({"windows": [{"file": d.job.folder + "/" + first, "w": 160, "h": 160}]}, d.job) == "wrong_file", "shuffle: the old answer is now wrong")


func check_saving(base: Dictionary) -> void:
	var SaveFile = load("res://scripts/save_file.gd")
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	m.save_path = "user://test_save.json"
	SaveFile.clear(m.save_path)
	check(not m.can_continue(), "save: jam campaign has saving off")
	m.campaign.save = true
	m.campaign.jobs[0] = JobData.merge(m.campaign.jobs[0], {"shuffle": true, "texts": {"notes.txt": ["Comets = ball {answer_n}"]}})
	m.start_game(false)
	await process_frame
	var d = m.current
	var answer: String = d.job.answer
	var w = d.open_picture(d.job.folder + "/ball_2.png")
	w.set_content_size(Vector2(130, 160))
	w.position = Vector2(400, 30)
	d.snapshot(w)
	d.run_command("cd ~")
	d.run_command("ls")
	d.set_big_text(true)
	d.kill(103)
	m.save_now(true)
	var mail_before: Array = d.shell.run("ls ~/mail").out
	check(m.can_continue(), "save: written")
	m.show_title()
	await process_frame
	var labels: Array = m.current.find_children("*", "Button", true, false).map(func(b): return b.text)
	check(m.current.can_continue and labels.slice(0, 4) == ["continue", "new game", "how to play", "settings"], "save: title offers continue + new game " + str(labels))
	m.start_game(true)
	await process_frame
	d = m.current
	check(d.shell.run("ls ~/mail").out == mail_before and d.slots[0].mail_path.ends_with("01_dex.txt"), "save: continue doesn't duplicate mail " + str(d.shell.run("ls ~/mail").out))
	var w2 = d.picture("ball_2.png")
	check(w2 != null and w2.get_content_size() == Vector2(130, 160) and w2.position == Vector2(400, 30), "save: window size + place restored")
	check(d.shell.fs.exists("/home/you/snapshot_1.png") and d.snap_count == 1, "save: home folder + snapshot count restored")
	check(d.shell.cwd == "/home/you" and d.shell.history.has("ls"), "save: folder + history restored")
	check(d.big_text and not m.sfx.music_on, "save: text size + radio restored")
	check(d.job.answer == answer, "save: shuffled answer kept")
	var aw = d.open_picture(d.job.folder + "/" + d.job.answer)
	aw.set_content_size(Vector2(160, 160))
	d.snapshot(aw)
	d.send()
	await create_timer(2.4).timeout
	check(m.job_index == 1 and SaveFile.read(m.save_path).job_index == 1, "save: progress saved after a win")
	m.start_game(true)
	await process_frame
	check(m.current.job.get("check", "") == "remote", "save: continue lands on job 2 (teach Dex)")
	m.current.run_command("write dex open photo_4.png")
	await create_timer(2.4).timeout
	check(not m.can_continue(), "save: cleared when the campaign ends")
	m.start_game(false)
	await process_frame
	m.current.set_big_text(true)
	var t = m.current.term
	check(t.output.get_theme_font_size("normal_font_size") == 16 and t._row.position.y + t._row.size.y <= t.get_content_size().y, "big text: terminal doubles and still fits")
	m.current.run_command("frob")
	check(m.current.email.body.get_theme_font_size("normal_font_size") == 16, "big text: email body doubles")
	m.current.set_big_text(false)
	check(t.output.get_theme_font_size("normal_font_size") == 8, "big text: back to normal")
	SaveFile.clear(m.save_path)
	m.queue_free()


func check_inbox(d, c: Dictionary) -> void:
	var won := []
	d.job_won.connect(func(r): won.append(r))
	d.load_jobs([c.jobs[0], medal])
	var tabs: Array = d.email._buttons.get_children().map(func(b): return b.text)
	check(tabs == [">Dex", "Dex"], "inbox: one tab per client " + str(tabs))
	check(d.shell.fs.exists("/clients/dex/notes.txt") and d.shell.fs.exists("/clients/dex/newsletter/coach.txt"), "inbox: both folders exist")
	d.select_job(1)
	check(d.job.search_word == "Gold" and d.email._subj.text.contains("WE WON"), "inbox: switching shows the other email")
	var j2: Dictionary = d.job
	var mw = d.open_picture(j2.folder + "/photo_1.png")
	d.snapshot(mw)
	d.send()
	check(d.strikes == 1 and d.slots[0].strikes == 0, "inbox: strikes are per client")
	mw = d.open_picture(j2.folder + "/" + j2.answer)
	mw.set_content_size(Vector2(j2.target.w, j2.target.h))
	d.snapshot(mw)
	d.send()
	check(d.slots[1].finished and d.email._buttons.get_child(1).text.ends_with("OK"), "inbox: finished client marked OK")
	await create_timer(2.4).timeout
	check(won.is_empty(), "inbox: group not done while a client waits")
	d.select_job(0)
	check(d.job.search_word == "Comets" and not d.finished, "inbox: back to the first client")
	d.select_job(1)
	check(d.email.last_reply == j2.replies.right and d.email.body.get_parsed_text().contains(j2.replies.wrong_file), "inbox: each email keeps its replies")
	var st: Dictionary = d.export_state()
	d.select_job(0)
	d.import_state(st)
	check(d.cur == 1 and d.slots[1].finished and d.slots[1].replies.size() == 2, "inbox: save/restore keeps both clients")
	d.select_job(0)
	var bw = d.open_picture(d.job.folder + "/ball_3.png")
	bw.set_content_size(Vector2(160, 160))
	d.snapshot(bw)
	d.send()
	await create_timer(2.4).timeout
	check(won.size() == 1, "inbox: group done when every client is happy")


func check_replays() -> void:
	var SaveFile = load("res://scripts/save_file.gd")
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	m.records_path = "user://test_records.json"
	SaveFile.clear(m.records_path)
	check(m.replays().is_empty(), "replay: jam jobs aren't timed")
	m.campaign.jobs[0].timed = true
	check(m.replays().is_empty(), "replay: locked until beaten")
	m.start_game(false)
	await process_frame
	var d = m.current
	var bw = d.open_picture(d.job.folder + "/ball_3.png")
	bw.set_content_size(Vector2(160, 160))
	d.snapshot(bw)
	d.send()
	await create_timer(2.4).timeout
	check(m.replays().size() == 1 and m.replays()[0].best < 0, "replay: unlocked after the campaign win, no best yet")
	m.show_title()
	await process_frame
	var labels: Array = m.current.find_children("*", "Button", true, false).map(func(b): return b.text)
	check(labels.has("replay: HELP game at 9"), "replay: title offers it " + str(labels))
	m.start_replay(0)
	await process_frame
	d = m.current
	check(d._clock_label != null and d._clock_label.text == "time 0:00", "replay: clock shows")
	await create_timer(1.1).timeout
	check(d._clock_label.text == "time 0:01", "replay: clock counts")
	bw = d.open_picture(d.job.folder + "/ball_3.png")
	bw.set_content_size(Vector2(160, 160))
	d.snapshot(bw)
	d.send()
	await create_timer(2.4).timeout
	var best: float = m.replays()[0].best
	check(best >= 1.0 and best < 1.8 and m.current.get_script().resource_path.ends_with("title_screen.gd"), "replay: best time saved, back to title (%.1f)" % best)
	labels = m.current.find_children("*", "Button", true, false).map(func(b): return b.text)
	check(labels.any(func(t): return t.begins_with("replay: HELP game at 9  best 0:0")), "replay: title shows the best time " + str(labels))
	SaveFile.clear(m.records_path)
	m.queue_free()


var solutions


func check_full_campaign() -> void:
	solutions = load("res://tests/solutions.gd").new(self, check)
	var fc := JobData.load_campaign("res://data/full/campaign.json")
	check(fc.jobs.size() == 13 and fc.title == "Promptless" and fc.defaults.shell.has("man"), "full: campaign extends the jam defaults")
	for e in fc.jobs:
		for j in (e if e is Array else [e]):
			check_job_data(j)
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	m.campaign = fc
	m.campaign.save = false
	m.start_game(false)
	await process_frame
	for idx in fc.jobs.size():
		var d = m.current
		check(m.job_index == idx, "full: on job %d" % (idx + 1))
		for i in d.slots.size():
			d.select_job(i)
			await solutions.solve(m, d, d.job)
		await create_timer(2.4).timeout
	check(m.current.get_script().resource_path.ends_with("end_screen.gd"), "full: campaign reaches the end screen")
	check(m.endings == ["run"], "full: ending recorded")
	var end_text: Array = m.current.find_children("*", "Label", true, false).map(func(l): return l.text)
	for who in ["Dex", "Marguerite", "Ada Okafor", "Tobi"]:
		check(end_text.has("%s bounced back." % who), "full: %s bounced back on the end screen" % who)
	m.campaign = fc
	m.start_game(false)
	await process_frame
	m.current.load_job(fc.jobs[11])
	m.current.send()
	check(m.current.ending == "wait" and m.current.email.last_reply.begins_with("Then we wait"), "owner: an empty reply chooses to wait")
	m.queue_free()


func btn(screen: Node, prefix: String) -> Button:
	for b in screen.find_children("*", "Button", true, false):
		if not b.is_queued_for_deletion() and b.text.begins_with(prefix):
			return b
	return null


func check_help_and_settings() -> void:
	var SaveFile = load("res://scripts/save_file.gd")
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	m.show_help()
	await process_frame
	var txt: String = m.current.find_children("*", "RichTextLabel", true, false)[0].text
	check(txt.begins_with("HOW TO PLAY") and txt.contains("write NAME"), "help: page shows the help text")
	m.current.back.emit()
	await process_frame
	check(m.current.get_script().resource_path.ends_with("title_screen.gd"), "help: back to title")
	m.start_game(false)
	await process_frame
	var d = m.current
	d.open_help()
	check(d.help_window != null and d.help_window.body.get_parsed_text().contains("HOW TO PLAY"), "help: HELP window opens on the desktop")
	d.help_window._buttons.get_child(0).pressed.emit()
	await process_frame
	check(d.help_window == null, "help: CLOSE closes it")
	m.sfx.settings = {"music": true, "music_vol": 7, "sfx_vol": 8, "big_text": false, "fullscreen": false}
	m.sfx.set_music(true)
	m.sfx.save_settings()
	m.show_settings()
	await process_frame
	var st = m.current
	btn(st, "big text").pressed.emit()
	await process_frame
	check(m.sfx.settings.big_text == true, "settings: big text toggles")
	btn(st, "music:").pressed.emit()
	await process_frame
	check(not m.sfx.music_on, "settings: music off")
	btn(st, "-").pressed.emit()
	await process_frame
	check(int(m.sfx.settings.music_vol) == 6 and m.sfx.music.volume_db < -10.0, "settings: music volume down")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(m.sfx.settings_path))
	check(saved.big_text == true and saved.music == false and int(saved.music_vol) == 6, "settings: saved to disk")
	var m2 = load("res://scenes/main.tscn").instantiate()
	root.add_child(m2)
	await process_frame
	check(m2.sfx.settings.big_text and not m2.sfx.music_on, "settings: loaded on next start")
	m2.start_game(false)
	await process_frame
	check(m2.current.big_text, "settings: big text applies to a new game")
	m2.queue_free()
	SaveFile.write({"job_index": 0, "desk": {}}, m.save_path)
	btn(st, "reset progress").pressed.emit()
	await process_frame
	check(FileAccess.file_exists(m.save_path), "settings: reset asks first")
	btn(st, "click again").pressed.emit()
	await process_frame
	check(not FileAccess.file_exists(m.save_path), "settings: second click erases progress")
	m.sfx.settings = {"music": true, "music_vol": 7, "sfx_vol": 8, "big_text": false, "fullscreen": false}
	m.sfx.music_on = true
	m.sfx.save_settings()
	m.queue_free()


func _initialize() -> void:
	load("res://scripts/sfx.gd").default_settings_path = "user://test_settings.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_settings.json"))
	var c := JobData.load_campaign("res://data/campaign.json")
	medal = JobData._load_job(c, "res://data/job_medal.json")
	check_job_data(medal)
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
	check(r.open == "/clients/dex/ball_3.png", "open full path picture")
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
	check(sh.run("echo ball_*.png").out == ["ball_1.png ball_2.png ball_3.png ball_4.png ball_5.png"], "glob: * expands, sorted")
	check(sh.run("echo ball_?.png").out[0].split(" ").size() == 5, "glob: ? matches one character")
	check(sh.run("echo \"ball_*\"").out == ["ball_*"], "glob: quoted stays literal")
	check(sh.run("echo zz*").out == ["zz*"], "glob: no match stays literal (like bash)")
	check(sh.run("grep Comets *.txt").out.size() == 1, "glob: grep across *.txt")
	check(sh.run("echo /clients/dex/n*").out == ["/clients/dex/notes.txt"], "glob: in a path")
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
	check(JobData.validate(JobData.merge(job, {"chek": "x"})) == ["unknown key 'chek'"], "validator: catches a typo'd key")
	var bad := JobData.merge(job, {"check": "overlay"})
	check(bad.check == "overlay" and "overlay needs overlay.top + overlay.under" in JobData.validate(bad), "validator: overlay without its settings")
	check("unknown tool 'lasso'" in JobData.validate(JobData.merge(job, {"tools": ["lasso"]})), "validator: unknown tool")
	check_file_system(job)
	check_permissions(job)
	check_late_commands(job)
	var sh2 = Shell.new(medal)
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
	var w3 = desk.picture("ball_3.png")
	var w1 = desk.picture("ball_1.png")
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
	check(desk.shell.fs.exists("/home/you/snapshot_3.png"), "snapshots are saved in the home folder")
	check(desk.shell.run("grep Comets /home/you/mail/01_dex.txt").out.size() == 2, "mail: the email (and the Comets reply) are greppable in ~/mail")
	check(desk.shell.run("grep bounced ~/mail/01_dex.txt").out.size() == 3, "mail: replies are appended to it")
	await create_timer(2.6).timeout
	check(main.current == desk and desk.job == c.jobs[1], "job 2 loads on the same desktop")
	check(desk.pictures.is_empty() and not desk.finished, "job 2 starts clean")
	check(desk.shell.fs.exists("/home/you/snapshot_3.png"), "home folder carries over to job 2")
	check(desk.shell.run("ls ~/mail").out == ["01_dex.txt  02_dex.txt"], "mail: old letters stay, new one added")
	desk.run_command("open ~/snapshot_3.png")
	check(desk.picture("snapshot_3.png") != null and desk.picture("snapshot_3.png").get_content_size() == Vector2(160, 160), "a snapshot opens at the size it was taken")
	var job2: Dictionary = c.jobs[1]
	check(desk.remote_screen != null and desk.email.body.text.contains("[url=0]"), "teach: Dex's screen + clickable write command")
	desk.send()
	check(desk.email.last_reply == job2.replies.no_attachment and not desk.finished, "teach: sending a picture isn't teaching")
	desk.run_command("write dex grep Newsletter notes.txt")
	check(desk.remote_screen.body.get_parsed_text().contains("photo 4") and not desk.finished, "teach: Dex greps his own notes")
	desk.run_command("write dex open photo_2.png")
	check(not desk.finished, "teach: wrong photo doesn't count")
	desk.run_command("write dex open photo_4.png")
	check(desk.finished and desk.email.last_reply == job2.replies.right and desk.remote_screen.body.get_parsed_text().contains("I DID THAT"), "teach: Dex opens it himself, job 2 won")
	check(desk.bounced == ["Dex"], "teach: Dex counted as bounced back")
	await create_timer(2.6).timeout
	check(main.current.get_script().resource_path.ends_with("end_screen.gd"), "end screen after last job")
	var end_text: Array = main.current.find_children("*", "Label", true, false).map(func(l): return l.text)
	check(end_text.has("THE TOWN IS BOUNCING BACK") and end_text.has("Dex bounced back."), "end screen: who bounced back " + str(end_text))
	var tobi := tobi_job(c.jobs[0])
	var d2 = main.current
	main.start_game()
	await process_frame
	d2 = main.current
	d2.load_job(tobi)
	d2.run_command("cp chart.sh ~")
	d2.run_command("chmod +x ~/chart.sh")
	d2.run_command("~/chart.sh")
	await process_frame
	check(d2.pictures.size() == 4, "desktop: script floods 4 chart windows (%d)" % d2.pictures.size())
	var pids: Array = d2.pictures.values().map(func(w): return w.pid)
	check(d2.pictures.values()[0]._title_label.text.begins_with("[%d] chart.png" % pids[0]), "desktop: PID shown in title bar")
	check(d2.term._title_label.text == "[101] terminal" and d2.email._title_label.text == "[102] mail", "desktop: terminal/mail show PIDs")
	d2.run_command("kill %d" % pids[1])
	d2.run_command("kill %d" % pids[2])
	await process_frame
	check(d2.pictures.size() == 2, "desktop: kill closes windows")
	d2.run_command("kill 101")
	check(is_instance_valid(d2.term) and d2.term.output.get_parsed_text().contains("holding this whole machine"), "desktop: terminal can't be killed")
	d2.run_command("ps")
	check(d2.term.output.get_parsed_text().contains("pixview chart.png"), "desktop: ps lists viewers")
	check_window_tools(d2, c.jobs[0])
	await check_runner(d2, c.jobs[0])
	await check_inbox(d2, c)
	d2.load_job(late_job(c.jobs[0]))
	d2.run_command("su marta")
	check(d2.term.input.secret, "desktop: password input is hidden")
	d2.run_command("lighthouse")
	check(not d2.term.input.secret and d2.term.prompt_label.text == "marta$", "desktop: prompt shows the user")
	check(not d2.term.output.get_parsed_text().contains("lighthouse"), "desktop: password never printed")
	check(d2.running_programs().any(func(p): return p.cmd == "radio"), "radio is a running program")
	d2.run_command("kill 103")
	check(not main.sfx.music.playing and not main.sfx.music_on, "kill the radio stops the music")
	check(not d2.running_programs().any(func(p): return p.cmd == "radio"), "radio gone from ps")
	d2._toggle_music()
	check(main.sfx.music.playing, "radio button brings it back")
	main.show_end("x")
	await process_frame
	main.current.again.emit()
	await process_frame
	check(main.current.job == c.jobs[0] and main.current.pictures.is_empty(), "play again restarts at job 1, clean")
	var r2: Dictionary = Shell.new(medal).run("grep Gold notes.txt")
	check(r2.hint == ["(nothing in that file. Coach keeps his own notes.)"], "job 2 overrides the no-match hint")
	await check_saving(c.jobs[0])
	await check_replays()
	await check_full_campaign()
	await check_help_and_settings()
	print("\n%d failure(s)" % fails)
	quit(1 if fails else 0)
