extends "res://scripts/desk_window.gd"
## Mail window: the client's email, replies appended below, and a reply bar
## with the current attachment and a Send button. Built once; show_job() refills it.

signal command_clicked(cmd)
signal send_pressed

var job: Dictionary
var body := RichTextLabel.new()
var attach_label: Label
var portrait := TextureRect.new()
var last_reply := ""
var _placeholder: Label
var _from: Label
var _subj: Label
var _send := Button.new()


func build(s: Vector2) -> void:
	set_title("mail")
	set_content_size(s)
	portrait.position = Vector2(2, 2)
	portrait.size = Vector2(32, 32)
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	content.add_child(portrait)
	_placeholder = UI.label("", UI.FONT_SIZE, Palette.TITLE_TEXT)
	_placeholder.position = portrait.position
	_placeholder.size = portrait.size
	_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(_placeholder)
	_from = UI.label("")
	_from.position = Vector2(38, 4)
	content.add_child(_from)
	_subj = UI.label("")
	_subj.position = Vector2(38, 16)
	content.add_child(_subj)
	body.bbcode_enabled = true
	body.position = Vector2(2, 37)
	body.size = Vector2(s.x - 4, s.y - 37 - 16)
	body.meta_clicked.connect(func(m): command_clicked.emit(job.email.clickable[int(str(m))]))
	content.add_child(body)
	var line := ColorRect.new()
	line.color = Palette.FRAME
	line.position = Vector2(0, s.y - 15)
	line.size = Vector2(s.x, 1)
	content.add_child(line)
	attach_label = UI.label("")
	attach_label.position = Vector2(2, s.y - 13)
	attach_label.size = Vector2(s.x - 44, 12)
	attach_label.clip_text = true
	content.add_child(attach_label)
	_send.focus_mode = FOCUS_NONE
	_send.add_theme_color_override("font_color", Palette.CLICK)
	_send.add_theme_color_override("font_hover_color", Palette.CLICK)
	_send.add_theme_stylebox_override("normal", UI.flat(Palette.BUTTON, Palette.CLICK, 1, 3))
	_send.pressed.connect(func(): send_pressed.emit())
	content.add_child(_send)


func show_job(j: Dictionary) -> void:
	job = j
	_placeholder.text = job.client.name.to_upper()
	_from.text = "From: " + job.email.from
	_subj.text = "Subject: " + job.email.subject
	body.text = _format_body()
	body.scroll_to_line(0)
	_send.text = job.ui.send
	_send.reset_size()
	var s := get_content_size()
	_send.position = Vector2(s.x - _send.size.x - 2, s.y - 13)
	last_reply = ""
	clear_attachment()
	set_mood("panic")


func set_mood(mood: String) -> void:
	var tex = UI.find([job.client.get("portrait_" + mood, "")])
	portrait.texture = tex
	_placeholder.visible = tex == null
	queue_redraw()


func show_attachment(name: String) -> void:
	attach_label.text = job.ui.attach_some.format({"name": name})


func clear_attachment() -> void:
	attach_label.text = job.ui.attach_none


func add_reply(text: String) -> void:
	last_reply = text
	body.append_text("\n\n[color=#%s][u]%s%s[/u][/color]\n%s" % [
		Palette.DIM.to_html(false), _esc(job.ui.reply_prefix), _esc(job.email.subject), _esc(text)])
	body.scroll_to_line.call_deferred(body.get_line_count() - 1)


func _draw() -> void:
	super._draw()
	if _placeholder and _placeholder.visible:
		draw_rect(Rect2(content.position + portrait.position, portrait.size), Palette.DIM)


func _format_body() -> String:
	var text := _esc(job.email.body)
	var cmds: Array = job.email.get("clickable", [])
	for i in cmds.size():
		var safe := _esc(cmds[i])
		text = text.replace(safe, "[url=%d][color=#%s]%s[/color][/url]" % [
			i, Palette.CLICK.to_html(false), safe])
	return text


static func _esc(t: String) -> String:
	return t.replace("[", "[lb]")
