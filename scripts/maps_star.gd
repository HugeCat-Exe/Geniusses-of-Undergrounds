extends "res://scripts/maps.gd"
## «Южная Звезда»: лагерь «Перрон» у ворот и одиннадцать этажей вниз («Венок из ветвей барбариса»).
## Важное стоит у дальних стен (верх и левый край), лифт – в углу у дальней стены.

const StoryVB := preload("res://scripts/story_vb.gd")

const KNIGHT_TEX := {"tauros": "knight_t", "ursuz": "knight_u", "ankvila": "knight_a"}
const KNIGHT_TALK := {"tauros": "vb_tauros_talk", "ursuz": "vb_knight_u", "ankvila": "vb_knight_a"}


func build(name: String) -> Dictionary:
	if name == "star_camp":
		return _camp()
	var n := int(name.substr(4))
	return _floor_map(clampi(n, 1, 11))


func _q() -> String:
	return G.p.quests.get("vb", "")


func _snpc(id: String, x: int, y: int, action: String, title: String = "") -> Dictionary:
	var w: Dictionary = preload("res://scripts/story.gd").WHO[id]
	return {"type": "npc", "id": id, "x": x, "y": y, "title": title if title != "" else str(w.name), "action": action,
		"block": true, "reach": 1, "look": NPC_LOOKS[id].person}


func _knight(id: String, x: int, y: int) -> Dictionary:
	var o := _snpc(id, x, y, KNIGHT_TALK[id])
	o.ntex = KNIGHT_TEX[id]
	o.reach = 2
	return o


## Рыцари стоят там, где держат линию: в лагере до первого разговора, потом на неотбитом этаже,
## после генератора ещё и у гермо-двери на пятом. После прощания их нет нигде.
func _knights_here(where: String) -> bool:
	if G.flag("vb_farewell") or _q() != "active":
		return false
	if where == "camp":
		return not G.flag("vb_tauros")
	if not G.flag("vb_tauros"):
		return false
	var n := int(where.substr(4))
	if G.flag("vb_f11") or G.flag("vb_button"):
		# после лаборатории рыцари ждут Гения на десятом, а потом на пятом
		return n == 5 or (n == 10 and not G.flag("vb_gun_back") and not G.flag("vb_button"))
	var f := StoryVB.frontier()
	if n == f:
		return true
	return n == 5 and f > 5


# ---------------- Лагерь «Перрон» ----------------

func _camp() -> Dictionary:
	var w := 30
	var h := 22
	var grid := _sand(w, h, 1201, 4)
	for x in w:
		grid[0][x] = "R"
	for y in h:
		grid[y][0] = "R"
	# бетонный спуск к воротам и платформа лагеря
	_fill(grid, Rect2i(12, 1, 6, 6), "k")
	_fill(grid, Rect2i(2, 7, 26, 8), ",")
	var objs: Array = []
	objs.append(_big("hermo", 14, 1, 2, 2, "Гермо-ворота «Южной Звезды»", "vb_gate"))
	objs.append(_snpc("hinjs", 16, 3, "vb_gate"))
	# внутреннее кольцо баррикад вокруг ворот
	for x in [10, 11, 12, 17, 18, 19]:
		objs.append(_prop("crate" if x % 2 == 0 else "wreck", x, 6, "Баррикада у ворот"))
	for y in [2, 4]:
		objs.append(_prop("crate", 10, y, "Баррикада у ворот"))
		objs.append(_prop("crate", 19, y, "Баррикада у ворот"))
	if _knights_here("camp"):
		objs.append(_knight("tauros", 13, 4))
		objs.append(_knight("ursuz", 11, 3))
		objs.append(_knight("ankvila", 17, 5))
	# медпалатка Сутуры
	objs.append(_prop("tent", 2, 8, "Медицинская палатка"))
	objs.append(_prop("tent", 4, 8, "Медицинская палатка"))
	objs.append(_snpc("sutura", 3, 10, "vb_sutura_start"))
	objs.append(_snpc("goz", 6, 9, "vb_goz"))
	objs.append(_snpc("berberis", 2, 11, "vb_berberis"))
	objs.append(_prop("pot", 7, 8, "Полевая кухня"))
	objs.append(_snpc("ladlow", 8, 9, "vb_ladlow"))
	if not G.flag("vb_f5"):
		objs.append(_prop("counter", 11, 8, "Прилавок маркитанта"))
		objs.append(_snpc("tindal", 11, 9, "vb_tindal"))
		objs.append(_prop("gunrack", 17, 8, "Верстак оружейника"))
		objs.append(_snpc("ferro", 17, 9, "vb_ferro"))
	objs.append(_prop("bed", 20, 8, "Койка"))
	objs.append(_prop("bed", 22, 8, "Койка"))
	objs.append(_snpc("dorma", 21, 10, "vb_dorma"))
	objs.append(_prop("board", 25, 8, "Доска пропавших: «Нашлись», «Ищем», «Внизу»", "vb_scribl"))
	objs.append(_snpc("scribl", 25, 10, "vb_scribl"))
	objs.append(_snpc("latch", 27, 12, "vb_latch"))
	objs.append(_prop("barrel", 8, 13, "Костёр в бочке"))
	objs.append(_snpc("evensong", 9, 12, "vb_evensong"))
	# раненые: после генератора часть расходится по домам
	var hurt := [Vector2i(4, 12), Vector2i(6, 14), Vector2i(12, 12), Vector2i(16, 13), Vector2i(19, 12), Vector2i(23, 13)]
	var left := 6 if not G.flag("vb_f5") else 2
	for i in left:
		objs.append(_snpc("wounded", hurt[i].x, hurt[i].y, "vb_wounded"))
	# внешнее кольцо баррикад, проход у Никки
	for x in range(2, 28):
		if x >= 20 and x <= 22:
			continue
		if x % 3 == 0:
			objs.append(_prop("rocks" if x % 2 == 0 else "crate", x, 16, "Внешняя баррикада"))
	objs.append(_snpc("nikki", 19, 15, "vb_nikki_talk"))
	# Артир со своей колымагой у края лагеря
	objs.append(_big("taxi", 23, 18, 2, 1, "Колымага Артира", "vb_artir_camp"))
	objs.append(_npc("taxi", 22, 19, "Таксист Артир", "vb_artir_camp", 1))
	if G.wander_star():
		objs.append(_npc("wanderer", 21, 4, "Странник Гаспар", "wander_start", 1))
		objs.append(_prop("cart", 22, 3, "Обоз Гаспара"))
	for p in [Vector2i(6, 6), Vector2i(14, 9), Vector2i(23, 11), Vector2i(9, 15), Vector2i(26, 15)]:
		objs.append(_prop("lamp", p.x, p.y, "Фонарь на шесте"))
	_scatter(grid, objs, 1202, 10, [Rect2i(2, 1, 26, 15), Rect2i(18, 16, 10, 6)])
	_ensure_paths(grid, objs, Vector2i(24, 20), [Vector2i(14, 3), Vector2i(3, 10), Vector2i(25, 10), Vector2i(27, 12)])
	return {"name": "Лагерь «Перрон»", "floor": grid, "objs": objs, "waste": true, "no_explore": true,
		"star_floor": 0, "spawns": {"arrive": Vector2i(24, 20), "gate": Vector2i(14, 4), "enter": Vector2i(24, 20)}, "light": 30.0}


# ---------------- Этажи ----------------

func _room(w: int, h: int, ch: String) -> Array:
	var rows: Array = []
	for y in h:
		var r := ""
		for x in w:
			r += "#" if x == 0 or y == 0 or x == w - 1 or y == h - 1 else ch
		rows.append(r)
	return _grid(rows)


func _burrow(objs: Array, burrows: Array, n: int, x: int, y: int) -> void:
	if G.flag("vb_f%d" % n) or _q() == "done":
		objs.append(_prop("plate", x, y, "Заваренная пробоина"))
	else:
		objs.append(_prop("burrow", x, y, "Пробоина в стене"))
		burrows.append(Vector2i(x, y))


func _floor_map(n: int) -> Dictionary:
	var objs: Array = []
	var burrows: Array = []
	var grid: Array
	var lift := Vector2i(1, 1)
	var up := Vector2i(2, 3)
	var kn: Array = []
	var res: Array = []         # где встают жители после возвращения
	var spawns := {}
	var done := _q() == "done"
	var lit5 := G.flag("vb_f5") or done
	var dark := false
	match n:
		1:
			grid = _room(22, 14, "_")
			objs.append(_prop("board", 9, 1, "Вывеска «Добро пожаловать домой!»" if not done else "Вывеска «Добро пожаловать домой!»: букву «ж» дорисовали от руки"))
			objs.append(_prop("palm", 7, 1, "Пальма в кадке"))
			objs.append(_prop("palm", 12, 1, "Пальма в кадке"))
			objs.append(_prop("palm_down" if not lit5 else "palm", 8, 7, "Опрокинутая пальма" if not lit5 else "Пальма в кадке"))
			objs.append(_prop("counter", 11, 5, "Стойка консьержа"))
			_burrow(objs, burrows, 1, 16, 1)
			_burrow(objs, burrows, 1, 19, 1)
			_burrow(objs, burrows, 1, 1, 10)
			kn = [Vector2i(4, 4), Vector2i(6, 2), Vector2i(3, 7)]
			res = [Vector2i(8, 10), Vector2i(15, 8), Vector2i(18, 5)]
			dark = not lit5
		2:
			grid = _room(24, 16, "p")
			lift = Vector2i(1, 13)
			up = Vector2i(2, 12)
			for x in [7, 13, 19]:
				objs.append(_prop("tent", x, 1, "Лавка под полосатым навесом"))
			objs.append(_prop("cart", 10, 7, "Карусель с облезлыми лошадками"))
			objs.append(_prop("cart", 12, 8, "Карусель с облезлыми лошадками"))
			for p in [Vector2i(6, 6), Vector2i(16, 6), Vector2i(18, 10)]:
				objs.append(_prop("crate", p.x, p.y, "Лоток со сгнившими фруктами"))
			_burrow(objs, burrows, 2, 22, 1)
			_burrow(objs, burrows, 2, 1, 5)
			if not G.flag("vb_f2"):
				var spots := {"pimm": Vector2i(5, 1), "vella": Vector2i(11, 1), "kort": Vector2i(17, 1)}
				for id in spots:
					if not G.flag("vb_s_" + id):
						var o := _snpc(id, spots[id].x, spots[id].y, "vb_" + id)
						objs.append(o)
						objs.append(_prop("gate", spots[id].x + 1, spots[id].y, "Поднятая решётка лавки"))
			elif lit5:
				objs.append(_snpc("pimm", 5, 2, "vb_pimm_home"))
				objs.append(_snpc("vella", 11, 2, "vb_vella_home"))
				objs.append(_snpc("kort", 14, 10, "vb_kort_home"))
			kn = [Vector2i(4, 11), Vector2i(3, 9), Vector2i(6, 12)]
			res = [Vector2i(9, 4), Vector2i(20, 8)]
			dark = not lit5
		3:
			grid = _room(26, 10, ",")
			lift = Vector2i(1, 8)
			up = Vector2i(2, 7)
			var signs := ["Дверь с табличкой «Семья Морроу»", "Выбитая дверь", "Дверь с табличкой «Не стучать, спит ребёнок»", "Выбитая дверь",
				"Дверь с табличкой «Ушли за водой, скоро вернёмся»", "Выбитая дверь", "Выбитая дверь"]
			for i in signs.size():
				var x := 3 + i * 3
				objs.append(_prop("door", x, 1, signs[i]))
				if not G.flag("vb_f3") and not done:
					burrows.append(Vector2i(x, 1))
			if lit5:
				# лавки из лагеря переехали сюда: на третьем этаже открылась ярмарка
				objs.append(_prop("counter", 9, 4, "Прилавок Тиндала"))
				objs.append(_snpc("tindal", 9, 5, "vb_tindal"))
				objs.append(_prop("gunrack", 15, 4, "Верстак Ферро"))
				objs.append(_snpc("ferro", 15, 5, "vb_ferro"))
			kn = [Vector2i(4, 6), Vector2i(6, 4), Vector2i(3, 4)]
			res = [Vector2i(20, 3), Vector2i(12, 7)]
			dark = not lit5
		4:
			grid = _room(24, 12, ",")
			lift = Vector2i(1, 5)
			up = Vector2i(2, 6)
			for x in [4, 8, 12, 16]:
				objs.append(_prop("door", x, 1, "Выбитая дверь"))
			if G.flag("vb_f4") or done:
				for c in [Vector2i(20, 4), Vector2i(21, 4), Vector2i(20, 5), Vector2i(21, 5)]:
					objs.append(_prop("plate", c.x, c.y, "Стальная заплата на главной норе"))
			else:
				objs.append(_big("bigburrow", 20, 4, 2, 2, "Огромная нора в бетоне"))
				burrows.append(Vector2i(19, 5))
			kn = [Vector2i(17, 3), Vector2i(17, 7), Vector2i(15, 5)]
			res = [Vector2i(10, 4), Vector2i(6, 8)]
			dark = not lit5
		5:
			grid = _room(24, 16, ".")
			for y in [6, 11]:
				for x in range(3, 22):
					grid[y][x] = "g"
			lift = Vector2i(1, 14)
			up = Vector2i(2, 13)
			objs.append(_big("turbine", 3, 1, 3, 2, "Турбина, похожая на спящего кита"))
			objs.append(_big("turbine", 8, 1, 3, 2, "Турбина, похожая на спящего кита"))
			objs.append(_prop("terminal", 13, 1, "Пульт управления" if lit5 else "Мёртвый пульт"))
			objs.append(_prop("terminal", 14, 1, "Пульт управления" if lit5 else "Мёртвый пульт"))
			objs.append(_big("hermo", 19, 1, 2, 2, "Гермо-дверь на нижние этажи", "vb_hermo"))
			objs.append(_big("generator", 11, 7, 2, 2, "Главный генератор", "vb_generator"))
			for y in [5, 10]:
				objs.append(_prop("door", 1, y, "Дверь в машинный коридор"))
				if not lit5:
					burrows.append(Vector2i(1, y))
			if lit5:
				kn = [Vector2i(18, 4), Vector2i(21, 4), Vector2i(16, 3)]
			else:
				kn = [Vector2i(3, 5), Vector2i(3, 10), Vector2i(9, 12)]
			res = [Vector2i(15, 12), Vector2i(7, 9)]
			dark = not lit5
		6, 7:
			grid = _room(24, 14, ",")
			lift = Vector2i(1, 12)
			up = Vector2i(2, 11)
			for i in 6:
				objs.append(_prop("door", 3 + i * 3, 1, "Дверь, заросшая грязью" if n == 7 else "Выбитая дверь"))
			for p in [Vector2i(8, 5), Vector2i(15, 7), Vector2i(11, 10), Vector2i(19, 4)]:
				objs.append(_prop("rocks" if (p.x + n) % 2 == 0 else "crate", p.x, p.y, "Мебель, сваленная в кучу"))
			_burrow(objs, burrows, n, 22, 1)
			_burrow(objs, burrows, n, 1, 4)
			_burrow(objs, burrows, n, 1, 8)
			if n == 7:
				_burrow(objs, burrows, n, 21, 5)
			kn = [Vector2i(4, 10), Vector2i(3, 8), Vector2i(6, 11)]
			dark = not done
		8:
			grid = _room(24, 16, ".")
			lift = Vector2i(1, 14)
			up = Vector2i(2, 13)
			for p in [Vector2i(4, 1), Vector2i(7, 1), Vector2i(16, 1), Vector2i(1, 4), Vector2i(1, 8)]:
				objs.append(_prop("counter", p.x, p.y, "Станок"))
			for p in [Vector2i(9, 5), Vector2i(15, 5), Vector2i(10, 10)]:
				objs.append(_prop("chain", p.x, p.y, "Цепи под потолком", "", false))
			objs.append(_prop("pylon", 12, 3, "Опора крана с балкой"))
			if not G.flag("vb_f8") and not done:
				objs.append({"type": "mob", "enemy": "muezzin_cave", "id": "vb8_boss", "x": 12, "y": 6, "title": D.ENEMIES.muezzin_cave.name,
					"aggro": 2, "block": false, "vb": true})
			kn = [Vector2i(4, 12), Vector2i(3, 10), Vector2i(6, 13)]
			dark = not done
		9:
			grid = _room(22, 14, ".")
			lift = Vector2i(1, 12)
			up = Vector2i(2, 11)
			for x in [4, 6, 12, 14]:
				objs.append(_prop("pipe", x, 1, "Трубы и вентили"))
			objs.append(_prop("shelf", 9, 1, "Шкаф с инструментами"))
			objs.append(_prop("shelf", 17, 1, "Шкаф с инструментами"))
			objs.append(_prop("vent", 1, 5, "Вентиляция"))
			objs.append(_prop("barrel", 10, 7, "Бочка, в которую капает вода"))
			kn = [Vector2i(4, 10), Vector2i(3, 8), Vector2i(6, 11)]
			dark = not done
		10:
			grid = _room(24, 16, "_")
			up = Vector2i(2, 2)
			for x in [5, 6, 7, 15, 16, 17]:
				objs.append(_prop("glass", x, 6, "Стеклянная перегородка"))
			for p in [Vector2i(4, 1), Vector2i(19, 1), Vector2i(1, 6)]:
				objs.append(_prop("sign", p.x, p.y, "Знак Института по Этике"))
			objs.append(_prop("door", 12, 1, "Дверь с зелёной обводкой" if not done else "Дверь с зелёной обводкой, заваренная рыцарями", "vb_green_door" if not done else ""))
			objs.append(_prop("terminal", 1, 13, "Терминал Института", "vb_terminal"))
			objs.append(_prop("rocks", 1, 12, "Обломки потолка"))
			objs.append(_prop("rocks", 2, 14, "Обломки потолка"))
			if G.flag("vb_button"):
				for p in [Vector2i(9, 4), Vector2i(14, 9), Vector2i(19, 12), Vector2i(7, 11), Vector2i(17, 3)]:
					objs.append(_prop("deaddog", p.x, p.y, "Мёртвая пещерная собака", "", false))
			spawns["door"] = Vector2i(12, 2)
			kn = [Vector2i(4, 12), Vector2i(3, 10), Vector2i(5, 14)]
		11:
			return _lab_room()
	# после кнопки на всех этажах ниже пятого лежат мёртвые мутанты
	if G.flag("vb_button") and n >= 6 and n <= 9 and not done:
		for i in 3:
			var p := Vector2i(6 + i * 5, 4 + (i * 3) % 7)
			if grid[p.y][p.x] != "#":
				objs.append(_prop("deaddog", p.x, p.y, "Мёртвая пещерная собака", "", false))
	objs.append(_prop("lift", lift.x, lift.y, "Служебный лифт", "vb_lift"))
	if _knights_here("star%d" % n):
		var ids := ["tauros", "ursuz", "ankvila"]
		for i in 3:
			objs.append(_knight(ids[i], kn[i].x, kn[i].y))
	# жители возвращаются на 1–5 после генератора, на 6–10 после задания работают ремонтники
	if (n <= 5 and lit5) or (n >= 6 and n <= 10 and done):
		var who := "resident" if n <= 5 else "worker"
		var spots: Array = res if not res.is_empty() else [Vector2i(10, 5), Vector2i(16, 9)]
		for p in spots:
			objs.append(_snpc(who, p.x, p.y, "vb_" + who))
	# лампы: аварийные до генератора, обычные после
	var lamps := [Vector2i(6, 3), Vector2i(grid[0].size() - 5, 3), Vector2i(4, grid.size() - 4), Vector2i(grid[0].size() / 2, grid.size() / 2 + 2)]
	for p in lamps:
		if grid[p.y][p.x] != "#":
			var free := true
			for o in objs:
				if o.x == p.x and o.y == p.y:
					free = false
			if free:
				objs.append(_prop("lamp", p.x, p.y, "Аварийная лампа" if dark else "Лампа"))
	spawns["up"] = up
	_ensure_paths(grid, objs, up, [Vector2i(lift.x + 1, lift.y)])
	var title: String = "Южная Звезда · Этаж %d" % n
	return {"name": title, "floor": grid, "objs": objs, "waste": false, "depth": 1, "dark": dark, "star_floor": n,
		"burrows": burrows, "spawns": spawns, "light": 4.0 if dark else 10.0}


## Одиннадцатый этаж: комната, которой не должно быть под землёй.
func _lab_room() -> Dictionary:
	var shot := G.flag("vb_shot")
	var grid := _room(14, 12, "a" if shot else "m")
	var objs: Array = []
	objs.append(_big("bigtree", 1, 1, 2, 2, "Увядшее дерево" if shot else "Дерево, проросшее сквозь потолок"))
	objs.append(_big("bigtree", 10, 1, 2, 2, "Увядшее дерево" if shot else "Дерево, проросшее сквозь потолок"))
	for p in [Vector2i(5, 1), Vector2i(1, 5), Vector2i(8, 2)]:
		objs.append(_prop("herb_pepper" if not shot else "roots", p.x, p.y, "Куст с алыми ягодами" if not shot else "Осыпавшиеся ягоды", "", false))
	for p in [Vector2i(4, 4), Vector2i(9, 7), Vector2i(3, 8)]:
		objs.append(_prop("roots", p.x, p.y, "Корни, бегущие по полу", "", false))
	objs.append(_prop("lamp", 6, 1, "Лампа, утонувшая в листве"))
	objs.append(_prop("lamp", 11, 6, "Лампа, утонувшая в листве"))
	objs.append(_prop("rocks", 1, 10, "Щель в завале", "vb_crack"))
	if shot:
		objs.append(_prop("barbaris_dead", 6, 5, "Барбарис", "", false))
	elif not G.flag("vb_f11"):
		var b := _snpc("barbaris", 6, 5, "vb_f11_enter", "Существо с длинной шеей")
		b.ntex = "barbaris"
		objs.append(b)
	return {"name": "Южная Звезда · Этаж ??", "floor": grid, "objs": objs, "waste": false, "depth": 1, "dark": false,
		"star_floor": 11, "burrows": [], "spawns": {"in": Vector2i(2, 9)}, "light": 10.0}
