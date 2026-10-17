extends RefCounted
## Карты: Кальдера (рисованная) и Пустошь у её ворот (собирается по зерну, всегда одинаково).
## Пол: # стена-панель, B кирпич, R руины, . металл, , бетон, _ плитка, = ковёр, s песок, a пепел, пробел — пустота.

const CALDERA := [
	"##############################",
	"#________#..........#________#",
	"#________#..........#________#",
	"#________#..........#________#",
	"#________#..........#________#",
	"#________#..........#________#",
	"####_#####..........#####_####",
	"#.................,,,,,......#",
	"#..............,,,,,,,,......#",
	"#.........,,,,,,,,,..........#",
	"#............................,",
	"#............................#",
	"#............................#",
	"####_#####..........#####_####",
	"#========#..........#________#",
	"#========#..........#________#",
	"#========#..........#________#",
	"#========#..........#________#",
	"#========#..........#________#",
	"##############################",
]

## Внешность NPC: спрайт на карте и портрет в сцене.
const NPC_LOOKS := {
	"trader": {"person": {"coat": 2, "hair": 1, "skin": 5, "accent": 6, "race": "Крысолюд"},
		"portrait": {"sex": "М", "race": "Крысолюд", "coat": 2, "collar": 6, "hair": 2, "glasses": true, "traits": ["Большие уши"]}},
	"cook": {"person": {"coat": 5, "hair": 6, "skin": 5, "long": true},
		"portrait": {"sex": "Ж", "coat": 4, "hair": 6, "old": true, "traits": ["Морщины", "Полнота"]}},
	"surgeon": {"person": {"coat": 5, "hair": 2, "skin": 5, "accent": 8},
		"portrait": {"sex": "М", "coat": 5, "collar": 8, "hair": 3, "mask": true, "glasses": true, "old": true}},
	"emirra": {"person": {"coat": 2, "hair": 8, "skin": 5, "accent": 9, "long": true},
		"portrait": {"sex": "Ж", "coat": 2, "collar": 9, "red": true, "freckles": true, "traits": ["Рыжие волосы", "Веснушки на коже"]}},
	"guard": {"person": {"coat": 3, "hat": true, "skin": 5, "accent": 8},
		"portrait": {"sex": "М", "coat": 3, "collar": 8, "helmet": true, "scar": true}},
	"old": {"person": {"coat": 1, "hair": 6, "skin": 4},
		"portrait": {"sex": "М", "coat": 1, "hair": 6, "beard": true, "old": true, "traits": ["Белые глаза", "Морщины"]}},
	"raider": {"person": {"coat": 2, "hat": true, "skin": 5, "accent": 9},
		"portrait": {"sex": "М", "coat": 2, "collar": 9, "bald": true, "scar": true, "traits": ["Ножевые шрамы", "Зубы крысолюда"]}},
}


func get_map(name: String) -> Dictionary:
	if name == "waste":
		return _waste()
	return _caldera()


func _caldera() -> Dictionary:
	var objs: Array = []
	# Лавка (северо-запад)
	for x in [1, 3, 5, 7]:
		objs.append(_prop("shelf", x, 1, "Стеллаж со старьём"))
	for x in range(2, 7):
		objs.append(_prop("counter", x, 3, "Прилавок"))
	objs.append(_npc("trader", 4, 2, "Старьёвщик Бартоломей", "trader_start", 2))
	# Столовая (северо-восток)
	objs.append(_prop("pot", 27, 1, "Котёл с похлёбкой"))
	objs.append(_npc("cook", 26, 2, "Матушка Грета", "cook_start", 1))
	for pos in [Vector2i(22, 3), Vector2i(24, 3), Vector2i(22, 5), Vector2i(24, 5)]:
		objs.append(_prop("table", pos.x, pos.y, "Стол"))
	# Ночлежка (юго-запад)
	for pos in [Vector2i(1, 14), Vector2i(1, 16), Vector2i(1, 18), Vector2i(6, 18), Vector2i(8, 18)]:
		objs.append(_prop("bed", pos.x, pos.y, "Койка", "bed"))
	# Аптека (юго-восток)
	objs.append(_npc("surgeon", 26, 16, "Хирург Ирвин Кост", "surgeon_start", 1))
	objs.append(_prop("table", 24, 17, "Операционный стол"))
	objs.append(_prop("shelf", 27, 14, "Шкаф с препаратами"))
	objs.append(_prop("shelf", 28, 14, "Шкаф с препаратами"))
	objs.append(_prop("lamp", 22, 14, "Лампа"))
	# Зал
	objs.append(_prop("terminal", 14, 3, "Терминал Института", "terminal"))
	objs.append(_prop("terminal", 16, 3, "Доска заданий Института", "board"))
	for pos in [Vector2i(11, 1), Vector2i(19, 1), Vector2i(2, 8), Vector2i(27, 8), Vector2i(11, 18), Vector2i(19, 18)]:
		objs.append(_prop("lamp", pos.x, pos.y, "Лампа"))
	objs.append(_prop("barrel", 12, 11, "Бочка"))
	objs.append(_prop("barrel", 13, 12, "Бочка"))
	objs.append(_npc("emirra", 14, 11, "Рыжая незнакомка", "emirra_start", 1))
	for pos in [Vector2i(17, 15), Vector2i(18, 15), Vector2i(18, 16)]:
		objs.append(_prop("crate", pos.x, pos.y, "Ящики"))
	objs.append(_npc("old", 16, 16, "Слепой Ефим", "old_start", 1))
	objs.append(_npc("guard", 28, 9, "Страж ворот", "guard_start", 1))
	objs.append(_prop("gate", 29, 10, "Гермоворота в Пустошь", "gate_out"))
	for pos in [Vector2i(10, 7), Vector2i(20, 12)]:
		objs.append(_prop("pipe", pos.x, pos.y, "Трубы"))
	var grid: Array = []
	for row in CALDERA:
		var arr: Array = []
		for i in row.length():
			arr.append(row[i])
		grid.append(arr)
	return {"name": "Кальдера", "floor": grid, "objs": objs, "waste": false,
		"spawns": {"start": Vector2i(15, 8), "gate": Vector2i(27, 10)}, "light": 11.0}


func _waste() -> Dictionary:
	var w := 40
	var h := 32
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var grid: Array = []
	for y in h:
		var row: Array = []
		for x in w:
			row.append("s")
		grid.append(row)
	# пепельные проплешины
	for i in 7:
		var cx := rng.randi_range(4, w - 5)
		var cy := rng.randi_range(4, h - 5)
		var r := rng.randf_range(2.0, 4.5)
		for y in range(cy - 5, cy + 6):
			for x in range(cx - 5, cx + 6):
				if x >= 0 and y >= 0 and x < w and y < h and Vector2(x - cx, y - cy).length() < r + rng.randf() * 0.8:
					grid[y][x] = "a"
	# руины
	var ruins := [Rect2i(10, 3, 7, 6), Rect2i(25, 13, 7, 6), Rect2i(5, 19, 5, 5), Rect2i(33, 4, 4, 4)]
	for rr in ruins:
		for x in range(rr.position.x, rr.end.x):
			for y in range(rr.position.y, rr.end.y):
				var edge: bool = x == rr.position.x or y == rr.position.y or x == rr.end.x - 1 or y == rr.end.y - 1
				if edge:
					grid[y][x] = "R"
				else:
					grid[y][x] = ","
		# проломы
		for i in 3:
			var side := rng.randi_range(0, 3)
			var gx := rng.randi_range(rr.position.x + 1, rr.end.x - 2)
			var gy := rng.randi_range(rr.position.y + 1, rr.end.y - 2)
			match side:
				0: grid[rr.position.y][gx] = "s"
				1: grid[rr.end.y - 1][gx] = "s"
				2: grid[gy][rr.position.x] = "s"
				3: grid[gy][rr.end.x - 1] = "s"
	var objs: Array = []
	var taken := {}
	var keep := [Vector2i(2, 2), Vector2i(3, 3), Vector2i(34, 27), Vector2i(33, 28), Vector2i(28, 16)]
	objs.append(_prop("gate", 2, 2, "Гермоворота Кальдеры", "gate_in"))
	objs.append(_prop("wreck", 34, 27, "Разбитый караван"))
	objs.append(_prop("cache", 33, 28, "Ящик с красным крестом", "cache_med"))
	objs.append(_prop("cache", 28, 16, "Тайник падальщиков", "cache_ruin"))
	objs.append(_prop("bones", 31, 27, "Кости", "", false))
	objs.append(_mob("iskaz", "iskaz_1", 31, 25, 4))
	objs.append(_mob("pes", "pes_1", 14, 14, 6))
	objs.append(_mob("pes", "pes_2", 20, 24, 6))
	objs.append(_mob("pes", "pes_3", 8, 27, 6))
	objs.append(_mob("padal", "padal_1", 13, 6, 5))
	objs.append(_mob("padal", "padal_2", 36, 10, 5))
	for o in objs:
		taken[Vector2i(o.x, o.y)] = true
	var kinds := [["rocks", "Камни", true], ["tree", "Мёртвое дерево", true], ["bones", "Кости", false]]
	for i in 70:
		var x := rng.randi_range(1, w - 2)
		var y := rng.randi_range(1, h - 2)
		var pos := Vector2i(x, y)
		if taken.has(pos) or not (grid[y][x] in ["s", "a"]):
			continue
		var near_key := false
		for k in keep:
			if absi(k.x - x) <= 1 and absi(k.y - y) <= 1:
				near_key = true
		if near_key:
			continue
		var kd: Array = kinds[rng.randi_range(0, kinds.size() - 1)]
		objs.append(_prop(kd[0], x, y, kd[1], "", kd[2]))
		taken[pos] = true
	_ensure_paths(grid, objs, Vector2i(3, 3), [Vector2i(33, 27), Vector2i(28, 15), Vector2i(13, 7), Vector2i(30, 25)])
	return {"name": "Пустошь у Кальдеры", "floor": grid, "objs": objs, "waste": true,
		"spawns": {"gate": Vector2i(3, 3)}, "light": 30.0}


func _prop(tex: String, x: int, y: int, title: String, action: String = "", block: bool = true) -> Dictionary:
	return {"type": "prop", "tex": tex, "x": x, "y": y, "title": title, "action": action, "block": block}


func _npc(id: String, x: int, y: int, title: String, dialogue: String, reach: int) -> Dictionary:
	return {"type": "npc", "id": id, "x": x, "y": y, "title": title, "action": dialogue, "block": true,
		"reach": reach, "look": NPC_LOOKS[id].person}


func _mob(enemy: String, id: String, x: int, y: int, aggro: int) -> Dictionary:
	return {"type": "mob", "enemy": enemy, "id": id, "x": x, "y": y, "title": D.ENEMIES[enemy].name,
		"aggro": aggro, "block": false}


## Если до важной точки не дойти, пробиваем проход по прямой.
func _ensure_paths(grid: Array, objs: Array, from: Vector2i, targets: Array) -> void:
	for t in targets:
		if _reachable(grid, objs, from, t):
			continue
		var n := maxi(absi(t.x - from.x), absi(t.y - from.y))
		for i in n + 1:
			var x := int(round(lerpf(from.x, t.x, i / float(n))))
			var y := int(round(lerpf(from.y, t.y, i / float(n))))
			if grid[y][x] == "R":
				grid[y][x] = "s"
			for o in objs.duplicate():
				if o.type == "prop" and o.action == "" and o.x == x and o.y == y:
					objs.erase(o)


func _reachable(grid: Array, objs: Array, from: Vector2i, to: Vector2i) -> bool:
	var solid := {}
	for o in objs:
		if o.block and o.type != "mob":
			solid[Vector2i(o.x, o.y)] = true
	var h := grid.size()
	var w: int = grid[0].size()
	var seen := {from: true}
	var queue := [from]
	while queue.size() > 0:
		var c: Vector2i = queue.pop_front()
		if absi(c.x - to.x) <= 1 and absi(c.y - to.y) <= 1:
			return true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: Vector2i = c + d
			if nx.x < 0 or nx.y < 0 or nx.x >= w or nx.y >= h or seen.has(nx):
				continue
			if grid[nx.y][nx.x] == "R" or solid.has(nx):
				continue
			seen[nx] = true
			queue.append(nx)
	return false
