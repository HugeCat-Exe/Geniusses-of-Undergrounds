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
var story_wait := false
var riding := false       # Артир везёт на юг или обратно: карта едет сама
var south := false        # показан южный лист карты

const MINI := {
	"mini_bus": "У обочины старой трассы лежит на боку автобус. Стёкла выбиты, дверь распахнута, вокруг следы ботинок, уже заметённые песком.",
	"mini_dogs": "Впереди, у бетонной плиты, неподвижно лежат несколько псов. Песок вокруг взрыт, будто здесь кто-то долго дрался.",
	"mini_camp": "В ложбине между барханами виден брошенный лагерь: латаная палатка, круг камней от костра. Дыма нет.",
	"mini_bones": "Путешествуя, Вы натыкаетесь на кости невиданного существа. Огромный скелет наполовину ушёл в грунт Пустоши, рёбра торчат из песка, как опоры рухнувшего моста.",
}
## События пешком по Пустоши (см. «События в пустоши.txt»): [id, вес]. Кости – редкость.
const EVENTS := [["mini_bus", 3], ["mini_dogs", 3], ["mini_camp", 3], ["caravan", 2], ["riders", 2], ["mini_bones", 1]]
const DOGS_TEXT := ["Путешествуя, Вы натыкаетесь на блуждающую собаку. Она замирает, нюхает воздух и поворачивает к Вам слепую морду.",
	"Путешествуя, Вы натыкаетесь на пару собак. Они расходятся в стороны, чтобы зайти с двух сторон.",
	"Путешествуя, Вы натыкаетесь на стаю из трёх собак. Вожак коротко взвизгивает, и стая пригибается к земле."]


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
	log_label.size = Vector2(484, 20)
	log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(log_label)

	info = PanelContainer.new()
	info.position = Vector2(420, 40)
	info.custom_minimum_size = Vector2(212, 0)
	info.visible = false
	add_child(info)
	info_box = VBoxContainer.new()
	info.add_child(info_box)

	var ride: String = str(G.p.flags.get("vb_ride", ""))
	if ride != "":
		G.p.flags.erase("vb_ride")
		G.changed.connect(_refresh_hud)
		G.logged.connect(_on_log)
		_refresh_hud()
		_ride_south.call_deferred(ride)
		return
	var at: String = G.p.get("map_at", "caldera")
	if at == "wild" and G.p.has("map_xy"):
		player_pos = Vector2(G.p.map_xy[0], G.p.map_xy[1])
	else:
		if not LOCS.has(at):
			at = "caldera"
			G.p.map_at = at
		player_pos = LOCS[at].pos
	G.changed.connect(_refresh_hud)
	# Возвращение с мини-истории: Гений идёт дальше туда, куда шёл.
	var res: String = str(G.p.flags.get("walk_resume", ""))
	if res != "":
		G.p.flags.erase("walk_resume")
		if res.begins_with("@"):
			var xy := res.substr(1).split(",")
			scout_pt = Vector2(float(xy[0]), float(xy[1]))
			_walk.call_deferred("", true)
		elif LOCS.has(res):
			_walk.call_deferred(res, true)
	G.logged.connect(_on_log)
	_refresh_hud()
	_on_log("Клик по точке – куда идти. Пешком тратится время и сытость, такси стоит Су.")


## Поездка с Артиром в «Южную Звезду» и обратно: карта уезжает за край листа,
## появляется южный лист, где отмечена только Звезда.
func _ride_south(dir: String) -> void:
	riding = true
	walking = true
	paused = true
	var star: Vector2 = D.LOCS_SOUTH.star.pos
	var home: Vector2 = LOCS.caldera.pos
	var north := dir != "south"
	south = north
	tex_rect.texture = Art.cached("worldmap_south", _terrain_south) if south else Art.cached("worldmap", _terrain)
	player_pos = star if north else home
	_on_log("Колымага Артира, чихая, катит по старой трассе %s." % ("на север, домой" if north else "на юг"))
	await get_tree().create_timer(0.6).timeout
	# к краю листа
	var edge := Vector2(home.x, -10.0 if north else 370.0)
	var tw := create_tween()
	tw.tween_property(self, "player_pos", edge, 1.6).set_trans(Tween.TRANS_SINE)
	await tw.finished
	# лист сменяется
	var shift := 360.0 if north else -360.0
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(tex_rect, "position:y", shift, 0.7)
	tw2.tween_property(marks, "position:y", shift, 0.7)
	await tw2.finished
	south = not north
	tex_rect.texture = Art.cached("worldmap_south", _terrain_south) if south else Art.cached("worldmap", _terrain)
	tex_rect.position.y = -shift
	marks.position.y = -shift
	var goal := home if north else star
	player_pos = Vector2(home.x, 370.0 if north else -10.0)
	var tw3 := create_tween().set_parallel(true)
	tw3.tween_property(tex_rect, "position:y", 0.0, 0.7)
	tw3.tween_property(marks, "position:y", 0.0, 0.7)
	await tw3.finished
	var tw4 := create_tween()
	tw4.tween_property(self, "player_pos", goal, 1.6).set_trans(Tween.TRANS_SINE)
	await tw4.finished
	pass_time(6)
	G.rel_add("taxi", 1)
	await get_tree().create_timer(0.5).timeout
	riding = false
	walking = false
	paused = false
	if north:
		G.p.map_at = "caldera"
		G.say("Артир довёз Вас до Кальдеры. Всю дорогу он рассказывал про свою первую машину.")
		enter("caldera")
	else:
		G.p.map_at = "star"
		G.main().show_world("star_camp", "arrive")


func _explore() -> void:
	if riding:
		return
	if walking or G.main().has_overlay():
		return
	info.visible = false
	G.main().explore()


func _pager() -> void:
	if not walking:
		G.main().open_pager(0)


func _unhandled_input(event: InputEvent) -> void:
	if riding:
		return
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
					G.main().open_pager(5)


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
	if story_wait and not G.main().has_overlay():
		story_wait = false
		paused = false
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
		if j.state == "active" and j.kind in ["find", "escort"] and j.poi == id:
			return true
		if id == "caldera" and j.kind == "escort" and j.state == "escort":
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
	var ride := G.flag("taxi_ride")
	if ride and id != here():
		var c2 := taxi_cost(id)
		var rb := Pal.button("Артир довезёт: %d Су, %d ч" % [c2, maxi(1, hours_to(id) / 2)], taxi.bind(id))
		rb.disabled = G.p.su < c2 or not (id in G.p.known)
		if not (id in G.p.known):
			rb.text = "Артир туда не ездит: место ещё не найдено"
		info_box.add_child(rb)
		info_box.add_child(Pal.button("Передумал, выйти из машины", _leave_taxi))
	elif id == here():
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
	_walk(id, false)


func _walk(id: String, resumed: bool) -> void:
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
	# Собаки приходят по одной, парой или стаей (60/30/10 %), падальщик – один.
	if rng.randf() < minf(0.55, 0.12 + 0.07 * walk_hours):
		if rng.randf() < 0.67:
			var r := rng.randf()
			events.append({"at": rng.randf_range(0.3, 0.8), "kind": "dogs", "n": 1 if r < 0.6 else (2 if r < 0.9 else 3)})
		else:
			events.append({"at": rng.randf_range(0.3, 0.8), "kind": "fight", "id": "padal"})
	# Событие у дороги: только пешком и не сразу после прошлой.
	if not resumed and walk_hours >= 2 and rng.randf() < 0.35:
		events.append({"at": rng.randf_range(0.25, 0.75), "kind": "story", "id": _pick_event(rng)})
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
	elif ev.kind == "dogs":
		paused = true
		story_wait = true
		var n: int = ev.n
		G.temp_nodes["ev_dogs"] = {"who": "", "text": DOGS_TEXT[n - 1] + "\n\nМожно принять бой или попробовать уйти.",
			"choices": [{"t": "Вступить в бой", "fx": [["ev_fight", "pes", n]], "next": "end"},
				{"t": "[Атлетика] Бежать", "check": ["Атлетика", 9 + n * 2], "ok": "ev_dogs_fled", "fail": "ev_dogs_caught"}]}
		G.temp_nodes["ev_dogs_fled"] = {"who": "", "fx": [["mini_skip"]], "text": "Вы срываетесь с места и бежите, не оглядываясь. Лай остаётся позади, потом стихает совсем.", "choices": [{"t": "Идти дальше", "next": "end"}]}
		G.temp_nodes["ev_dogs_caught"] = {"who": "", "text": "Песок уходит из-под ног. Собаки быстрее: %s." % ["она уже рядом", "обе уже рядом", "вся стая уже рядом"][n - 1],
			"choices": [{"t": "Драться", "fx": [["ev_fight", "pes", n]], "next": "end"}]}
		G.main().open_dialogue("ev_dogs")
	elif ev.id == "riders":
		paused = true
		story_wait = true
		G.temp_nodes["ev_riders"] = {"who": "", "text": "Путешествуя, Вы слышите, как где-то вдалеке ревут два мотора. Мотоциклы. Это рейдеры, и они едут сюда.",
			"choices": [{"t": "[Скрытность] Спрятаться", "check": ["Скрытность", 12], "ok": "ev_riders_hid", "fail": "ev_riders_found"},
				{"t": "Бежать", "next": "ev_riders_run"},
				{"t": "Вступить в бой", "fx": [["ev_fight", "rider", 2]], "next": "end"}]}
		G.temp_nodes["ev_riders_hid"] = {"who": "", "fx": [["mini_skip"]], "text": "Вы вжимаетесь в песок за барханом. Моторы ревут совсем рядом, потом звук уходит на восток. Пронесло.", "choices": [{"t": "Идти дальше", "next": "end"}]}
		G.temp_nodes["ev_riders_found"] = {"who": "", "text": "Из-за бархана выкатывается мотоцикл, фара бьёт Вам в лицо. Рейдер свистит второму: нашёл.", "choices": [{"t": "Драться", "fx": [["ev_fight", "rider", 2]], "next": "end"}]}
		G.temp_nodes["ev_riders_run"] = {"who": "", "text": "От мотоцикла не убежишь. Через минуту рейдеры уже нарезают круги вокруг Вас, улюлюкая и поднимая пыль.", "choices": [{"t": "Драться", "fx": [["ev_fight", "rider", 2]], "next": "end"}]}
		G.main().open_dialogue("ev_riders")
	elif ev.id == "caravan":
		paused = true
		story_wait = true
		G.temp_nodes["ev_caravan"] = {"who": "", "text": "Путешествуя, Вы натыкаетесь на караван странствующих торговцев. Под брезентом обоза позвякивает товар, а на оглобле сидит седой человек в выгоревшем плаще: Странник Гаспар.\n\n– Смотри, кого принесло! Гений! Заходи, покупай, Су не жалей!",
			"choices": [{"t": "Торговать", "fx": [["ev_trade"]], "next": "end"}, {"t": "Идти дальше", "fx": [["mini_skip"]], "next": "end"}]}
		G.main().open_dialogue("ev_caravan")
	elif ev.kind == "story":
		paused = true
		story_wait = true
		G.temp_nodes["mini_ask"] = {"who": "", "text": MINI[ev.id] + "\n\nМожно свернуть и посмотреть поближе или пройти мимо.",
			"choices": [{"t": "Свернуть и осмотреться", "fx": [["mini_go", ev.id]], "next": "end"},
				{"t": "Пройти мимо", "fx": [["mini_skip"]], "next": "end"}]}
		G.main().open_dialogue("mini_ask")


func _pick_event(rng: RandomNumberGenerator) -> String:
	var total := 0
	for e in EVENTS:
		total += int(e[1])
	var r := rng.randi() % total
	for e in EVENTS:
		r -= int(e[1])
		if r < 0:
			return e[0]
	return "mini_bus"


## Бой из события: n врагов по очереди. Проиграл одного – дальше не дерутся.
func ev_fight(enemy: String, n: int) -> void:
	paused = true
	story_wait = false
	_chain(enemy, n, n)


func _chain(enemy: String, left: int, total: int) -> void:
	G.main().start_combat(enemy, func(res: String):
		if res == "win" and left > 1:
			G.say("Следом бросается ещё один: %s (%d из %d)." % [D.ENEMIES[enemy].name, total - left + 2, total])
			_chain.call_deferred(enemy, left - 1, total)
		else:
			_after_fight(res))


## Сойти с дороги на мини-локацию: пройденная часть пути уже потрачена.
func go_mini(id: String) -> void:
	var h := maxi(1, int(round(walk_hours * walk_t)))
	G.p.food = maxi(0, G.p.food - h * FOOD_PER_HOUR)
	pass_time(h)
	G.p.map_at = "wild"
	G.p.map_xy = [player_pos.x, player_pos.y]
	G.p.flags["walk_resume"] = walk_target if walk_target != "" else "@%d,%d" % [int(scout_pt.x), int(scout_pt.y)]
	G.p.flags["mini_n"] = int(G.p.flags.get("mini_n", 0)) + 1
	walking = false
	story_wait = false
	G.main().show_world(id, "enter")


func resume() -> void:
	story_wait = false
	paused = false


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
	G.p.food = maxi(0, G.p.food - food)
	if G.starving():
		G.p.hp = mini(G.p.hp, G.max_hp())
		G.say("В пути закончилась еда. Голод: предел ООЗ на треть ниже, пока Гений не поест.")
	pass_time(walk_hours)
	G.phobia_open(3)
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
	G.phobia_open(1)
	player_pos = LOCS[id].pos
	G.p.map_at = id
	if G.flag("taxi_ride"):
		G.p.flags.erase("taxi_ride")
		G.rel_add("taxi", 2)
		G.say("Артир довёз за %d Су и всю дорогу рассказывал про свою первую машину." % cost)
	else:
		G.say("Такси довезло за %d Су. Водитель всю дорогу молчал." % cost)
	G.changed.emit()
	enter(id)


func _leave_taxi() -> void:
	G.p.flags.erase("taxi_ride")
	info.visible = false
	G.main().show_world("waste", "gate")


func enter(id: String) -> void:
	info.visible = false
	G.p.flags.erase("taxi_ride")
	match id:
		"caldera":
			G.main().show_world("waste", "road")
		_:
			# Открытые места – настоящие карты, по ним можно ходить.
			G.main().show_world("poi_" + id, "enter")


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
	var shown: Array = G.p.known
	var locs: Dictionary = LOCS
	if south:
		shown = ["star"]
		locs = D.LOCS_SOUTH
	for id in shown:
		if not locs.has(id):
			continue
		var l: Dictionary = locs[id]
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
		if not south and has_marker(id) and fmod(blink, 1.0) < 0.7:
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


## Южный лист: та же Пустошь, но без гор, с сухими руслами и трассой, уходящей к «Южной Звезде».
func _terrain_south() -> ImageTexture:
	var cv = ArtLib.Canvas.new(320, 180)
	var noise := FastNoiseLite.new()
	noise.seed = 4242
	noise.frequency = 0.03
	var n2 := FastNoiseLite.new()
	n2.seed = 99
	n2.frequency = 0.11
	for y in 180:
		for x in 320:
			var v := noise.get_noise_2d(x, y) * 0.8 + n2.get_noise_2d(x, y) * 0.25
			var base := 1
			if v > 0.5:
				base = 3
			elif v > 0.15:
				base = 2
			cv.put(x, y, cv.lit(base, v * 0.6, x, y))
	# сухие русла
	for r in 2:
		var rx := 60.0 + r * 150.0
		for y in 180:
			rx += sin(y * 0.07 + r) * 0.8
			cv.put(int(rx), y, 1)
	# трасса с севера к Звезде
	cv.line(95, 0, 120, 60, 3)
	cv.line(120, 60, 165, 107, 3)
	# воронка Подземки
	for a in 40:
		var ang := a * TAU / 40.0
		cv.put(165 + int(cos(ang) * 12), 107 + int(sin(ang) * 7), 4)
	return Art.to_tex(cv)
