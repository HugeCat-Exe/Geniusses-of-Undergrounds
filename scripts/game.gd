extends Node
## Состояние Гения, правила проверок и сохранения.

signal logged(text: String)
signal changed

const VERSION := "0.9.2"
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
		"inv": {}, "weapon": "", "melee": "Нож", "armor": "Футболка", "mag": 0, "loose": {},
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


## Свойство постсмертия: его не было при создании, оно появилось от травм.
## Возвращает травмы, из-за которых оно есть (пусто — врождённое).
func perk_cause(name: String, c: Dictionary = p) -> Array:
	var base := c.duplicate()
	base.got_phys = []
	base.got_psy = []
	if name in perks(base):
		return []
	var k := ""
	var good := false
	for a in D.ATTRS:
		if D.PERKS[a][0] == name or D.PERKS[a][1] == name:
			k = a
			good = D.PERKS[a][0] == name
	var i := D.KEYS.find(k)
	var res: Array = []
	for tr in c.got_phys:
		var v: float = D.PHYS[tr][i]
		if (v < 0 and not good) or (v > 0 and good):
			res.append(tr)
	for tr in c.got_psy:
		var v2: float = D.PSY[tr][i]
		if (v2 < 0 and not good) or (v2 > 0 and good):
			res.append(tr)
	return res


## Какие свойства постсмертия уйдут вместе с травмой.
func perks_from(trauma: String) -> Array:
	var res: Array = []
	for x in perks():
		if trauma in perk_cause(x):
			res.append(x)
	return res


## Реконструкция у автодока дорожает с каждым разом.
func autodoc_cure_price() -> int:
	return 1200 + 300 * int(p.flags.get("autodoc_cures", 0))


func has_perk(name: String, c: Dictionary = p) -> bool:
	return name in perks(c)


## Цены у торговцев: −3% за каждый +1 мода ХАР, +3% за каждый −1.
## Чья лавка сейчас открыта: от отношения с хозяином зависят цены.
var shop_who := ""


## Множитель цен по отношению: врагам дороже, приятелям и близким дешевле.
func rel_price_k(who: String) -> float:
	if who == "":
		return 1.0
	match rel_tier(who).idx:
		-2: return 1.25
		-1: return 1.1
		2: return 0.93
		3: return 0.88
	return 1.0


## «Для своих»: знакомым хозяин каждый день уступает одну вещь на четверть дешевле.
func deal_item(stock: Array, who: String) -> String:
	if who == "" or stock.is_empty() or rel_tier(who).idx < 1:
		return ""
	return stock[absi(hash(str(p.seed) + who + "deal" + str(p.day))) % stock.size()]


func price(base: int, item: String = "") -> int:
	var k := 1.0 - 0.03 * mod("ХАР")
	k *= rel_price_k(shop_who)
	if item != "" and item == p.get("deal_today", ""):
		k *= 0.75
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
	var k := 1.0 + 0.03 * mod("ХАР")
	if shop_who != "" and rel_tier(shop_who).idx >= 2:
		k += 0.05
	return maxi(1, roundi(base * k))


## Приветствие по отношению: от «прикидывает, где закопать» до «садись, рассказывай».
const REL_GREET := {
	-2: "{name} смотрит на вас так, будто прикидывает, где закопать тело. Цены для вас выросли.",
	-1: "Вас встречают холодно, без улыбки. Здесь вам не рады.",
	1: "Вас узнают и коротко кивают.",
	2: "{name} улыбается: «А, это ты. Заходи, свои».",
	3: "{name} по-настоящему рад{а} вам: «Садись, рассказывай. Живой, и слава Сефирам».",
}
## Мелкие услуги для приятелей: раз в день, не всегда.
const REL_FAVOR := {
	"cook": ["feed", 25, "Грета молча ставит перед вами миску: «За счёт дома. Худой ты какой-то». (+25 сытости)"],
	"surgeon": ["item", "Бинт", "Кост, не глядя, кидает вам бинт: «Чтобы не шёл ко мне с каждой царапиной». (+1 Бинт)"],
	"gunsmith": ["item", "Пистолетные патроны", "Сава подталкивает к вам пачку патронов: «Бракованные гильзы, но стреляют». (+1 Пистолетные патроны)"],
	"bartender": ["item", "Самогон", "Гарри наливает и подвигает стакан: «Этот за мой счёт». (+1 Самогон)"],
	"trader": ["item", "Сухпаёк", "Бартоломей суёт вам сухпаёк: «Просрочен, но тебе можно». (+1 Сухпаёк)"],
	"old": ["calm", 6, "Ефим кладёт сухую ладонь вам на плечо, и в голове становится тише. (+6 ООР)"],
	"mistel": ["feed", 15, "Ода угощает вас лепёшкой: «Дети велели передать». (+15 сытости)"],
}


## Строка в начале разговора: как к Гению относятся и не перепало ли чего.
func rel_greeting(who: String, name: String, fem: bool) -> String:
	var t := rel_tier(who)
	var txt := ""
	if REL_GREET.has(t.idx):
		txt = str(REL_GREET[t.idx]).replace("{name}", name.get_slice(",", 0)).replace("{а}", "а" if fem else "")
	var key := "favor_%s_%d" % [who, p.day]
	if t.idx >= 2 and REL_FAVOR.has(who) and not flag(key):
		set_flag(key)
		if hash(str(p.seed) + key) % 2 == 0:
			var fv: Array = REL_FAVOR[who]
			match fv[0]:
				"feed": feed(int(fv[1]))
				"item": add_item(fv[1])
				"calm": calm(int(fv[1]))
			txt += "\n" + fv[2]
	return txt


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

## Живое время: час игры идёт минуту настоящего, сутки сменяются за 24 минуты.
const SEC_PER_HOUR := 60.0


func tick(delta: float) -> void:
	p.minf = float(p.get("minf", 0.0)) + delta * 60.0 / SEC_PER_HOUR
	if p.minf >= 60.0:
		p.minf -= 60.0
		pass_hours(1)


func clock() -> String:
	return "%02d:%02d" % [int(p.hour), int(p.get("minf", 0.0))]


## Ночь: с 20:00 до 5:00.
func is_night() -> bool:
	return int(p.hour) >= 20 or int(p.hour) < 5


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
	p.minf = 0.0
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
	if old != "" and old != id:
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


# ---------- Сердца (у кого ★) ----------

const Hearts := preload("res://scripts/hearts.gd")


func hearts(who: String) -> int:
	return int(p.get("hearts", {}).get(who, 0))


## Состояние следующего сердца: {state, text, heart}. state: locked / wait / unwritten / ready / full.
func heart_state(who: String) -> Dictionary:
	if not Hearts.HEARTS.has(who):
		return {"state": "none", "text": ""}
	var n := hearts(who)
	if n >= 5:
		return {"state": "full", "text": "Все пять сердец заполнены."}
	if rel_tier(who).idx < 3:
		return {"state": "locked", "text": "Сердца откроются на ступени «Близкие знакомые»."}
	var last := int(p.get("heart_day", {}).get(who, -99))
	if n > 0 and int(p.day) < last + Hearts.GAP_DAYS:
		var left := last + Hearts.GAP_DAYS - int(p.day)
		return {"state": "wait", "text": "Следующее сердце: через %d дн." % left}
	var h: Dictionary = Hearts.HEARTS[who][n]
	if h.is_empty():
		return {"state": "unwritten", "text": "Сердце %d: сюжет ещё не написан." % (n + 1)}
	return {"state": "ready", "text": "Сердце %d «%s»: загляните сюда — %s." % [n + 1, h.get("title", "…"), h.get("where", h.map)], "heart": h}


## Готовая сцена сердца, которая происходит на этой карте (или null).
func heart_here(map_name: String):
	for who in Hearts.HEARTS:
		var st := heart_state(who)
		if st.state == "ready" and st.heart.map == map_name:
			return {"who": who, "scene": st.heart.scene}
	return null


func heart_done(who: String) -> void:
	if not p.has("hearts"):
		p["hearts"] = {}
	if not p.has("heart_day"):
		p["heart_day"] = {}
	p.hearts[who] = hearts(who) + 1
	p.heart_day[who] = int(p.day)
	say("%s: сердце %d из 5 заполнено." % [WHO_NAME(who), hearts(who)])
	changed.emit()
	autosave()


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
	if tpl.has("pois"):
		j["poi"] = tpl.pois[rng.randi() % tpl.pois.size()]
		j["text"] = str(tpl.text).replace("{place}", D.LOCS[j.poi].name)
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
	var pool: Array = []
	for k in D.JOBS.size():
		if job_cooldown(k) <= 0:
			pool.append(k)
	var res: Array = []
	for i in 3:
		if pool.is_empty():
			break
		var k: int = pool.pop_at(rng.randi() % pool.size())
		var id := "d%d_%d" % [p.day, k]
		var taken := false
		for j in p.jobs:
			if j.id == id or (j.giver == D.JOBS[k].giver and j.title == D.JOBS[k].title):
				taken = true
		if not taken and not flag("job_done_" + id):
			res.append(_make_job(D.JOBS[k], rng, id))
	return res


## Сколько дней ещё ждать, пока этот житель снова попросит о том же (0 — можно).
func job_cooldown(k: int) -> int:
	var last := int(p.flags.get("jobcd_%d" % k, -99))
	return maxi(0, last + int(D.JOBS[k].get("cd", 1)) - int(p.day))


## Особые задания: открываются постепенно. Возвращает [[предложение или null, причина замка]].
func special_offers() -> Array:
	var res: Array = []
	var done := int(p.flags.get("board_done", 0))
	for sp in D.SPECIAL_BOARD:
		var tpl: Dictionary = {"RESCUE_JOB": D.RESCUE_JOB, "RAID_CLEAR_JOB": D.RAID_CLEAR_JOB}[sp.tpl]
		if sp.has("need_board") and done < int(sp.need_board):
			res.append([null, "Откроется после %d регулярн%s заданий (сдано %d)." % [sp.need_board, "ого" if int(sp.need_board) == 1 else "ых", done]])
			continue
		if sp.has("need_flag") and not flag(sp.need_flag):
			res.append([null, "Откроется, когда в Кальдере вскроют заваренный люк."])
			continue
		var id := "sp_%s_%d" % [sp.id, p.day]
		var busy := false
		for j in p.jobs:
			if j.title == tpl.title:
				busy = true
		if busy or flag("job_done_" + id):
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(id)
		res.append([_make_job(tpl, rng, id), ""])
	return res


func take_job(j: Dictionary) -> void:
	p.jobs.append(j)
	if j.kind == "find" and not (j.poi in p.known):
		p.known.append(j.poi)
		say("На карте отмечено: %s." % D.LOCS[j.poi].name)
	if j.kind == "escort" and not (j.poi in p.known):
		p.known.append(j.poi)
		say("На карте отмечено: %s." % D.LOCS[j.poi].name)
	if j.kind == "kill" and j.enemy == "muezzin" and not ("den" in p.known):
		p.known.append("den")
		say("На карте отмечено: %s." % D.LOCS.den.name)
	say("Новая подработка: %s." % j.title)
	changed.emit()


## Сегодня Рыжая сидит дома, а не в баре (решается по зерну дня).
func ry_home_today() -> bool:
	return hash(str(p.seed) + "ryhome" + str(p.day)) % 2 == 0


## Задание на спасение, если оно взято.
func escort_job():
	for j in p.jobs:
		if j.kind == "escort":
			return j
	return null


## Бедолага пошёл за Гением.
func escort_start() -> void:
	var j = escort_job()
	if j == null:
		return
	j.state = "escort"
	say("Бедолага идёт за вами. Доведите его до Кальдеры.")
	changed.emit()


## Гений спустился в Кальдеру с бедолагой: у того теперь есть дом.
func escort_arrive() -> void:
	var j = escort_job()
	if j == null or j.state != "escort":
		return
	var su := int(j.su)
	turn_in(j.id)
	set_flag("rescued_once")
	# отдельная сцена: человек благодарит, Институт переводит оплату на пейджер
	temp_nodes["stray_thanks"] = {"who": "stray", "text": "У ворот Кальдеры бедолага останавливается, будто не верит, что дошёл. Трогает холодную стену, потом хватает вас за руку обеими ладонями.\n\n— Я думал, там и останусь. В том посёлке. Спасибо, Гений. Я... я не знаю, чем отдать.\n\nОн уходит вглубь яруса, оглядываясь на каждом шагу. У него теперь есть дом.\n\nПейджер дважды пищит. На экране: «ИНСТИТУТ ПО ЭТИКЕ. ЗАДАНИЕ «СИГНАЛ ИЗ ПОСЁЛКА» ЗАКРЫТО. ПЕРЕВЕДЕНО: %d СУ».\n\n[color=#7ff07a](+%d Су на счёт пейджера)[/color]" % [su, su],
		"choices": [{"t": "Не за что.", "next": "end"}]}
	main().open_dialogue.call_deferred("stray_thanks")


func job_by_id(id: String):
	for j in p.jobs:
		if j.id == id:
			return j
	return null


## Убит враг: засчитать во все подходящие подработки.
func on_kill(enemy: String) -> void:
	if enemy == "muezzin":
		p.flags["muezzin_dead_day"] = int(p.day)
	if enemy == "pes":
		p.flags["dogs"] = int(p.flags.get("dogs", 0)) + 1
		if p.quests.get("dogs", "") == "active" and int(p.flags.dogs) >= 3:
			quest("dogs", "done")
	# слепец — взрослый слепыш: засчитывается и в задания на слепышей
	var alias := "slepysh" if enemy == "slepets" else enemy
	for j in p.jobs:
		if j.state == "active" and j.kind == "kill" and (j.enemy == enemy or j.enemy == alias):
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
	# любое обычное задание (с доски или от жителя), кроме особых и личных просьб
	if str(j.id).begins_with("d"):
		p.flags["board_done"] = int(p.flags.get("board_done", 0)) + 1
		p.flags["jobcd_" + str(j.id).get_slice("_", 1)] = int(p.day)
		if int(p.flags.board_done) == 3 and not p.quests.has("spice"):
			say("Слух по Кальдере: Матушка Грета на третьем ярусе ищет надёжного человека.")
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
	return p.mag + rounds_left(it.ammo)


## Патроны в запасе: россыпь из начатой пачки + целые пачки.
func rounds_left(ammo: String) -> int:
	if not p.has("loose"):
		p.loose = {}
	return int(p.loose.get(ammo, 0)) + p.inv.get(ammo, 0) * int(D.ITEMS[ammo].count)


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
			if it.has("hp"):
				heal(it.hp)
				return "%s: +%d сытости, +%d ООЗ." % [item, it.amount, it.hp]
			return "%s: +%d сытости." % [item, it.amount]
		"mod":
			return install_mod(item)
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
			if p.mag == 0 and rounds_left(it.ammo) > 0:
				extra = " " + reload()
			changed.emit()
			return "В руке: %s (в магазине %d).%s" % [item, p.mag, extra]
	return "Это нельзя использовать."


# ---------- Самолечение ----------

## Зашить раны самому: тратит бинт; исход зависит от шва (k из 6), Медицины и броска к20.
func self_heal(k: int) -> String:
	remove_item("Бинт")
	var skill := skill_bonus("Медицина")
	var d := randi_range(1, 20)
	var ok := d + skill >= 12
	var res := "Самолечение: зашито %d из 6, к20=%d %+d (Медицина) — %s. " % [k, d, skill, "удачно" if ok else "неудачно"]
	if k <= 1:
		var dmg := hurt(6, "body")
		changed.emit()
		return res + "Игла соскальзывает, рана расходится: −%d ООЗ." % dmg
	var amount := int(round((12.0 + 5.0 * maxi(0, skill)) * k / 6.0))
	if k >= 6:
		amount = maxi(amount, 18 + 6 * maxi(0, skill))
	if ok:
		amount = int(amount * 1.5)
	heal(amount)
	res += "+%d ООЗ." % amount
	if k >= 6 and ok and skill >= 2 and not p.wounds.is_empty():
		var w: String = p.wounds.pop_front()
		res += " Рана «%s» зашита как следует." % w.to_lower()
	changed.emit()
	return res


# ---------- Слухи, крафт, специи ----------

## Слух от Гарри: новое место на карте или тайник в уже известном.
func buy_rumor() -> String:
	p.flags["rumor_day"] = int(p.day)
	var unknown: Array = []
	for id in D.LOCS:
		if not (id in p.known) and D.LOCS[id].kind == "poi":
			unknown.append(id)
	if not unknown.is_empty():
		var id: String = unknown.pick_random()
		p.known.append(id)
		last_note = "— Говорят, %s. Сам не видел, но дорогу тебе нарисую.\n\n[color=#7ff07a]На карте отмечено: %s.[/color]" % [D.LOCS[id].desc.to_lower().trim_suffix("."), D.LOCS[id].name]
		say("Слух: на карте отмечено новое место — %s." % D.LOCS[id].name)
		return id
	var pois: Array = []
	for id in p.known:
		if D.LOCS.has(id) and D.LOCS[id].kind == "poi":
			pois.append(id)
	var poi: String = pois.pick_random()
	p.flags["rumor_cache"] = poi
	last_note = "— Один падальщик, перед тем как его съели, хвастался тайником: место «%s», у самой тропы. Проверь, пока другие не проверили.\n\n[color=#7ff07a]В месте «%s» появился тайник.[/color]" % [D.LOCS[poi].name, D.LOCS[poi].name]
	say("Слух: тайник в месте «%s»." % D.LOCS[poi].name)
	return poi


func rumor_loot() -> void:
	var poi: String = p.flags.get("rumor_cache", "")
	p.flags.erase("rumor_cache")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(p.seed) + "rumor" + poi + str(p.day))
	var got: Array = []
	if rng.randf() < 0.35:
		var m: String = RAID_MODS[rng.randi() % RAID_MODS.size()]
		add_item(m)
		got.append(m)
	var l: Array = RAID_COMMON[rng.randi() % RAID_COMMON.size()]
	add_item(l[0], l[1])
	got.append(l[0])
	var su := rng.randi_range(20, 60)
	p.su += su
	got.append("%d Су" % su)
	last_note = ", ".join(got)
	say("Найдено: %s." % last_note)


func craft_can(r: Array) -> bool:
	if p.su < int(r[2]):
		return false
	for it in r[1]:
		if p.inv.get(it, 0) < int(r[1][it]):
			return false
	return true


func craft_need(r: Array) -> String:
	var parts: Array = []
	for it in r[1]:
		parts.append("%s ×%d (есть %d)" % [it, r[1][it], p.inv.get(it, 0)])
	return "%s, %d Су" % [", ".join(parts), r[2]]


func craft(giver: String, idx: int) -> void:
	var r: Array = D.CRAFT[giver][idx]
	if not craft_can(r):
		return
	for it in r[1]:
		remove_item(it, int(r[1][it]))
	p.su -= int(r[2])
	add_item(r[0])
	say("Сделано: %s." % r[0])


## Запутанные специи открываются, когда Гений знаком с Гретой и сдал три задания с экрана.
func spice_ready() -> bool:
	return flag("cook_met") and int(p.flags.get("board_done", 0)) >= 3 and not p.quests.has("spice")


func spice_herbs() -> int:
	var n := 0
	for h in D.HERBS:
		if has(h):
			n += 1
	return n


# ---------- Рейд ----------

var last_note := ""

const RAID_COMMON := [["Старая аптечка", 1], ["Бинт", 2], ["Пистолетные патроны", 1], ["Карабинные патроны", 1],
	["Револьверные патроны", 1], ["Стимулятор", 1], ["Стандартная дробь", 1], ["Сухпаёк", 1]]
const RAID_MODS := ["Удлинённый магазин (пистолет)", "Удлинённый магазин (карабин)", "Удлинённый магазин (винтовка)",
	"Прицел (пистолет)", "Прицел (карабин)", "Прицел (револьвер)", "Ускоритель перезарядки (пистолет)",
	"Ускоритель перезарядки (карабин)", "Ускоритель перезарядки (винтовка)", "Ускоритель перезарядки (револьвер)", "Тяжёлая рукоять"]


func raid_key(id: String) -> String:
	return "rc_%s_%d" % [id, int(p.day) / 3]


## Обыскать тайник в рейде: две находки, на нижнем ярусе чаще попадаются обвесы.
func raid_loot(id: String) -> void:
	set_flag(raid_key(id))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(p.seed) + raid_key(id))
	var deep := int(id.substr(1)) >= 5
	var got: Array = []
	if rng.randf() < (0.55 if deep else 0.3):
		var m: String = RAID_MODS[rng.randi() % RAID_MODS.size()]
		add_item(m)
		got.append(m)
	for i in (2 if deep else 1):
		var l: Array = RAID_COMMON[rng.randi() % RAID_COMMON.size()]
		add_item(l[0], l[1])
		got.append("%s ×%d" % [l[0], l[1]] if l[1] > 1 else l[0])
	var su := rng.randi_range(5, 30 if deep else 18)
	p.su += su
	got.append("%d Су" % su)
	last_note = ", ".join(got)
	say("Найдено: %s." % last_note)


# ---------- Обвесы на оружие ----------

## Класс оружия для обвесов: пистолет, револьвер, карабин, винтовка, дробовик, ближний бой.
func weapon_class(w: String) -> String:
	var it: Dictionary = D.ITEMS.get(w, {})
	if it.get("melee", false) or it.get("kind", "") == "Ближний бой":
		return "Ближний бой"
	var kind: String = it.get("kind", "")
	if kind == "Пистолет":
		return "Револьвер" if it.get("ammo", "") == "Револьверные патроны" else "Пистолет"
	if kind == "Винтовка":
		return "Винтовка" if float(it.get("reload", 1.0)) >= 3.0 else "Карабин"
	return kind


func wmods(w: String) -> Array:
	return p.get("wmods", {}).get(w, [])


func has_wmod(w: String, kind: String) -> bool:
	for m in wmods(w):
		if D.ITEMS[m].mod == kind:
			return true
	return false


## Поставить обвес на оружие в руках (огнестрел или ближний бой — по классу обвеса).
func install_mod(m: String) -> String:
	var it: Dictionary = D.ITEMS[m]
	var w: String = p.melee if it.fits == "Ближний бой" else p.weapon
	if w == "" or weapon_class(w) != it.fits:
		return "%s подходит только для класса «%s». Возьмите такое оружие в руку." % [m, it.fits.to_lower()]
	var slots := int(D.ITEMS[w].get("mods", 2))
	if wmods(w).size() >= slots:
		return "На %s больше нет места для обвеса (слотов: %d)." % [w, slots]
	if has_wmod(w, it.mod):
		return "На %s такой обвес уже стоит." % w
	if not p.has("wmods"):
		p.wmods = {}
	var arr: Array = p.wmods.get(w, [])
	arr.append(m)
	p.wmods[w] = arr
	remove_item(m)
	changed.emit()
	return "Обвес установлен: %s → %s." % [m, w]


func remove_mod(w: String, m: String) -> void:
	var arr: Array = wmods(w)
	arr.erase(m)
	p.wmods[w] = arr
	add_item(m)
	if D.ITEMS[m].mod == "mag":
		p.mag = mini(p.mag, mag_size(w))


func mag_size(w: String) -> int:
	var n := int(D.ITEMS[w].get("mag", 0))
	if has_wmod(w, "mag"):
		n = int(ceil(n * 1.5))
	return n


func reload_time(w: String) -> float:
	var r := float(D.ITEMS[w].get("reload", 1.0))
	if has_wmod(w, "reload"):
		r = 0.5 if r <= 1.0 else r - 1.0
	return r


func aim_bonus(w: String) -> int:
	return 2 if has_wmod(w, "aim") else 0


func melee_mult(w: String) -> float:
	return 1.25 if has_wmod(w, "heavy") else 1.0


## Перезарядка: берёт ровно столько патронов, сколько не хватает в магазине.
## Сначала из начатой пачки, потом вскрывает новые; остаток пачки остаётся в запасе.
func reload() -> String:
	if p.weapon == "":
		return "Нет огнестрела."
	var w: Dictionary = D.ITEMS[p.weapon]
	if p.mag >= mag_size(p.weapon):
		return "Магазин полон."
	if rounds_left(w.ammo) <= 0:
		return "Нет боеприпасов: %s." % w.ammo
	var need: int = mag_size(p.weapon) - p.mag
	var loose: int = int(p.loose.get(w.ammo, 0))
	while loose < need and has(w.ammo):
		remove_item(w.ammo)
		loose += int(D.ITEMS[w.ammo].count)
	var take: int = mini(need, loose)
	p.mag += take
	loose -= take
	if loose > 0:
		p.loose[w.ammo] = loose
	else:
		p.loose.erase(w.ammo)
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
		"caldera2": "Кальдера, ярус 2", "caldera3": "Кальдера, ярус 3", "caldera4": "Кальдера, ярус 4",
		"caldera_ryhome": "Домик Рыжей", "raid1": "Заброшенный ярус 5", "raid2": "Затопленный ярус 6",
		"poi_station": "Заправка", "poi_river": "Река Лета", "poi_tower": "Вышка", "poi_den": "Логово псов",
		"poi_ruins": "Разрушенный посёлок", "poi_forest": "Запутанный лес", "worldmap": "Карта мира"}.get(pp.get("map", ""), "?")
	return "%s · %s · %s" % [pp.get("callsign", "?"), where, data.get("time", "")]


func load_slot(i: int) -> bool:
	if not FileAccess.file_exists(slot_path(i)):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(slot_path(i)))
	if typeof(data) != TYPE_DICTIONARY:
		return false
	p = _fix_numbers(data.p)
	log_lines = data.get("log", [])
	_migrate()
	return true


## Старые сохранения: до 0.9 счётчик сданных заданий учитывал только задания от самой доски,
## а их почти нет. Пересчитываем по флагам job_done_d… (все обычные подработки).
func _migrate() -> void:
	if int(p.flags.get("save_ver", 0)) >= 9:
		return
	var n := 0
	for k in p.flags:
		if str(k).begins_with("job_done_d"):
			n += 1
	p.flags["board_done"] = maxi(int(p.flags.get("board_done", 0)), n)
	p.flags["save_ver"] = 9


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
