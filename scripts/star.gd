extends Node2D
## «Южная Звезда»: живая часть квеста «Венок из ветвей барбариса» поверх обычной карты.
## Псы лезут из пробоин, рыцари отстреливают тех, кто ещё не добежал до Гения,
## жители второго этажа идут следом к лифту, а заставки этажей играют один раз.

const StoryVB := preload("res://scripts/story_vb.gd")
const Story := preload("res://scripts/story.gd")

## Сколько врагов нужно убить на этаже (Гений и рыцари вместе).
const SPEC := {
	1: {"pes_cave": 5},
	2: {"pes_cave": 4},
	3: {"pes_cave": 9},
	6: {"pes_cave": 3, "pustobreh": 2},
	7: {"pes_cave": 4, "pustobreh": 3},
}
const WAVES := 3
const WAVE_SIZE := 5
const MAX_ALIVE := 4
const KNIGHTS := ["tauros", "ursuz", "ankvila"]

## Заставки при первом входе: описание этажа и реплики рыцарей (сценарий, разделы 5, 7, 8).
const INTRO := {
	1: [["dialogue", "vb_f1_enter"], ["say", "ankvila", "– Пятеро, судя по звуку. Разминка."]],
	2: [["dialogue", "vb_f2_enter"], ["say", "", "Голос из-за решётки: – Эй! Эй, кто там? Мы живы! Нас трое!"],
		["say", "tauros", "– Выжившие. {callsign}, выводи их к лифту. Мы прикроем."]],
	3: [["dialogue", "vb_f3_enter"], ["say", "tauros", "– Их здесь много. Не разделяйтесь."]],
	4: [["dialogue", "vb_f4_enter"], ["say", "tauros", "– Это главный ход. Мы его заварим, но на это нужно время. {callsign}, держи позицию вместе с нами. Три волны, не меньше."]],
	5: [["dialogue", "vb_f5_enter"], ["say", "tauros", "– Запусти его. Мы будем держать двери."]],
	6: [["dialogue", "vb_f6_enter"], ["say", "ankvila", "– Это что ещё за лысая гадость?"],
		["say", "tauros", "– Пустобрёхи. Запутанные кроты. Не подпускать к себе, у них зубы длиннее моего ножа."]],
	7: [["dialogue", "vb_f7_enter"], ["say", "ursuz", "– Их больше."]],
	8: [["dialogue", "vb_f8_enter"], ["say", "tauros", "– Вожак. Если стая слушается кого-то, то его."]],
	9: [["dialogue", "vb_f9_enter"]],
}
const CLEAR := {
	1: [["say", "", "Рыцари подходят к дырам в стенах и прижимают к ним листы стали. Шипит сварка, летят искры. Урсуз молча закрывает створки лифтовой шахты и проводит по шву факелом."],
		["say", "tauros", "– Этаж наш. Дальше будет только хуже, {callsign}. Отдохни, если нужно."]],
	2: [["say", "pimm", "– Спасибо, Гений. Если моя лавка когда-нибудь снова откроется, для Вас всё бесплатно. Кроме свечей, их больше нет."]],
	3: [["say", "", "Рыцари заваривают выбитые двери одну за другой. В коридоре становится тихо."],
		["say", "tauros", "– Чисто. Дальше."]],
	4: [["dialogue", "vb_f4_clear"], ["say", "tauros", "– Держится. Теперь главное: генератор. Без света жители не вернутся."]],
	5: [["dialogue", "vb_f5_clear"], ["say", "tauros", "– Свет есть. Теперь люди вернутся."],
		["say", "ankvila", "– Наконец-то увижу, в кого стреляю."]],
	6: [["say", "", "Рыцари заваривают пробоины. Из-за стали ещё долго слышно, как что-то скребётся."]],
	7: [["say", "ursuz", "– Чисто."]],
	8: [["say", "ankvila", "– Готов. Видимо, всё из-за него."],
		["say", "", "Урсуз смотрит на ручной радар и мотает головой."],
		["say", "ursuz", "– Нет. Их всё ещё много. Ниже."],
		["say", "tauros", "– Значит, вожак был не последним звеном. Идём."]],
}
const WAVE_LINES := [["ankvila", "– Одна есть! Урсуз, сколько там ещё?"], ["ursuz", "– Много."], ["ankvila", "– Ненавижу, когда он прав."]]

var w: Node2D
var n := 0
var spawned := {}        # сколько врагов каждого вида уже вылезло на этом заходе
var spawn_t := 0.7
var life_t := 4.0        # реплики жителей и рабочих
var sparks: Array = []   # искры сварки: [точка, скорость, сколько ещё видно]
var spark_t := 0.0
var farewell_on := false
var shot_t := 3.0
var bark_t := 5.0
var tracers: Array = []  # [от, до, сколько ещё видно]
var barks: Array = []    # {who, text, t}
var followers: Array = []
var trail: Array = []
var wave_left := 0       # сколько псов текущей волны ещё не вылезло
var wave_pause := 0.0
var busy := false        # идёт заставка этажа
var seq := 0


func setup(world: Node2D) -> void:
	w = world
	n = int(w.map.star_floor)
	z_index = 50
	for k in KNIGHTS:
		var o = w.cut_find(k)
		if o != null:
			w.lamp_pos.append(Vector2(o.pos))
	if n == 4 and _hunting():
		wave_left = WAVE_SIZE
	if n == 10 and _q() == "active" and not G.flag("vb_button"):
		_calm_dogs()
	_on_enter.call_deferred()


func _q() -> String:
	return G.p.quests.get("vb", "")


## Этаж ещё не отбит, а рыцари стоят на нём: псы лезут.
func _hunting() -> bool:
	if _q() != "active" or not G.flag("vb_tauros") or n < 1 or n > 8 or G.flag("vb_f%d" % n):
		return false
	if n >= 6 and not G.flag("vb_deep"):
		return false
	return n == StoryVB.frontier()


func _knights() -> Array:
	var res: Array = []
	for k in KNIGHTS:
		var o = w.cut_find(k)
		if o != null:
			res.append(o)
	return res


# ---------------- вход на карту ----------------

func _on_enter() -> void:
	if n == 0:
		_camp_enter()
		return
	if _q() == "done":
		if not G.flag("vb_star_after_seen"):
			G.set_flag("vb_star_after_seen")
			_play([["dialogue", "vb_star_after"]])
		return
	if _q() != "active":
		return
	# после лаборатории: рыцари ждут Гения там, где он появился, и прощаются прямо здесь
	if _after_lab():
		_farewell.call_deferred()
		return
	if not G.flag("vb_tauros") or G.flag("vb_e%d" % n):
		return
	if n == 10:
		G.set_flag("vb_e10")
		_play([["dialogue", "vb_f10_enter"], ["call", _shoot_calm], ["wait", 0.5], ["call", _shoot_calm], ["wait", 0.6],
			["say", "tauros", "– Не стрелять. Они не нападают."], ["dialogue", "vb_f10_weld"]])
		return
	if not INTRO.has(n) or (n >= 6 and not G.flag("vb_deep")) or n != StoryVB.frontier():
		return
	G.set_flag("vb_e%d" % n)
	var steps: Array = INTRO[n].duplicate()
	if n == 9:
		steps.append(["call", func(): _clear_floor(false)])
	_play(steps)


func _knights_leave() -> void:
	for o in _knights():
		w.remove_cut_actor(o)


## Лаборатория пройдена (или чипы уничтожены), а прощания ещё не было.
func _after_lab() -> bool:
	return _q() == "active" and n >= 1 and n <= 10 and (G.flag("vb_f11") or G.flag("vb_button")) and not G.flag("vb_farewell")


## Возврат пушки (если она ещё у Гения) и прощание на том этаже, где стоят рыцари.
## Потом рыцари идут к лифту и уезжают наверх.
func _farewell() -> void:
	if farewell_on or busy or _knights().is_empty():
		return
	farewell_on = true
	var steps: Array = []
	if G.has("Импульсная пушка") and not G.flag("vb_gun_back"):
		steps.append(["dialogue", "vb_return_gun"])
	steps.append(["dialogue", "vb_farewell"])
	steps.append(["call", _knights_walk_off])
	steps.append(["wait", 2.4])
	steps.append(["fade_out", 0.6])
	steps.append(["call", _knights_leave])
	steps.append(["fade_in", 0.6])
	_play(steps)


func _knights_walk_off() -> void:
	var lift = _lift()
	if lift == null:
		return
	var i := 0
	for o in _knights():
		var goal: Vector2i = lift.pos
		for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 0), Vector2i(0, 2), Vector2i(2, 1)].slice(i):
			var c: Vector2i = lift.pos + d
			if w.walkable(c) and not w.obj_at.has(c):
				goal = c
				break
		i += 1
		w.cut_walk(o.id, goal)


func _lift():
	for o in w.objs:
		if str(o.get("action", "")) == "vb_lift":
			return o
	return null


func _camp_enter() -> void:
	if _q() == "active" and not G.flag("vb_arrived"):
		G.set_flag("vb_arrived")
		_play([["dialogue", "vb_arrive"], ["say", "taxi", "– Удачи, Гений. Вернёшься живым, подвезу бесплатно. Ну, почти бесплатно."],
			["walk", "genius", 20, 16], ["dialogue", "vb_nikki_talk"]])


func _play(steps: Array, done: Callable = Callable()) -> void:
	busy = true
	w.play_cutscene(steps, func():
		busy = false
		if done.is_valid():
			done.call())


# ---------------- каждый кадр ----------------

func _process(delta: float) -> void:
	for t in tracers:
		t[2] -= delta
	tracers = tracers.filter(func(t): return t[2] > 0.0)
	for b in barks:
		b.t -= delta
	barks = barks.filter(func(b): return b.t > 0.0)
	queue_redraw()
	_sparks_tick(delta)
	_wander_tick(delta)
	if w.blocked() or w.cut_active or busy or w.enc_wait > 0.0:
		return
	if _after_lab() and not farewell_on:
		_farewell()
		return
	_follow_tick(delta)
	_life_barks(delta)
	# третий узел генератора запущен: свет дают, даже если диалог закрыли раньше времени
	if n == 5 and G.flag("vb_gen3") and not G.flag("vb_f5") and _q() == "active":
		_clear_floor(true)
		return
	if n == 0:
		_camp_barks(delta)
		return
	if _hunting():
		_spawn_tick(delta)
	elif n == 5 and _q() == "active" and G.flag("vb_tauros") and not G.flag("vb_f5"):
		_spawn_tick(delta)
	_shoot_tick(delta)


func _camp_barks(delta: float) -> void:
	bark_t -= delta
	if bark_t > 0.0:
		return
	bark_t = randf_range(5.0, 9.0)
	var near: Array = []
	for o in w.objs:
		if o.type == "npc" and o.get("id", "") == "wounded" and w._cheb(o.pos, w.ppos) <= 7:
			near.append(o)
	if not near.is_empty():
		_bark(near.pick_random(), StoryVB.WOUNDED_LINES.pick_random())


# ---------------- псы из пробоин ----------------

func _alive() -> int:
	var c := 0
	for m in w.mobs:
		if m.get("vb", false) and not m.get("calm", false) and m.enemy != "muezzin_cave":
			c += 1
	return c


func _kills(e: String) -> int:
	return int(G.p.flags.get("vb_k%d_%s" % [n, e], 0))


func _spawn_tick(delta: float) -> void:
	if n == 4:
		_wave_tick(delta)
		return
	spawn_t -= delta
	if spawn_t > 0.0:
		return
	spawn_t = randf_range(0.9, 1.7)
	if _alive() >= MAX_ALIVE or w.map.burrows.is_empty():
		return
	if n == 5:
		# до генератора: собаки лезут в двери машинного зала, рыцари их держат
		if _alive() < 2:
			_spawn("pes_cave")
		return
	var spec: Dictionary = SPEC.get(n, {})
	var left: Array = []
	for e in spec:
		if _kills(e) + int(spawned.get(e, 0)) < int(spec[e]):
			left.append(e)
	if left.is_empty():
		return
	# из пробоин лезут по двое, если на этаже тихо
	for k in (2 if _alive() <= 1 else 1):
		left = left.filter(func(x): return _kills(x) + int(spawned.get(x, 0)) < int(spec[x]))
		if left.is_empty() or _alive() >= MAX_ALIVE:
			return
		var e: String = left.pick_random()
		if _spawn(e):
			spawned[e] = int(spawned.get(e, 0)) + 1


func _wave_tick(delta: float) -> void:
	if wave_pause > 0.0:
		wave_pause -= delta
		if wave_pause <= 0.0:
			wave_left = WAVE_SIZE
		return
	if wave_left > 0:
		spawn_t -= delta
		if spawn_t <= 0.0:
			spawn_t = 0.8
			if _spawn("pes_cave"):
				wave_left -= 1
		return
	if _alive() > 0:
		return
	var wave := int(G.p.flags.get("vb_wave", 0)) + 1
	G.p.flags["vb_wave"] = wave
	G.changed.emit()
	if wave >= WAVES:
		_clear_floor(true)
		return
	var k := wave - 1
	_bark_who(WAVE_LINES[k % WAVE_LINES.size()][0], WAVE_LINES[k % WAVE_LINES.size()][1])
	G.say("Волна %d из %d отбита. Следующая на подходе." % [wave, WAVES])
	wave_pause = 2.5


func _spawn(e: String) -> bool:
	var b: Vector2i = w.map.burrows.pick_random()
	var cell := Vector2i(-1, -1)
	for d in [Vector2i(1, 1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var c: Vector2i = b + d
		if w.in_bounds(c) and w.walkable(c) and c != w.ppos and w._cheb(c, w.ppos) > 2 and not _mob_at(c):
			cell = c
			break
	if cell.x < 0:
		return false
	seq += 1
	var m := {"type": "mob", "enemy": e, "id": "vb%d_%d_%d" % [n, seq, randi() % 1000], "title": D.ENEMIES[e].name,
		"aggro": 99, "block": false, "vb": true, "pos": cell, "fpos": Vector2(b), "stun": 0.4, "home": cell}
	w.mobs.append(m)
	return true


func _mob_at(c: Vector2i) -> bool:
	for m in w.mobs:
		if m.pos == c:
			return true
	return false


## Лаборатория: собаки бродят и не нападают, им не велят.
func _calm_dogs() -> void:
	for p in [Vector2i(9, 4), Vector2i(14, 9), Vector2i(19, 12), Vector2i(7, 11), Vector2i(17, 3), Vector2i(11, 13)]:
		if w.walkable(p):
			seq += 1
			w.mobs.append({"type": "mob", "enemy": "pes_cave", "id": "vb10_calm_%d" % seq, "title": D.ENEMIES.pes_cave.name,
				"aggro": 0, "block": false, "vb": true, "calm": true, "pos": p, "fpos": Vector2(p), "stun": 0.0, "home": p})


# ---------------- рыцари стреляют ----------------

func _shoot_tick(delta: float) -> void:
	var ks := _knights()
	if ks.is_empty():
		return
	shot_t -= delta
	if shot_t > 0.0:
		return
	shot_t = randf_range(2.0, 2.8) if n == 4 or n == 5 else randf_range(2.8, 3.8)
	var k = ks.pick_random()
	var best = null
	var bd := 99.0
	for m in w.mobs:
		if not m.get("vb", false) or m.get("calm", false) or m.enemy == "muezzin_cave" or m == w.cur_mob:
			continue
		if w._cheb(m.pos, w.ppos) <= 1:
			continue
		var d: float = Vector2(m.pos).distance_to(Vector2(k.pos))
		if d < bd and d <= 14.0:
			bd = d
			best = m
	if best == null:
		return
	_shoot(k, best)
	if randf() < 0.4:
		_bark(k, StoryVB.KNIGHT_BARKS[k.id].pick_random())


func _shoot(k: Dictionary, m: Dictionary) -> void:
	tracers.append([w.iso(Vector2(k.pos)) + Vector2(0, -26), w.iso(m.fpos) + Vector2(0, -6), 0.18])
	w.shake_amt = maxf(w.shake_amt, 1.5)
	w.mobs.erase(m)
	w._add_body(m)
	on_kill(m)


## Заставка десятого: двух собак рыцари снимают по привычке, прежде чем понимают, что те не нападают.
func _shoot_calm() -> void:
	var ks := _knights()
	for m in w.mobs:
		if m.get("calm", false) and not ks.is_empty():
			_shoot(ks.pick_random(), m)
			return


func on_kill(m: Dictionary) -> void:
	if not m.get("vb", false) or m.get("calm", false):
		return
	var key := "vb_k%d_%s" % [n, m.enemy]
	G.p.flags[key] = int(G.p.flags.get(key, 0)) + 1
	spawned[m.enemy] = maxi(0, int(spawned.get(m.enemy, 0)) - 1)
	G.changed.emit()
	if m.enemy == "muezzin_cave" and n == 8:
		_clear_floor.call_deferred(true)
		return
	_check_clear.call_deferred()


func _check_clear() -> void:
	if not _hunting() or not SPEC.has(n):
		return
	var spec: Dictionary = SPEC[n]
	for e in spec:
		if _kills(e) < int(spec[e]):
			return
	if n == 2 and StoryVB.saved() < 3:
		G.say("Псы на площади перебиты. Осталось вывести жителей к лифту (%d/3)." % StoryVB.saved())
		return
	_clear_floor(true)


func _clear_floor(scene: bool) -> void:
	if G.flag("vb_f%d" % n):
		return
	G.set_flag("vb_f%d" % n)
	G.add_xp(60 if n < 8 else 120)
	for m in w.mobs.duplicate():
		if m.get("vb", false) and not m.get("calm", false):
			w.mobs.erase(m)
	if n == 5:
		G.p.flags["vb_f5_day"] = int(G.p.day)
		G.say("«Южная Звезда»: подача энергии восстановлена. Этажи 1–5 открыты для жителей, начинается ремонт.")
	G.changed.emit()
	# карта пересобирается после заставки: пробоины становятся заплатами, загорается свет
	if scene and CLEAR.has(n):
		_play(CLEAR[n], _rebuild)
	elif scene:
		_rebuild()


func _rebuild() -> void:
	G.world_dirty = true
	G.refresh_world()


## Генератор запущен (main.gd после третьей мини-игры).
func generator_done() -> void:
	_clear_floor(true)


# ---------------- жители идут к лифту ----------------

func follow(id: String) -> void:
	var o = w.cut_find(id)
	if o == null or is_following(id):
		return
	if o.get("block", false):
		w.astar.set_point_solid(o.pos, false)
	o.block = false
	if w.obj_at.get(o.pos) == o:
		w.obj_at.erase(o.pos)
	o["cpos"] = Vector2(o.pos)
	followers.append(o)
	trail = [w.ppos]


func is_following(id: String) -> bool:
	for o in followers:
		if o.id == id:
			return true
	return false


func _follow_tick(delta: float) -> void:
	if followers.is_empty():
		return
	if trail.is_empty() or trail[-1] != w.ppos:
		trail.append(w.ppos)
		if trail.size() > 12:
			trail.pop_front()
	var lift = null
	for o in w.objs:
		if o.get("kind", "") == "lift":
			lift = o
	for i in followers.size():
		var o: Dictionary = followers[i]
		var idx := maxi(0, trail.size() - 2 - i * 2)
		var goal := Vector2(trail[idx])
		var cp: Vector2 = o.cpos
		if cp.distance_to(goal) > 0.05:
			var d := goal - cp
			if absf(d.x - d.y) > 0.05:
				o["face"] = (d.x - d.y) < 0
			o.cpos = cp.move_toward(goal, delta * 5.5 * 0.85)
			o["walk"] = float(o.get("walk", 0.0)) + delta
		else:
			o["walk"] = 0.0
		o.pos = Vector2i(o.cpos.round())
	if lift == null:
		return
	for o in followers.duplicate():
		if w._cheb(o.pos, lift.pos) <= 2:
			followers.erase(o)
			G.set_flag("vb_s_" + str(o.id))
			w.objs.erase(o)
			G.say("%s в безопасности: рыцари отправили лифт наверх (%d/3)." % [Story.WHO[o.id].name, StoryVB.saved()])
			G.add_xp(15)
			G.changed.emit()
			if StoryVB.saved() >= 3:
				_check_clear()


# ---------------- жизнь на отбитых этажах ----------------

const LIFE_BARKS := {
	"worker": ["– Подай ключ на семнадцать!", "– Держи балку, держи!", "– Варю шов, не смотри на огонь.", "– Ещё одна плита, и обед.",
		"– Кто опять унёс мою кувалду?", "– Тут трубу менять целиком.", "– Осторожно, сверху капает.", "– Проводку тянем к третьему."],
	"resident": ["– Свет! Настоящий свет!", "– Мама, смотри, лифт едет!", "– Я свою дверь сразу узнал, представляете?", "– Шторы бы повесить...",
		"– Тут был мой ларёк. Будет снова.", "– Спасибо рыцарям. И Вам, Гений.", "– Пахнет краской. Хороший запах.", "– Соседи вернулись, слышите?"],
}


func _life_barks(delta: float) -> void:
	life_t -= delta
	if life_t > 0.0:
		return
	life_t = randf_range(3.0, 6.0)
	var near: Array = []
	for o in w.objs:
		if o.type == "npc" and LIFE_BARKS.has(o.get("id", "")) and w._cheb(o.pos, w.ppos) <= 8:
			near.append(o)
	if not near.is_empty():
		var o: Dictionary = near.pick_random()
		_bark(o, LIFE_BARKS[o.id].pick_random())


## Жители и рабочие ходят по этажу недалеко от своего места: делают вид, что заняты.
func _wander_tick(delta: float) -> void:
	for o in w.objs:
		if not o.get("wander", false) or followers.has(o):
			continue
		if not o.has("home"):
			o["home"] = o.pos
			o["wt"] = randf_range(1.0, 5.0)
		if o.has("wpath"):
			var path: Array = o.wpath
			if path.is_empty():
				o.erase("wpath")
				o.erase("cpos")
				o["walk"] = 0.0
				if not w.obj_at.has(o.pos):
					w.obj_at[o.pos] = o
				continue
			var c := Vector2(path[0])
			var cp: Vector2 = o.get("cpos", Vector2(o.pos))
			var d := c - cp
			if absf(d.x - d.y) > 0.01:
				o["face"] = (d.x - d.y) < 0
			cp = cp.move_toward(c, delta * 2.2)
			o["cpos"] = cp
			o["walk"] = float(o.get("walk", 0.0)) + delta
			if cp.distance_to(c) < 0.01:
				path.pop_front()
				var cell := Vector2i(c)
				if w.obj_at.get(o.pos) == o:
					w.obj_at.erase(o.pos)
				o.pos = cell
				if not w.obj_at.has(cell):
					w.obj_at[cell] = o
			continue
		o.wt = float(o.wt) - delta
		if o.wt > 0.0 or w.blocked() or w.cut_active:
			continue
		o.wt = randf_range(3.0, 7.0)
		if o.get("weld", false) and randf() < 0.7:
			continue
		var home: Vector2i = o.home
		var t: Vector2i = home + Vector2i(randi_range(-3, 3), randi_range(-2, 2))
		if not w.in_bounds(t) or not w.walkable(t) or w.obj_at.has(t) or t == w.ppos or _mob_at(t):
			continue
		if o.get("block", false):
			w.astar.set_point_solid(o.pos, false)
			o.block = false
		var ids: Array = w.astar.get_id_path(o.pos, t)
		if ids.size() < 2 or ids.size() > 8:
			continue
		ids.pop_front()
		o["wpath"] = ids


## Сварка: у рабочих с горелкой сыплются искры и вспыхивает свет.
func _sparks_tick(delta: float) -> void:
	for sp in sparks:
		sp[0] += sp[1] * delta
		sp[1].y += 90.0 * delta
		sp[2] -= delta
	sparks = sparks.filter(func(sp): return sp[2] > 0.0)
	spark_t -= delta
	if spark_t > 0.0:
		return
	spark_t = randf_range(0.08, 0.2)
	for o in w.objs:
		if o.get("weld", false) and not o.has("wpath") and randf() < 0.5:
			var cp: Vector2 = o.get("cpos", Vector2(o.pos))
			var base: Vector2 = w.iso(cp) + Vector2(10 if not o.get("face", false) else -10, -14)
			for k in randi_range(2, 4):
				sparks.append([base, Vector2(randf_range(-40, 40), randf_range(-60, -10)), randf_range(0.25, 0.5)])


# ---------------- реплики над головой ----------------

func _bark(o: Dictionary, text: String) -> void:
	for b in barks:
		if b.o == o:
			return
	barks.append({"o": o, "text": text, "t": 2.6})


func _bark_who(id: String, text: String) -> void:
	var o = w.cut_find(id)
	if o != null:
		_bark(o, text)


func _draw() -> void:
	for sp in sparks:
		var a: float = clampf(sp[2] / 0.3, 0.0, 1.0)
		draw_rect(Rect2(sp[0], Vector2(1.5, 1.5)), Color(Pal.G5 if randf() < 0.6 else Pal.R3, a))
	for t in tracers:
		var a: float = clampf(t[2] / 0.18, 0.0, 1.0)
		draw_line(t[0], t[1], Color(Pal.G5, a), 2.0)
		draw_line(t[0], t[1], Color(Pal.R3, a * 0.6), 1.0)
		draw_circle(t[1], 3.0 * a + 1.0, Color(Pal.G5, a))
	var font: Font = Pal.font
	for b in barks:
		var o: Dictionary = b.o
		var cp: Vector2 = o.get("cpos", Vector2(o.pos))
		var h := 50.0 if o.has("ntex") else 36.0
		var p: Vector2 = w.iso(cp) + Vector2(0, -h)
		var tw := font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var r := Rect2(p - Vector2(tw / 2.0 + 4, 10), Vector2(tw + 8, 13))
		var a: float = clampf(b.t / 0.4, 0.0, 1.0)
		draw_rect(r, Color(Pal.BG, 0.85 * a))
		draw_rect(r, Color(Pal.G2, a), false, 1.0)
		draw_string(font, p + Vector2(-tw / 2.0, 0), b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(Pal.G5, a))
