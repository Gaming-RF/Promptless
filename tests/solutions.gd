extends RefCounted

var tree: SceneTree
var checker: Callable


func _init(t: SceneTree, c: Callable = func(_ok, _msg): pass) -> void:
	tree = t
	checker = c


func say(m, cmd: String) -> void:
	m.current.run_command(cmd)


func solve(m, d, job: Dictionary) -> void:
	var subj: String = job.email.subject
	match subj:
		"is this the computer place??":
			say(m, "open id_photo.png")
			d.snapshot(d.picture("id_photo.png"))
			d.send()
		"HELP game at 9":
			var w = d.open_picture(job.folder + "/ball_3.png")
			w.set_content_size(Vector2(160, 160))
			d.snapshot(w)
			d.send()
		"my turn??":
			say(m, "write dex grep Newsletter notes.txt")
			say(m, "write dex open photo_4.png")
		"HELP due 9am":
			say(m, "grep Orrin notes.txt")
			var n := String(job.answer).get_basename().get_slice("_", 1).to_int()
			checker.call(d.term.output.get_parsed_text().contains("Lake Orrin = map %d." % n), "lake: grep names the map")
			var mw = d.open_picture(job.folder + "/" + job.answer)
			mw.set_content_size(Vector2(160, 160))
			d.snapshot(mw)
			d.send()
		"apology. urgent.":
			say(m, "grep Priyanka sent_mail.txt")
			var memo = d.open_picture("/clients/marguerite/memo.png")
			var note = d.open_picture("/clients/marguerite/note.png")
			note.position = memo.position
			note.set_tracing(true)
			d.snapshot(note)
			d.send()
		"fine. teach me.":
			say(m, "write marguerite grep sorry sent.txt")
		"our wedding photo":
			say(m, "cd /clients/okafor")
			checker.call(d.shell.run("ls").out.is_empty() and d.shell.run("ls -a").out[0].contains(".album"), "okafor: folder looks empty until ls -a")
			say(m, "cd .album")
			say(m, "open faded_1.png")
			say(m, "open faded_2.png")
			var f1 = d.picture("faded_1.png")
			var f2 = d.picture("faded_2.png")
			f1.position = f2.position
			f1.set_tracing(true)
			f1.move_to_front()
			d.snapshot(f1)
			d.send()
		"can you teach us?":
			say(m, "write ada ls -a")
			say(m, "write ada cd .backup")
			say(m, "write ada open honeymoon.png")
		"quick favour (urgent)":
			say(m, "cd /clients/tobi")
			say(m, "chmod +x chart.sh")
			checker.call(d.term.output.get_parsed_text().contains("Operation not permitted"), "tobi: can't chmod his file")
			say(m, "cp chart.sh ~")
			say(m, "cd ~")
			say(m, "chmod +x chart.sh")
			say(m, "./chart.sh")
			await tree.process_frame
			checker.call(d.pictures.size() == 4, "tobi: the script floods 4 windows")
			var charts: Array = d.pictures.values()
			charts[0].set_content_size(Vector2(160, 160))
			d.snapshot(charts[0])
			d.send()
			checker.call(d.email.last_reply.begins_with("Why are there four"), "tobi: crowded until the copies are gone")
			say(m, "kill %d" % charts[1].pid)
			await tree.process_frame
			checker.call(d.pictures.size() == 4, "tobi: killing a copy respawns it")
			var parent: Dictionary = d.running_programs().filter(func(p): return p.cmd == "chart.sh")[0]
			say(m, "kill %d" % parent.pid)
			charts = d.pictures.values()
			for i in range(1, charts.size()):
				say(m, "kill %d" % charts[i].pid)
			await tree.process_frame
			charts = d.pictures.values()
			charts[0].set_content_size(Vector2(160, 160))
			d.snapshot(charts[0])
			d.send()
		"ok fine (teach me)":
			say(m, "write tobi ./fix.sh")
			checker.call(not d.finished and d.remote_screen.body.get_parsed_text().contains("Permission denied"), "tobi teach: his script isn't runnable yet")
			say(m, "write tobi chmod +x fix.sh")
			say(m, "write tobi ./fix.sh")
		"Check my working":
			say(m, "cat ~/mail/ansel_1.txt")
			say(m, "unzip ledger.zip -d ~")
			say(m, "1971")
			checker.call(d.shell.run("sort -n ~/ledger/index.txt").out[0] == "1 scan_b.png", "ansel: sort -n gives the page order")
			var pages: Array = []
			for nm in ["scan_b", "scan_d", "scan_c", "scan_a"]:
				pages.append(d.open_picture("/home/you/ledger/%s.png" % nm))
			pages[0].position = Vector2(330, 120)
			for i in range(1, 4):
				pages[i].position = pages[i - 1].position + Vector2(pages[i - 1].size.x + 3, 0)
				d._on_drag_finished(pages[i])
			d.snapshot(pages[0])
			d.send()
		"quiz tomorrow!!":
			say(m, "write dex grep Deepest geo.txt")
		"about your machine":
			say(m, "su owner")
			say(m, "harbor1984")
			say(m, "./end_drill.sh")
			checker.call(not d.finished, "owner: needs root")
			say(m, "sudo /home/owner/end_drill.sh")
			say(m, "harbor1984")
		"last lesson??":
			say(m, "write dex gerp club notes.txt")
			checker.call(d.remote_screen.body.get_parsed_text().contains("did you mean grep"), "final: his machine runs typos exactly")
			say(m, "write dex grep club notes.txt")
			say(m, "write dex open flyer_3.png")
	checker.call(d.finished, "full: '%s' finished (reply: %s)" % [subj, d.email.last_reply])
