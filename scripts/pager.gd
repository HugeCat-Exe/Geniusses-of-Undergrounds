extends Control
## Пейджер Института: лист Гения, имущество, задачи, журнал, сохранения.

const Creator := preload("res://scripts/creator.gd")
const TABS := ["ЛИСТ ГЕНИЯ", "ИМУЩЕСТВО", "ЗАДАЧИ", "ЖУРНАЛ", "СИСТЕМА"]
const QUESTS := {
	"med": {"title": "Груз для хирурга",
		"active": "Найти ящик с красным крестом у разбитого каравана на юго-востоке Пустоши и отнести хирургу Косту.",
		"closed": "Выполнено. Кост заплатил 150 Су и обещал бесплатное лечение."},
	"dogs": {"title": "Заказ №117",
		"active": "Убить трёх пустынных псов в Пустоши у Кальдеры. Убито: {dogs}/3.",
		"done": "Три пса убиты. Вернуться к доске заданий Института за оплатой.",
		"closed": "Выполнено. Институт перевёл 90 Су."},
}

var tab := 0
var content: VBoxContainer
var scroll: ScrollContainer
var tab_buttons: Array = []
## Строка-подсказка внизу экрана пейджера: что значит характеристика или черта под курсором.
var info: RichTextLabel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var body := Panel.new()
	body.position = Vector2(40, 14)
	body.size = Vector2(560, 332)
	body.add_theme_stylebox_override("panel", Pal.box(Pal.G0, Pal.G3, 3))
	add_child(body)
	var head := Pal.label("ПЕЙДЖЕР ИНСТИТУТА ПО ЭТИКЕ · МОДЕЛЬ Г-7", Pal.G3, 9, true)
	head.position = Vector2(54, 20)
	add_child(head)
	var led := ColorRect.new()
	led.color = Pal.R2
	led.position = Vector2(574, 24)
	led.size = Vector2(6, 6)
	add_child(led)
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(54, 36)
	add_child(tabs)
	for i in TABS.size():
		var b := Pal.button(TABS[i], _set_tab.bind(i), 9)
		b.toggle_mode = true
		tabs.add_child(b)
		tab_buttons.append(b)
	var screen := Panel.new()
	screen.position = Vector2(54, 60)
	screen.size = Vector2(532, 252)
	screen.add_theme_stylebox_override("panel", Pal.box(Pal.BG, Pal.G2, 1))
	add_child(screen)
	scroll = ScrollContainer.new()
	scroll.position = Vector2(60, 64)
	scroll.size = Vector2(522, 212)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	var line := ColorRect.new()
	line.color = Pal.G1
	line.position = Vector2(58, 278)
	line.size = Vector2(524, 1)
	add_child(line)
	info = Pal.rich("", 8)
	info.fit_content = false
	info.scroll_active = true
	info.position = Vector2(60, 280)
	info.size = Vector2(522, 30)
	add_child(info)
	var close_b := Pal.button("ЗАКРЫТЬ [Tab]", queue_free, 9)
	close_b.position = Vector2(486, 318)
	close_b.size = Vector2(100, 18)
	add_child(close_b)
	_set_tab(tab)


func _unhandled_key_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode in [KEY_TAB, KEY_ESCAPE, KEY_I]:
		queue_free()
		get_viewport().set_input_as_handled()


func _set_tab(i: int) -> void:
	tab = i
	for j in tab_buttons.size():
		tab_buttons[j].button_pressed = j == i
	for c in content.get_children():
		c.queue_free()
	scroll.scroll_vertical = 0
	info.text = "[color=%s]Наведите курсор на характеристику, показатель или черту, чтобы прочесть описание.[/color]" % Pal.hex(Pal.G2) if i == 0 else ""
	match i:
		0: _sheet()
		1: _inventory()
		2: _quests()
		3: _journal()
		4: _system()


func _sheet() -> void:
	var p := G.p
	var top := HBoxContainer.new()
	content.add_child(top)
	var pic := TextureRect.new()
	pic.texture = Art.portrait_tex(G.look())
	pic.custom_minimum_size = Vector2(84, 98)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	top.add_child(pic)
	var idt := Pal.rich("", 9)
	idt.custom_minimum_size = Vector2(186, 0)
	idt.meta_hover_started.connect(_on_meta)
	idt.text = "[b]%s[/b]\n%s\n%s · %s · %s\n%s\nРодом из: %s\n[color=%s]«%s»[/color]\n\n[url=ООЗ][color=%s]ООЗ %d/%d[/color][/url]   [url=ООР][color=%s]ООР %d/%d[/color][/url]\n[url=Воля]Воля[/url] %d/%d\n[url=Защита]Защита[/url]: физ. %d · псих. %d\nУдача: перебросов сегодня %d\nСытость %d · Су %d · День %d" % [
		p.callsign, p.name, p.race, "М" if p.sex == "М" else "Ж", p.age, D.FACTIONS[p.faction].name, p.birth,
		Pal.hex(Pal.G3), p.motive if p.motive != "" else "—",
		Pal.hex(Pal.R3), p.hp, G.max_hp(), Pal.hex(Pal.G5), p.mind, G.max_mind(),
		p.will, G.max_will(), G.phys_def(), G.psy_def(), G.luck_left(), p.food, p.su, p.day]
	top.add_child(idt)
	var stats := Pal.rich("", 9)
	stats.custom_minimum_size = Vector2(236, 0)
	stats.meta_hover_started.connect(_on_meta)
	var s := "[b]ХАРАКТЕРИСТИКИ[/b]\n" + Creator.sheet_text(p, false)
	if (p.got_phys + p.got_psy).size() > 0:
		var got: Array = []
		for t in p.got_phys + p.got_psy:
			got.append("[url=%s]%s[/url]" % [t, t])
		s += "[color=%s]Приобретённые: %s[/color]\n" % [Pal.hex(Pal.R3), ", ".join(got)]
	if p.wounds.size() > 0:
		s += "[color=%s]Раны: %s[/color]" % [Pal.hex(Pal.R3), ", ".join(p.wounds)]
	stats.text = s
	top.add_child(stats)
	content.add_child(HSeparator.new())
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	content.add_child(grid)
	for sk in D.SKILLS:
		var b := G.skill_bonus(sk[0])
		var main: bool = sk[0] in p.main
		var l := Pal.label("%s%s (%s) %+d" % ["★ " if main else "", sk[0], sk[1], b], Pal.G5 if main else Pal.G4, 9)
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		l.mouse_entered.connect(func(): info.text = "[b]%s[/b] (%s): %s%s" % [sk[0], sk[1], sk[2], "  ★ основной: +%d" % G.main_bonus() if main else ""])
		grid.add_child(l)


func _on_meta(meta) -> void:
	info.text = Creator.info_for(str(meta)).replace("\n", " ")


func _inventory() -> void:
	var p := G.p
	var w := "—"
	if p.weapon != "":
		var wi: Dictionary = D.ITEMS[p.weapon]
		w = "%s (урон %d, магазин %d/%d, %s)" % [p.weapon, wi.dmg, p.mag, wi.mag, wi.ammo]
	content.add_child(Pal.rich("[b]Огнестрел:[/b] %s\n[b]Ближний бой:[/b] %s (урон %d)\n[b]Одежда:[/b] %s (защита %d)\n[b]Капитал:[/b] %d Су" % [
		w, p.melee, D.ITEMS[p.melee].dmg, p.armor, D.ITEMS[p.armor].def if p.armor != "" else 0, p.su], 9))
	content.add_child(HSeparator.new())
	var keys: Array = p.inv.keys()
	keys.sort()
	for it in keys:
		var info: Dictionary = D.ITEMS[it]
		var row := HBoxContainer.new()
		content.add_child(row)
		var equipped: bool = it == p.weapon or it == p.melee or it == p.armor
		var l := Pal.label("%s%s ×%d" % ["● " if equipped else "", it, p.inv[it]], Pal.G5 if equipped else Pal.G4, 9)
		l.custom_minimum_size = Vector2(170, 0)
		row.add_child(l)
		var dsc := Pal.label(D.item_desc(it), Pal.G3, 8)
		dsc.custom_minimum_size = Vector2(250, 0)
		dsc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(dsc)
		var act := ""
		match info.type:
			"heal", "food", "calm": act = "Использовать"
			"armor": act = "Надеть" if not equipped else ""
			"weapon": act = "Взять" if not equipped else ""
		if act != "":
			var b := Pal.button(act, _use.bind(it), 8)
			b.custom_minimum_size = Vector2(80, 0)
			row.add_child(b)
	if p.weapon != "":
		content.add_child(Pal.button("Перезарядить %s" % p.weapon, _reload, 9))


func _use(it: String) -> void:
	G.say(G.use_item(it))
	_set_tab(1)


func _reload() -> void:
	G.say(G.reload())
	_set_tab(1)


func _quests() -> void:
	if G.p.get("companion", "") == "ryzhaya":
		content.add_child(Pal.rich("[color=%s][b]Спутница: Рыжая[/b] · отношение «%s»[/color]" % [Pal.hex(Pal.G5), G.rel_tier("ryzhaya").name], 9))
		content.add_child(HSeparator.new())
	for j in G.p.jobs:
		var prog := ""
		if j.kind == "kill":
			prog = " Прогресс: %d/%d." % [j.have, j.need]
		var st: String = "Выполнено, вернитесь к %s." % G.giver_name(j.giver, true) if j.state == "done" else "В работе." + prog
		var who := G.giver_name(j.giver)
		content.add_child(Pal.rich("[color=%s][b]%s[/b] · %s · %d Су\n%s\n%s[/color]" % [Pal.hex(Pal.G5), j.title, who, j.su, j.text, st], 9))
		content.add_child(HSeparator.new())
	if G.p.quests.is_empty() and G.p.jobs.is_empty():
		content.add_child(Pal.label("Активных задач нет. Поговорите с жителями Кальдеры\nили загляните к доске объявлений на втором ярусе.", Pal.G3, 9))
	for q in G.p.quests:
		var st: String = G.p.quests[q]
		var info: Dictionary = QUESTS.get(q, {"title": q})
		var txt: String = info.get(st, st).replace("{dogs}", str(int(G.p.flags.get("dogs", 0))))
		var col := Pal.G2 if st == "closed" else Pal.G5
		content.add_child(Pal.rich("[color=%s][b]%s[/b]\n%s[/color]" % [Pal.hex(col), info.title, txt], 9))
		content.add_child(HSeparator.new())


func _journal() -> void:
	var lines: Array = G.log_lines.duplicate()
	lines.reverse()
	var t := Pal.rich("\n".join(lines), 9)
	t.custom_minimum_size = Vector2(510, 0)
	content.add_child(t)


func _system() -> void:
	content.add_child(Pal.label("СОХРАНИТЬ", Pal.G5, 10, true))
	for i in G.SLOTS:
		content.add_child(_slot_button("Ячейка %d: %s" % [i + 1, G.slot_info(i)], _save.bind(i)))
	content.add_child(HSeparator.new())
	content.add_child(Pal.label("ЗАГРУЗИТЬ", Pal.G5, 10, true))
	for i in G.SLOTS + 1:
		var b := _slot_button("%s: %s" % [G.slot_name(i), G.slot_info(i)], _load.bind(i))
		b.disabled = not FileAccess.file_exists(G.slot_path(i))
		content.add_child(b)
	content.add_child(Pal.label("Автосохранение пишется само при входе на каждую карту и после сна.", Pal.G2, 8))
	content.add_child(HSeparator.new())
	content.add_child(Pal.label("ЭКРАН", Pal.G5, 10, true))
	content.add_child(Pal.button("Полный экран: %s  [F11]" % ("ВКЛ" if G.main().fullscreen else "ВЫКЛ"), _toggle_full, 9))
	var crt := Pal.button("Эффект старого монитора: %s" % ("ВКЛ" if G.main().crt_on else "ВЫКЛ"), _toggle_crt, 9)
	content.add_child(crt)
	content.add_child(HSeparator.new())
	content.add_child(Pal.button("Выйти в главное меню (без сохранения)", func(): G.main().show_title(), 9))
	content.add_child(Pal.button("Выйти из игры", func(): get_tree().quit(), 9))


func _slot_button(text: String, cb: Callable) -> Button:
	var b := Pal.button(text, cb, 9)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.custom_minimum_size = Vector2(500, 0)
	return b


func _toggle_full() -> void:
	G.main().set_fullscreen(not G.main().fullscreen)
	_set_tab(4)


func _save(i: int) -> void:
	G.save(i)
	_set_tab(4)


func _load(i: int) -> void:
	G.main().load_and_play(i)


func _toggle_crt() -> void:
	G.main().set_crt(not G.main().crt_on)
	_set_tab(4)
