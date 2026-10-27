extends RefCounted
## Карты: Кальдера (рисованная) и Пустошь у её ворот (собирается по зерну, всегда одинаково).
## Пол: # стена-панель, B кирпич, R руины, . металл, , бетон, _ плитка, = ковёр, s песок, a пепел, пробел – пустота.

## Кальдера – три яруса вниз. v – шахта (сквозь неё видно нижний ярус), g – решётка, / – лестница,
## p – площадь на дне шахты, k – асфальт.
const FLOOR1 := [
	"####################",
	"#sss#aa,,,,,,,,,,,,#",
	"#sssaaa,,,,,,,,,,,,#",
	"#sss#aa,,,,,,,,,,,,#",
	"#####,,,gggggg,,,,,#",
	"#///,,,,gvvvvg,,,,,#",
	"#///,,,,gvvvvg,,,,,#",
	"#,,,,,,,gggggg,,,,,#",
	"#,,,,,,,,,,,,,,,,,,#",
	"#,,,,,,,,,,,,,,,,,,#",
	"####################",
]
const FLOOR2 := [
	"######################",
	"#_____#......#====#,,#",
	"#_____#......#====#,,#",
	"#_____#......#====#,,#",
	"#,,,,,,,,,,,,,,,,,,,,#",
	"#///,,,,gggggg,,,,,,,#",
	"#///,,,,gvvvvg,,,,,,,#",
	"#,,,,,,,gvvvvg,,,,,,,#",
	"#///,,,,gggggg,,,,,,,#",
	"#///,,,,,,,,,,,,,,,,,#",
	"######################",
]
const FLOOR3 := [
	"######################",
	"#///,#______#........#",
	"#///,#______#.======.#",
	"#,,,,#______#........#",
	"#,,,,,,,,,,,,........#",
	"#,,,,,,pppp,,........#",
	"#,,,,,,pppp,,,,,,,,,,#",
	"####,####,,,,,,,,,,,,#",
	"#======#,,,,,,,,,,,,,#",
	"#======,,,,,,,,,,,,,,#",
	"#======#,,,,,,,,,,,,,#",
	"######################",
]
## Ярус 4 – жилые кварталы: дома жильцов у дальней стены, домик Рыжей, общий двор.
const FLOOR4 := [
	"######################",
	"#///,,,,,,,,,,,,,,,,,#",
	"#///,,,,,,,,,,,,,,,,,#",
	"#,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,,,,,____,,,,,,,,#",
	"#,,,,,,,,____,,,,,,,,#",
	"#,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,,,,,,,,,,,,,,,,,#",
	"######################",
]
## Рейд: заброшенные ярусы под кварталами, за заваренным люком.
const RAID1 := [
	"########################",
	"#///,,,#,,,,,,,#,,,,,,,#",
	"#///,,,#,,,,,,,#,,,,,,,#",
	"#,,,,,,#,,,,,,,#,,,,,,,#",
	"#,,,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,,,,,,,,,,,,,,,,,,,#",
	"###,####,,,,,,,####,####",
	"#,,,,,,#,,,,,,,#,,,,,,,#",
	"#,,,,,,#,,,,,,,#,,,,,,,#",
	"#,,,,,,,,,,,,,,,,,,,,,,#",
	"#,,,,,,#,,,,,,,#,,,,,,,#",
	"####,###,,,,,,,###,#####",
	"#///,,,,,,,,,,,,,,,,,,,#",
	"#///,,,,,,,,,,,,,,,,,,,#",
	"########################",
]
const RAID2 := [
	"####################",
	"#///,,,,#,,,,,,,,,,#",
	"#///,,,,#,,,,,,,,,,#",
	"#,,,,,,,#,,,,,,,,,,#",
	"#,,,,,,,,,,,wwww,,,#",
	"#,,,,,,,#,,,wwww,,,#",
	"####,####,,,wwww,,,#",
	"#,,,,,,,#,,,,,,,,,,#",
	"#,,,,,,,#,,,,,,,,,,#",
	"#,,,,,,,,,,,,,,,,,,#",
	"#,,,,,,,#,,,,,,,,,,#",
	"#,,,,,,,#,,,,,,,,,,#",
	"####################",
]
## Домик Рыжей изнутри.
const DANA_HOME := [
	"########",
	"#______#",
	"#______#",
	"#,,,,,,#",
	"#,,,,,,#",
	"########",
]
const RY_HOME := [
	"##########",
	"#===_____#",
	"#===_____#",
	"#===_____#",
	"#,,,,,,,,#",
	"#,,,,,,,,#",
	"#,,,,,,,,#",
	"##########",
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
	"zoya": {"person": {"coat": 5, "hair": 6, "skin": 5, "long": true, "accent": 3},
		"portrait": {"sex": "Ж", "coat": 5, "collar": 3, "hair": 6, "old": true, "traits": ["Морщины"]}},
	"miron": {"person": {"coat": 1, "hair": 6, "skin": 4, "accent": 8},
		"portrait": {"sex": "М", "coat": 1, "collar": 8, "hair": 6, "beard": true, "old": true, "glasses": true, "traits": ["Ожоги"]}},
	"pip": {"person": {"coat": 4, "hair": 3, "skin": 5, "race": "Крысолюд"},
		"portrait": {"sex": "М", "race": "Крысолюд", "coat": 4, "hair": 3, "traits": ["Большие уши"]}},
	"stray": {"person": {"coat": 1, "hair": 2, "skin": 4},
		"portrait": {"sex": "М", "coat": 1, "hair": 2, "beard": true, "traits": ["Морщины", "Ножевые шрамы"]}},
	"stranger": {"person": {"coat": 1, "hat": true, "skin": 3, "accent": 3},
		"portrait": {"sex": "М", "coat": 1, "collar": 3, "bald": true, "mask": true, "glasses": true}},
	"librarian": {"person": {"coat": 4, "hair": 6, "skin": 4, "accent": 5},
		"portrait": {"sex": "М", "coat": 4, "collar": 5, "hair": 6, "glasses": true, "old": true, "traits": ["Морщины"]}},
	"taxi": {"person": {"coat": 2, "hat": true, "skin": 5, "accent": 9},
		"portrait": {"sex": "М", "coat": 2, "collar": 9, "hair": 1, "beard": true, "glasses": true, "scar": true}},
	"wanderer": {"person": {"coat": 5, "hat": true, "skin": 4, "accent": 8},
		"portrait": {"sex": "М", "coat": 5, "collar": 8, "hair": 3, "beard": true, "old": true, "traits": ["Морщины"]}},
	"raider": {"person": {"coat": 2, "hat": true, "skin": 5, "accent": 9},
		"portrait": {"sex": "М", "coat": 2, "collar": 9, "bald": true, "scar": true, "traits": ["Ножевые шрамы", "Зубы крысолюда"]}},
}


func get_map(name: String) -> Dictionary:
	return _build(name)


func _build(name: String) -> Dictionary:
	match name:
		"waste":
			return _waste()
		"caldera2":
			return _caldera2()
		"caldera3":
			return _caldera3()
		"caldera4":
			return _caldera4()
		"caldera_ryhome":
			return _ry_home()
		"caldera_danahome":
			return _dana_home()
		"mini_bus":
			return _mini_bus()
		"mini_dogs":
			return _mini_dogs()
		"mini_camp":
			return _mini_camp()
		"poi_ruins":
			return _poi_ruins()
		"poi_forest":
			return _poi_forest()
		"raid1":
			return _raid1()
		"raid2":
			return _raid2()
		"poi_station":
			return _poi_station()
		"poi_river":
			return _poi_river()
		"poi_tower":
			return _poi_tower()
		"poi_den":
			return _poi_den()
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


## Правило расстановки: важное стоит у дальних стен (верх и левый край на экране),
## ничего не ставится вплотную перед стеной, обращённой к камере, и в проходах.
func _caldera1() -> Dictionary:
	var objs: Array = []
	objs.append(_prop("stairs_up", 1, 2, "Подъём на поверхность", "to_surface"))
	objs.append(_prop("barrel", 5, 1, "Бочка с водой"))
	objs.append(_npc("guard", 6, 1, "Страж Кальдеры", "guard_start", 1))
	objs.append(_prop("crate", 8, 1, "Мешки с песком"))
	for x in [10, 13]:
		objs.append(_prop("shack", x, 1, "Лачуга из листового железа"))
	objs.append(_npc("beggar", 11, 2, "Нищий Тимоха", "res_beggar", 1))
	# будка патрульной Даны: пускает к себе только своих, как Рыжая
	objs.append(_big("danabooth", 15, 1, 2, 2, "Будка патрульной Даны", "dana_door"))
	objs.append(_npc("kid", 13, 3, "Девочка Ласка", "res_kid", 1))
	objs.append(_prop("lift", 17, 1, "Грузовой лифт", "lift"))
	objs.append(_prop("stairs_down", 1, 5, "Лестница вниз, на ярус 2", "go:caldera2:down1"))
	objs.append(_npc("smoker", 4, 5, "Курильщик Лёва", "stairs_smoker", 1))
	objs.append(_prop("terminal", 1, 7, "Терминал Института", "terminal"))
	objs.append(_prop("pipe", 1, 8, "Трубы"))
	objs.append(_prop("tent", 15, 5, "Палатка беженцев"))
	objs.append(_prop("tent", 17, 5, "Палатка беженцев"))
	objs.append(_prop("cable", 16, 4, "Провода и гирлянда"))
	_lamps(objs, [Vector2i(7, 3), Vector2i(14, 7), Vector2i(5, 8)])
	var grid := _grid(FLOOR1)
	return {"name": "Кальдера · Ярус 1 · Вход", "floor": grid, "objs": objs, "waste": false, "depth": 1,
		"spawns": {"surface": Vector2i(2, 2), "start": Vector2i(2, 2), "lift": Vector2i(17, 2), "up2": Vector2i(4, 6), "danabooth": Vector2i(15, 3)}, "light": 10.0}


func _caldera2() -> Dictionary:
	var objs: Array = []
	objs.append(_prop("stairs_up", 1, 5, "Лестница наверх, на ярус 1", "go:caldera1:up2"))
	objs.append(_prop("stairs_down", 1, 8, "Лестница вниз, на ярус 3", "go:caldera3:down2"))
	objs.append(_npc("ian", 4, 7, "Ян Мистел", "stairs_ian", 1))
	# медпункт
	objs.append(_prop("shelf", 1, 1, "Шкаф с препаратами"))
	objs.append(_prop("table", 2, 1, "Операционный стол"))
	objs.append(_prop("autodoc", 4, 1, "Автодок «Санитар-3»", "autodoc"))
	objs.append(_npc("surgeon", 3, 3, "Хирург Ирвин Кост", "surgeon_start", 1))
	objs.append(_prop("bed", 1, 3, "Койка для больных"))
	# оружейная
	objs.append(_prop("gunrack", 7, 1, "Стойка с оружием"))
	objs.append(_prop("counter", 9, 1, "Верстак"))
	objs.append(_prop("gunrack", 11, 1, "Стойка с оружием"))
	objs.append(_npc("gunsmith", 9, 2, "Оружейник Сава Клин", "gunsmith_start", 1))
	# лавка
	objs.append(_prop("clothes", 14, 1, "Вешалка с одеждой"))
	objs.append(_prop("shelf", 16, 1, "Полки с безделушками"))
	objs.append(_npc("trader", 15, 3, "Старьёвщик Бартоломей", "trader_start", 1))
	# лифт в нише
	objs.append(_prop("lift", 19, 1, "Грузовой лифт", "lift"))
	objs.append(_prop("jobscreen", 6, 4, "Экран заданий Института", "board"))
	if G.p.get("companion", "") != "patrol":
		objs.append(_npc("patrol", 16, 7, "Патрульная Дана", "dana_start", 1))
	objs.append(_prop("crate", 15, 5, "Ящики"))
	objs.append(_prop("barrel", 18, 5, "Бочка"))
	objs.append(_prop("cable", 14, 4, "Провода"))
	_lamps(objs, [Vector2i(7, 5), Vector2i(17, 4), Vector2i(6, 8)])
	var grid := _grid(FLOOR2)
	return {"name": "Кальдера · Ярус 2 · Торговый", "floor": grid, "objs": objs, "waste": false, "depth": 1,
		"spawns": {"down1": Vector2i(4, 5), "lift": Vector2i(19, 2), "up3": Vector2i(4, 8)}, "light": 10.0}


func _caldera3() -> Dictionary:
	var objs: Array = []
	objs.append(_prop("stairs_up", 1, 1, "Лестница наверх, на ярус 2", "go:caldera2:up3"))
	objs.append(_prop("stairs_down", 3, 1, "Лестница вниз, на ярус 4", "go:caldera4:down3"))
	objs.append(_npc("old", 3, 4, "Слепой Ефим", "old_start", 1))
	objs.append(_prop("lift", 1, 5, "Грузовой лифт", "lift"))
	# кухня
	objs.append(_prop("shelf", 6, 1, "Полки с посудой"))
	objs.append(_prop("table", 7, 1, "Разделочный стол"))
	objs.append(_prop("pot", 10, 1, "Котёл с похлёбкой"))
	objs.append(_npc("cook", 8, 2, "Матушка Грета", "cook_start", 1))
	# площадь на дне шахты
	objs.append(_prop("table", 8, 5, "Стол"))
	objs.append(_prop("stool", 7, 5, "Табурет", "", false))
	objs.append(_prop("stool", 9, 6, "Табурет", "", false))
	objs.append(_prop("barrel", 11, 6, "Бочка-жаровня"))
	# бар «Клык»
	objs.append(_prop("neon", 14, 1, "Неоновая вывеска"))
	objs.append(_prop("bottles", 16, 1, "Полки с бутылками"))
	objs.append(_prop("bottles", 19, 1, "Полки с бутылками"))
	objs.append(_npc("bartender", 17, 2, "Бармен Гарри Зуб", "bar_start", 2))
	for x in [15, 16, 17, 18]:
		objs.append(_prop("bar", x, 3, "Стойка бара «Клык»"))
	for pos in [Vector2i(15, 4), Vector2i(18, 4)]:
		objs.append(_prop("stool", pos.x, pos.y, "Табурет", "", false))
	objs.append(_prop("table", 16, 5, "Столик"))
	if G.p.get("companion", "") != "ryzhaya" and not G.ry_home_today():
		objs.append(_npc("ryzhaya", 19, 4, "Рыжая", "ry_start", 1))
	# мотель
	for pos in [Vector2i(1, 8), Vector2i(3, 8), Vector2i(5, 8)]:
		objs.append(_prop("bed", pos.x, pos.y, "Койка в мотеле", "bed"))
	# жилой блок
	objs.append(_prop("shack", 8, 8, "Дом семьи Мистел"))
	objs.append(_npc("mistel", 9, 9, "Ода Мистел", "mistel_start", 1))
	objs.append(_prop("laundry", 11, 7, "Бельё на верёвке"))
	for pos in [Vector2i(14, 8), Vector2i(17, 8)]:
		objs.append(_prop("tent", pos.x, pos.y, "Жилая палатка"))
	_lamps(objs, [Vector2i(5, 5), Vector2i(13, 6), Vector2i(19, 7)])
	var grid := _grid(FLOOR3)
	return {"name": "Кальдера · Ярус 3 · Жилой", "floor": grid, "objs": objs, "waste": false, "depth": 0,
		"spawns": {"down2": Vector2i(2, 3), "lift": Vector2i(2, 5), "up4": Vector2i(3, 3)}, "light": 10.0}


func _caldera4() -> Dictionary:
	var objs: Array = []
	objs.append(_prop("stairs_up", 1, 1, "Лестница наверх, на ярус 3", "go:caldera3:up4"))
	objs.append(_prop("lift", 1, 5, "Грузовой лифт", "lift"))
	# дома жильцов вдоль дальней стены
	objs.append(_prop("laundry", 4, 1, "Бельё на верёвке"))
	objs.append(_npc("zoya", 5, 3, "Прачка Зоя", "zoya_start", 1))
	objs.append(_prop("shack", 7, 1, "Дом прачки Зои"))
	objs.append(_prop("shack", 10, 1, "Мастерская деда Мирона"))
	objs.append(_prop("crate", 11, 1, "Ящик с деталями"))
	objs.append(_prop("hatch", 12, 1, "Заваренный люк вниз", "raid_hatch"))
	objs.append(_npc("miron", 9, 3, "Дед Мирон", "miron_start", 1))
	# домик Рыжей: войти можно только по-приятельски
	objs.append(_big("ryhouse", 14, 1, 3, 2, "Домик Рыжей", "ry_door"))
	objs.append(_prop("pot", 17, 2, "Горшок с бледным вьюнком"))
	objs.append(_prop("tent", 19, 1, "Жилая палатка"))
	# вдоль левой стены
	objs.append(_prop("pipe", 1, 8, "Трубы с тёплой водой"))
	objs.append(_prop("tent", 1, 9, "Палатка без хозяина"))
	# общий двор
	objs.append(_prop("barrel", 10, 5, "Бочка-жаровня"))
	objs.append(_prop("table", 13, 7, "Общий стол"))
	objs.append(_prop("stool", 12, 7, "Табурет", "", false))
	objs.append(_prop("stool", 14, 8, "Табурет", "", false))
	objs.append(_npc("pip", 7, 6, "Крысёнок Пип", "pip_start", 1))
	# книжный развал у левой стены
	objs.append(_prop("bookshelf", 1, 6, "Полки с книгами Института"))
	objs.append(_prop("bookshelf", 1, 7, "Полки с книгами Института"))
	objs.append(_npc("librarian", 2, 7, "Книжник Феликс", "lib_start", 1))
	_lamps(objs, [Vector2i(5, 5), Vector2i(17, 5), Vector2i(8, 9)])
	var grid := _grid(FLOOR4)
	return {"name": "Кальдера · Ярус 4 · Кварталы", "floor": grid, "objs": objs, "waste": false, "depth": 0,
		"spawns": {"down3": Vector2i(3, 3), "lift": Vector2i(2, 5), "ryhouse": Vector2i(15, 4), "raid": Vector2i(12, 3)}, "light": 9.0}


## Будка Даны: койка, шкафчик с формой, рация. Ночью Дана здесь (распорядок в sched.gd).
func _dana_home() -> Dictionary:
	var objs: Array = []
	objs.append(_prop("door", 1, 4, "Дверь на ярус 1", "go:caldera1:danabooth"))
	objs.append(_prop("bed", 1, 1, "Узкая койка, заправленная по-армейски"))
	objs.append(_prop("shelf", 3, 1, "Шкафчик с формой", "dana_locker"))
	objs.append(_prop("table", 5, 1, "Стол с рацией", "dana_radio"))
	objs.append(_prop("crate", 6, 3, "Ящик с запасными фонарями"))
	_lamps(objs, [Vector2i(4, 3)])
	var grid := _grid(DANA_HOME)
	return {"name": "Кальдера · Будка Даны", "floor": grid, "objs": objs, "waste": false, "depth": 0,
		"spawns": {"door": Vector2i(2, 4)}, "light": 6.0}


func _ry_home() -> Dictionary:
	var objs: Array = []
	objs.append(_prop("door", 1, 5, "Дверь на ярус 4", "go:caldera4:ryhouse"))
	objs.append(_prop("bed", 1, 1, "Кровать Рыжей"))
	objs.append(_prop("shelf", 4, 1, "Полка с безделушками", "ry_shelf"))
	objs.append(_prop("bottles", 6, 1, "Заначка из бара"))
	objs.append(_prop("neon", 7, 1, "Краденая вывеска «Клык»"))
	objs.append(_prop("table", 6, 3, "Столик с фотографией", "ry_photo"))
	objs.append(_prop("stool", 7, 4, "Табурет", "", false))
	objs.append(_prop("clothes", 1, 3, "Куртки на вешалке"))
	if G.p.get("companion", "") != "ryzhaya" and G.ry_home_today():
		objs.append(_npc("ryzhaya", 4, 3, "Рыжая", "ry_start", 1))
	_lamps(objs, [Vector2i(3, 1)])
	var grid := _grid(RY_HOME)
	return {"name": "Кальдера · Домик Рыжей", "floor": grid, "objs": objs, "waste": false, "depth": 0,
		"spawns": {"door": Vector2i(2, 5)}, "light": 7.0}


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
	# обрывок старой трассы – точка эвакуации
	for y in [12, 13]:
		for x in range(0, 8):
			grid[y][x] = "k"
	var keep := [Vector2i(2, 2), Vector2i(3, 3), Vector2i(5, 4), Vector2i(4, 5), Vector2i(6, 1), Vector2i(7, 1), Vector2i(8, 2), Vector2i(34, 27), Vector2i(33, 28), Vector2i(28, 16), Vector2i(1, 12), Vector2i(4, 13), Vector2i(6, 12)]
	objs.append(_prop("hatch", 2, 2, "Шахта Кальдеры", "to_caldera"))
	objs.append(_big("taxi", 6, 1, 2, 1, "Такси Арсена"))
	objs.append(_npc("taxi", 8, 2, "Таксист Арсен", "taxi_start", 1))
	# странствующий торговец стоит у шахты только в дни прихода (G.wander_here)
	if G.wander_here():
		objs.append(_prop("cart", 4, 5, "Тележка странника"))
		objs.append(_npc("wanderer", 5, 4, "Странник Гаспар", "wander_start", 1))
	if G.p.quests.get("spice", "") == "active" and not G.has("Пепельный тимьян"):
		objs.append(_prop("herb_ash", 5, 4, "Пепельный тимьян", "herb_1", false))
	objs.append(_prop("roadend", 1, 12, "Обрывок дороги · точка эвакуации", "evac"))
	objs.append(_big("bus", 3, 8, 5, 2, "Опрокинутый автобус"))
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
		for t in _cells(o):
			taken[t] = true
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


## Большой предмет: занимает w×h клеток начиная с (x, y) – дальнего от камеры угла.
func _big(tex: String, x: int, y: int, w: int, h: int, title: String, action: String = "") -> Dictionary:
	var o := _prop(tex, x, y, title, action)
	o.w = w
	o.h = h
	return o


func _cells(o: Dictionary) -> Array:
	var res: Array = []
	for dy in int(o.get("h", 1)):
		for dx in int(o.get("w", 1)):
			res.append(Vector2i(o.x + dx, o.y + dy))
	return res


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
				if o.type == "prop" and o.action == "" and not o.has("w") and o.x == x and o.y == y:
					objs.erase(o)


func _reachable(grid: Array, objs: Array, from: Vector2i, to: Vector2i) -> bool:
	var solid := {}
	for o in objs:
		if o.block and o.type != "mob":
			for t in _cells(o):
				solid[t] = true
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
			if grid[nx.y][nx.x] in ["R", "w"] or solid.has(nx):
				continue
			seen[nx] = true
			queue.append(nx)
	return false


# ---------------- Открытые места Пустоши: по ним можно ходить ----------------

func _sand(w: int, h: int, seed: int, ash_spots: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var grid: Array = []
	for y in h:
		var row: Array = []
		for x in w:
			row.append("s")
		grid.append(row)
	for i in ash_spots:
		var cx := rng.randi_range(2, w - 3)
		var cy := rng.randi_range(2, h - 3)
		var r := rng.randf_range(1.5, 3.5)
		for y in h:
			for x in w:
				if Vector2(x - cx, y - cy).length() < r:
					grid[y][x] = "a"
	return grid


func _fill(grid: Array, r: Rect2i, ch: String) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			grid[y][x] = ch


## Мусор и камни по зерну, мимо занятых клеток и запретных прямоугольников.
func _scatter(grid: Array, objs: Array, seed: int, count: int, avoid: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var taken := {}
	for o in objs:
		for t in _cells(o):
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					taken[t + Vector2i(dx, dy)] = true
	var kinds := [["rocks", "Камни", true], ["tree", "Мёртвое дерево", true], ["bones", "Кости", false]]
	var h := grid.size()
	var w: int = grid[0].size()
	for i in count:
		var pos := Vector2i(rng.randi_range(1, w - 2), rng.randi_range(1, h - 2))
		if taken.has(pos) or not (grid[pos.y][pos.x] in ["s", "a"]):
			continue
		var bad := false
		for r in avoid:
			if (r as Rect2i).grow(1).has_point(pos):
				bad = true
		if bad:
			continue
		var kd: Array = kinds[rng.randi_range(0, kinds.size() - 1)]
		objs.append(_prop(kd[0], pos.x, pos.y, kd[1], "", kd[2]))
		taken[pos] = true


# ---------------- Мини-истории по дороге (только пешком, см. worldmap.gd) ----------------

func _mini_bus() -> Dictionary:
	var w := 18
	var h := 13
	var grid := _sand(w, h, 701 + int(G.p.flags.get("mini_n", 0)), 2)
	_fill(grid, Rect2i(0, 8, w, 2), "k")
	var objs: Array = []
	objs.append(_big("bus", 4, 3, 5, 2, "Перевёрнутый автобус"))
	objs.append(_prop("cache", 10, 4, "Багажное отделение", "mini_bus_trunk"))
	objs.append(_prop("bones", 3, 6, "Кости у разбитого окна", "mini_bus_bones"))
	objs.append(_prop("crate", 12, 2, "Чемодан, выпавший на песок", "mini_bus_case"))
	objs.append(_prop("wreck", 14, 6, "Оторванное колесо"))
	objs.append(_exit(16, 11))
	_scatter(grid, objs, 702, 10, [Rect2i(3, 2, 11, 6), Rect2i(0, 8, w, 2), Rect2i(14, 10, 4, 3)])
	_ensure_paths(grid, objs, Vector2i(15, 11), [Vector2i(10, 5), Vector2i(3, 7), Vector2i(12, 3)])
	return {"name": "Перевёрнутый автобус", "floor": grid, "objs": objs, "waste": true, "mini": true,
		"spawns": {"enter": Vector2i(15, 11)}, "light": 30.0}


func _mini_dogs() -> Dictionary:
	var w := 16
	var h := 13
	var grid := _sand(w, h, 711 + int(G.p.flags.get("mini_n", 0)), 4)
	var objs: Array = []
	objs.append(_prop("deaddog", 5, 4, "Мёртвый пёс", "mini_dog_1"))
	objs.append(_prop("deaddog", 8, 3, "Мёртвый пёс", "mini_dog_2"))
	objs.append(_prop("deaddog", 7, 7, "Растерзанный пёс", "mini_dog_3"))
	objs.append(_prop("rocks", 10, 5, "Следы борьбы", "mini_dog_signs"))
	objs.append(_prop("bones", 3, 8, "Обглоданные кости"))
	objs.append(_exit(14, 11))
	_scatter(grid, objs, 712, 9, [Rect2i(3, 2, 9, 8), Rect2i(12, 10, 4, 3)])
	_ensure_paths(grid, objs, Vector2i(13, 11), [Vector2i(5, 5), Vector2i(8, 4), Vector2i(7, 8), Vector2i(10, 6)])
	return {"name": "Место схватки", "floor": grid, "objs": objs, "waste": true, "mini": true,
		"spawns": {"enter": Vector2i(13, 11)}, "light": 30.0}


func _mini_camp() -> Dictionary:
	var w := 16
	var h := 13
	var grid := _sand(w, h, 721 + int(G.p.flags.get("mini_n", 0)), 2)
	var objs: Array = []
	objs.append(_prop("tent", 4, 2, "Брошенная палатка", "mini_camp_tent"))
	objs.append(_prop("barrel", 7, 5, "Остывшее кострище в бочке"))
	objs.append(_prop("cache", 2, 6, "Свёрток под камнем", "mini_camp_stash"))
	objs.append(_prop("stump", 9, 3, "Пень с вырезанными зарубками", "mini_camp_note"))
	objs.append(_exit(14, 11))
	_scatter(grid, objs, 722, 10, [Rect2i(1, 1, 10, 7), Rect2i(12, 10, 4, 3)])
	_ensure_paths(grid, objs, Vector2i(13, 11), [Vector2i(4, 3), Vector2i(2, 7), Vector2i(9, 4)])
	return {"name": "Брошенная стоянка", "floor": grid, "objs": objs, "waste": true, "mini": true,
		"spawns": {"enter": Vector2i(13, 11)}, "light": 30.0}


func _exit(x: int, y: int) -> Dictionary:
	return _prop("roadend", x, y, "Тропа обратно · карта мира", "leave_poi")


## Монстры, которые возвращаются каждый день: id содержит номер дня.
func _daily(id: String) -> String:
	return "%s_d%d" % [id, int(G.p.get("day", 1))]


func _poi_station() -> Dictionary:
	var w := 26
	var h := 18
	var grid := _sand(w, h, 401, 3)
	# здание заправки у дальних стен, вход снизу
	_fill(grid, Rect2i(2, 1, 9, 6), ",")
	for x in range(2, 11):
		grid[1][x] = "R"
		grid[6][x] = "R"
	for y in range(1, 7):
		grid[y][2] = "R"
		grid[y][10] = "R"
	grid[6][6] = ","
	grid[6][7] = ","
	# площадка с колонками
	_fill(grid, Rect2i(2, 8, 21, 6), "k")
	var objs: Array = []
	objs.append(_prop("counter", 4, 2, "Прилавок заправки", "poi_station"))
	objs.append(_prop("shelf", 7, 2, "Пустые полки"))
	objs.append(_prop("crate", 9, 3, "Ящик из-под масла"))
	for x in [7, 11, 15]:
		objs.append(_prop("pump", x, 10, "Топливная колонка «Золотой век»"))
	objs.append(_prop("pylon", 21, 2, "Вывеска АЗС"))
	objs.append(_prop("wreck", 18, 6, "Брошенная легковушка"))
	objs.append(_prop("barrel", 13, 3, "Бочка с дырой"))
	objs.append(_exit(23, 16))
	_scatter(grid, objs, 402, 26, [Rect2i(2, 1, 9, 6), Rect2i(2, 8, 21, 6), Rect2i(20, 14, 6, 4)])
	_ensure_paths(grid, objs, Vector2i(22, 15), [Vector2i(4, 3), Vector2i(23, 16)])
	_rumor(grid, objs, "station")
	return {"name": "Заброшенная заправка", "floor": grid, "objs": objs, "waste": true, "poi": "station",
		"spawns": {"enter": Vector2i(22, 15)}, "light": 30.0}


func _poi_river() -> Dictionary:
	var w := 34
	var h := 24
	var grid := _sand(w, h, 501, 4)
	# река Лета: шесть клеток воды через всю карту
	_fill(grid, Rect2i(0, 9, w, 6), "w")
	# старый мост
	_fill(grid, Rect2i(16, 9, 2, 6), "h")
	var objs: Array = []
	objs.append(_prop("pylon", 13, 11, "Опора старого моста"))
	objs.append(_prop("stump", 20, 12, "Обломок опоры"))
	objs.append(_prop("post", 10, 15, "Спуск к воде", "poi_river"))
	objs.append(_prop("shack", 6, 3, "Хижина паромщика", "river_cache"))
	objs.append(_prop("wreck", 25, 3, "Ржавая лодка на берегу"))
	objs.append(_mob("pes", _daily("river_pes"), 27, 6, 5))
	for pos in [Vector2i(3, 15), Vector2i(7, 15), Vector2i(21, 15), Vector2i(26, 15), Vector2i(31, 15), Vector2i(4, 8), Vector2i(12, 8), Vector2i(22, 8), Vector2i(30, 8)]:
		objs.append(_prop("reeds", pos.x, pos.y, "Камыш", "", false))
	objs.append(_exit(30, 22))
	_scatter(grid, objs, 502, 30, [Rect2i(0, 8, w, 8), Rect2i(15, 15, 4, 4), Rect2i(27, 19, 7, 5)])
	_ensure_paths(grid, objs, Vector2i(29, 21), [Vector2i(10, 16), Vector2i(16, 15), Vector2i(17, 8), Vector2i(6, 4), Vector2i(30, 22)])
	_rumor(grid, objs, "river")
	return {"name": "Река Лета", "floor": grid, "objs": objs, "waste": true, "poi": "river",
		"spawns": {"enter": Vector2i(29, 21)}, "light": 30.0}


func _poi_tower() -> Dictionary:
	var w := 28
	var h := 22
	var grid := _sand(w, h, 601, 4)
	_fill(grid, Rect2i(4, 2, 7, 7), ",")
	var objs: Array = []
	objs.append(_big("tower", 6, 4, 3, 3, "Ретрансляционная вышка Института", "poi_tower"))
	objs.append(_prop("sign", 11, 9, "Табличка «Институт · ретранслятор №4»"))
	objs.append(_prop("crate", 4, 2, "Ящик с изоляторами"))
	objs.append(_prop("cable", 10, 2, "Оборванные провода"))
	objs.append(_prop("wreck", 19, 4, "Фургон связистов"))
	objs.append(_mob("padal", _daily("tower_padal"), 15, 9, 5))
	objs.append(_exit(25, 19))
	_scatter(grid, objs, 602, 28, [Rect2i(3, 1, 10, 10), Rect2i(22, 16, 6, 6)])
	_ensure_paths(grid, objs, Vector2i(24, 18), [Vector2i(9, 7), Vector2i(25, 19)])
	_rumor(grid, objs, "tower")
	return {"name": "Ретрансляционная вышка", "floor": grid, "objs": objs, "waste": true, "poi": "tower",
		"spawns": {"enter": Vector2i(24, 18)}, "light": 30.0}


func _poi_den() -> Dictionary:
	var w := 26
	var h := 20
	var grid := _sand(w, h, 701, 6)
	# склоны оврага – дальние стены, сверху и слева
	for x in w:
		grid[0][x] = "R"
	for y in h:
		grid[y][0] = "R"
	var objs: Array = []
	objs.append(_big("bigburrow", 11, 1, 2, 2, "Главная нора логова", "poi_den"))
	for pos in [Vector2i(3, 1), Vector2i(7, 1), Vector2i(17, 1), Vector2i(21, 1), Vector2i(1, 6), Vector2i(1, 11)]:
		objs.append(_prop("burrow", pos.x, pos.y, "Нора"))
	objs.append(_mob("pes", _daily("den_pes_a"), 8, 5, 4))
	objs.append(_mob("pes", _daily("den_pes_b"), 16, 6, 4))
	# Собачий Муэдзин сидит в глубине логова; убитый, он возвращается через три дня.
	var dead := int(G.p.flags.get("muezzin_dead_day", -99))
	if int(G.p.get("day", 1)) >= dead + 3:
		objs.append(_mob("muezzin", "den_muezzin_%d" % dead, 19, 3, 3))
	for pos in [Vector2i(10, 6), Vector2i(14, 4), Vector2i(5, 9), Vector2i(19, 8)]:
		objs.append(_prop("bones", pos.x, pos.y, "Обглоданные кости", "", false))
	if G.p.quests.get("spice", "") == "active" and not G.has("Собачья мята"):
		objs.append(_prop("herb_mint", 6, 3, "Собачья мята", "herb_2", false))
	objs.append(_exit(23, 17))
	_scatter(grid, objs, 702, 22, [Rect2i(9, 1, 6, 5), Rect2i(20, 14, 6, 6)])
	_ensure_paths(grid, objs, Vector2i(22, 16), [Vector2i(12, 3), Vector2i(23, 17)])
	_rumor(grid, objs, "den")
	return {"name": "Логово диких псов", "floor": grid, "objs": objs, "waste": true, "poi": "den",
		"spawns": {"enter": Vector2i(22, 16)}, "light": 30.0}


## Разрушенный посёлок: сюда ведёт задание на спасение, бедолага ждёт в уцелевшем доме.
func _poi_ruins() -> Dictionary:
	var w := 28
	var h := 20
	var grid := _sand(w, h, 801, 4)
	var houses := [Rect2i(2, 1, 6, 5), Rect2i(10, 1, 5, 4), Rect2i(2, 8, 5, 5)]
	for rr in houses:
		_fill(grid, rr, ",")
		for x in range(rr.position.x, rr.end.x):
			grid[rr.position.y][x] = "R"
			grid[rr.end.y - 1][x] = "R"
		for y in range(rr.position.y, rr.end.y):
			grid[y][rr.position.x] = "R"
			grid[y][rr.end.x - 1] = "R"
	# проёмы к югу и востоку
	grid[5][4] = ","
	grid[5][5] = ","
	grid[4][12] = ","
	grid[10][6] = ","
	var objs: Array = []
	objs.append(_prop("bed", 3, 2, "Сырой матрас"))
	objs.append(_prop("shelf", 5, 2, "Пустая полка"))
	objs.append(_prop("cache", 11, 2, "Разбитый шкафчик", "ruins_cache"))
	objs.append(_prop("wreck", 19, 3, "Сгоревший грузовик"))
	objs.append(_prop("pylon", 23, 2, "Покосившийся столб"))
	objs.append(_prop("bones", 9, 11, "Кости", "", false))
	var j = G.escort_job()
	if j != null and j.state == "active":
		objs.append(_npc("stray", 4, 3, "Бедолага", "stray_start", 1))
	objs.append(_mob("padal", _daily("ruins_padal"), 16, 8, 4))
	objs.append(_mob("pes", _daily("ruins_pes"), 12, 13, 5))
	objs.append(_exit(25, 17))
	_scatter(grid, objs, 802, 24, houses + [Rect2i(21, 14, 7, 6)])
	_ensure_paths(grid, objs, Vector2i(24, 16), [Vector2i(4, 4), Vector2i(11, 3), Vector2i(25, 17)])
	_rumor(grid, objs, "ruins")
	return {"name": "Разрушенный посёлок", "floor": grid, "objs": objs, "waste": true, "poi": "ruins",
		"spawns": {"enter": Vector2i(24, 16)}, "light": 30.0}


# ---------------- Рейд: заброшенные ярусы ----------------

## Номер «волны» рейда: раз в три дня внизу снова кто-то заводится и снова что-то лежит.
func _raid_cycle() -> int:
	return int(G.p.get("day", 1)) / 3


func _raid_mob(enemy: String, tag: String, x: int, y: int, aggro: int) -> Dictionary:
	return _mob(enemy, "raid%d_%s" % [_raid_cycle(), tag], x, y, aggro)


func _raid1() -> Dictionary:
	var objs: Array = []
	objs.append(_prop("stairs_up", 1, 1, "Лестница наверх, к кварталам", "go:caldera4:raid"))
	objs.append(_prop("crate", 5, 1, "Сгнивший ящик"))
	objs.append(_prop("cache", 8, 1, "Шкафчик жильца", "raid_c1"))
	objs.append(_prop("shelf", 10, 1, "Пустые полки"))
	objs.append(_prop("bones", 12, 3, "Кости", "", false))
	objs.append(_prop("cache", 16, 1, "Тумбочка у койки", "raid_c2"))
	objs.append(_prop("bed", 18, 1, "Ржавая койка"))
	objs.append(_prop("bed", 20, 1, "Ржавая койка"))
	objs.append(_prop("cache", 1, 7, "Аптечный шкаф", "raid_c3"))
	objs.append(_prop("table", 3, 7, "Опрокинутый стол"))
	objs.append(_prop("barrel", 8, 7, "Остывшая жаровня"))
	# в подвале всегда ночь: светло только у редких слабых ламп
	objs.append(_prop("lamp", 11, 7, "Мигающая лампа"))
	objs.append(_prop("lamp", 17, 4, "Слабая лампа"))
	objs.append(_prop("lamp", 6, 12, "Слабая лампа"))
	objs.append(_prop("cache", 16, 7, "Сейф без дверцы", "raid_c4"))
	objs.append(_prop("shelf", 18, 7, "Стеллаж с инструментом"))
	objs.append(_prop("stairs_down", 1, 12, "Лестница вниз, на ярус 6", "go:raid2:top"))
	objs.append(_raid_mob("slepysh", "a", 12, 2, 4))
	objs.append(_raid_mob("slepysh", "b", 11, 9, 4))
	objs.append(_raid_mob("slepysh", "c", 19, 9, 4))
	var grid := _grid(RAID1)
	return {"name": "Ярус 5 · Заброшенный", "floor": grid, "objs": objs, "waste": false, "depth": 0, "raid": true, "dark": true,
		"spawns": {"top": Vector2i(2, 3), "bottom": Vector2i(4, 12)}, "light": 2.0}


func _raid2() -> Dictionary:
	var objs: Array = []
	objs.append(_prop("stairs_up", 1, 1, "Лестница наверх, на ярус 5", "go:raid1:bottom"))
	objs.append(_prop("cache", 9, 1, "Ящик с красным крестом", "raid_c5"))
	objs.append(_prop("cache", 17, 1, "Оружейный шкаф", "raid_c6"))
	objs.append(_prop("pipe", 11, 1, "Лопнувшая труба"))
	objs.append(_prop("cache", 1, 7, "Сундук под водой", "raid_c7"))
	objs.append(_prop("cache", 9, 7, "Мастерская оружейника", "raid_c8"))
	objs.append(_prop("bones", 13, 9, "Кости", "", false))
	objs.append(_prop("lamp", 14, 1, "Слабая лампа"))
	objs.append(_prop("lamp", 5, 8, "Слабая лампа"))
	objs.append(_prop("lamp", 17, 9, "Слабая лампа"))
	# на шестом ярусе живут старшие, слепцы: крупнее, злее, слышат сердце
	objs.append(_raid_mob("slepets", "d", 5, 4, 4))
	objs.append(_raid_mob("slepets", "e", 14, 2, 4))
	objs.append(_raid_mob("slepysh", "f", 12, 9, 5))
	objs.append(_raid_mob("slepysh", "g", 4, 9, 4))
	var grid := _grid(RAID2)
	return {"name": "Ярус 6 · Затопленный", "floor": grid, "objs": objs, "waste": false, "depth": 0, "raid": true, "dark": true,
		"spawns": {"top": Vector2i(2, 3)}, "light": 2.0}


## Тайник из слуха Гарри: у тропы, рядом с точкой входа.
func _rumor(grid: Array, objs: Array, poi: String) -> void:
	if G.p.flags.get("rumor_cache", "") != poi:
		return
	var taken := {}
	for o in objs:
		for t in _cells(o):
			taken[t] = true
	var h := grid.size()
	var w: int = grid[0].size()
	for r in range(3, 8):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var pos := Vector2i(w - 6 + dx, h - 6 + dy)
				if pos.x < 1 or pos.y < 1 or pos.x >= w - 1 or pos.y >= h - 1:
					continue
				if taken.has(pos) or not (grid[pos.y][pos.x] in ["s", "a", ",", "k", "m"]):
					continue
				objs.append(_prop("cache", pos.x, pos.y, "Тайник из слуха", "rumor_cache"))
				return


func _poi_forest() -> Dictionary:
	var w := 30
	var h := 22
	var grid := _sand(w, h, 901, 0)
	for y in h:
		for x in w:
			grid[y][x] = "m"
	# прогалины с пеплом
	for c in [Vector2i(8, 12), Vector2i(19, 6)]:
		for y in h:
			for x in w:
				if Vector2(x - c.x, y - c.y).length() < 2.5:
					grid[y][x] = "a"
	var objs: Array = []
	# огромные деревья: по два на дальних краях и в глубине
	for t in [Vector2i(2, 1), Vector2i(9, 1), Vector2i(17, 1), Vector2i(24, 2), Vector2i(1, 8), Vector2i(1, 15), Vector2i(12, 7), Vector2i(20, 11)]:
		objs.append(_big("bigtree", t.x, t.y, 2, 2, "Огромное дерево", "forest_tree"))
	objs.append(_prop("roots", 6, 4, "Свежие коренья", "forest_forage_1"))
	objs.append(_prop("roots", 15, 4, "Светлые листья", "forest_forage_2"))
	objs.append(_prop("roots", 4, 12, "Свежие коренья", "forest_forage_3"))
	objs.append(_prop("roots", 23, 7, "Светлые листья", "forest_forage_4"))
	if G.p.quests.get("spice", "") == "active" and not G.has("Звёздный перец"):
		objs.append(_prop("herb_pepper", 16, 9, "Звёздный перец", "herb_3", false))
	objs.append(_mob("plant", _daily("forest_plant_a"), 15, 8, 1))
	objs.append(_mob("plant", _daily("forest_plant_b"), 7, 6, 1))
	objs.append(_mob("plant", _daily("forest_plant_c"), 22, 9, 1))
	objs.append(_mob("pes", _daily("forest_pes"), 10, 15, 5))
	# Незнакомец сидит на пепельной прогалине и лечит голову от того, что в неё нашептала Запутанность.
	objs.append(_npc("stranger", 8, 11, "Незнакомец в капюшоне", "stranger_start", 1))
	objs.append(_exit(27, 19))
	_scatter(grid, objs, 902, 18, [Rect2i(24, 16, 6, 6)])
	_ensure_paths(grid, objs, Vector2i(26, 18), [Vector2i(6, 5), Vector2i(15, 5), Vector2i(4, 13), Vector2i(23, 8), Vector2i(16, 10), Vector2i(27, 19), Vector2i(9, 12)])
	_rumor(grid, objs, "forest")
	return {"name": "Запутанный лес", "floor": grid, "objs": objs, "waste": true, "poi": "forest",
		"spawns": {"enter": Vector2i(26, 18)}, "light": 30.0}
