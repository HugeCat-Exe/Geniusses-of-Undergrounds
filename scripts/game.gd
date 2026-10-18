extends Node
## Состояние Гения, правила проверок и сохранения.

signal logged(text: String)
signal changed

const VERSION := "0.6"
const SLOTS := 3
## Ячейка автосохранения: идёт после ручных.
const AUTO := 3

var p: Dictionary = {}
## Узлы диалогов, собранные на лету (исходы прогулок и т. п.).
var temp_nodes: Dictionary = {}
var log_lines: Array = []
var world_dirty := false


func new_character() -> Dictionary:
	return {
		"callsign": "", "name": "", "sex": "М", "race": "Человек", "faction": 0,
		"age": "Взрослый", "birth": "Тристаль", "phys": [], "psy": [], "main": [],
		"got_phys": [], "got_psy": [], "motive": "",
		"hp": 1, "mind": 1, "food": 80, "su": 300, "will": 0,
		"inv": {}, "weapon": "", "melee": "Нож", "armor": "Футболка", "mag": 0,
		"wounds": [], "mags": {}, "flags": {}, "quests": {}, "killed": [],
		"map": "caldera", "pos": [0, 0], "steps": 0, "day": 1, "hour": 8,
		"map_at": "caldera", "known": ["caldera"], "pity": {}, "seed": randi(),
		"rel": {}, "jobs": [], "companion": "",
		"gear": {"head": "", "legs": "", "feet": "", "amulet": ""},
	}


func start_game(c: Dictionary) -> void:
	p = c
	var pistol: String = D.START_PISTOL[p.faction]
	p.weapon = pistol
	p.mag = D.ITEMS[pistol].mag
	p.inv = {}
	quiet = true
	add_item(pistol)
	p.melee = D.START_MELEE[p.faction]
	add_item(p.melee)
	add_item("Футболка")
	add_item(D.ITEMS[pistol].ammo)
	add_item("Бинт", 2)
	add_item("Сухпаёк")
	quiet = false
	p.hp = max_hp()
	p.mind = max_mind()
	p.will = max_will()
	log_lines.clear()
	say("Пейджер Института активирован. Добро пожаловать в Кальдеру, Гений %s." % p.callsign)


# ---------- Характеристики ----------

## Сумма модификаторов. acquired = false: только анкета (пол, фракция, возраст, раса, место рождения, черты).
func mods_total(c: Dictionary = p, acquired: bool = true) -> Array:
	var t := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var rows: Array = [D.SEXES[c.sex], D.FACTIONS[c.faction].mods, D.AGES[c.age].mods,
		D.RACES[c.race].mods, D.BIRTH[c.birth]]
	for tr in c.phys:
		rows.append(D.PHYS[tr])
	for tr in c.psy:
		rows.append(D.PSY[tr])
	if acquired:
		for tr in c.got_phys:
			rows.append(D.PHYS[tr])
		for tr in c.got_psy:
			rows.append(D.PSY[tr])
	for r in rows:
		for i in 8:
			t[i] += r[i]
	return t


## Модификаторы того, что Гений приобрёл в пути: травмы и новые черты от безумия.
func mods_acquired(c: Dictionary = p) -> Array:
	var t := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	for tr in c.got_phys:
		for i in 8:
			t[i] += D.PHYS[tr][i]
	for tr in c.got_psy:
		for i in 8:
			t[i] += D.PSY[tr][i]
	return t


## Сжатие минусов: отрицательная сумма весит 60%, пока таблицы черт не перебалансированы вручную.
func soft(x: float) -> float:
	return x if x >= 0.0 else x * 0.6


## Стат по системе Б+В: при создании от 4 до 26, травмы в пути опускают ниже 4.
func stat(k: String, c: Dictionary = p) -> int:
	var i := D.KEYS.find(k)
	var base := clampi(roundi(10.0 + soft(mods_total(c, false)[i])), 4, 26)
	return clampi(base + roundi(soft(mods_acquired(c)[i])), 0, 30)


func mod(k: String, c: Dictionary = p) -> int:
	return D.check_mod(stat(k, c))


## ООЗ = 80 + 5 × (ТЕЛ − 10) + 3 × ΣООЗ, не меньше 40.
func max_hp(c: Dictionary = p) -> int:
	var mx := maxi(40, 80 + 5 * (stat("ТЕЛ", c) - 10) + roundi(3.0 * mods_total(c)[0]))
	# Голод не убивает: пока Гений не поест, предел ООЗ на треть ниже.
	if starving(c):
		mx = int(mx * 0.66)
	return mx


func starving(c: Dictionary = p) -> bool:
	return int(c.get("food", 100)) <= 0


## ООР = 80 + 5 × (ИНТ − 10) + 3 × ΣООР, не меньше 40.
func max_mind(c: Dictionary = p) -> int:
	var mx := maxi(40, 80 + 5 * (stat("ИНТ", c) - 10) + roundi(3.0 * mods_total(c)[1]))
	if amulet(c) == "Камень души":
		mx += 10
	return mx


func max_will(c: Dictionary = p) -> int:
	return maxi(0, floori((stat("ТЕЛ", c) + stat("ВСП", c)) / 5.0))


## Внимание (инициатива) = ВСП + мод ЛВК.
func speed(c: Dictionary = p) -> int:
	return maxi(1, stat("ВСП", c) + mod("ЛВК", c))


## Уклонение (сложность попасть по Гению) = 8 + мод ЛВК + броня.
func evasion(c: Dictionary = p) -> int:
	return 8 + mod("ЛВК", c) + armor_total(c)


## Защита всей одежды: торс, шлем, штаны, обувь.
func armor_total(c: Dictionary = p) -> int:
	var a := 0
	if c.get("armor", "") != "":
		a += int(D.ITEMS[c.armor].def)
	var gear: Dictionary = c.get("gear", {})
	for slot in ["head", "legs", "feet"]:
		var it: String = gear.get(slot, "")
		if it != "":
			a += int(D.ITEMS[it].get("def", 0))
	return a


func amulet(c: Dictionary = p) -> String:
	return c.get("gear", {}).get("amulet", "")


## Надето или в руках.
func equipped(it: String) -> bool:
	if it == p.weapon or it == p.melee or it == p.armor:
		return true
	return it in p.get("gear", {}).values()


## Бонус основного навыка = мод УДЧ + 1, но не меньше +1.
func main_bonus(c: Dictionary = p) -> int:
	return maxi(1, mod("УДЧ", c) + 1)


## Сколько основных навыков: два, третий даёт «Эрудит» (ИНТ 16+).
func main_count(c: Dictionary = p) -> int:
	return 3 if has_perk("Эрудит", c) else 2


func skill_bonus(skill: String, c: Dictionary = p) -> int:
	var b := mod(D.skill_stat(skill), c)
	if skill in c.main:
		b += main_bonus(c)
	# «Агорафобия»: в укрытии Подземки чувства обострены.
	if skill in ["Анализ", "Шестое чувство"] and is_same(c, p) and trait_has("Агорафобия") and str(p.get("map", "")).begins_with("caldera"):
		b += 2
	# «Одержимость запутанностью»: +2 к Сефирам.
	if skill == "Сефиры" and is_same(c, p) and trait_has("Одержимость запутанностью"):
		b += 2
	if skill == "Сефиры" and amulet(c) == "Камень души":
		b += 2
	return b


func phys_def() -> int:
	return armor_total() + maxi(0, mod("ТЕЛ"))


func psy_def() -> int:
	return maxi(0, mod("ИНТ"))


## Пороговые свойства (16+) и изъяны (4 и ниже).
func perks(c: Dictionary = p) -> Array:
	var res: Array = []
	for k in D.ATTRS:
		var v := stat(k, c)
		if v >= 16:
			res.append(D.PERKS[k][0])
		elif v <= 4:
			res.append(D.PERKS[k][1])
	return res


func has_perk(name: String, c: Dictionary = p) -> bool:
	return name in perks(c)


## Цены у торговцев: −3% за каждый +1 мода ХАР, +3% за каждый −1.
func price(base: int) -> int:
	var k := 1.0 - 0.03 * mod("ХАР")
	# «Паранойя»: торговцы чувствуют недоверие. «Страшный человек»: скидка из страха.
	if trait_has("Паранойя"):
		k += 0.05
	if trait_has("Страшный человек"):
		k -= 0.10
	return maxi(1, roundi(base * k))


func trait_has(tr: String) -> bool:
	return tr in p.phys or tr in p.got_phys or tr in p.psy or tr in p.got_psy


## «Агорафобия»: на открытой Пустоши рассудок тает.
func phobia_open(n: int) -> void:
	if trait_has("Агорафобия"):
		p.mind = maxi(1, p.mind - n)
		say("[Агорафобия] Слишком много неба над головой: −%d ООР." % n)
		changed.emit()


func sell_price(base: int) -> int:
	return maxi(1, roundi(base * (1.0 + 0.03 * mod("ХАР"))))


## Бесплатные перебросы удачи: 1 + мод УДЧ / 2 в день, если мод не отрицательный.
func luck_max() -> int:
	var m := mod("УДЧ")
	return 0 if m < 0 else 1 + floori(m / 2.0)


func luck_left() -> int:
	if int(p.flags.get("luck_day", 0)) != int(p.day):
		return luck_max()
	return maxi(0, luck_max() - int(p.flags.get("luck_used", 0)))


func use_luck() -> void:
	if int(p.flags.get("luck_day", 0)) != int(p.day):
		p.flags["luck_day"] = int(p.day)
		p.flags["luck_used"] = 0
	p.flags["luck_used"] = int(p.flags.get("luck_used", 0)) + 1
	changed.emit()


## Невидимая подкрутка: после каждого провала следующий к20 берётся лучшим из нескольких бросков.
func d20(cat: String) -> int:
	var lvl: int = int(p.get("pity", {}).get(cat, 0))
	var d := randi_range(1, 20)
	for i in lvl:
		d = maxi(d, randi_range(1, 20))
	return d


func pity_result(cat: String, ok: bool) -> void:
	if not p.has("pity"):
		p["pity"] = {}
	if ok:
		p.pity[cat] = 0
	else:
		p.pity[cat] = mini(3, int(p.pity.get(cat, 0)) + 1)


## Бросок к20 + бонус навыка против сложности.
func roll(skill: String, dc: int, cat: String = "check") -> Dictionary:
	var d := d20(cat)
	var b := skill_bonus(skill)
	var ok := d + b >= dc
	if d >= crit_from():
		ok = true
	if d == 1:
		ok = false
	var cursed := false
	# «Проклятый»: раз в день Пустошь превращает успех в провал.
	if ok and cat != "" and has_perk("Проклятый") and int(p.flags.get("curse_day", 0)) != int(p.day):
		p.flags["curse_day"] = int(p.day)
		ok = false
		cursed = true
	if cat != "":
		pity_result(cat, ok)
	return {"d": d, "bonus": b, "total": d + b, "dc": dc, "ok": ok, "skill": skill, "cursed": cursed}


## С какого значения к20 считается критом: «Везунчик» — с 19.
func crit_from() -> int:
	return 19 if has_perk("Везунчик") else 20


func chance(bonus: int, dc: int) -> int:
	var need := dc - bonus
	return clampi(roundi((21 - need) / 20.0 * 100.0), 5, 95)


func roll_text(r: Dictionary) -> String:
	var res := "УСПЕХ" if r.ok else "ПРОВАЛ"
	if r.get("cursed", false):
		res = "ПРОВАЛ · сработало «Проклятый»"
	return "[%s: к20=%d %+d = %d против %d — %s]" % [r.skill, r.d, r.bonus, r.total, r.dc, res]


## Как фракция NPC относится к Гению (матрица «К Вам будут относиться»).
func relation(npc_faction: int) -> int:
	return D.FACTIONS[p.faction].rel[npc_faction]


# ---------- Здоровье, рассудок, голод ----------

## Возвращает строку о последствиях, если что-то обнулилось.
func hurt(amount: int, kind: String = "body") -> int:
	if kind == "mind":
		var m := maxi(1, amount - psy_def())
		p.mind -= m
		changed.emit()
		return m
	var h := maxi(1, amount - phys_def())
	p.hp -= h
	changed.emit()
	return h


func heal(amount: int) -> void:
	p.hp = mini(max_hp(), p.hp + amount)
	changed.emit()


func calm(amount: int) -> void:
	p.mind = mini(max_mind(), p.mind + amount)
	changed.emit()


func feed(amount: int) -> void:
	p.food = mini(100, p.food + amount)
	changed.emit()


## Безумие: новая психологическая черта, рассудок частично восстанавливается.
func go_mad() -> String:
	var pool: Array = []
	for k in D.PSY.keys():
		if not (k in p.psy or k in p.got_psy):
			pool.append(k)
	var tr: String = pool.pick_random()
	p.got_psy.append(tr)
	p.mind = maxi(1, max_mind() / 2)
	changed.emit()
	return tr


## Три проверки Антисмерти. Возвращает {alive, successes, injury}.
func death_saves() -> Dictionary:
	var ok := 0
	var rolls: Array = []
	for i in 3:
		var r := roll("Антисмерть", 10, "")
		rolls.append(r)
		if r.ok:
			ok += 1
	var res := {"alive": ok >= 2, "ok": ok, "rolls": rolls, "injury": "", "fragile": false}
	# «Хрупкий»: травма на ступень тяжелее — даже чистый успех оставляет след, а с двумя успехами ещё и рана.
	var fragile := has_perk("Хрупкий")
	if fragile and ok == 2:
		var free_parts: Array = ["Голова", "Руки", "Ноги"].filter(func(w): return not (w in p.wounds))
		if free_parts.size() > 0:
			p.wounds.append(free_parts.pick_random())
			res.fragile = true
	if ok == 2 or (fragile and ok == 3):
		res.fragile = res.fragile or ok == 3
		var pool: Array = []
		for k in D.INJURIES:
			if not (k in p.phys or k in p.got_phys):
				pool.append(k)
		if pool.size() > 0:
			res.injury = pool.pick_random()
			p.got_phys.append(res.injury)
	if res.alive:
		p.hp = 1
	changed.emit()
	return res


## Шаг по карте: голод и усталость.
func step(in_wasteland: bool) -> void:
	p.steps += 1
	var every := 8 if in_wasteland else 25
	if p.steps % every == 0:
		var was := starving()
		p.food = maxi(0, p.food - 1)
		if starving():
			p.hp = mini(p.hp, max_hp())
			if not was or p.steps % (every * 6) == 0:
				say("Голод: ноги ватные, Гений идёт медленнее, предел ООЗ на треть ниже. Нужно поесть.")
		changed.emit()


# ---------- Время ----------

func pass_hours(h: int) -> void:
	p.hour = int(p.hour) + h
	while p.hour >= 24:
		p.hour -= 24
		p.day += 1
		new_day()
	changed.emit()


## Сон до утра: следующий день, 8:00.
func sleep_till_morning() -> void:
	p.day += 1
	p.hour = 8
	new_day()
	changed.emit()
	autosave()


## Новый день: звери и падальщики возвращаются в Пустошь.
func new_day() -> void:
	var keep: Array = []
	for id in p.killed:
		if not (str(id).begins_with("pes_") or str(id).begins_with("padal_")):
			keep.append(id)
	p.killed = keep


# ---------- Отношения ----------

## Нанять или отпустить спутника. Карта пересобирается: нанятый пропадает со своего места
## и идёт следом, отпущенный возвращается туда, где обычно стоит.
func set_companion(id: String) -> void:
	var old: String = p.get("companion", "")
	p.companion = id
	if id == "" and old != "":
		say("%s возвращается на своё место: %s." % [WHO_NAME(old), D.COMPANION_HOME.get(old, "в Кальдеру")])
	changed.emit()
	world_dirty = true
	if not main().has_overlay():
		refresh_world()


## Пересобрать текущую карту на том же месте (после найма или прощания со спутником).
func refresh_world() -> void:
	if not world_dirty:
		return
	world_dirty = false
	var m: Node = main()
	if m.world:
		var mp: String = p.map
		m.show_world.call_deferred(mp, "")


func WHO_NAME(who: String) -> String:
	return preload("res://scripts/story.gd").WHO.get(who, {}).get("name", who)


func rel_points(who: String) -> int:
	if p.rel.has(who):
		return int(p.rel[who])
	var st: Dictionary = preload("res://scripts/story.gd").WHO.get(who, {})
	var pts := 0
	if st.has("faction"):
		pts = relation(st.faction) * 4
	# ХАР: стартовое отношение + мод × 3 очка (в настолке ×10 по шкале фракций).
	pts += mod("ХАР") * 3
	if has_perk("Отталкивающий"):
		pts -= 8
	return pts


func rel_add(who: String, n: int) -> void:
	var before := rel_tier(who)
	# Обаятельный Гений (мод ХАР +3 и выше) получает от спутников +1 сверху к каждому повышению.
	if n > 0 and who == "ryzhaya" and mod("ХАР") >= 3:
		n += 1
	p.rel[who] = rel_points(who) + n
	var after := rel_tier(who)
	if after.name != before.name:
		var nm: String = preload("res://scripts/story.gd").WHO.get(who, {}).get("name", who)
		say("Отношения: %s — теперь «%s»." % [nm, after.name])
	changed.emit()


## {name, idx (−2..3), pts, next — очки до следующей ступени или −1}
func rel_tier(who: String) -> Dictionary:
	var pts := rel_points(who)
	var res: Dictionary = {}
	var nxt := -1
	for i in D.REL_TIERS.size():
		var t: Array = D.REL_TIERS[i]
		if pts >= t[0]:
			res = {"name": t[1], "idx": t[2], "pts": pts}
			nxt = D.REL_TIERS[i + 1][0] if i + 1 < D.REL_TIERS.size() else -1
	res["next"] = nxt
	return res


# ---------- Подработки ----------

func _make_job(tpl: Dictionary, rng: RandomNumberGenerator, id: String) -> Dictionary:
	var j: Dictionary = tpl.duplicate(true)
	j["id"] = id
	j["state"] = "active"
	if j.kind == "kill":
		var need: int = rng.randi_range(tpl.need[0], tpl.need[1])
		j["need"] = need
		j["have"] = 0
		j["text"] = tpl.text % need
		j["su"] = int(tpl.su * need / float(tpl.need[0]))
	return j


## Объявления на доске на сегодня (одни и те же весь день).
func board_offers() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(p.seed) + "board" + str(p.day))
	var pool: Array = range(D.JOBS.size())
	var res: Array = []
	for i in 3:
		var k: int = pool.pop_at(rng.randi() % pool.size())
		var id := "d%d_%d" % [p.day, k]
		var taken := false
		for j in p.jobs:
			if j.id == id or (j.giver == D.JOBS[k].giver and j.title == D.JOBS[k].title):
				taken = true
		if not taken and not flag("job_done_" + id):
			res.append(_make_job(D.JOBS[k], rng, id))
	return res


func take_job(j: Dictionary) -> void:
	p.jobs.append(j)
	if j.kind == "find" and not (j.poi in p.known):
		p.known.append(j.poi)
		say("На карте отмечено: %s." % D.LOCS[j.poi].name)
	if j.kind == "kill" and j.enemy == "muezzin" and not ("den" in p.known):
		p.known.append("den")
		say("На карте отмечено: %s." % D.LOCS.den.name)
	say("Новая подработка: %s." % j.title)
	changed.emit()


func job_by_id(id: String):
	for j in p.jobs:
		if j.id == id:
			return j
	return null


## Убит враг: засчитать во все подходящие подработки.
func on_kill(enemy: String) -> void:
	if enemy == "pes":
		p.flags["dogs"] = int(p.flags.get("dogs", 0)) + 1
		if p.quests.get("dogs", "") == "active" and int(p.flags.dogs) >= 3:
			quest("dogs", "done")
	for j in p.jobs:
		if j.state == "active" and j.kind == "kill" and j.enemy == enemy:
			j.have = int(j.have) + 1
			if j.have >= j.need:
				j.state = "done"
				say("Подработка выполнена: %s. Вернитесь к %s." % [j.title, giver_name(j.giver, true)])
	changed.emit()


func job_found(id: String) -> void:
	var j = job_by_id(id)
	if j == null:
		return
	add_item(j.item)
	j.state = "done"
	say("Найдено: %s. Вернитесь к %s." % [j.item, giver_name(j.giver, true)])


func giver_name(g: String, dative := false) -> String:
	if g == "board":
		return "доске заданий" if dative else "Доска заданий"
	return preload("res://scripts/story.gd").WHO.get(g, {}).get("short" if dative else "name", g)


func turn_in(id: String) -> void:
	var j = job_by_id(id)
	if j == null:
		return
	if j.kind == "find":
		remove_item(j.item)
	p.su += int(j.su)
	if j.giver != "board" and int(j.rel) > 0:
		rel_add(j.giver, int(j.rel))
	if j.giver == "ryzhaya":
		p.flags["ry_errands"] = int(p.flags.get("ry_errands", 0)) + 1
	set_flag("job_done_" + j.id)
	if j.has("unlock"):
		say(j.unlock)
	p.jobs.erase(j)
	say("Подработка сдана: %s.%s" % [j.title, (" +%d Су." % j.su) if j.su > 0 else ""])
	changed.emit()


# ---------- Изучение Пустоши ----------

## Прогулка по Пустоши: 2 часа и сытость. Возвращает исход: poi / fight / loot / empty.
func explore_roll() -> Dictionary:
	p.food = maxi(0, p.food - 6)
	pass_hours(2)
	var unknown: Array = []
	for id in D.LOCS:
		if not (id in p.known):
			unknown.append(id)
	var r := randf()
	var miss := int(p.flags.get("explore_miss", 0))
	var curious := 0.15 if trait_has("Любопытство") else 0.0
	if not unknown.is_empty() and r < 0.3 + curious + miss * 0.15:
		p.flags["explore_miss"] = 0
		var id: String = unknown.pick_random()
		p.known.append(id)
		return {"kind": "poi", "id": id}
	p.flags["explore_miss"] = miss + 1
	if r < 0.6:
		return {"kind": "fight", "enemy": "pes" if randf() < 0.7 else "padal"}
	if r < 0.85:
		var loot: Array = [["su", randi_range(8, 30)], ["Сухпаёк", 1], ["Бинт", 1], ["Пистолетные патроны", 1], ["Самогон", 1]]
		var l: Array = loot.pick_random()
		if l[0] == "su":
			p.su += l[1]
		else:
			add_item(l[0], l[1])
		return {"kind": "loot", "what": l}
	return {"kind": "empty"}


# ---------- Имущество ----------

var quiet := false


func add_item(item: String, n: int = 1) -> void:
	if not quiet and D.ITEMS[item].type == "weapon" and p.inv.get(item, 0) == 0:
		say("Новое оружие: %s. Взять в руку: пейджер (Tab) → Имущество → «Взять», или в бою «Сменить оружие»." % item)
	p.inv[item] = p.inv.get(item, 0) + n
	changed.emit()


func remove_item(item: String, n: int = 1) -> bool:
	if p.inv.get(item, 0) < n:
		return false
	p.inv[item] -= n
	if p.inv[item] <= 0:
		p.inv.erase(item)
	changed.emit()
	return true


func has(item: String) -> bool:
	return p.inv.get(item, 0) > 0


func ammo_left() -> int:
	if p.weapon == "":
		return 0
	var it: Dictionary = D.ITEMS[p.weapon]
	return p.mag + p.inv.get(it.ammo, 0) * D.ITEMS[it.ammo].count


## Использовать предмет из имущества. Возвращает текст результата.
func use_item(item: String) -> String:
	var it: Dictionary = D.ITEMS[item]
	match it.type:
		"heal":
			remove_item(item)
			heal(it.amount)
			return "%s: +%d ООЗ." % [item, it.amount]
		"food":
			remove_item(item)
			feed(it.amount)
			return "%s: +%d сытости." % [item, it.amount]
		"calm":
			remove_item(item)
			calm(it.amount)
			return "%s: +%d ООР." % [item, it.amount]
		"armor":
			var slot: String = it.get("slot", "body")
			if slot == "body":
				p.armor = item
			else:
				p.gear[slot] = item
			changed.emit()
			return "Надето: %s." % item
		"amulet":
			p.gear.amulet = item
			p.mind = mini(p.mind, max_mind())
			changed.emit()
			return "На шее: %s." % item
		"weapon":
			if it.get("melee", false):
				p.melee = item
				changed.emit()
				return "Для ближнего боя: %s." % item
			if p.weapon != "":
				p.mags[p.weapon] = p.mag
			p.weapon = item
			p.mag = int(p.mags.get(item, 0))
			var extra := ""
			if p.mag == 0 and has(it.ammo):
				extra = " " + reload()
			changed.emit()
			return "В руке: %s (в магазине %d).%s" % [item, p.mag, extra]
	return "Это нельзя использовать."


## Перезарядка: тратит пачку патронов, если магазин пуст наполовину и больше.
func reload() -> String:
	if p.weapon == "":
		return "Нет огнестрела."
	var w: Dictionary = D.ITEMS[p.weapon]
	if p.mag >= w.mag:
		return "Магазин полон."
	if not has(w.ammo):
		return "Нет боеприпасов: %s." % w.ammo
	remove_item(w.ammo)
	p.mag = w.mag
	changed.emit()
	return "Перезарядка: %s (%d)." % [p.weapon, p.mag]


# ---------- Журнал ----------

func say(text: String) -> void:
	log_lines.append(text)
	if log_lines.size() > 60:
		log_lines.pop_front()
	logged.emit(text)


func quest(id: String, state: String) -> void:
	p.quests[id] = state
	changed.emit()


func flag(k: String) -> bool:
	return p.flags.get(k, false)


func set_flag(k: String, v = true) -> void:
	p.flags[k] = v


# ---------- Сохранения ----------

func slot_path(i: int) -> String:
	if i == AUTO:
		return "user://save_auto.json"
	return "user://save_%d.json" % i


func slot_name(i: int) -> String:
	return "Автосохранение" if i == AUTO else "Ячейка %d" % (i + 1)


func save(i: int) -> void:
	var data := {"version": VERSION, "p": p, "log": log_lines,
		"time": Time.get_datetime_string_from_system(false, true)}
	var f := FileAccess.open(slot_path(i), FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()
	if i != AUTO:
		say("Сохранено в ячейку %d." % (i + 1))


## Тихое сохранение при входе на карту и после сна, чтобы смерть не отбрасывала далеко.
func autosave() -> void:
	if p.is_empty() or p.get("hp", 1) <= 0:
		return
	save(AUTO)


func slot_info(i: int) -> String:
	if not FileAccess.file_exists(slot_path(i)):
		return "— пусто —"
	var data = JSON.parse_string(FileAccess.get_file_as_string(slot_path(i)))
	if typeof(data) != TYPE_DICTIONARY:
		return "— повреждено —"
	var pp: Dictionary = data.p
	var where: String = {"waste": "Пустошь", "caldera": "Кальдера", "caldera1": "Кальдера, ярус 1",
		"caldera2": "Кальдера, ярус 2", "caldera3": "Кальдера, ярус 3", "worldmap": "Карта мира"}.get(pp.get("map", ""), "?")
	return "%s · %s · %s" % [pp.get("callsign", "?"), where, data.get("time", "")]


func load_slot(i: int) -> bool:
	if not FileAccess.file_exists(slot_path(i)):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(slot_path(i)))
	if typeof(data) != TYPE_DICTIONARY:
		return false
	p = _fix_numbers(data.p)
	log_lines = data.get("log", [])
	return true


func any_save() -> int:
	var best := -1
	var best_t := 0
	for i in SLOTS + 1:
		if FileAccess.file_exists(slot_path(i)):
			var t := FileAccess.get_modified_time(slot_path(i))
			if t > best_t:
				best_t = t
				best = i
	return best


## JSON превращает все числа в float; возвращаем целые там, где они нужны.
func _fix_numbers(d: Dictionary) -> Dictionary:
	for k in ["faction", "hp", "mind", "food", "su", "will", "mag", "steps", "day", "seed", "hour"]:
		if d.has(k):
			d[k] = int(d[k])
	var inv := {}
	for k in d.inv:
		inv[k] = int(d.inv[k])
	d.inv = inv
	d.pos = [int(d.pos[0]), int(d.pos[1])]
	if not d.has("hour"):
		d["hour"] = 8
	if not d.has("map_at"):
		d["map_at"] = "caldera"
	if not d.has("gear"):
		d["gear"] = {"head": "", "legs": "", "feet": "", "amulet": ""}
	if not d.has("known"):
		d["known"] = ["caldera"]
	d.known.erase("outskirts")
	if d.get("map_at", "") == "outskirts":
		d.map_at = "caldera"
	if d.get("map", "") == "caldera":
		d.map = "caldera1"
		d.pos = [3, 3]
	for k in ["rel", "flags"]:
		if not d.has(k):
			d[k] = {}
	for k in d.rel:
		d.rel[k] = int(d.rel[k])
	if not d.has("jobs"):
		d["jobs"] = []
	for j in d.jobs:
		for k in ["need", "have", "su", "rel"]:
			if j.has(k):
				j[k] = int(j[k])
	if not d.has("companion"):
		d["companion"] = ""
	# Эмирра стала Рыжей: переносим флаги.
	for k in d.flags.keys():
		if str(k).begins_with("emirra_"):
			d.flags["ry_" + str(k).substr(7)] = d.flags[k]
			d.flags.erase(k)
	var pity := {}
	for k in d.get("pity", {}):
		pity[k] = int(d.pity[k])
	d["pity"] = pity
	for k in d.get("mags", {}):
		d.mags[k] = int(d.mags[k])
	return d


func main() -> Node:
	return get_meta("main")


## Внешность для портрета и спрайта по анкете.
const FACTION_LOOK := [
	{"coat": 2, "collar": 4}, {"coat": 3, "collar": 6}, {"coat": 4, "collar": 5},
	{"coat": 1, "collar": 6}, {"coat": 1, "collar": 8}, {"coat": 2, "collar": 9},
	{"coat": 3, "collar": 5}, {"coat": 4, "collar": 6}, {"coat": 1, "collar": 7},
]


func look(c: Dictionary = p) -> Dictionary:
	var traits: Array = c.phys + c.got_phys
	var fl: Dictionary = FACTION_LOOK[c.faction]
	var hair := 2
	if "Рыжие волосы" in traits:
		hair = 8
	elif "Белые волосы" in traits:
		hair = 6
	return {"sex": c.sex, "race": c.race, "traits": traits, "coat": fl.coat, "collar": fl.collar,
		"hair": hair, "old": c.age in ["Старый", "Пожилой"], "skin": 4}


func person_look(c: Dictionary = p) -> Dictionary:
	var l := look(c)
	return {"coat": l.coat + 1, "hair": l.hair, "race": l.race, "skin": 5, "accent": l.collar,
		"long": c.sex == "Ж"}
