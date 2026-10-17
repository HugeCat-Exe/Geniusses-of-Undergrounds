extends Control
## Карта мира: переходы между Подземкой и Пустошью пешком или на такси.

const ArtLib := preload("res://scripts/art.gd")

## Места карты лежат в data.gd (D.LOCS), чтобы их видели и прогулки по Пустоши.
var LOCS: Dictionary = D.LOCS

const SPEED := 40.0      # пикселей карты в час пешком
const FOOD_PER_HOUR := 3

var tex_rect: TextureRect
var marks: Control
var info: PanelContainer
var info_box: VBoxContainer
var hud: Label
var log_label: Label
var selected := ""
var walking := false
var walk_from := Vector2.ZERO
var walk_to := Vector2.ZERO
var walk_target := ""
var walk_t := 0.0
var walk_len := 0.0
var walk_hours := 0
var events: Array = []   # [{"at": 0..1, "kind": "fight"/"find", "id": ...}]
var paused := false
var player_pos := Vector2.ZERO
var blink := 0.0
var scout_pt := Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Pal.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	tex_rect = TextureRect.new()
	tex_rect.texture = Art.cached("worldmap", _terrain)
	tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	tex_rect.position = Vector2.ZERO
	tex_rect.size = Vector2(640, 360)
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tex_rect)
	marks = Control.new()
	marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marks.draw.connect(_draw_marks)
	add_child(marks)

	var top := PanelContainer.new()
	top.position = Vector2(4, 4)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var tv := VBoxContainer.new()
	top.add_child(tv)
	tv.add_child(Pal.label("КАРТА МИРА", Pal.G5, 12, true))
	hud = Pal.label("", Pal.G4, 10)
	tv.add_child(hud)

	var eb := Pal.button("ИЗУЧАТЬ ОКРЕСТНОСТИ (2 ч)", _explore, 10)
	eb.position = Vector2(4, 74)
	add_child(eb)

	var pb := Pal.button("ПЕЙДЖЕР [Tab]", _pager, 10)
	pb.position = Vector2(540, 6)
	add_child(pb)

	log_label = Pal.label("", Pal.G3, 10)
	log_label.position = Vector2(8, 336)
	log_label.size = Vector2(624, 20)
	log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(log_label)

	info = PanelContainer.new()
	info.position = Vector2(420, 40)
	info.custom_minimum_size = Vector2(212, 0)
	info.visible = false
	add_child(info)
	info_box = VBoxContainer.new()
	info.add_child(info_box)

	var at: String = G.p.get("map_at", "caldera")
	if at == "wild" and G.p.has("map_xy"):
		player_pos = Vector2(G.p.map_xy[0], G.p.map_xy[1])
	else:
		if not LOCS.has(at):
			at = "caldera"
			G.p.map_at = at
		player_pos = LOCS[at].pos
	G.changed.connect(_refresh_hud)
	G.logged.connect(_on_log)
	_refresh_hud()
	_on_log("Клик по точке — куда идти. Пешком тратится время и сытость, такси стоит Су.")


func _explore() -> void:
	if walking or G.main().has_overlay():
		return
	info.visible = false
	G.main().explore()


func _pager() -> void:
	if not walking:
		G.main().open_pager(0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB:
				_pager()
				accept_event()
			KEY_I:
				if not walking:
					G.main().open_pager(1)
			KEY_ESCAPE:
				if info.visible:
					info.visible = false
				elif not walking:
					G.main().open_pager(4)


func _gui_input(event: InputEvent) -> void:
	if walking or G.main().has_overlay():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var best := ""
		var bd := 18.0
		for id in G.p.known:
			if LOCS.has(id):
				var d: float = (LOCS[id].pos as Vector2).distance_to(event.position)
				if d < bd:
					bd = d
					best = id
		if best != "":
			select(best)
		elif event.position.y > 40 and event.position.y < 330:
			select_point(event.position)


func _process(delta: float) -> void:
	blink += delta
	if walking and not paused and not G.main().has_overlay():
		walk_t = minf(1.0, walk_t + delta * 140.0 / maxf(walk_len, 1.0))
		player_pos = walk_from.lerp(walk_to, walk_t)
		if not events.is_empty() and walk_t >= events[0].at:
			_fire(events.pop_front())
		elif walk_t >= 1.0:
			_arrive()
	marks.queue_redraw()


# ---------------- Выбор точки ----------------

func here() -> String:
	return G.p.get("map_at", "caldera")


func hours_to(id: String) -> int:
	return maxi(1, int(ceil(player_pos.distance_to(LOCS[id].pos) / SPEED)))


func taxi_cost(id: String) -> int:
	return 5 + int(player_pos.distance_to(LOCS[id].pos) / 8.0)


func has_marker(id: String) -> bool:
	var q: Dictionary = G.p.quests
	for j in G.p.jobs:
		if j.state == "active" and j.kind == "find" and j.poi == id:
			return true
		if id == "caldera" and (j.state == "done" or j.kind == "kill"):
			return true
	if id == "caldera":
		return q.get("med", "") == "active" or q.get("dogs", "") in ["active", "done"]
	return false


func select(id: String) -> void:
	selected = id
	for c in info_box.get_children():
		c.queue_free()
	var l: Dictionary = LOCS[id]
	info_box.add_child(Pal.label(l.name, Pal.G5, 10, true))
	var d := Pal.rich(l.desc, 10)
	d.custom_minimum_size = Vector2(200, 0)
	info_box.add_child(d)
	if has_marker(id):
		info_box.add_child(Pal.label("! Здесь есть дело по задаче", Pal.R3, 10))
	if id == here():
		info_box.add_child(Pal.button("Войти", enter.bind(id)))
	else:
		var h := hours_to(id)
		var food := h * FOOD_PER_HOUR
		info_box.add_child(Pal.button("Пешком: %d ч, −%d сытости, риск" % [h, food], walk.bind(id)))
		var cost := taxi_cost(id)
		var tb := Pal.button("Такси: %d Су, %d ч, без риска" % [cost, maxi(1, h / 2)], taxi.bind(id))
		if l.kind == "poi":
			tb.disabled = true
			tb.text = "Такси сюда не ездит"
		elif G.p.su < cost:
			tb.disabled = true
		info_box.add_child(tb)
	info_box.add_child(Pal.button("Закрыть", _close_info))
	info.visible = true
	marks.queue_redraw()


## Разведка: пешком в произвольную точку, где могут найтись новые места.
func select_point(pt: Vector2) -> void:
	selected = ""
	scout_pt = pt
	for c in info_box.get_children():
		c.queue_free()
	info_box.add_child(Pal.label("Пустошь", Pal.G5, 10, true))
	var d := Pal.rich("Безымянные пески. По пути можно наткнуться на новое место или на зверя.", 10)
	d.custom_minimum_size = Vector2(200, 0)
	info_box.add_child(d)
	var h := maxi(1, int(ceil(player_pos.distance_to(pt) / SPEED)))
	info_box.add_child(Pal.button("Разведать: %d ч, −%d сытости" % [h, h * FOOD_PER_HOUR], walk.bind("")))
	info_box.add_child(Pal.button("Закрыть", _close_info))
	info.visible = true


func _close_info() -> void:
	info.visible = false
	selected = ""


func pass_time(h: int) -> void:
	G.pass_hours(h)


# ---------------- Перемещение ----------------

func walk(id: String) -> void:
	info.visible = false
	walk_from = player_pos
	walk_to = LOCS[id].pos if id != "" else scout_pt
	walk_len = walk_from.distance_to(walk_to)
	walk_target = id
	walk_hours = maxi(1, int(ceil(walk_len / SPEED)))
	walk_t = 0.0
	walking = true
	events = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(G.p.seed) + id + str(G.p.day) + str(G.p.hour))
	# Находки: неизвестные точки рядом с маршрутом.
	for pid in LOCS:
		if pid in G.p.known:
			continue
		var pos: Vector2 = LOCS[pid].pos
		var t := clampf((pos - walk_from).dot(walk_to - walk_from) / maxf(walk_len * walk_len, 1.0), 0.05, 0.95)
		if pos.distance_to(walk_from.lerp(walk_to, t)) < 110.0 and rng.randf() < 0.6:
			events.append({"at": t, "kind": "find", "id": pid})
	# Стычка: чем дольше путь, тем вероятнее.
	if rng.randf() < minf(0.55, 0.12 + 0.07 * walk_hours):
		events.append({"at": rng.randf_range(0.3, 0.8), "kind": "fight", "id": ["pes", "padal", "pes"][rng.randi() % 3]})
	events.sort_custom(func(a, b): return a.at < b.at)
	_on_log("Гений идёт пешком: %s." % (LOCS[id].name if id != "" else "разведка"))


func _fire(ev: Dictionary) -> void:
	if ev.kind == "find":
		G.p.known.append(ev.id)
		G.say("По дороге замечено новое место: %s. Оно отмечено на карте." % LOCS[ev.id].name)
	elif ev.kind == "fight":
		paused = true
		G.say("Из-за барханов показался враг: %s." % D.ENEMIES[ev.id].name)
		G.main().start_combat(ev.id, _after_fight)


func _after_fight(result: String) -> void:
	match result:
		"dead":
			G.main().game_over("Гений не дошёл. Пустошь между точками на карте не прощает.")
			return
		"down":
			var lost := int(G.p.su * 0.25)
			G.p.su -= lost
			G.say("Гений очнулся в пыли. Пропало %d Су. Путь продолжается." % lost)
	paused = false
	_refresh_hud()


func _arrive() -> void:
	walking = false
	var food: int = walk_hours * FOOD_PER_HOUR
	if G.p.food < food:
		G.p.hp = maxi(1, G.p.hp - (food - G.p.food))
		G.say("В пути закончилась еда. Голод отнял силы.")
	G.p.food = maxi(0, G.p.food - food)
	pass_time(walk_hours)
	if walk_target == "":
		G.p.map_at = "wild"
		G.p.map_xy = [player_pos.x, player_pos.y]
		G.changed.emit()
		_on_log("Разведка окончена. Вокруг только песок и ветер.")
		return
	G.p.map_at = walk_target
	G.changed.emit()
	select(walk_target)


func taxi(id: String) -> void:
	var cost := taxi_cost(id)
	if G.p.su < cost:
		return
	G.p.su -= cost
	pass_time(maxi(1, hours_to(id) / 2))
	player_pos = LOCS[id].pos
	G.p.map_at = id
	G.say("Такси довезло за %d Су. Водитель всю дорогу молчал." % cost)
	G.changed.emit()
	enter(id)


func enter(id: String) -> void:
	info.visible = false
	match id:
		"caldera":
			G.main().show_world("waste", "road")
		_:
			G.main().open_dialogue(LOCS[id].node, _refresh_hud)


# ---------------- Интерфейс ----------------

func _refresh_hud() -> void:
	if not is_instance_valid(hud):
		return
	hud.text = "День %d, %02d:00   Сытость %d   %d Су\nООЗ %d/%d   ООР %d/%d" % [
		G.p.day, G.p.hour, G.p.food, G.p.su, G.p.hp, G.max_hp(), G.p.mind, G.max_mind()]


func _on_log(t: String) -> void:
	if is_instance_valid(log_label):
		log_label.text = t


func _draw_marks() -> void:
	# Пунктир маршрута.
	if walking:
		var n := int(walk_len / 8.0)
		for i in n:
			if i % 2 == 0:
				marks.draw_line(walk_from.lerp(walk_to, i / float(n)), walk_from.lerp(walk_to, (i + 1) / float(n)), Pal.G3, 2)
	for id in G.p.known:
		if not LOCS.has(id):
			continue
		var l: Dictionary = LOCS[id]
		var p: Vector2 = l.pos
		var col := Pal.G5 if id == selected else Pal.G4
		match l.kind:
			"town":
				marks.draw_rect(Rect2(p - Vector2(7, 7), Vector2(14, 14)), Pal.BG)
				marks.draw_rect(Rect2(p - Vector2(7, 7), Vector2(14, 14)), col, false, 2)
				for k in 3:
					marks.draw_line(p + Vector2(-4, -3 + k * 3), p + Vector2(4, -3 + k * 3), col, 1)
			"zone":
				marks.draw_circle(p, 7, Pal.BG)
				marks.draw_arc(p, 7, 0, TAU, 16, col, 2)
				marks.draw_circle(p, 2, col)
			_:
				var pts := PackedVector2Array([p + Vector2(0, -7), p + Vector2(7, 0), p + Vector2(0, 7), p + Vector2(-7, 0)])
				marks.draw_colored_polygon(pts, Pal.BG)
				pts.append(pts[0])
				marks.draw_polyline(pts, col, 2)
		var font := Pal.font
		var w := font.get_string_size(l.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		marks.draw_rect(Rect2(p + Vector2(-w / 2 - 2, 9), Vector2(w + 4, 12)), Color(Pal.BG, 0.8))
		marks.draw_string(font, p + Vector2(-w / 2, 19), l.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)
		if has_marker(id) and fmod(blink, 1.0) < 0.7:
			marks.draw_string(Pal.font_title, p + Vector2(8, -6), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.R3)
	# Гений.
	var on := fmod(blink, 0.6) < 0.4 or walking
	marks.draw_circle(player_pos + Vector2(0, -12), 4, Pal.R2 if on else Pal.R1)
	marks.draw_line(player_pos + Vector2(0, -8), player_pos + Vector2(0, -2), Pal.R2, 2)


## Рельеф карты: пустошь с дюнами, горами на севере и рекой на востоке.
func _terrain() -> ImageTexture:
	var cv = ArtLib.Canvas.new(320, 180)
	var noise := FastNoiseLite.new()
	noise.seed = 1337
	noise.frequency = 0.035
	var n2 := FastNoiseLite.new()
	n2.seed = 7
	n2.frequency = 0.12
	for y in 180:
		for x in 320:
			var v := noise.get_noise_2d(x, y) * 0.8 + n2.get_noise_2d(x, y) * 0.25
			var mount := clampf((30.0 - y) / 30.0, 0.0, 1.0) * 0.9 + (0.25 if x < 40 else 0.0)
			v += mount
			var base := 1
			if v > 0.55:
				base = 3
			elif v > 0.2:
				base = 2
			cv.put(x, y, cv.lit(base, v * 0.6, x, y))
	# Горные гребни.
	for i in 14:
		var mx := 20 + i * 22 + (i * 37) % 9
		var my := 6 + (i * 13) % 14
		cv.poly(PackedVector2Array([Vector2(mx - 10, my + 12), Vector2(mx, my), Vector2(mx + 11, my + 12)]), 3)
	# Река с севера на юго-восток.
	var rx := 230.0
	for y in 180:
		rx += sin(y * 0.09) * 0.9 + 0.12
		for k in 3:
			cv.put(int(rx) + k, y, 4 if k == 1 else 3)
	# Старая трасса.
	cv.line(0, 120, 120, 104, 3)
	cv.line(120, 104, 260, 128, 3)
	cv.line(260, 128, 320, 150, 3)
	# Кратер вокруг Кальдеры.
	for a in 48:
		var ang := a * TAU / 48.0
		cv.put(95 + int(cos(ang) * 16), 105 + int(sin(ang) * 10), 4)
	return Art.to_tex(cv)
