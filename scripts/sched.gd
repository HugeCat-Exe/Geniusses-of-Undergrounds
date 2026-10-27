extends RefCounted
## Распорядок жителей: вечером они сами идут к ночным местам, утром обратно.
## Положение считается по часам, поэтому житель виден в пути на любом ярусе,
## через который он проходит, а при входе на карту стоит там, где должен быть сейчас.

## Переходы между картами: [карта A, точка выхода на A, карта B, точка прихода на B].
## Обратно – наоборот. Точки – это spawns карт (там же появляется и Гений).
const LINKS := [
	["caldera1", "up2", "caldera2", "down1"],
	["caldera2", "up3", "caldera3", "down2"],
	["caldera3", "up4", "caldera4", "down3"],
	["caldera1", "danabooth", "caldera_danahome", "door"],
]

## Днём и ночью. Четвёртый элемент "hide" – дошёл до двери своего дома и скрылся внутри.
const ROUTINE := {
	"kid": {"day": ["caldera1", 13, 3], "night": ["caldera1", 13, 2, "hide"]},
	"smoker": {"day": ["caldera1", 4, 5], "night": ["caldera3", 16, 4]},
	"beggar": {"day": ["caldera1", 11, 2], "night": ["caldera3", 12, 5]},
	"ian": {"day": ["caldera2", 4, 7], "night": ["caldera3", 17, 4]},
	"patrol": {"day": ["caldera2", 16, 7], "night": ["caldera_danahome", 4, 2]},
	"zoya": {"day": ["caldera4", 5, 3], "night": ["caldera4", 7, 2, "hide"]},
	"pip": {"day": ["caldera4", 7, 6], "night": ["caldera4", 11, 5]},
	"miron": {"day": ["caldera4", 9, 3], "night": ["caldera4", 9, 5]},
}

const LEAVE := 20 * 60    # вечером расходятся с 20:00
const BACK := 6 * 60      # утром возвращаются с 6:00
const MIN_PER_TILE := 0.8 # игровых минут на клетку: прогулочный шаг
const STAIRS_MIN := 1.5   # сколько житель «на лестнице», невидимый

static var _spawns: Dictionary = {}


static func spawn(map: String, key: String) -> Vector2i:
	if not _spawns.has(map):
		_spawns[map] = preload("res://scripts/maps.gd").new().get_map(map).spawns
	return _spawns[map].get(key, Vector2i(1, 1))


## Цепочка карт от A до B (обход в ширину по LINKS).
static func _route(a: String, b: String) -> Array:
	var prev := {a: ""}
	var q: Array = [a]
	while not q.is_empty():
		var m: String = q.pop_front()
		if m == b:
			break
		for l in LINKS:
			for dir in 2:
				var from: String = l[0] if dir == 0 else l[2]
				var to: String = l[2] if dir == 0 else l[0]
				if from == m and not prev.has(to):
					prev[to] = m
					q.append(to)
	var res: Array = []
	var cur := b
	while cur != "":
		res.push_front(cur)
		cur = prev.get(cur, "")
	return res


## Через какую клетку уходить с карты a на соседнюю b, и где появиться на b.
static func _door(a: String, b: String) -> Array:
	for l in LINKS:
		if l[0] == a and l[2] == b:
			return [spawn(a, l[1]), spawn(b, l[3])]
		if l[2] == a and l[0] == b:
			return [spawn(a, l[3]), spawn(b, l[1])]
	return [Vector2i.ZERO, Vector2i.ZERO]


## Отрезки пути: [{map, a, b, t0, t1}], время в минутах от начала прогулки.
static func legs(from: Array, to: Array) -> Array:
	var maps := _route(from[0], to[0])
	var res: Array = []
	var t := 0.0
	var start := Vector2i(from[1], from[2])
	for i in maps.size():
		var m: String = maps[i]
		var goal := Vector2i(to[1], to[2])
		var next_start := Vector2i.ZERO
		if i < maps.size() - 1:
			var d := _door(m, maps[i + 1])
			goal = d[0]
			next_start = d[1]
		var dist := maxi(absi(goal.x - start.x), absi(goal.y - start.y)) * 1.2 + 1.0
		var dur := dist * MIN_PER_TILE
		res.append({"map": m, "a": start, "b": goal, "t0": t, "t1": t + dur})
		t += dur
		if i < maps.size() - 1:
			t += STAIRS_MIN
			start = next_start
	return res


static func _stagger(id: String, salt: String) -> int:
	return absi(hash(id + salt)) % 40


## Где житель сейчас: {map, cell, walk: bool, leg, f (доля пройденного отрезка)}; map == "" – не виден.
static func state(id: String) -> Dictionary:
	var r: Dictionary = ROUTINE[id]
	var m := float(G.p.hour) * 60.0 + float(G.p.get("minf", 0.0))
	var leave := float(LEAVE + _stagger(id, "n"))
	var back := float(BACK + _stagger(id, "d"))
	var from: Array = r.day
	var to: Array = r.night
	var e := 0.0
	if m >= leave:
		e = m - leave
	elif m < back:
		e = m + 1440.0 - leave
	else:
		from = r.night
		to = r.day
		e = m - back
	for lg in legs(from, to):
		if e < lg.t0:
			return {"map": "", "walk": false}
		if e < lg.t1:
			return {"map": lg.map, "walk": true, "leg": lg, "f": (e - lg.t0) / maxf(0.01, lg.t1 - lg.t0)}
	if to.size() > 3 and to[3] == "hide":
		return {"map": "", "walk": false}
	return {"map": to[0], "walk": false, "cell": Vector2i(to[1], to[2])}


static func at_home(id: String, map: String) -> bool:
	var s := state(id)
	return s.map == map and not s.walk
