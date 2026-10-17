extends Node
## Состояние Гения, правила проверок и сохранения.

signal logged(text: String)
signal changed

const VERSION := "0.3"
const SLOTS := 3

var p: Dictionary = {}
## Узлы диалогов, собранные на лету (исходы прогулок и т. п.).
var temp_nodes: Dictionary = {}
var log_lines: Array = []


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
	}


func start_game(c: Dictionary) -> void:
	p = c
	var pistol: String = D.START_PISTOL[p.faction]
	p.weapon = pistol
	p.mag = D.ITEMS[pistol].mag
	p.inv = {}
	quiet = true
	add_item(pistol)
	add_item("Нож")
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

func mods_total(c: Dictionary = p) -> Array:
	var t := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var rows: Array = [D.SEXES[c.sex], D.FACTIONS[c.faction].mods, D.AGES[c.age].mods,
		D.RACES[c.race].mods, D.BIRTH[c.birth]]
	for tr in c.phys + c.got_phys:
		rows.append(D.PHYS[tr])
	for tr in c.psy + c.got_psy:
		rows.append(D.PSY[tr])
	for r in rows:
		for i in 8:
			t[i] += r[i]
	return t


## Сжатие минусов: отрицательная сумма весит 60%, чтобы черты не роняли Гения в «яму».
func soft(x: float) -> float:
	return x if x >= 0.0 else x * 0.6


func stat(k: String, c: Dictionary = p) -> int:
	var t := mods_total(c)
	var i := D.KEYS.find(k)
	return clampi(roundi(10.0 + soft(t[i])), 4, 22)


func max_hp(c: Dictionary = p) -> int:
	return clampi(roundi(70.0 + soft(mods_total(c)[0]) * 4.0) + stat("ТЕЛ", c), 40, 110)


func max_mind(c: Dictionary = p) -> int:
	return clampi(roundi(70.0 + soft(mods_total(c)[1]) * 4.0) + stat("ИНТ", c), 40, 110)


func max_will(c: Dictionary = p) -> int:
	return maxi(0, floori((stat("ТЕЛ", c) + stat("ВСП", c)) / 5.0))


func speed(c: Dictionary = p) -> int:
	return maxi(1, roundi((stat("ТЕЛ", c) + stat("ВСП", c) + stat("ЛВК", c)) / 4.0 * 1.7))


func skill_bonus(skill: String, c: Dictionary = p) -> int:
	var b := D.check_mod(stat(D.skill_stat(skill), c))
	if skill in c.main:
		b += 2 + maxi(0, D.check_mod(stat("УДЧ", c)))
	return b


func phys_def() -> int:
	var a := 0
	if p.armor != "":
		a = D.ITEMS[p.armor].def
	return a + maxi(0, D.check_mod(stat("ТЕЛ")))


func psy_def() -> int:
	return maxi(0, D.check_mod(stat("ИНТ")))


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
	if d == 20:
		ok = true
	if d == 1:
		ok = false
	if cat != "":
		pity_result(cat, ok)
	return {"d": d, "bonus": b, "total": d + b, "dc": dc, "ok": ok, "skill": skill}


func chance(bonus: int, dc: int) -> int:
	var need := dc - bonus
	return clampi(roundi((21 - need) / 20.0 * 100.0), 5, 95)


func roll_text(r: Dictionary) -> String:
	var res := "УСПЕХ" if r.ok else "ПРОВАЛ"
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
	var res := {"alive": ok >= 2, "ok": ok, "rolls": rolls, "injury": ""}
	if ok == 2:
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
		p.food = maxi(0, p.food - 1)
		if p.food == 0:
			p.hp -= 1
			if p.steps % (every * 4) == 0:
				say("Желудок сводит от голода. ООЗ уходит.")
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


## Новый день: звери и падальщики возвращаются в Пустошь.
func new_day() -> void:
	var keep: Array = []
	for id in p.killed:
		if not (str(id).begins_with("pes_") or str(id).begins_with("padal_")):
			keep.append(id)
	p.killed = keep


# ---------- Отношения ----------

func rel_points(who: String) -> int:
	if p.rel.has(who):
		return int(p.rel[who])
	var st: Dictionary = preload("res://scripts/story.gd").WHO.get(who, {})
	if st.has("faction"):
		return relation(st.faction) * 4
	return 0


func rel_add(who: String, n: int) -> void:
	var before := rel_tier(who)
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
	if not unknown.is_empty() and r < 0.3 + miss * 0.15:
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
			p.armor = item
			changed.emit()
			return "Надето: %s." % item
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
	return "user://save_%d.json" % i


func save(i: int) -> void:
	var data := {"version": VERSION, "p": p, "log": log_lines,
		"time": Time.get_datetime_string_from_system(false, true)}
	var f := FileAccess.open(slot_path(i), FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	say("Сохранено в ячейку %d." % (i + 1))


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
	for i in SLOTS:
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
