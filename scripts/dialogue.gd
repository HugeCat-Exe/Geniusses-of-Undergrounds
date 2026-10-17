extends Control
## Сцена-новелла: крупный портрет, печатающийся текст, выборы с проверками навыков.

const Story := preload("res://scripts/story.gd")
const Maps := preload("res://scripts/maps.gd")

var on_close: Callable
var nodes: Dictionary
var after: Array = []
var closed := false
var portrait: TextureRect
var pframe: Panel
var name_label: Label
var text: RichTextLabel
var text_panel: PanelContainer
var choices: VBoxContainer
var choice_panel: PanelContainer
var chars := 0.0
var current_who := ""
var injury_result := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	pframe = Panel.new()
	pframe.position = Vector2(12, 24)
	pframe.size = Vector2(152, 176)
	add_child(pframe)
	portrait = TextureRect.new()
	portrait.position = Vector2(16, 28)
	portrait.scale = Vector2(3, 3)
	add_child(portrait)

	text_panel = PanelContainer.new()
	add_child(text_panel)
	var tv := VBoxContainer.new()
	text_panel.add_child(tv)
	name_label = Pal.label("", Pal.G5, 11, true)
	tv.add_child(name_label)
	text = Pal.rich("", 10)
	text.fit_content = false
	text.scroll_active = true
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tv.add_child(text)
	text_panel.gui_input.connect(_on_text_click)

	choice_panel = PanelContainer.new()
	add_child(choice_panel)
	choices = VBoxContainer.new()
	choice_panel.add_child(choices)


func start(id: String) -> void:
	nodes = Story.nodes()
	_show(id)


func _layout(has_portrait: bool) -> void:
	pframe.visible = has_portrait
	portrait.visible = has_portrait
	if has_portrait:
		text_panel.position = Vector2(172, 24)
		text_panel.size = Vector2(456, 176)
		choice_panel.position = Vector2(172, 206)
		choice_panel.size = Vector2(456, 140)
	else:
		text_panel.position = Vector2(60, 24)
		text_panel.size = Vector2(520, 196)
		choice_panel.position = Vector2(60, 226)
		choice_panel.size = Vector2(520, 120)


func _show(id: String) -> void:
	if closed:
		return
	if id == "end" or id == "":
		close()
		return
	var n: Dictionary = nodes[id]
	if n.has("route"):
		for r in n.route:
			if r.size() == 1 or _cond(r[0]):
				_show(r[r.size() - 1])
				return
	_fx(n.get("fx", []))
	if closed:
		return
	current_who = n.get("who", "")
	if current_who != "":
		var who: Dictionary = Story.WHO[current_who]
		var title: String = who.name
		if current_who == "emirra" and not G.flag("emirra_named"):
			title = "Рыжая незнакомка"
		name_label.text = title
		portrait.texture = Art.portrait_tex(Maps.NPC_LOOKS[current_who].portrait)
		_layout(true)
	else:
		name_label.text = ""
		_layout(false)
	text.text = _subst(n.text)
	text.visible_characters = 0
	chars = 0.0
	_clear_choices()
	var i := 1
	for ch in n.get("choices", []):
		if ch.has("if") and not _cond(ch["if"]):
			continue
		var label := "%d. %s" % [i, _subst(ch.t)]
		if ch.has("check"):
			var dc := _dc(ch.check[1])
			label += "  [%s · %d%%]" % [ch.check[0], G.chance(G.skill_bonus(ch.check[0]), dc)]
		_add_choice(label, _choose.bind(ch))
		i += 1
	if i == 1:
		_add_choice("1. Далее", _show.bind(n.get("next", "end")))


func _clear_choices() -> void:
	for c in choices.get_children():
		c.queue_free()


func _add_choice(label: String, cb: Callable) -> void:
	var b := Pal.button(label, cb, 9)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	choices.add_child(b)


## Сложность с поправкой на отношение фракции говорящего к Гению.
func _dc(base: int) -> int:
	if current_who != "" and Story.WHO[current_who].has("faction"):
		return clampi(base - G.relation(Story.WHO[current_who].faction), 2, 30)
	return base


func _choose(ch: Dictionary) -> void:
	_fx(ch.get("fx", []))
	if closed:
		return
	if ch.has("check"):
		_resolve_check(ch, G.roll(ch.check[0], _dc(ch.check[1])))
		return
	_show(ch.get("next", "end"))


func _resolve_check(ch: Dictionary, r: Dictionary) -> void:
	var col := Pal.hex(Pal.G5) if r.ok else Pal.hex(Pal.R3)
	text.text += "\n\n[color=%s]%s[/color]" % [col, G.roll_text(r)]
	text.visible_characters = -1
	_clear_choices()
	if r.ok:
		_add_choice("1. Далее", _show.bind(ch.get("ok", ch.get("next", "end"))))
	else:
		var i := 1
		if G.p.will >= 3:
			_add_choice("%d. Переброс за 3 Воли (осталось %d)" % [i, G.p.will], _reroll.bind(ch))
			i += 1
		_add_choice("%d. Принять провал" % i, _fail.bind(ch))


func _reroll(ch: Dictionary) -> void:
	G.p.will -= 3
	G.changed.emit()
	_resolve_check(ch, G.roll(ch.check[0], _dc(ch.check[1])))


func _fail(ch: Dictionary) -> void:
	_fx(ch.get("fail_fx", []))
	if closed:
		return
	if G.p.hp <= 0:
		close()
		G.main().game_over("Гений %s истёк кровью над чужим замком." % G.p.callsign)
		return
	_show(ch.get("fail", "end"))


func _on_text_click(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		text.visible_characters = -1


func _process(delta: float) -> void:
	if text.visible_characters >= 0:
		chars += delta * 90.0
		text.visible_characters = int(chars)
		if text.visible_characters >= text.get_total_character_count():
			text.visible_characters = -1


func _unhandled_key_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	if ev.keycode >= KEY_1 and ev.keycode <= KEY_9:
		var idx: int = ev.keycode - KEY_1
		var live: Array = []
		for c in choices.get_children():
			if not c.is_queued_for_deletion():
				live.append(c)
		if idx < live.size():
			live[idx].pressed.emit()
		get_viewport().set_input_as_handled()
	elif ev.keycode == KEY_SPACE or ev.keycode == KEY_ENTER:
		text.visible_characters = -1
		get_viewport().set_input_as_handled()


func close() -> void:
	if closed:
		return
	closed = true
	queue_free()
	if on_close.is_valid():
		on_close.call()
	for a in after:
		a.call_deferred()


# ---------- условия и эффекты ----------

func _cond(c: String) -> bool:
	if c.begins_with("!"):
		return not _cond(c.substr(1))
	if c.begins_with("su>="):
		return G.p.su >= int(c.substr(4))
	if c.begins_with("has:"):
		return G.has(c.substr(4))
	if c.begins_with("flag:"):
		return G.flag(c.substr(5))
	if c.begins_with("quest:"):
		var q := c.substr(6)
		if "=" in q:
			var parts := q.split("=")
			return G.p.quests.get(parts[0], "") == parts[1]
		return G.p.quests.has(q)
	match c:
		"hurt":
			return G.p.hp < G.max_hp() and G.p.su >= _heal_cost()
		"wounds":
			return G.p.wounds.size() > 0 and G.p.su >= 40
		"injury":
			return G.p.got_phys.size() > 0 and G.p.su >= 120
	return false


func _heal_cost() -> int:
	if G.flag("free_heal"):
		return 0
	return (G.max_hp() - G.p.hp) * 2


func _subst(s: String) -> String:
	return s.replace("{callsign}", G.p.callsign).replace("{faction}", D.FACTIONS[G.p.faction].name) \
		.replace("{heal_cost}", str(_heal_cost())).replace("{dogs}", str(int(G.p.flags.get("dogs", 0)))) \
		.replace("{injury_result}", injury_result)


func _fx(list: Array) -> void:
	for f in list:
		match f[0]:
			"su":
				G.p.su += f[1]
				G.changed.emit()
			"item":
				G.add_item(f[1], f[2] if f.size() > 2 else 1)
			"take":
				G.remove_item(f[1], f[2] if f.size() > 2 else 1)
			"flag":
				G.set_flag(f[1], f[2] if f.size() > 2 else true)
			"quest":
				G.quest(f[1], f[2])
			"heal":
				G.heal(f[1])
			"calm":
				G.calm(f[1])
			"mind":
				G.p.mind = maxi(1, G.p.mind + f[1])
				G.changed.emit()
			"feed":
				G.feed(f[1])
			"hurt":
				G.p.hp -= f[1]
				G.changed.emit()
			"say":
				G.say(f[1])
			"heal_full":
				G.p.su -= _heal_cost()
				G.set_flag("free_heal", false)
				G.heal(999)
			"fix_wounds":
				G.p.wounds.clear()
				G.changed.emit()
			"remove_injury":
				var tr: String = G.p.got_phys[G.p.got_phys.size() - 1]
				if randf() < 0.8:
					G.p.got_phys.erase(tr)
					injury_result = "Кост работает молча и долго. Когда вы приходите в себя, травмы «%s» больше нет.\n\n— Не благодари. Плати." % tr
				else:
					G.p.mind = maxi(1, G.p.mind - 10)
					injury_result = "Что-то идёт не так. Вы просыпаетесь посреди операции и видите свои внутренности. Травма «%s» осталась.\n\n[color=#ff6650](-10 ООР)[/color]" % tr
				G.changed.emit()
			"sleep":
				G.p.su -= 20
				G.heal(30)
				G.calm(30)
				G.p.will = G.max_will()
				G.p.food = maxi(0, G.p.food - 10)
				G.p.day += 1
				G.changed.emit()
			"accept_dogs":
				G.quest("dogs", "active")
				G.say("Новая задача: убить трёх пустынных псов.")
				if int(G.p.flags.get("dogs", 0)) >= 3:
					G.quest("dogs", "done")
			"emirra_steal":
				var r := G.roll("Шестое чувство", 13)
				if r.ok:
					G.set_flag("emirra_noticed")
				G.p.su = maxi(0, G.p.su - 25)
				G.changed.emit()
				if not r.ok:
					G.say("Кошелёк почему-то стал легче на 25 Су.")
			"shop":
				var stock: Array = Story.SHOPS[f[1]]
				after.append(func(): G.main().open_shop(stock))
			"fight":
				after.append(func(): G.main().world.fight_current())
			"spare":
				if G.main().world:
					G.main().world.spare_current()
			"goto":
				var m: String = f[1]
				var sp: String = f[2]
				after.append(func(): G.main().show_world(m, sp))
