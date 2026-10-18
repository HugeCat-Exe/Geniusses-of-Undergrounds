extends RefCounted
## Карты: Кальдера (рисованная) и Пустошь у её ворот (собирается по зерну, всегда одинаково).
## Пол: # стена-панель, B кирпич, R руины, . металл, , бетон, _ плитка, = ковёр, s песок, a пепел, пробел — пустота.

## Кальдера — три яруса вниз. v — шахта (сквозь неё видно нижний ярус), g — решётка, / — лестница,
## p — площадь на дне шахты, k — асфальт.
const FLOOR1 := [
	"####################",
	"#sss#aa,,,,,,,,,,,,#",
	"#sssaaa,,,,,,,,,,,,#",
	"#sss#aa,,,,,,,,,,,,#",
	"#####,,,gggggg,,,,,#",
	"#,,,,,,,gvvvvg,,,,,#",
	"#,,,,,,,gvvvvg,,,,,#",
	"#,,,,,,,gggggg,,,,,#",
	"#,,,,,,,,,,,,,,,,,,#",
	"#,,,,,,,,,,,,,,///,#",
	"#,,,,,,,,,,,,,,///,#",
	"####################",
]
const FLOOR2 := [
	"######################",
	"#_____#......#=======#",
	"#_____#......#=======#",
	"#_____,......,=======#",
	"###,,##,,,,,,##,,,####",
	"#///,,,,,,,,,,,,,,,,,#",
	"#///,,,,gggggg,,,,,,,#",
	"#,,,,,,,gvvvvg,,,,,,,#",
	"#,,,,,,,gvvvvg,,,,,,,#",
	"#,,,,,,,gggggg,,,////#",
	"#,,,,,,,,,,,,,,,,////#",
	"######################",
]
const FLOOR3 := [
	"######################",
	"#///,#______#........#",
	"#///,#______#.======.#",
	"#,,,,#______#........#",
	"#,,,,##,,,###........#",
	"#,,,,,,,,,,,,........#",
	"#,,,,,,pppp,,#.......#",
	"#,,,,,,pppp,,#########",
	"####=###,,,,,,,,,,,,,#",
	"#======#,,,,,,,,,,,,,#",
	"#======,,,,,,,,,,,,,,#",
	"#======#,,,,,,,,,,,,,#",
	"######################",
]

## Внешность NPC: спрайт на карте и портрет в сцене.
const NPC_LOOKS := {
	"trader": {"person": {"coat": 2, "hair": 1, "skin": 5, "accent": 6, "race": "Крысолюд"},
		"portrait": {"sex": "М", "race": "Крысолюд", "coat": 2, "collar": 6, "hair": 2, "glasses": true, "traits": ["Большие уши"]}},
	"cook": {"person": {"coat": 5, "hair": 6, "skin": 5, "long": true},
		"portrait": {"sex": "Ж", "coat": 4, "hair": 6, "old": true, "traits": ["Морщины", "Полнота"]}},
	"surgeon": {"person": {"coat": 5, "hair": 2, "skin": 5, "accent": 8},
		"portrait": {"sex": "М", "coat": 5, "collar": 8, "hair": 3, "mask": true, "glasses": true, "old": true}},
	"ryzhaya": {"person": {"coat": 2, "hair": 8, "skin": 5, "accent": 9, "long": true},
		"portrait": {"sex": "Ж", "coat": 2, "collar": 9, "red": true, "freckles": true, "traits": ["Рыжие волосы", "Веснушки на коже"]}},
	"guard": {"person": {"coat": 3, "hat": true, "skin": 5, "accent": 8},
		"portrait": {"sex": "М", "coat": 3, "collar": 8, "helmet": true, "scar": true}},
	"old": {"person": {"coat": 1, "hair": 6, "skin": 4},
		"portrait": {"sex": "М", "coat": 1, "hair": 6, "beard": true, "old": true, "traits": ["Белые глаза", "Морщины"]}},
	"beggar": {"person": {"coat": 1, "hair": 2, "skin": 4},
		"portrait": {"sex": "М", "coat": 1, "hair": 2, "beard": true, "traits": ["Морщины"]}},
	"kid": {"person": {"coat": 4, "hair": 3, "skin": 5, "long": true, "race": "Крысолюд"},
		"portrait": {"sex": "Ж", "race": "Крысолюд", "coat": 4, "hair": 3, "traits": ["Большие уши", "Веснушки на коже"]}},
	"smoker": {"person": {"coat": 3, "hair": 1, "skin": 5, "accent": 4},
		"portrait": {"sex": "М", "coat": 3, "collar": 4, "hair": 1, "scar": true}},
	"gunsmith": {"person": {"coat": 1, "hat": true, "skin": 5, "accent": 8},
		"portrait": {"sex": "М", "coat": 1, "collar": 8, "bald": true, "beard": true, "glasses": true, "traits": ["Ожоги"]}},
	"ian": {"person": {"coat": 4, "hair": 2, "skin": 5},
		"portrait": {"sex": "М", "coat": 4, "hair": 2, "traits": ["Веснушки на коже"]}},
	"mistel": {"person": {"coat": 4, "hair": 2, "skin": 5, "long": true},
		"portrait": {"sex": "Ж", "coat": 4, "collar": 3, "hair": 2, "traits": ["Морщины"]}},
	"patrol": {"person": {"coat": 3, "hat": true, "skin": 5, "accent": 4},
		"portrait": {"sex": "Ж", "coat": 3, "collar": 4, "helmet": true}},
	"bartender": {"person": {"coat": 2, "hair": 1, "skin": 5, "accent": 6},
		"portrait": {"sex": "М", "coat": 2, "collar": 6, "hair": 1, "beard": true, "traits": ["Золотой зуб"]}},
	"raider": {"person": {"coat": 2, "hat": true, "skin": 5, "accent": 9},
		"portrait": {"sex": "М", "coat": 2, "collar": 9, "bald": true, "scar": true, "traits": ["Ножевые шрамы", "Зубы крысолюда"]}},
}


func get_map(name: String) -> Dictionary:
	match name:
		"waste":
			return _waste()
		"caldera2":
			return _caldera2()
		"caldera3":
			return _caldera3()
	return _caldera1()


func _grid(rows: Array) -> Array:
	var grid: Array = []
	for row in rows:
		var arr: Array = []
		for i in row.length():
			arr.append(row[i])
		grid.append(arr)
	return grid


## Перила по краю шахты.
func _rails(grid: Array, objs: Array) -> void:
	for y in grid.size():
		for x in grid[y].size():
			if grid[y][x] != "v":
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var c: String = grid[y + d.y][x + d.x]
				if c != "v" and c != "#":
					objs.append(_prop("rail", x, y, "Перила над шахтой"))
					break


func _lamps(objs: Array, list: Array) -> void:
	for pos in list:
		objs.append(_prop("lamp", pos.x, pos.y, "Лампа"))


func _caldera1() -> Dictionary:
	var objs: Array = []
	objs.append(_prop("stairs_up", 1, 2, "Подъём на поверхность", "to_surface"))
	objs.append(_prop("crate", 8, 1, "Мешки с песком"))
	objs.append(_prop("barrel", 5, 3, "Бочка с водой"))
	objs.append(_npc("guard", 6, 1, "Страж Кальдеры", "guard_start", 1))
	objs.append(_prop("terminal", 2, 6, "Терминал Института", "terminal"))
	for x in [10, 14]:
		objs.append(_prop("shack", x, 1, "Лачуга из листового железа"))
	objs.append(_prop("laundry", 16, 2, "Бельё на верёвке"))
	objs.append(_npc("beggar", 12, 2, "Нищий Тимоха", "res_beggar", 1))
	objs.append(_npc("kid", 17, 3, "Девочка Ласка", "res_kid", 1))
	objs.append(_prop("cable", 15, 4, "Провода и гирлянда"))
	objs.append(_prop("pipe", 1, 8, "Трубы"))
	objs.append(_prop("tent", 4, 10, "Палатка беженцев"))
	objs.append(_prop("tent", 7, 10, "Палатка беженцев"))
	objs.append(_prop("crate", 11, 10, "Ящики"))
	objs.append(_prop("lift", 18, 6, "Грузовой лифт", "lift"))
	objs.append(_prop("stairs_down", 18, 9, "Лестница вниз, на ярус 2", "go:caldera2:down1"))
	objs.append(_npc("smoker", 14, 10, "Курильщик Лёва", "stairs_smoker", 1))
	_lamps(objs, [Vector2i(7, 4), Vector2i(14, 7), Vector2i(2, 9), Vector2i(9, 3)])
	var grid := _grid(FLOOR1)
	return {"name": "Кальдера · Ярус 1 · Вход", "floor": grid, "objs": objs, "waste": false, "depth": 1,
		"spawns": {"surface": Vector2i(2, 2), "start": Vector2i(2, 2), "lift": Vector2i(17, 6), "up2": Vector2i(14, 9)}, "light": 10.0}


func _caldera2() -> Dictionary:
	var objs: Array = []
	objs.append(_prop("stairs_up", 1, 5, "Лестница наверх, на ярус 1", "go:caldera1:up2"))
	objs.append(_npc("ian", 4, 7, "Ян Мистел", "stairs_ian", 1))
	# медпункт
	objs.append(_npc("surgeon", 3, 2, "Хирург Ирвин Кост", "surgeon_start", 1))
	objs.append(_prop("shelf", 1, 1, "Шкаф с препаратами"))
	objs.append(_prop("table", 4, 1, "Операционный стол"))
	objs.append(_prop("autodoc", 5, 1, "Автодок «Санитар-3»", "autodoc"))
	objs.append(_prop("bed", 1, 3, "Койка для больных"))
	# оружейная
	objs.append(_npc("gunsmith", 10, 2, "Оружейник Сава Клин", "gunsmith_start", 1))
	objs.append(_prop("gunrack", 8, 1, "Стойка с оружием"))
	objs.append(_prop("gunrack", 12, 1, "Стойка с оружием"))
	objs.append(_prop("counter", 8, 3, "Верстак"))
	# лавка
	objs.append(_npc("trader", 17, 2, "Старьёвщик Бартоломей", "trader_start", 1))
	objs.append(_prop("clothes", 14, 1, "Вешалка с одеждой"))
	objs.append(_prop("clothes", 20, 1, "Вешалка с одеждой"))
	objs.append(_prop("shelf", 19, 1, "Полки с безделушками"))
	objs.append(_prop("counter", 19, 3, "Прилавок"))
	objs.append(_prop("board", 6, 5, "Доска объявлений", "board"))
	objs.append(_prop("lift", 20, 6, "Грузовой лифт", "lift"))
	objs.append(_prop("stairs_down", 20, 9, "Лестница вниз, на ярус 3", "go:caldera3:down2"))
	objs.append(_npc("patrol", 15, 7, "Патрульная Дана", "res_patrol", 1))
	objs.append(_prop("crate", 1, 9, "Ящики"))
	objs.append(_prop("crate", 2, 9, "Ящики"))
	objs.append(_prop("barrel", 6, 10, "Бочка"))
	objs.append(_prop("cable", 13, 5, "Провода"))
	_lamps(objs, [Vector2i(7, 8), Vector2i(15, 5), Vector2i(3, 10), Vector2i(12, 10)])
	var grid := _grid(FLOOR2)
	return {"name": "Кальдера · Ярус 2 · Торговый", "floor": grid, "objs": objs, "waste": false, "depth": 1,
		"spawns": {"down1": Vector2i(4, 6), "lift": Vector2i(19, 6), "up3": Vector2i(16, 10)}, "light": 10.0}


func _caldera3() -> Dictionary:
	var objs: Array = []
	objs.append(_prop("stairs_up", 1, 1, "Лестница наверх, на ярус 2", "go:caldera2:up3"))
	objs.append(_npc("old", 4, 2, "Слепой Ефим", "old_start", 1))
	# кухня
	objs.append(_npc("cook", 9, 2, "Матушка Грета", "cook_start", 1))
	objs.append(_prop("pot", 11, 1, "Котёл с похлёбкой"))
	objs.append(_prop("shelf", 6, 1, "Полки с посудой"))
	objs.append(_prop("table", 7, 3, "Разделочный стол"))
	# площадь на дне шахты
	objs.append(_prop("table", 8, 6, "Стол"))
	objs.append(_prop("table", 10, 7, "Стол"))
	objs.append(_prop("stool", 7, 6, "Табурет", "", false))
	objs.append(_prop("stool", 9, 7, "Табурет", "", false))
	objs.append(_prop("barrel", 12, 7, "Бочка-жаровня"))
	# бар «Клык»
	for x in [15, 16, 17, 18]:
		objs.append(_prop("bar", x, 3, "Стойка бара «Клык»"))
	objs.append(_npc("bartender", 17, 2, "Бармен Гарри Зуб", "bar_start", 2))
	objs.append(_prop("bottles", 16, 1, "Полки с бутылками"))
	objs.append(_prop("bottles", 19, 1, "Полки с бутылками"))
	objs.append(_prop("neon", 14, 1, "Неоновая вывеска"))
	for pos in [Vector2i(15, 4), Vector2i(18, 4), Vector2i(20, 5)]:
		objs.append(_prop("stool", pos.x, pos.y, "Табурет", "", false))
	objs.append(_prop("table", 16, 5, "Столик"))
	if G.p.get("companion", "") != "ryzhaya":
		objs.append(_npc("ryzhaya", 19, 5, "Рыжая", "ry_start", 1))
	# мотель
	for pos in [Vector2i(1, 9), Vector2i(1, 11), Vector2i(3, 11), Vector2i(5, 11)]:
		objs.append(_prop("bed", pos.x, pos.y, "Койка в мотеле", "bed"))
	# жилой блок
	for pos in [Vector2i(10, 11), Vector2i(13, 11)]:
		objs.append(_prop("tent", pos.x, pos.y, "Жилая палатка"))
	objs.append(_prop("shack", 18, 11, "Дом семьи Мистел"))
	objs.append(_npc("mistel", 16, 10, "Ода Мистел", "mistel_start", 1))
	objs.append(_prop("laundry", 14, 9, "Бельё на верёвке"))
	objs.append(_prop("cable", 11, 8, "Провода"))
	objs.append(_prop("lift", 20, 9, "Грузовой лифт", "lift"))
	_lamps(objs, [Vector2i(8, 9), Vector2i(5, 5), Vector2i(12, 5), Vector2i(20, 11)])
	var grid := _grid(FLOOR3)
	return {"name": "Кальдера · Ярус 3 · Жилой", "floor": grid, "objs": objs, "waste": false, "depth": 0,
		"spawns": {"down2": Vector2i(3, 3), "lift": Vector2i(19, 9)}, "light": 10.0}


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
	# обрывок старой трассы — точка эвакуации
	for y in [12, 13]:
		for x in range(0, 8):
			grid[y][x] = "k"
	var keep := [Vector2i(2, 2), Vector2i(3, 3), Vector2i(34, 27), Vector2i(33, 28), Vector2i(28, 16), Vector2i(1, 12), Vector2i(4, 13), Vector2i(6, 12)]
	objs.append(_prop("hatch", 2, 2, "Шахта Кальдеры", "to_caldera"))
	objs.append(_prop("roadend", 1, 12, "Обрывок дороги · точка эвакуации", "evac"))
	objs.append(_prop("wreck", 6, 11, "Ржавый автобус"))
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
		if taken.has(pos) or not (grid[y][x] in ["s", "a"]) or (y >= 10 and y <= 15 and x <= 9):
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
	_ensure_paths(grid, objs, Vector2i(3, 3), [Vector2i(33, 27), Vector2i(28, 15), Vector2i(13, 7), Vector2i(30, 25), Vector2i(3, 13)])
	return {"name": "Пустошь у Кальдеры", "floor": grid, "objs": objs, "waste": true,
		"spawns": {"gate": Vector2i(3, 3), "hatch": Vector2i(3, 3), "road": Vector2i(3, 13)}, "light": 30.0}


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
