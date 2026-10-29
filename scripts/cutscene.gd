extends CanvasLayer
## Катсцена прямо на карте: чёрные полосы, камера, персонажи ходят по сценарию, реплики с портретами.
## Шаги сценария – массивы, первый элемент – команда:
##   ["say", кто, "текст"]       реплика ("" – авторский текст, "genius" – сам Гений); ждёт щелчка
##   ["walk", кто, x, y]         пройти к клетке (кто: "genius", "mate" или id жителя на карте)
##   ["face", кто, "left"/"right"]
##   ["cam", x, y]               камера едет к клетке; ["cam"] – вернуть камеру Гению
##   ["wait", секунды]
##   ["emote", кто, "!"/"?"/"♥"/"..."]   значок над головой
##   ["spawn", id, x, y] / ["remove", id]   поставить или убрать жителя на время сцены
##   ["fade_out", с] / ["fade_in", с]
##   ["dialogue", "узел"]        обычный диалог с выбором из story.gd; сцена ждёт, пока он закроется
##   ["rel", кто, n] ["su", n] ["item", "предмет"] ["flag", "имя"]
##   ["call", Callable]          выполнить код (флаги квеста, награды)

signal finished

const Maps := preload("res://scripts/maps.gd")
const Story := preload("res://scripts/story.gd")

var world: Node2D
var steps: Array = []
var top_bar: ColorRect
var bot_bar: ColorRect
var box: Panel
var portrait: TextureRect
var name_l: Label
var text_l: RichTextLabel
var hint_l: Label
var advance := false
var auto := OS.get_environment("GP_SMOKE") != ""


func _ready() -> void:
	layer = 7
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.theme = Pal.theme
	root.gui_input.connect(_on_input)
	add_child(root)
	top_bar = ColorRect.new()
	top_bar.color = Color.BLACK
	top_bar.position = Vector2(0, -40)
	top_bar.size = Vector2(640, 40)
	root.add_child(top_bar)
	bot_bar = ColorRect.new()
	bot_bar.color = Color.BLACK
	bot_bar.position = Vector2(0, 360)
	bot_bar.size = Vector2(640, 40)
	root.add_child(bot_bar)
	box = Panel.new()
	box.add_theme_stylebox_override("panel", Pal.box(Pal.G0, Pal.G3, 2))
	box.position = Vector2(40, 246)
	box.size = Vector2(560, 92)
	box.visible = false
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	portrait = TextureRect.new()
	portrait.position = Vector2(8, 8)
	portrait.size = Vector2(76, 76)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(portrait)
	name_l = Pal.label("", Pal.G5, 10, true)
	name_l.position = Vector2(94, 6)
	box.add_child(name_l)
	text_l = Pal.rich("", 10)
	text_l.fit_content = false
	text_l.position = Vector2(94, 22)
	text_l.size = Vector2(458, 60)
	text_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(text_l)
	hint_l = Pal.label("▼ щелчок / пробел", Pal.G2, 8)
	hint_l.position = Vector2(470, 78)
	box.add_child(hint_l)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(top_bar, "position:y", 0.0, 0.4)
	tw.tween_property(bot_bar, "position:y", 320.0, 0.4)


func play(w: Node2D, list: Array) -> void:
	world = w
	steps = list
	world.cut_active = true
	await get_tree().create_timer(0.45).timeout
	for st in steps:
		await _step(st)
	box.visible = false
	world.cam_override = null
	var tw := create_tween().set_parallel(true)
	tw.tween_property(top_bar, "position:y", -40.0, 0.35)
	tw.tween_property(bot_bar, "position:y", 360.0, 0.35)
	await tw.finished
	for o in world.objs.duplicate():
		if o.get("cut_temp", false):
			world.remove_cut_actor(o)
	world.cut_active = false
	finished.emit()
	queue_free()


func _on_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		advance = true


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode in [KEY_SPACE, KEY_ENTER, KEY_E]:
		advance = true
		get_viewport().set_input_as_handled()


func _step(st: Array) -> void:
	match str(st[0]):
		"say":
			await _say(str(st[1]), str(st[2]))
		"walk":
			await world.cut_walk(str(st[1]), Vector2i(int(st[2]), int(st[3])))
		"face":
			world.cut_face(str(st[1]), str(st[2]) == "left")
		"cam":
			world.cam_override = null if st.size() < 3 else Vector2(float(st[1]), float(st[2]))
			await get_tree().create_timer(0.6).timeout
		"wait":
			await get_tree().create_timer(float(st[1])).timeout
		"emote":
			world.cut_emote(str(st[1]), str(st[2]))
			await get_tree().create_timer(0.9).timeout
		"spawn":
			world.add_cut_actor(str(st[1]), Vector2i(int(st[2]), int(st[3])))
		"remove":
			world.remove_cut_actor(world.cut_find(str(st[1])))
		"fade_out":
			var m: Node = G.main()
			var t := float(st[1]) if st.size() > 1 else 0.5
			m.fade.create_tween().tween_property(m.fade, "color:a", 1.0, t)
			await get_tree().create_timer(t).timeout
		"fade_in":
			var m2: Node = G.main()
			var t2 := float(st[1]) if st.size() > 1 else 0.5
			m2.fade.create_tween().tween_property(m2.fade, "color:a", 0.0, t2)
			await get_tree().create_timer(t2).timeout
		"dialogue":
			box.visible = false
			var closed := [false]
			G.main().open_dialogue(str(st[1]), func(): closed[0] = true)
			while not closed[0] and is_inside_tree():
				if auto:
					for c in G.main().overlay.get_children():
						c.queue_free()
					closed[0] = true
				await get_tree().process_frame
		"rel":
			G.rel_add(str(st[1]), int(st[2]))
		"su":
			G.p.su += int(st[1])
			G.say("На пейджер пришло %d Су." % int(st[1]))
		"item":
			G.add_item(str(st[1]))
		"flag":
			G.set_flag(str(st[1]))
		"call":
			st[1].call()


func _say(who: String, text: String) -> void:
	box.visible = true
	if who == "" :
		portrait.visible = false
		name_l.text = ""
		text_l.position = Vector2(14, 14)
		text_l.size = Vector2(538, 70)
	else:
		portrait.visible = true
		text_l.position = Vector2(94, 22)
		text_l.size = Vector2(458, 60)
		if who == "genius":
			portrait.texture = Art.portrait_tex(G.look())
			name_l.text = G.p.callsign
		else:
			portrait.texture = Art.who_portrait(who)
			name_l.text = Story.WHO.get(who, {}).get("name", who)
	text = text.replace("{callsign}", G.p.callsign).replace("{pa}", "а" if G.p.get("sex", "М") == "Ж" else "")
	text_l.text = text
	text_l.visible_ratio = 0.0
	advance = false
	# текст печатается; первый щелчок допечатывает, второй листает дальше
	var n := text.length()
	var t := 0.0
	while text_l.visible_ratio < 1.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		text_l.visible_ratio = minf(1.0, t * 55.0 / maxf(1.0, n))
		if advance or auto:
			text_l.visible_ratio = 1.0
	advance = false
	var waited := 0.0
	while not advance:
		await get_tree().process_frame
		waited += get_process_delta_time()
		hint_l.modulate.a = 0.5 + 0.5 * sin(waited * 5.0)
		if auto and waited > 0.25:
			break
	advance = false
