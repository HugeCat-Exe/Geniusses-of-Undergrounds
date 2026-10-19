extends Control
## Анкета Института по Этике: пошаговое создание Гения с живым пересчётом листа.

const STEPS := ["Позывной и имя", "Биологический пол", "Раса", "Родная фракция", "Возраст",
	"Место рождения", "Внешние черты", "Черты характера", "Основные навыки", "Заключение Института"]
const HELP := [
	"Введите уникальный позывной, под которым Вас будут знать Гении. Для Вашей безопасности не используйте полное имя.",
	"Укажите биологический пол. Институт напоминает: Пустошь не делает скидок.",
	"Выберите вид из Реестра рас. Наведите курсор, чтобы прочесть справку.",
	"Укажите родную фракцию. Система покажет, как к Вам будут относиться другие.",
	"Возрастная категория определяет число черт, которые Вы обязаны внести.",
	"Подземка, в которой Вы появились на свет. Актуальный список — в Реестре Подземок.",
	"Внесите внешние черты согласно «Справочнику Занимательных Черт».",
	"Внесите черты характера. Гении должны знать, чего ожидать друг от друга.",
	"Отметьте основные навыки: к ним добавляется бонус удачи (мод УДЧ + 1, не меньше +1). Два навыка, три при ИНТ 16+ («Эрудит»).",
	"Проверьте данные. Введите «О» (Одобрено) в зелёное поле, чтобы закрепить карточку в базе.",
]

var c: Dictionary
var step := 0
var header: Label
var help: Label
var list: VBoxContainer
var scroll: ScrollContainer
var desc: RichTextLabel
var portrait: TextureRect
var sheet: RichTextLabel
var counter: Label
var next_btn: Button
var back_btn: Button
var approve: LineEdit


func _ready() -> void:
	c = G.new_character()
	c.callsign = ""
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Pal.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	header = Pal.label("", Pal.G5, 12, true)
	header.position = Vector2(12, 6)
	add_child(header)
	help = Pal.label("", Pal.G3, 8)
	help.position = Vector2(12, 26)
	help.size = Vector2(616, 22)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(help)

	var left := PanelContainer.new()
	left.position = Vector2(12, 52)
	left.size = Vector2(232, 262)
	add_child(left)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var frame := Panel.new()
	frame.position = Vector2(254, 52)
	frame.size = Vector2(148, 150)
	add_child(frame)
	portrait = TextureRect.new()
	portrait.position = Vector2(262, 56)
	portrait.scale = Vector2(2.75, 2.6)
	add_child(portrait)
	desc = Pal.rich("", 8)
	desc.fit_content = false
	desc.scroll_active = true
	desc.position = Vector2(254, 208)
	desc.size = Vector2(150, 106)
	add_child(desc)

	var right := PanelContainer.new()
	right.position = Vector2(412, 52)
	right.size = Vector2(216, 262)
	add_child(right)
	sheet = Pal.rich("", 8)
	sheet.fit_content = false
	sheet.scroll_active = true
	sheet.meta_hover_started.connect(_on_meta)
	right.add_child(sheet)

	back_btn = Pal.button("< НАЗАД", _back, 10)
	back_btn.position = Vector2(12, 324)
	back_btn.size = Vector2(110, 22)
	add_child(back_btn)
	counter = Pal.label("", Pal.G4, 10)
	counter.position = Vector2(140, 328)
	add_child(counter)
	next_btn = Pal.button("ДАЛЕЕ >", _next, 10)
	next_btn.position = Vector2(518, 324)
	next_btn.size = Vector2(110, 22)
	add_child(next_btn)
	_build()


# ---------- шаги ----------

func _build() -> void:
	for ch in list.get_children():
		ch.queue_free()
	approve = null
	header.text = "АНКЕТА ГЕНИЯ  ·  ШАГ %d/%d  ·  %s" % [step + 1, STEPS.size(), STEPS[step].to_upper()]
	help.text = HELP[step]
	desc.text = ""
	match step:
		0:
			_field("Позывной", c.callsign, _set_text.bind("callsign"), 28)
			_field("Полное имя", c.name, _set_text.bind("name"), 40)
			_field("Ключевая фраза", c.motive, _set_text.bind("motive"), 80)
		1:
			for s in ["М", "Ж"]:
				_option("Мужской" if s == "М" else "Женский", c.sex == s, _pick.bind("sex", s), _mods_text(D.SEXES[s]))
		2:
			for r in D.RACES:
				_option(r, c.race == r, _pick.bind("race", r), D.RACES[r].desc + "\n\n" + _mods_text(D.RACES[r].mods))
		3:
			for i in D.FACTIONS.size():
				var f: Dictionary = D.FACTIONS[i]
				_option("%d. %s" % [i + 1, f.name], c.faction == i, _pick.bind("faction", i),
					f.desc + "\n\n" + _mods_text(f.mods) + "\n\n" + _relations_text(i))
		4:
			for a in D.AGES:
				var ag: Dictionary = D.AGES[a]
				_option("%s (%d вн. / %d хар.)" % [a, ag.ext, ag.psy], c.age == a, _pick.bind("age", a),
					"Внешних черт: %d\nЧерт характера: %d\n\n%s" % [ag.ext, ag.psy, _mods_text(ag.mods)])
		5:
			for b in D.BIRTH:
				_option(b, c.birth == b, _pick.bind("birth", b), "Подземка %s\n\n%s" % [b, _mods_text(D.BIRTH[b])])
		6:
			for t in D.PHYS:
				_option(t, t in c.phys, _toggle.bind("phys", t, D.AGES[c.age].ext), _trait_info(t, D.PHYS[t]))
		7:
			if D.AGES[c.age].psy == 0:
				list.add_child(Pal.label("Ребёнку черты характера\nне вносятся.", Pal.G3))
			for t in D.PSY:
				_option(t, t in c.psy, _toggle.bind("psy", t, D.AGES[c.age].psy), _trait_info(t, D.PSY[t]))
		8:
			c.main = c.main.slice(0, G.main_count(c))
			for s in D.SKILLS:
				_option("%s (%s)" % [s[0], s[1]], s[0] in c.main, _toggle.bind("main", s[0], G.main_count(c)),
					"%s\n\nХарактеристика %s: %s" % [s[2], s[1], D.STAT_DESC[s[1]]])
		9:
			list.add_child(Pal.label("Заключение Института\nпо Этике о характеристиках\nГения:", Pal.G4, 10, true))
			var verdict := Pal.rich(_verdict(), 8)
			verdict.custom_minimum_size = Vector2(210, 0)
			list.add_child(verdict)
			list.add_child(Pal.label("Подпись (введите «О»):", Pal.G4))
			approve = LineEdit.new()
			approve.max_length = 3
			approve.placeholder_text = "О"
			approve.text_changed.connect(func(_t): _refresh())
			list.add_child(approve)
	scroll.scroll_vertical = 0
	_refresh()


func _field(caption: String, value: String, cb: Callable, maxlen: int = 28) -> void:
	list.add_child(Pal.label(caption + ":", Pal.G3))
	var le := LineEdit.new()
	le.text = value
	le.max_length = maxlen
	le.text_changed.connect(cb)
	list.add_child(le)


func _set_text(t: String, key: String) -> void:
	c[key] = t
	_refresh()


func _option(text: String, selected: bool, cb: Callable, info: String) -> void:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = selected
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 9)
	b.pressed.connect(cb)
	b.mouse_entered.connect(func(): desc.text = "[b]%s[/b]\n%s" % [text, info])
	list.add_child(b)


func _pick(key: String, value) -> void:
	c[key] = value
	if key == "age":
		c.phys = c.phys.slice(0, D.AGES[value].ext)
		c.psy = c.psy.slice(0, D.AGES[value].psy)
	_rebuild_keep_scroll()


func _toggle(key: String, value: String, limit: int) -> void:
	var arr: Array = c[key]
	if value in arr:
		arr.erase(value)
	elif arr.size() < limit:
		arr.append(value)
	_rebuild_keep_scroll()


func _rebuild_keep_scroll() -> void:
	var s := scroll.scroll_vertical
	var d := desc.text
	_build()
	desc.text = d
	await get_tree().process_frame
	scroll.scroll_vertical = s


func _valid() -> String:
	match step:
		0:
			if c.callsign.strip_edges() == "":
				return "Нужен позывной"
		6:
			if c.phys.size() != D.AGES[c.age].ext:
				return "Выбрано %d из %d" % [c.phys.size(), D.AGES[c.age].ext]
		7:
			if c.psy.size() != D.AGES[c.age].psy:
				return "Выбрано %d из %d" % [c.psy.size(), D.AGES[c.age].psy]
		8:
			if c.main.size() != G.main_count(c):
				return "Выбрано %d из %d" % [c.main.size(), G.main_count(c)]
		9:
			if approve == null or not (approve.text.strip_edges().to_upper() in ["О", "O"]):
				return "Ожидается подпись «О»"
	return ""


func _next() -> void:
	if _valid() != "":
		return
	if step == STEPS.size() - 1:
		c.callsign = c.callsign.strip_edges()
		if c.name.strip_edges() == "":
			c.name = c.callsign
		G.start_game(c)
		G.main().show_world("caldera", "start")
		return
	step += 1
	_build()


func _back() -> void:
	if step == 0:
		G.main().show_title()
		return
	step -= 1
	_build()


# ---------- тексты ----------

func _mods_text(m: Array) -> String:
	var parts: Array = []
	for i in 8:
		if m[i] != 0:
			var col := Pal.hex(Pal.G5) if m[i] > 0 else Pal.hex(Pal.R3)
			var v: String = ("%+d" % m[i]) if float(m[i]) == floorf(m[i]) else ("%+.1f" % m[i])
			parts.append("[color=%s]%s %s[/color]" % [col, D.KEYS[i], v])
	if parts.is_empty():
		return "[color=%s]Без изменений[/color]" % Pal.hex(Pal.G2)
	return "  ".join(parts)


func _trait_info(t: String, m: Array) -> String:
	return "[color=%s]%s[/color]\n\n%s\n\n[color=%s]Наведите на характеристику справа, чтобы прочесть, за что она отвечает.[/color]" % [
		Pal.hex(Pal.G4), D.TRAIT_DESC.get(t, ""), _mods_text(m), Pal.hex(Pal.G2)]


## Наведение на строку листа справа: описание характеристики, показателя, свойства или черты.
func _on_meta(meta) -> void:
	desc.text = info_for(str(meta))


static func info_for(key: String) -> String:
	if D.STAT_DESC.has(key):
		return "[b]%s[/b]\n%s" % [key, D.STAT_DESC[key]]
	if D.PERK_DESC.has(key):
		return "[b]%s[/b]\n%s" % [key, D.PERK_DESC[key]]
	if D.TRAIT_DESC.has(key):
		return "[b]%s[/b]\n%s" % [key, D.TRAIT_DESC[key]]
	if key == "Перебросы":
		return "[b]Перебросы удачи[/b]\nБесплатные перебросы проваленной проверки: 1 + мод УДЧ / 2 в день, если мод УДЧ не отрицательный."
	if key == "Основные":
		return "[b]Бонус основных навыков[/b]\nМод УДЧ + 1, но не меньше +1. Добавляется к проверкам основных навыков."
	return ""


func _relations_text(fi: int) -> String:
	var lines: Array = ["К Вам будут относиться:"]
	var rel: Array = D.FACTIONS[fi].rel
	for j in D.FACTIONS.size():
		var v: int = rel[j]
		var word := "хорошо" if v >= 2 else ("плохо" if v <= -2 else "средне")
		var col := Pal.hex(Pal.G5) if v >= 2 else (Pal.hex(Pal.R3) if v <= -2 else Pal.hex(Pal.G3))
		lines.append("[color=%s]%s: %s (%+d)[/color]" % [col, D.FACTIONS[j].short, word, v])
	return "\n".join(lines)


func _verdict() -> String:
	var best := ""
	var worst := ""
	var bv := -99
	var wv := 99
	for k in D.ATTRS:
		var v := G.stat(k, c)
		if v > bv:
			bv = v
			best = k
		if v < wv:
			wv = v
			worst = k
	return "Позывной: %s\nИмя: %s\n%s, %s, %s\nФракция: %s\nРодом из: %s\n\nСильная сторона: %s (%s).\nСлабое место: %s (%s).\n\n«%s»" % [
		c.callsign, c.name if c.name != "" else "—", c.race, "мужчина" if c.sex == "М" else "женщина",
		c.age.to_lower(), D.FACTIONS[c.faction].short, c.birth, best, D.grade(bv), worst, D.grade(wv),
		c.motive if c.motive != "" else "Без ключевой фразы"]


func _refresh() -> void:
	var v := _valid()
	next_btn.disabled = v != ""
	next_btn.text = "ПРИНЯТЬ" if step == STEPS.size() - 1 else "ДАЛЕЕ >"
	counter.text = v
	counter.add_theme_color_override("font_color", Pal.R3 if v != "" else Pal.G4)
	portrait.texture = Art.portrait_tex(G.look(c))
	sheet.text = _sheet_text()


func _sheet_text() -> String:
	return sheet_text(c, true)


## Лист Гения с наводимыми строками (общий для анкеты и пейджера).
static func sheet_text(ch: Dictionary, creating: bool) -> String:
	var s := "[b]ЛИЧНАЯ КАРТА ГЕНИЯ[/b]\n" if creating else ""
	if creating:
		s += "%s  ·  %s\n" % [ch.callsign if ch.callsign != "" else "без позывного", D.FACTIONS[ch.faction].short]
	s += "[url=ООЗ][color=%s]ООЗ[/color][/url] %d   [url=ООР][color=%s]ООР[/color][/url] %d\n" % [Pal.hex(Pal.R3), G.max_hp(ch), Pal.hex(Pal.G5), G.max_mind(ch)]
	s += "[url=Воля]Воля[/url] %d  [url=Внимание]Внимание[/url] %d  [url=Уклонение]Уклон.[/url] %d\n" % [G.max_will(ch), G.speed(ch), G.evasion(ch)]
	s += "[url=Основные]Бонус основных[/url] +%d  [url=Перебросы]Перебросы[/url] %d/день\n\n" % [G.main_bonus(ch), maxi(0, (1 + floori(G.mod("УДЧ", ch) / 2.0)) if G.mod("УДЧ", ch) >= 0 else 0)]
	for k in D.ATTRS:
		var val := G.stat(k, ch)
		var m := D.check_mod(val)
		var col := Pal.hex(Pal.G5) if m > 0 else (Pal.hex(Pal.R3) if m < 0 else Pal.hex(Pal.G4))
		s += "[url=%s][color=%s]%s %2d  мод %+d  %s[/color][/url]\n" % [k, col, k, val, m, D.grade(val)]
	var pk := G.perks(ch)
	if pk.size() > 0:
		var parts: Array = []
		for x in pk:
			var good: bool = x in ["Тяжеловес", "Эрудит", "Чуткий", "Ловкач", "Вожак", "Везунчик"]
			var cause: Array = G.perk_cause(x, ch) if not creating else []
			var why := " (постсмертие: %s)" % ", ".join(cause) if cause.size() > 0 else ""
			parts.append("[url=%s][color=%s]%s%s[/color][/url]" % [x, Pal.hex(Pal.G5) if good else Pal.hex(Pal.R3), x, why])
		s += "\n[color=%s]Свойства:[/color] %s\n" % [Pal.hex(Pal.G3), ", ".join(parts)]
	var tr: Array = []
	for t in ch.phys + ch.psy:
		tr.append("[url=%s]%s[/url]" % [t, t])
	s += "\n[color=%s]Черты:[/color] %s\n" % [Pal.hex(Pal.G3), ", ".join(tr) if tr.size() > 0 else "—"]
	if creating:
		s += "[color=%s]Основные навыки:[/color] %s" % [Pal.hex(Pal.G3), ", ".join(ch.main) if ch.main.size() > 0 else "—"]
	return s
