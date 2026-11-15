extends "res://scripts/desk_window.gd"
## Mail window: the client's email, replies appended below, and a reply bar
## with the current attachment and a Send button.

signal command_clicked(cmd)
signal send_pressed

var job: Dictionary
var body := RichTextLabel.new()
var attach_label: Label
var portrait := TextureRect.new()
var last_reply := ""
var _placeholder: Label


func build(j: Dictionary, s: Vector2) -> void:
	job = j
	set_title("mail")
	set_content_size(s)
	# header: 32x32 portrait + from/subject
	portrait.position = Vector2(2, 2)
	portrait.size = Vector2(32, 32)
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	content.add_child(portrait)
	_placeholder = UI.label(job.client.name.to_upper(), UI.FONT_SIZE, Palette.TITLE_TEXT)
	_placeholder.position = portrait.position
	_placeholder.size = portrait.size
	_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(_placeholder)
	var from := UI.label("From: " + job.email.from)
	from.position = Vector2(38, 4)
	content.add_child(from)
	var subj := UI.label("Subject: " + job.email.subject)
	subj.position = Vector2(38, 16)
	content.add_child(subj)
	# body
	body.bbcode_enabled = true
	body.position = Vector2(2, 37)
	body.size = Vector2(s.x - 4, s.y - 37 - 16)
	body.meta_clicked.connect(func(m): command_clicked.emit(job.email.clickable[int(str(m))]))
	body.text = _format_body()
	content.add_child(body)
	# reply bar
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
	var send := Button.new()
	send.text = job.ui.send
	send.focus_mode = FOCUS_NONE
	send.add_theme_color_override("font_color", Palette.CLICK)
	send.add_theme_color_override("font_hover_color", Palette.CLICK)
	send.add_theme_stylebox_override("normal", UI.flat(Palette.BUTTON, Palette.CLICK, 1, 3))
	send.pressed.connect(func(): send_pressed.emit())
	content.add_child(send)
	send.reset_size()
	send.position = Vector2(s.x - send.size.x - 2, s.y - 13)
	clear_attachment()
	set_mood("panic")


func set_mood(mood: String) -> void:
	var tex = UI.find([job.client.get("portrait_" + mood, "")])
	portrait.texture = tex
	_placeholder.visible = tex == null
	if tex == null:
		portrait.texture = null
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
