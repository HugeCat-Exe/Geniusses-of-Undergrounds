extends Control
## Сцена-новелла: крупный портрет, печатающийся текст, выборы с проверками навыков.

const Story := preload("res://scripts/story.gd")
const Maps := preload("res://scripts/maps.gd")
const Live := preload("res://scripts/live.gd")
const StoryVB := preload("res://scripts/story_vb.gd")

var on_close: Callable
var nodes: Dictionary
var after: Array = []
var closed := false
var portrait: TextureRect
var pframe: Panel
var name_label: Label
var rel_label: RichTextLabel
var text: RichTextLabel
var text_panel: PanelContainer
var choices: VBoxContainer
var choice_panel: PanelContainer
var chars := 0.0
var current_who := ""
var current_id := ""
var injury_result := ""
var cure_result := ""
## Первый узел разговора: здесь звучит голос черты и появляются её реплики.
var first_id := ""
var voice: Dictionary = {}
var voice_checked := false
var remark_done := false
var gift_back := ""


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
	var head := HBoxContainer.new()
	tv.add_child(head)
	name_label = Pal.label("", Pal.G5, 11, true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	rel_label = Pal.rich("", 9)
	rel_label.custom_minimum_size = Vector2(190, 0)
	rel_label.fit_content = true
	head.add_child(rel_label)
	text = Pal.rich("", 10)
	text.fit_content = false
	text.scroll_active = true
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tv.add_child(text)
	text_panel.gui_input.connect(_on_text_click)

	choice_panel = PanelContainer.new()
	add_child(choice_panel)
	var csc := ScrollContainer.new()
	csc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	choice_panel.add_child(csc)
	choices = VBoxContainer.new()
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	csc.add_child(choices)


func start(id: String) -> void:
	nodes = Story.nodes()
	nodes.merge(G.temp_nodes, true)
	first_id = id
	# с Барбарис рядом жители сперва спрашивают, что это за существо (каждый – один раз)
	var who0: String = str(nodes.get(id, {}).get("who", ""))
	if who0 == "" and nodes.get(id, {}).has("route"):
		who0 = _route_who(id)
	if G.p.get("companion", "") == "barbaris" and who0 != "" and not (who0 in NO_ASK) and not G.flag("ask_barb_" + who0):
		G.set_flag("ask_barb_" + who0)
		for k in ["vb_ask_barb", "vb_ask_barb_pack", "vb_ask_barb_friend"]:
			nodes[k] = nodes[k].duplicate(true)
			nodes[k].who = who0
		nodes.vb_ask_barb_pack.choices[0].next = id
		nodes.vb_ask_barb_friend.choices[0].next = id
		# приветствие, «Осмотреть» и реплики черт появятся уже в самом разговоре
		_show("vb_ask_barb")
		return
	_show(id)


## Кого Барбарис не удивит: она сама, лесные, рыцари (их уже нет), безымянные.
const NO_ASK := ["barbaris", "stranger", "berberis", "tauros", "ursuz", "ankvila", "raider", "wounded"]


## Ветка маршрута: все условия до последнего элемента (узла) должны выполняться.
func _route_ok(r: Array) -> bool:
	for i in r.size() - 1:
		if not _cond(r[i]):
			return false
	return true


func _route_who(id: String) -> String:
	for r in nodes[id].route:
		var nid: String = r[r.size() - 1]
		if _route_ok(r):
			return str(nodes.get(nid, {}).get("who", ""))
	return ""


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
			if _route_ok(r):
				_show(r[r.size() - 1])
				return
	_fx(n.get("fx", []))
	if closed:
		return
	current_id = id
	current_who = n.get("who", "")
	# писк пейджера: собеседник говорит что-то новое
	if current_who != "":
		Sfx.play("notify", 0.7)
	if current_who != "":
		var who: Dictionary = Story.WHO[current_who]
		name_label.text = who.name
		rel_label.text = _rel_text(current_who) if who.get("rel", false) else ""
		var pic := Art.who_portrait(current_who)
		if pic.get_width() >= 100:
			# картинка 112x112: растянута до ширины рамки
			portrait.texture = pic
			portrait.scale = Vector2(144.0 / 112.0, 144.0 / 112.0)
			portrait.position = Vector2(16, 40)
		else:
			portrait.texture = pic
			portrait.scale = Vector2(3, 3)
			portrait.position = Vector2(16, 28)
		_layout(true)
	else:
		name_label.text = ""
		rel_label.text = ""
		_layout(false)
	text.text = _board_text() if n.get("board", false) else _subst(n.get("text", ""))
	if n.has("craft"):
		text.text += _craft_text(n.craft)
	text.visible_characters = 0
	chars = 0.0
	_clear_choices()
	var i := 1
	var own: Array = n.get("choices", [])
	var list: Array = _dynamic_choices(n)
	var live: Array = []
	# «Живые черты»: голос в начале разговора и свои реплики черт.
	if current_who != "" and id == first_id and Story.WHO[current_who].get("rel", false):
		var gr := G.rel_greeting(current_who, Story.WHO[current_who].name, Story.WHO[current_who].get("fem", false))
		if gr != "":
			text.text = "[color=%s][i]%s[/i][/color]\n\n" % [Pal.hex(Pal.G3), gr] + text.text
	if current_who != "" and current_who != "raider" and id == first_id and not voice_checked:
		text.text = _opening(current_who) + text.text
	if current_who != "" and current_who != "raider" and id == first_id:
		if not voice_checked:
			voice_checked = true
			voice = Live.pick_voice(current_who)
		if not voice.is_empty():
			text.text += "\n\n[color=%s][%s][/color] [i]%s[/i]" % [Pal.hex(Pal.R3), voice.trait, voice.line]
			live.append({"t": "[%s] Последовать подсказке" % voice.trait, "live": ["voice", voice.trait]})
		elif not remark_done:
			remark_done = true
			var rm := Live.pick_remark(current_who)
			if not rm.is_empty():
				text.text += "\n\n[color=%s][%s][/color] [i][color=%s]%s[/color][/i]" % [Pal.hex(Pal.R3), rm.trait, Pal.hex(Pal.G3), rm.line]
	if current_who != "" and (id == first_id or n.get("hub", false)) and Story.LOOK.has(current_who) and G.flag("look_" + current_who):
		nodes["look_" + current_who] = {"who": current_who, "text": "[i]%s[/i]" % Story.LOOK[current_who], "choices": [{"t": "Вернуться к разговору", "next": id}]}
		live.append({"t": "Осмотреть", "next": "look_" + current_who})
	if current_who != "" and current_who != "raider" and (id == first_id or n.get("hub", false)):
		var acts := Live.acts_for(current_who)
		for tr in acts.slice(0, 2):
			var at: String = Live.ACTS[tr].t
			if tr == "Рыжие волосы" and current_who == "ryzhaya":
				at = "«Рыжий рыжего видит». Подмигнуть."
			live.append({"t": "[%s] %s" % [tr, Live.gender(at, current_who)], "live": ["act", tr]})
	# Реплики черт встают перед последним вариантом узла (обычно это «уйти»).
	if own.size() > 0:
		list += own.slice(0, own.size() - 1) + live + own.slice(own.size() - 1)
	else:
		list += live
	for ch in list:
		if ch.has("if") and not _cond(ch["if"]):
			continue
		if _hidden_by_trait(ch):
			continue
		var label := "%d. %s" % [i, _subst(ch.t)]
		if ch.has("check"):
			# «[Медицина] Это не яд, это аллергия · 65%»: навык впереди, шанс в конце
			var dc := _dc(ch.check[1], ch.check[0])
			var body := _subst(ch.t)
			if body.begins_with("[%s]" % ch.check[0]):
				body = body.substr(ch.check[0].length() + 2).strip_edges()
			label = "%d. [%s] %s · %d%%" % [i, ch.check[0], body, G.chance(G.skill_bonus(ch.check[0]), dc)]
		_add_choice(label, _choose.bind(ch))
		i += 1
	if i == 1:
		_add_choice("1. Далее", _show.bind(n.get("next", "end")))


## Ночью у жителей другое настроение.
const NIGHT_MOOD := {
	"guard": "Страж зевает в кулак и светит фонарём Вам в лицо дольше, чем нужно.",
	"beggar": "Тимоха греет руки над жаровней и говорит тише обычного, будто боится разбудить ярус.",
	"smoker": "Лёва уже не курит у лестницы, а пьёт в «Клыке». Глаза мутные, язык развязался.",
	"ian": "Ян сидит у стойки, крутит пустой стакан и явно не торопится домой.",
	"trader": "Бартоломей считает выручку при свете огарка и недоволен, что его отвлекают.",
	"gunsmith": "Сава чистит ствол при лампе. Ночью он говорит меньше и злее.",
	"surgeon": "Кост не спит: под глазами тени, на халате свежие пятна. Ночью к нему приходят с самым страшным.",
	"cook": "Грета домывает котёл. Ночью она мягче: остатки похлёбки всё равно пропадут.",
	"bartender": "Ночью в «Клыке» людно и душно. Гарри отвечает через плечо, разливая сразу на троих.",
	"ryzhaya": "Ночью, глядя на Рыжую, Вы испытываете иные чувства. Она движется чуть быстрее, чем Вы успеваете заметить. То ли это Ваша усталость, то ли навыки ночного хищника.",
	"old": "Ефим не спит. Говорит, что ночью Подземка слышна лучше.",
	"mistel": "Ода выглядывает из-за двери в накинутом пальто. Видно, что Вы её разбудили.",
	"patrol": "Дана в ночном обходе: дубинка в руке, фонарь на плече, взгляд по углам. Ночью она говорит тише и чуть медленнее.",
	"miron": "Мирон сидит у жаровни с кружкой. Ночью он вспоминает молодость охотнее.",
	"pip": "Пип ночью не прячется: шныряет у жаровни и шепчет, кто куда пошёл.",
	"librarian": "Феликс читает при огарке и откладывает книгу неохотно.",
	"taxi": "Артир дремлет за рулём и просыпается, только когда Вы стучите по крыше.",
	"wanderer": "Торговец громко зевает.\n\n– А, Гений, заходи, товары на любой вкус и цвет.",
	"stranger": "Лесник наслаждается ночной прохладой и влажностью леса. Ветка под Вашими ногами ломается, и он приоткрывает глаза.",
	"kid": "Девочка-крысолюд трёт глаза и иногда зевает.",
}
## Днём – своё настроение (у кого есть).
const DAY_MOOD := {
	"wanderer": "– Смотри, кого принесло! Гений! Заходи, покупай, Су не жалей!",
	"stranger": "Лесник собирает грибы, приподнимая листья тросточкой. Вы прерываете его поиски.",
	"patrol": "Дана стоит у перил прямо, как на смотре, и следит за шахтой.",
}

## Как жители относятся к Гению из-за его фракции (D.FACTIONS[...].rel).
func _faction_line(who: String) -> String:
	var w: Dictionary = Story.WHO[who]
	if not w.has("faction") or w.get("bond", false):
		return ""
	var key := "fg_" + who
	if int(G.p.flags.get(key, 0)) == int(G.p.day):
		return ""
	G.p.flags[key] = int(G.p.day)
	var r := G.relation(w.faction)
	var mine: String = D.FACTIONS[G.p.faction].short
	var theirs: String = D.FACTIONS[w.faction].short
	var nm: String = str(w.name).get_slice(",", 0)
	var fem: bool = w.get("fem", false)
	if r <= -3:
		return "%s замечает нашивку «%s» и каменеет лицом. %s и ваши не ладят давно. Цены и разговор будут жёстче." % [nm, mine, theirs]
	if r <= -1:
		return "%s скользит взглядом по нашивке «%s» и держится настороженно: у %s к вашим счёты." % [nm, mine, theirs]
	if r >= 4:
		return "%s видит нашивку «%s» и заметно теплеет: %s с вашими давно заодно." % [nm, mine, theirs]
	if r >= 2:
		return "%s кивает на Вашу нашивку «%s»: %s таких уважают." % [nm, mine, theirs]
	return ""


## Начало разговора: отношение фракции, ночное настроение, трещины в рассудке.
func _opening(who: String) -> String:
	var res := ""
	# при первой встрече – внешность; потом её можно «Осмотреть»
	if Story.LOOK.has(who) and not G.flag("look_" + who):
		G.set_flag("look_" + who)
		if who != "ryzhaya":
			res += "[color=%s][i]%s[/i][/color]\n\n" % [Pal.hex(Pal.G4), Story.LOOK[who]]
	var fl := _faction_line(who)
	if fl != "":
		var r := G.relation(Story.WHO[who].faction)
		res += "[color=%s][i]%s[/i][/color]\n\n" % [Pal.hex(Pal.R3 if r < 0 else Pal.G4), fl]
	if G.is_night() and NIGHT_MOOD.has(who):
		res += "[color=%s][i]%s[/i][/color]\n\n" % [Pal.hex(Pal.G3), NIGHT_MOOD[who]]
	elif not G.is_night() and DAY_MOOD.has(who):
		res += "[color=%s][i]%s[/i][/color]\n\n" % [Pal.hex(Pal.G3), DAY_MOOD[who]]
	var ml := Live.mind_line(who)
	if ml != "" and randf() < 0.6:
		res += "[color=%s][Рассудок %d][/color] [i]%s[/i]\n\n" % [Pal.hex(Pal.R2), int(G.p.mind), ml]
	return res


## Отношение собеседника к Гению: название ступени и полоска до следующей.
func _rel_text(who: String) -> String:
	var t := G.rel_tier(who)
	var col: Color = Pal.R3 if t.idx < 0 else (Pal.G3 if t.idx == 0 else Pal.G5)
	var bar := ""
	if t.next > 0:
		var lo: int = 0
		for tier in D.REL_TIERS:
			if t.pts >= tier[0]:
				lo = maxi(tier[0], -30)
		var f := clampi(int(6.0 * (t.pts - lo) / maxf(1.0, t.next - lo)), 0, 6)
		bar = " " + "▮".repeat(f) + "▯".repeat(6 - f)
	return "[right][color=%s]Отношение: %s%s[/color][/right]" % [Pal.hex(col), t.name, bar]


## Выборы, которые зависят от состояния игры: сдача подработок, поиски, объявления.
func _dynamic_choices(n: Dictionary) -> Array:
	var res: Array = []
	if n.get("hub", false) and current_who != "" and G.can_gift(current_who):
		gift_back = current_id
		var gl: Array = []
		for it in G.sort_items(G.gifts_owned(current_who)):
			gl.append({"t": "Подарить: %s" % it, "fx": [["gift", current_who, it]], "next": "gift_result"})
		gl.append({"t": "Передумать", "next": current_id})
		nodes["gift_pick"] = {"who": current_who, "text": "[color=%s]Что подарить? Подарок можно сделать раз в день. Не всем нравится одно и то же: кому-то по душе полезные мелочи, кому-то украшения.[/color]" % Pal.hex(Pal.G3), "choices": gl}
		res.append({"t": "Подарить подарок…", "next": "gift_pick"})
	if n.get("hub", false) and current_who != "":
		for j in G.p.jobs:
			if j.giver == current_who and j.state == "done":
				res.append({"t": "Сдать: %s%s" % [j.title, (" (+%d Су)" % j.su) if j.su > 0 else ""],
					"fx": [["turn_in", j.id]], "next": "thanks_" + current_who if nodes.has("thanks_" + current_who) else current_id})
	if n.has("cure"):
		var psy: bool = n.cure == "psy"
		var list: Array = G.p.got_psy if psy else G.p.got_phys
		var cost := 350 if psy else G.autodoc_cure_price()
		var used := G.flag("cure_%s_%d" % [n.cure, G.p.day])
		for tr in list:
			var t := "%s «%s» (%d Су)" % ["Вынуть из головы" if psy else "Реконструкция:", tr, cost]
			if not psy and G.perks_from(tr).size() > 0:
				t = "Реконструкция: «%s», уйдёт «%s» (%d Су)" % [tr, ", ".join(G.perks_from(tr)), cost]
			if used:
				res.append({"t": t + " – только завтра", "next": current_id})
			elif G.p.su >= cost:
				res.append({"t": t, "fx": [["cure", n.cure, tr]], "next": "stranger_cure_result" if psy else "cure_result"})
			else:
				res.append({"t": t + " – не хватает Су", "next": current_id})
		if not psy:
			_autodoc_why(res)
	if n.has("poi"):
		for j in G.p.jobs:
			if j.kind == "find" and j.poi == n.poi and j.state == "active" and not j.get("spot", false):
				var risk: String = " (там %s)" % D.ENEMIES[j.guard].name.to_lower() if j.guard != "" else ""
				res.append({"t": "Искать: %s%s" % [j.item, risk], "fx": [["find_job", j.id]], "next": "end"})
	if n.get("board", false):
		for j in G.p.jobs:
			if j.giver == "board" and j.state == "done":
				res.append({"t": "Получить оплату: %s (+%d Су)" % [j.title, j.su], "fx": [["turn_in", j.id]], "next": "board"})
		if G.p.quests.get("dogs", "") == "done":
			res.append({"t": "Получить 90 Су за заказ №117", "fx": [["su", 90], ["quest", "dogs", "closed"]], "next": "board"})
		for o in G.board_offers():
			var who := G.giver_name(o.giver)
			res.append({"t": "Взять: %s – %s (%d Су)" % [o.title, who, o.su], "fx": [["take_offer", o]], "next": "board"})
		for sp in G.special_offers():
			if sp[0] != null:
				res.append({"t": "★ Особое: %s (%d Су)" % [sp[0].title, sp[0].su], "fx": [["take_offer", sp[0]]], "next": "board"})
	if n.has("craft"):
		var list: Array = D.CRAFT[n.craft]
		for i in list.size():
			if G.craft_can(list[i]):
				res.append({"t": "Сделать: %s" % list[i][0], "fx": [["craft", n.craft, i]], "next": current_id})
	return res


func _craft_text(giver: String) -> String:
	var s := ""
	for r in D.CRAFT[giver]:
		var ok: bool = G.craft_can(r)
		s += "\n[color=%s]%s[/color] – %s" % [Pal.hex(Pal.G5 if ok else Pal.G2), r[0], G.craft_need(r)]
	return s


func _board_text() -> String:
	var s := "ЭКРАН ЗАДАНИЙ ИНСТИТУТА · УЗЕЛ КАЛЬДЕРА\nЗелёные строки ползут по треснувшему стеклу. Регулярные заказы обновляются каждый день.\n\n[color=%s][b]РЕГУЛЯРНЫЕ ЗАДАНИЯ[/b][/color]" % Pal.hex(Pal.G4)
	var offers := G.board_offers()
	if offers.is_empty():
		s += "\nСегодня всё разобрали. Загляните завтра."
	for o in offers:
		s += "\n[color=%s]%s[/color] – %s" % [Pal.hex(Pal.G5), o.title, o.text]
	s += "\n\n[color=%s][b]★ ОСОБЫЕ ЗАДАНИЯ[/b][/color]" % Pal.hex(Pal.R3)
	var sps := G.special_offers()
	var shown := 0
	for sp in sps:
		if sp[0] != null:
			s += "\n[color=%s]%s[/color] – %s" % [Pal.hex(Pal.G5), sp[0].title, sp[0].text]
			shown += 1
		else:
			s += "\n[color=%s][ДОСТУП ЗАКРЫТ] %s[/color]" % [Pal.hex(Pal.G2), sp[1]]
			shown += 1
	if shown == 0:
		s += "\nНа сегодня особых заданий нет."
	var mine := 0
	for j in G.p.jobs:
		mine += 1
	if mine > 0:
		s += "\n\n[color=%s]Ваших подработок: %d. Подробности – в пейджере, вкладка «Задачи».[/color]" % [Pal.hex(Pal.G3), mine]
	return s


func _clear_choices() -> void:
	for c in choices.get_children():
		c.queue_free()


func _add_choice(label: String, cb: Callable) -> void:
	var b := Pal.button(label, cb, 9)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# Длинные реплики переносятся на вторую строку, а не обрезаются: шанс успеха всегда виден.
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Кнопка с переносом сама не растёт в высоту: считаем строки по ширине панели.
	var per_line := maxi(20, int((choice_panel.size.x - 28) / 5.5))
	var lines := ceili(label.length() / float(per_line))
	b.custom_minimum_size = Vector2(200, 8 + 12 * lines)
	choices.add_child(b)


## Сдвиг сложностей под шкалу Б+В: модификаторы стали крупнее, проверки – на 2 строже.
const DC_SHIFT := 2


## Сложность с поправкой на отношение фракции говорящего к Гению.
func _dc(base: int, skill: String = "") -> int:
	base += DC_SHIFT
	if skill in ["История", "Медицина", "Сефиры"] and G.has_perk("Простак"):
		base += 3
	if current_who != "" and Story.WHO[current_who].has("faction"):
		var personal: int = G.rel_tier(current_who).idx if Story.WHO[current_who].get("rel", false) else 0
		return clampi(base - G.relation(Story.WHO[current_who].faction) - personal, 2, 30)
	return base


## Черты закрывают часть реплик: страшному не до дружбы, глупому не до науки, невозмутимому не до флирта.
func _hidden_by_trait(ch: Dictionary) -> bool:
	var skill: String = ch.check[0] if ch.has("check") else ""
	if skill == "Дружелюбие" and Live.has("Страшный человек"):
		return true
	if skill in ["История", "Сефиры", "Медицина"] and Live.has("Глупость"):
		return true
	if "[Флирт]" in str(ch.get("t", "")) and Live.has("Невозмутимость"):
		return true
	return false


func _scroll_text_end() -> void:
	await get_tree().process_frame
	text.scroll_to_line(maxi(0, text.get_line_count() - 1))


func _live(ch: Dictionary) -> void:
	var kind: String = ch.live[0]
	var tr: String = ch.live[1]
	var res := Live.resolve(kind, tr, current_who)
	if kind == "voice":
		voice = {}
	text.text += "\n\n" + res
	text.visible_characters = -1
	_scroll_text_end.call_deferred()
	if current_who != "" and Story.WHO[current_who].get("rel", false):
		rel_label.text = _rel_text(current_who)
	_clear_choices()
	_add_choice("1. Далее", _show.bind(current_id))


func _choose(ch: Dictionary) -> void:
	if ch.has("live"):
		_live(ch)
		return
	_fx(ch.get("fx", []))
	if closed:
		return
	if ch.has("check"):
		_resolve_check(ch, G.roll(ch.check[0], _dc(ch.check[1], ch.check[0])))
		return
	_show(ch.get("next", "end"))


func _resolve_check(ch: Dictionary, r: Dictionary) -> void:
	var col := Pal.hex(Pal.G5) if r.ok else Pal.hex(Pal.R3)
	text.text += "\n\n[color=%s]%s[/color]" % [col, G.roll_text(r)]
	text.visible_characters = -1
	_scroll_text_end.call_deferred()
	_clear_choices()
	if r.ok:
		_fx(ch.get("ok_fx", []))
		_add_choice("1. Далее", _show.bind(ch.get("ok", ch.get("next", "end"))))
	else:
		var i := 1
		if G.luck_left() > 0:
			_add_choice("%d. [Удача] Бесплатный переброс (сегодня осталось %d)" % [i, G.luck_left()], _luck_reroll.bind(ch))
			i += 1
		if G.p.will >= 3:
			_add_choice("%d. Переброс за 3 Воли (осталось %d)" % [i, G.p.will], _reroll.bind(ch))
			i += 1
		_add_choice("%d. Принять провал" % i, _fail.bind(ch))


func _luck_reroll(ch: Dictionary) -> void:
	G.use_luck()
	_resolve_check(ch, G.roll(ch.check[0], _dc(ch.check[1], ch.check[0])))


func _reroll(ch: Dictionary) -> void:
	G.p.will -= 3
	G.changed.emit()
	_resolve_check(ch, G.roll(ch.check[0], _dc(ch.check[1], ch.check[0])))


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
	G.refresh_world.call_deferred()


# ---------- условия и эффекты ----------

func _cond(c: String) -> bool:
	if c.begins_with("!"):
		return not _cond(c.substr(1))
	if c.begins_with("vb:"):
		return StoryVB.cond(c.substr(3))
	if c.begins_with("su>="):
		return G.p.su >= int(c.substr(4))
	if c.begins_with("has:"):
		return G.has(c.substr(4))
	if c.begins_with("flag:"):
		return G.flag(c.substr(5))
	if c.begins_with("job:"):
		return G.job_by_id(c.substr(4)) != null
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
			return G.p.got_phys.size() > 0 and G.p.su >= 1600
		"old_stone":
			return G.rel_tier("old").idx >= 1
		"prayed_today":
			return int(G.p.flags.get("pray_day", -1)) == G.p.day
		"river_today":
			return int(G.p.flags.get("river_day", -1)) == G.p.day
		"den_today":
			return int(G.p.flags.get("den_day", -1)) == G.p.day
		"doc_hurt":
			return G.p.hp < G.max_hp() and G.p.su >= _doc_cost()
		"companion":
			return G.p.get("companion", "") == "ryzhaya"
		"dn_job_active":
			for j in G.p.jobs:
				if j.giver == "patrol":
					return true
			return false
		"dn_round":
			return not G.flag("dn_round_done") and int(G.p.flags.get("dn_round_day", -1)) != G.p.day
		"dn_tag_day":
			if G.flag("dn_tag_given") or int(G.p.flags.get("dana_errands", 0)) < 1 or _cond("dn_job_active"):
				return false
			return hash(str(G.p.seed) + "dntag" + str(G.p.day)) % 2 == 0
		"dn_test_ready":
			return int(G.p.flags.get("dana_errands", 0)) >= 2 and not G.flag("dn_test_done") \
				and int(G.p.flags.get("dn_test_day", -1)) != G.p.day
		"dn_home_chat":
			return G.p.map == "caldera_danahome" and not G.flag("dn_home_chat")
		"ry_job_active":
			for j in G.p.jobs:
				if j.giver == "ryzhaya":
					return true
			return false
		"ry_earring_day":
			if G.flag("ry_earring_given") or int(G.p.flags.get("ry_errands", 0)) < 1 or _cond("ry_job_active"):
				return false
			return hash(str(G.p.seed) + "ear" + str(G.p.day)) % 2 == 0
		"ry_test_ready":
			return int(G.p.flags.get("ry_errands", 0)) >= 2 and not G.flag("ry_test_done") \
				and int(G.p.flags.get("ry_test_day", -1)) != G.p.day
	if c == "rumor_today":
		return int(G.p.flags.get("rumor_day", -1)) == G.p.day
	if c == "spice_ready":
		return G.spice_ready()
	if c == "spice_all":
		return G.p.quests.get("spice", "") == "active" and G.spice_herbs() == 3
	if c.begins_with("comp:"):
		return G.p.get("companion", "") == c.substr(5)
	if c.begins_with("today:"):
		return int(G.p.flags.get(c.substr(6), -1)) == G.p.day
	if c.begins_with("raid_taken:"):
		return G.flag(G.raid_key(c.substr(11)))
	if c.begins_with("mini:"):
		return G.mini_done(c.substr(5))
	if c == "dana_home_now":
		return preload("res://scripts/sched.gd").at_home("patrol", "caldera_danahome")
	if c == "ry_home_today":
		return G.ry_home_today()
	if c == "ry_home_chat":
		return G.p.map == "caldera_ryhome" and not G.flag("ry_home_chat")
	if c.begins_with("floor:"):
		return G.p.map == "caldera" + c.substr(6)
	if c.begins_with("dn_errands>="):
		return int(G.p.flags.get("dana_errands", 0)) >= int(c.substr(12))
	if c.begins_with("dn_errands="):
		return int(G.p.flags.get("dana_errands", 0)) == int(c.substr(11))
	if c.begins_with("errands>="):
		return int(G.p.flags.get("ry_errands", 0)) >= int(c.substr(9))
	if c.begins_with("errands="):
		return int(G.p.flags.get("ry_errands", 0)) == int(c.substr(8))
	if c.begins_with("rel:"):
		var parts := c.substr(4).split(">=")
		return G.rel_points(parts[0]) >= int(parts[1])
	return false


## Снять приобретённую черту: физическую у автодока, психологическую у Лесника в лесу.
## Автодок объясняет, почему не берётся за плохие свойства постсмертия без травмы тела.
func _autodoc_why(res: Array) -> void:
	for a in D.PERKS:
		var bad: String = D.PERKS[a][1]
		if not G.has_perk(bad):
			continue
		var causes := G.perk_cause(bad)
		var body := false
		for tr in causes:
			if tr in G.p.got_phys:
				body = true
		if body:
			continue
		var why := ""
		if causes.is_empty():
			why = "«%s» – НЕ ТРАВМА. СВОЙСТВО ВРОЖДЁННОЕ: %s 4 И НИЖЕ ПО АНКЕТЕ. РЕКОНСТРУКЦИЯ НЕВОЗМОЖНА».\n\nМашина чинит только то, что сломала Пустошь. С тем, каким Гений родился, она ничего не сделает. Свойство уйдёт само, если %s станет выше 4: помогают книги и снаряжение." % [bad.to_upper(), a, a]
		else:
			why = "«%s» ВЫЗВАН ТРАВМОЙ РАССУДКА: %s. ПРОГРАММА РАБОТАЕТ ТОЛЬКО С ТЕЛОМ».\n\nТравмы рассудка автодоку не по силам. Говорят, в Запутанном лесу живёт Лесник, который умеет вынимать такое из головы. Уйдёт травма – уйдёт и «%s»." % [bad.to_upper(), ", ".join(causes).to_upper(), bad]
		var id: String = "autodoc_why_" + str(a)
		nodes[id] = {"who": "", "text": "Экран автодока мигает красным: «" + why, "choices": [{"t": "Понятно", "next": current_id}]}
		res.append({"t": "Почему не лечится «%s»?" % bad, "next": id})


func _cure(kind: String, tr: String) -> String:
	var psy := kind == "psy"
	G.set_flag("cure_%s_%d" % [kind, G.p.day])
	G.p.su -= 350 if psy else G.autodoc_cure_price()
	var res: String
	if psy:
		G.pass_hours(4)
		var r := G.roll("Воля", 12)
		if r.ok:
			G.p.got_psy.erase(tr)
			res = "%s\n\nЛесник кладёт ладони Вам на виски. Четыре часа Вы слушаете, как лес дышит. Потом что-то тонкое и холодное вытягивается из затылка, и в голове становится непривычно тихо.\n\n– Готово. Черты «%s» больше нет. Не приноси её обратно.\n\n[color=#7ff07a](Черта снята)[/color]" % [G.roll_text(r), tr]
		else:
			var m := G.hurt(15, "mind")
			res = "%s\n\nВы держитесь сколько можете, но голос внутри цепляется крепче. Лесник отнимает руки.\n\n– Не сегодня. Она вросла глубже, чем я думал. Приходи завтра.\n\n[color=#ff6650](Черта «%s» осталась, −%d ООР. Су не вернуть.)[/color]" % [G.roll_text(r), tr, m]
	else:
		if randf() < 0.65:
			G.p.flags["autodoc_cures"] = int(G.p.flags.get("autodoc_cures", 0)) + 1
			G.p.got_phys.erase(tr)
			res = "Ремни затягиваются, манипуляторы опускаются. Машина гудит, режет и шьёт час с лишним. Экран: «РЕКОНСТРУКЦИЯ ЗАВЕРШЕНА».\n\n[color=#7ff07a](Травма «%s» устранена)[/color]" % tr
		else:
			var h := G.hurt(20, "body")
			G.p.hp = maxi(1, G.p.hp)
			res = "Посреди программы автодок дёргается и замирает. Экран: «ОШИБКА 0x3F. ОБРАТИТЕСЬ К СПЕЦИАЛИСТУ». Манипулятор на прощание задевает живое.\n\n[color=#ff6650](Травма «%s» осталась, −%d ООЗ. Су не возвращаются.)[/color]" % [tr, h]
	G.changed.emit()
	return res


func _doc_heal() -> int:
	return ceili((G.max_hp() - G.p.hp) / 2.0)


func _doc_cost() -> int:
	return _who_price(_doc_heal())


## Цена у собеседника: отношение с ним тоже влияет.
func _who_price(base: int) -> int:
	G.shop_who = current_who
	var v := G.price(base)
	G.shop_who = ""
	return v


func _heal_cost() -> int:
	if G.flag("free_heal"):
		return 0
	return _who_price((G.max_hp() - G.p.hp) * 2)


func _subst(s: String) -> String:
	if "{vb_" in s:
		s = StoryVB.subst(s)
	return s.replace("{callsign}", G.p.callsign).replace("{faction}", D.FACTIONS[G.p.faction].name) \
		.replace("{heal_cost}", str(_heal_cost())).replace("{dogs}", str(int(G.p.flags.get("dogs", 0)))) \
		.replace("{injury_result}", injury_result).replace("{cure_result}", cure_result).replace("{doc_heal}", str(_doc_heal())).replace("{doc_cost}", str(_doc_cost())) \
		.replace("{day}", str(G.p.day)).replace("{hour}", G.clock()).replace("{loot}", G.last_note) \
		.replace("{pa}", "а" if G.p.get("sex", "М") == "Ж" else "")


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
				if true:
					G.p.got_phys.erase(tr)
					injury_result = "Кост работает молча и долго. Когда Вы приходите в себя, травмы «%s» больше нет.\n\n– Не благодари. Плати." % tr
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
				G.sleep_till_morning()
			"accept_dogs":
				G.quest("dogs", "active")
				G.say("Новая задача: убить трёх пустынных псов.")
				if int(G.p.flags.get("dogs", 0)) >= 3:
					G.quest("dogs", "done")
			"ry_steal":
				var r := G.roll("Шестое чувство", 13)
				if r.ok:
					G.set_flag("ry_noticed")
				G.p.su = maxi(0, G.p.su - 25)
				G.changed.emit()
				if not r.ok:
					G.say("Пейджер тихо пискнул. Баланс почему-то стал меньше на 25 Су.")
			"taxi":
				# Артир везёт в любое уже знакомое место: открываем карту мира в режиме поездки
				G.set_flag("taxi_ride")
				G.p["map_at"] = "caldera"
				after.append(func(): G.main().show_map())
			"shop":
				var stock: Array = Story.SHOPS.get(f[1], []).duplicate()
				for u in D.SHOP_UNLOCKS.get(f[1], []):
					if G.flag("job_done_" + u[0]):
						stock.append(u[1])
				# в Кальдере не продают оружие мощнее 35: лучшее – крафтом или в других Подземках
				if not str(f[1]).begins_with("vb_"):
					stock = stock.filter(func(it): return D.ITEMS[it].type != "weapon" or int(D.ITEMS[it].dmg) <= D.CALDERA_MAX_DMG)
				if f[1] == "library":
					stock = G.lib_stock()
				if f[1] == "wanderer":
					stock = G.wander_left()
				var st_title: String = {"trader": "ЛАВКА БАРТОЛОМЕЯ", "medic": "МЕДПУНКТ КОСТА", "guns": "ОРУЖЕЙНАЯ САВЫ КЛИНА",
					"library": "КНИЖНЫЙ РАЗВАЛ ФЕЛИКСА", "taxi": "БАГАЖНИК ТАКСИ", "wanderer": "ТЕЛЕЖКА СТРАННИКА",
					"vb_ladlow": "ПОЛЕВАЯ КУХНЯ ЛАДЛОУ", "vb_tindal": "ЛАВКА ТИНДАЛА", "vb_ferro": "ОРУЖЕЙНАЯ ФЕРРО"}.get(f[1], "ЛАВКА")
				var owner: String = {"trader": "trader", "medic": "surgeon", "guns": "gunsmith", "library": "librarian", "taxi": "taxi", "wanderer": "wanderer",
					"vb_ladlow": "ladlow", "vb_tindal": "tindal", "vb_ferro": "ferro"}.get(f[1], "")
				after.append(func(): G.main().open_shop(stock, st_title, owner))
			"fight":
				after.append(func(): G.main().world.fight_current())
			"spare":
				if G.main().world:
					G.main().world.spare_current()
			"at":
				G.p["map_at"] = f[1]
			"wash":
				G.p.flags["river_day"] = G.p.day
				G.p.wounds.clear()
				G.heal(15)
				G.p.mind = maxi(1, G.p.mind - 3)
				G.changed.emit()
			"goto":
				var m: String = f[1]
				if G.trait_has("Клаустрофобия") and str(G.p.map).begins_with("caldera") and m.begins_with("caldera"):
					G.p.mind = maxi(1, G.p.mind - 2)
					G.say("[Клаустрофобия] В тесной клети лифта нечем дышать: −2 ООР.")
				var sp: String = f[2]
				after.append(func(): G.main().show_world(m, sp))
			"rel":
				G.rel_add(f[1], f[2])
			"buy":
				if G.p.su >= f[2]:
					G.p.su -= f[2]
					G.add_item(f[1])
			"turn_in":
				G.turn_in(f[1])
			"take_offer":
				G.take_job(f[1])
			"dana_job":
				var dtpl: Dictionary = D.DANA_TAG if f[1] == "tag" else D.DANA_JOBS[int(f[1])]
				var rngd := RandomNumberGenerator.new()
				G.take_job(G._make_job(dtpl, rngd, "pt_%s" % str(f[1])))
			"ry_job":
				var tpl: Dictionary = D.RY_EARRING if f[1] == "earring" else D.RY_JOBS[int(f[1])]
				var rng := RandomNumberGenerator.new()
				G.take_job(G._make_job(tpl, rng, "ry_%s" % str(f[1])))
			"find_job":
				var j = G.job_by_id(f[1])
				if j != null:
					G.temp_nodes["find_ok"] = {"who": "", "text": "Вы перерываете всё вокруг и находите то, что искали: [b]%s[/b].\n\n[color=#7ff07a](Отнесите находку: %s)[/color]" % [j.item, G.giver_name(j.giver, true)],
						"choices": [{"t": "Забрать", "next": "end"}]}
					if j.guard != "":
						var jid: String = j.id
						var en: String = j.guard
						after.append(func(): G.main().battle(en, "find_ok", jid))
					else:
						G.job_found(j.id)
						var nid := "find_ok"
						after.append(func(): G.main().open_dialogue(nid))
			"battle":
				var en2: String = f[1]
				var win: String = f[2] if f.size() > 2 else ""
				after.append(func(): G.main().battle(en2, win))
			"day_flag":
				G.p.flags[f[1]] = G.p.day
			"cure":
				cure_result = _cure(f[1], f[2])
			"autodoc":
				var h := _doc_heal()
				G.p.su -= _doc_cost()
				G.heal(h)
			"companion":
				G.set_companion(f[1])
			"mark_day":
				G.p.flags[f[1]] = int(G.p.day)
			"mark":
				if not (f[1] in G.p.known):
					G.p.known.append(f[1])
					G.say("На карте отмечено: %s." % D.LOCS[f[1]].name)
			"mini_flag":
				G.set_flag("mini_%d_%s" % [int(G.p.flags.get("mini_n", 0)), f[1]])
			"mini_loot":
				G.mini_loot(f[1])
			"mini_go":
				after.append(func():
					var cur = G.main().current
					if cur and cur.has_method("go_mini"):
						cur.go_mini(f[1]))
			"ev_fight":
				after.append(func():
					var cur = G.main().current
					if cur and cur.has_method("ev_fight"):
						cur.ev_fight(f[1], int(f[2])))
			"ev_trade":
				after.append(func(): G.main().open_shop(G.wander_left(), "ОБОЗ ГАСПАРА", "wanderer"))
			"bones_pray":
				cure_result = G.bones_pray(f[1])
			"mini_skip":
				after.append(func():
					var cur = G.main().current
					if cur and cur.has_method("resume"):
						cur.resume())
			"ach_add":
				preload("res://scripts/ach.gd").add(f[1])
			"gift":
				nodes["gift_result"] = {"who": f[1], "text": G.give_gift(f[1], f[2]), "choices": [{"t": "Далее", "next": gift_back}]}
				if rel_label:
					rel_label.text = _rel_text(f[1])
			"raid_flag":
				G.set_flag(G.raid_key(f[1]))
			"rumor_loot":
				G.rumor_loot()
			"craft":
				G.craft(f[1], int(f[2]))
			"rumor":
				G.buy_rumor()
			"minigame":
				var game_id: String = f[1]
				after.append(func(): G.main().open_minigame(game_id))
			"raid_loot":
				G.raid_loot(f[1])
			"escort_start":
				G.escort_start()
				G.world_dirty = true
			"time":
				G.pass_hours(f[1])
			"special_job":
				if G.job_by_id(f[1]) == null:
					G.take_job(G._make_job(D.SPECIAL_JOBS[f[1]], RandomNumberGenerator.new(), f[1]))
			"explore_go":
				after.append(func(): G.main().explore_now())
			"vb":
				StoryVB.fx(f, self)
