extends Control
## Бой в духе Fear and Hunger: пошаговый, удары по частям тела, раны, рассудок, монетка.

var enemy_id: String
var on_end: Callable
var E: Dictionary
var parts: Array = []
var view: Control
var art: Dictionary
var log_box: RichTextLabel
var status: RichTextLabel
var actions: GridContainer
var hover_part := ""
var analyzed := false
## Бонус урона к следующему попаданию после успешного Анализа (+мод ВСП ×2).
var weak_spot := 0
var leader_used := false
## «Вспышки гнева»: ходы ярости, когда доступна только атака.
var rage := 0
const Live := preload("res://scripts/live.gd")
var defending := false
var busy := false
var enemy_streak := 0
var finished := false
var scale_k := 3.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	E = D.ENEMIES[enemy_id]
	for p in E.parts:
		var c: Dictionary = p.duplicate()
		c.max = p.hp
		parts.append(c)
	art = Art.enemy_art(E.sprite)

	var bg := ColorRect.new()
	bg.color = Pal.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var stripe := ColorRect.new()
	stripe.color = Pal.R1
	stripe.position = Vector2(0, 0)
	stripe.size = Vector2(640, 3)
	add_child(stripe)

	var title := Pal.label(E.name.to_upper(), Pal.R3, 14, true)
	title.position = Vector2(24, 10)
	add_child(title)
	var frame := Panel.new()
	frame.position = Vector2(20, 34)
	frame.size = Vector2(224, 206)
	add_child(frame)
	view = Control.new()
	view.position = Vector2(36, 40)
	view.size = Vector2(192, 192)
	view.draw.connect(_draw_view)
	add_child(view)

	var st_panel := PanelContainer.new()
	st_panel.position = Vector2(20, 246)
	st_panel.size = Vector2(224, 100)
	add_child(st_panel)
	status = Pal.rich("", 9)
	st_panel.add_child(status)

	var log_panel := PanelContainer.new()
	log_panel.position = Vector2(256, 34)
	log_panel.size = Vector2(372, 178)
	add_child(log_panel)
	log_box = Pal.rich("", 9)
	log_box.fit_content = false
	log_box.scroll_active = true
	log_box.scroll_following = true
	log_panel.add_child(log_box)

	var act_panel := PanelContainer.new()
	act_panel.position = Vector2(256, 218)
	act_panel.size = Vector2(372, 128)
	add_child(act_panel)
	var asc := ScrollContainer.new()
	asc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	act_panel.add_child(asc)
	actions = GridContainer.new()
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", 4)
	actions.add_theme_constant_override("v_separation", 3)
	asc.add_child(actions)

	_log("[color=%s]%s[/color]" % [Pal.hex(Pal.G3), E.intro])
	_start()


func _player_speed() -> int:
	var sp := G.speed()
	if Live.has("Дар Изгоя") and G.p.get("companion", "") == "":
		sp += maxi(0, G.mod("ВСП"))
	return sp


func _start() -> void:
	busy = true
	# «Страшный человек»: слабые твари могут сбежать ещё до драки.
	if Live.has("Страшный человек") and enemy_id in ["pes", "padal"] and randf() < 0.25:
		_log("[color=%s][Страшный человек][/color] %s встречается с вами взглядом, пятится и убегает." % [Pal.hex(Pal.R3), E.name])
		finished = true
		_update_status()
		_clear_actions()
		busy = false
		_act("Дальше", _end.bind("fled"))
		return
	if Live.has("Одержимость кровью"):
		var weak: String = ""
		var wm := 99
		for q in parts:
			if q.get("kill", false) and int(q.mod) < wm:
				wm = int(q.mod)
				weak = q.name
		_log("[color=%s][Одержимость кровью][/color] [i]Бей в «%s». Там больнее всего.[/i]" % [Pal.hex(Pal.R3), weak])
	if E.horror > 0 and Live.has("Невозмутимость"):
		_log("[color=%s][Невозмутимость][/color] Вид твари не трогает вас. Рассудок цел." % Pal.hex(Pal.G5))
	elif E.horror > 0:
		var m := G.hurt(E.horror, "mind")
		_log("[color=%s]От одного вида рассудок трещит: -%d ООР.[/color]" % [Pal.hex(Pal.R3), m])
		_check_mind()
	if G.has_perk("Чуткий"):
		_log("Вы чуете врага раньше, чем он вас («Чуткий»). Вы действуете первым.")
	elif G.has_perk("Глухой к миру") or E.speed > _player_speed():
		if G.has_perk("Глухой к миру"):
			_log("%s оказывается рядом раньше, чем вы его замечаете («Глухой к миру»)." % E.name)
		else:
			_log("%s быстрее вас (Внимание %d против %d) и атакует первым!" % [E.name, E.speed, _player_speed()])
		await _wait(0.7)
		await _enemy_turn()
	else:
		_log("Ваше Внимание выше (%d против %d). Вы действуете первым." % [_player_speed(), E.speed])
	busy = false
	_menu()


# ---------- вывод ----------

func _log(s: String) -> void:
	log_box.append_text(s + "\n")


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _bar(v: int, mx: int, n: int = 8) -> String:
	var f := clampi(ceili(float(v) / maxf(1.0, mx) * n), 0, n)
	return "█".repeat(f) + "░".repeat(n - f)


func _update_status() -> void:
	var p := G.p
	var s := "[b]%s[/b]\n" % p.callsign
	s += "[color=%s]ООЗ %s %d/%d[/color]\n" % [Pal.hex(Pal.R3), _bar(p.hp, G.max_hp()), maxi(0, p.hp), G.max_hp()]
	s += "[color=%s]ООР %s %d/%d[/color]\n" % [Pal.hex(Pal.G5), _bar(p.mind, G.max_mind()), maxi(0, p.mind), G.max_mind()]
	if p.weapon != "":
		s += "%s: %d в магазине, запас %d\n" % [p.weapon, p.mag, G.ammo_left() - p.mag]
	s += "Ближний: %s · защ. %d · уклон. %d" % [p.melee, G.phys_def(), G.evasion()]
	if p.get("companion", "") == "ryzhaya":
		s += "\n[color=%s]Рыжая рядом: стреляет сама[/color]" % Pal.hex(Pal.G5)
	if p.wounds.size() > 0:
		s += "\n[color=%s]Раны: %s[/color]" % [Pal.hex(Pal.R3), ", ".join(p.wounds)]
	status.text = s
	view.queue_redraw()


func _draw_view() -> void:
	view.draw_texture_rect(art.tex, Rect2(Vector2.ZERO, Vector2(192, 192)), false)
	for p in parts:
		var r: Rect2 = art.parts.get(p.name, Rect2())
		var rr := Rect2(r.position * scale_k, r.size * scale_k)
		if p.hp <= 0:
			view.draw_rect(rr, Color(Pal.R1, 0.45))
			view.draw_line(rr.position, rr.end, Pal.R2, 2.0)
			view.draw_line(Vector2(rr.position.x, rr.end.y), Vector2(rr.end.x, rr.position.y), Pal.R2, 2.0)
		if p.name == hover_part:
			view.draw_rect(rr, Pal.R3, false, 2.0)


func _clear_actions() -> void:
	for c in actions.get_children():
		c.queue_free()


func _act(label: String, cb: Callable, enabled := true) -> Button:
	var b := Pal.button(label, cb, 9)
	b.custom_minimum_size = Vector2(178, 18)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = not enabled or busy
	actions.add_child(b)
	return b


# ---------- ход игрока ----------

func _menu() -> void:
	_update_status()
	_clear_actions()
	hover_part = ""
	if finished:
		return
	var p := G.p
	if rage > 0:
		_act("[Ярость] Удар: %s" % p.melee, _pick_target.bind(true))
		if p.weapon != "" and p.mag > 0:
			_act("[Ярость] Выстрел: %s" % p.weapon, _pick_target.bind(false))
		return
	if p.weapon != "":
		_act("Выстрел: %s (%d)" % [p.weapon, p.mag], _pick_target.bind(false), p.mag > 0)
	else:
		_act("Выстрел: нет огнестрела", func(): pass, false)
	_act("Удар: %s" % p.melee, _pick_target.bind(true))
	var w_ok: bool = p.weapon != "" and p.mag < D.ITEMS[p.weapon].mag and G.has(D.ITEMS[p.weapon].ammo)
	_act("Перезарядка", _reload, w_ok)
	_act("Анализ [ВСП]" if not analyzed else "Анализ: проведён", _analyze, not analyzed)
	_act("Самозащита [ТЕЛ]", _defend)
	_act("Предмет", _items_menu)
	_act("Сменить оружие (бесплатно)", _weapons_menu, _spare_weapons().size() > 0)
	_act("Подбросить монетку (бежать)", _flee)


func _attack_bonus(melee: bool, part: Dictionary) -> int:
	var b := G.mod("ТЕЛ" if melee else "ЛВК") + int(part.mod)
	if analyzed:
		b += 2
	if "Руки" in G.p.wounds and not Live.has("Стоик"):
		b -= 2
	if part.name == "Глаза" and G.flag("ry_tip"):
		b += 2
	return b


func _pick_target(melee: bool) -> void:
	_clear_actions()
	for p in parts:
		if p.hp <= 0:
			continue
		var ch := G.chance(_attack_bonus(melee, p), E.evade)
		var hp_txt := "%d/%d" % [p.hp, p.max] if analyzed else _bar(p.hp, p.max, 5)
		var b := _act("%s %s · %d%%" % [p.name, hp_txt, ch], _attack.bind(melee, p))
		b.mouse_entered.connect(_set_hover.bind(p.name))
		b.mouse_exited.connect(_set_hover.bind(""))
	_act("< Назад", _menu)


func _set_hover(n: String) -> void:
	hover_part = n
	view.queue_redraw()


func _attack(melee: bool, part: Dictionary) -> void:
	busy = true
	_clear_actions()
	var p := G.p
	var wname: String = p.melee if melee else p.weapon
	var base: float = D.ITEMS[wname].dmg
	if melee:
		base += maxi(0, G.mod("ТЕЛ")) * 2
		if G.has_perk("Тяжеловес"):
			base *= 1.25
	else:
		p.mag -= 1
	var d := G.d20("hit")
	var bonus := _attack_bonus(melee, part)
	var crit_on := G.crit_from()
	var hit: bool = (d + bonus >= E.evade or d >= crit_on) and d != 1
	var misfire := d <= 2 and G.has_perk("Неуклюжий")
	if misfire:
		hit = false
	G.pity_result("hit", hit)
	var verb := "бьёте" if melee else "стреляете"
	if misfire:
		_log("[color=%s]Осечка: руки подводят («Неуклюжий»), к20=%d.[/color]" % [Pal.hex(Pal.R3), d])
	elif not hit:
		_log("Вы %s в «%s» (%s): к20=%d %+d против %d — [color=%s]мимо[/color]." % [verb, part.name, wname, d, bonus, E.evade, Pal.hex(Pal.G2)])
	else:
		var dmg := int(round(base * randf_range(0.85, 1.15)))
		if rage > 0:
			var extra := maxi(1, G.mod("ТЕЛ")) * 2
			dmg += extra
			_log("[color=%s][Вспышки гнева] Ярость добавляет %d урона.[/color]" % [Pal.hex(Pal.R3), extra])
		if weak_spot > 0:
			dmg += weak_spot
			_log("[color=%s]Удар по найденному слабому месту: +%d урона.[/color]" % [Pal.hex(Pal.G5), weak_spot])
			weak_spot = 0
		if d >= crit_on:
			dmg *= 2
		dmg = maxi(1, dmg - int(E.def))
		part.hp -= dmg
		var crit := " [color=%s]КРИТ![/color]" % Pal.hex(Pal.R3) if d >= crit_on else ""
		_log("Вы %s в «%s» (%s): к20=%d %+d — [color=%s]попадание, %d урона[/color].%s" % [verb, part.name, wname, d, bonus, Pal.hex(Pal.G5), dmg, crit])
		if not part.get("kill", false):
			for q in parts:
				if q.name == "Туловище":
					q.hp -= int(dmg * 0.35)
		_flash()
		if part.hp <= 0:
			_log("[color=%s]«%s» уничтожено.[/color]" % [Pal.hex(Pal.R3), part.name])
			for a in part.get("disables", []):
				_log("%s больше не может использовать «%s»." % [E.name, a])
	rage = maxi(0, rage - 1)
	_update_status()
	if _enemy_dead():
		await _wait(0.5)
		_victory()
		return
	await _wait(0.6)
	await _round_end()
	_after_enemy()


## Перезарядка из таблицы оружия: 0,5 и меньше — ход не тратится, 2 и больше — враг успевает ударить лишний раз.
func _reload() -> void:
	busy = true
	var rl: float = D.ITEMS[G.p.weapon].get("reload", 1.0)
	_log(G.reload())
	if G.has_perk("Ловкач") or rl <= 0.5:
		var why := "Пальцы делают всё сами («Ловкач»)" if G.has_perk("Ловкач") else "Быстрая перезарядка (%s)" % G.p.weapon
		_log("[color=%s]%s: ход не потрачен.[/color]" % [Pal.hex(Pal.G5), why])
		await _wait(0.3)
		busy = false
		_menu()
		return
	await _wait(0.4)
	if rl >= 2.0 and not finished:
		_log("[color=%s]Долгая перезарядка (%s): враг успевает ударить лишний раз.[/color]" % [Pal.hex(Pal.R3), str(rl).replace(".0", "")])
		await _enemy_turn()
		if G.p.hp <= 0:
			_after_enemy()
			return
	await _round_end()
	_after_enemy()


func _analyze() -> void:
	busy = true
	var r := G.roll("Анализ", 14)
	if r.ok:
		analyzed = true
		weak_spot = maxi(0, G.mod("ВСП")) * 2
		var weak := ""
		for p in parts:
			if p.get("kill", false) and (weak == "" or p.mod < -3):
				weak = p.name
		_log("%s Вы видите слабые места: точные цифры повреждений, +2 к попаданию и +%d урона следующим попаданием." % [G.roll_text(r), weak_spot])
		var dis: Array = []
		for p in parts:
			if p.has("disables"):
				dis.append("%s → %s" % [p.name, ", ".join(p.disables)])
		_log("[color=%s]Без этих частей враг лишится атак: %s.[/color]" % [Pal.hex(Pal.G3), "; ".join(dis)])
	else:
		_log("%s Враг двигается слишком хаотично." % G.roll_text(r))
	await _wait(0.5)
	await _round_end()
	_after_enemy()


func _defend() -> void:
	busy = true
	var r := G.roll("Самозащита", 12)
	defending = r.ok
	_log("%s %s" % [G.roll_text(r), "Вы закрываетесь — урон этого хода вдвое меньше." if r.ok else "Вы не успеваете закрыться."])
	await _wait(0.5)
	await _round_end()
	defending = false
	_after_enemy()


func _spare_weapons() -> Array:
	var res: Array = []
	for it in G.p.inv.keys():
		if D.ITEMS[it].type == "weapon" and it != G.p.weapon and it != G.p.melee:
			res.append(it)
	return res


func _weapons_menu() -> void:
	_clear_actions()
	for it in _spare_weapons():
		var info: Dictionary = D.ITEMS[it]
		var kind := "ближний" if info.get("melee", false) else "магазин %d" % int(G.p.mags.get(it, 0))
		_act("%s (урон %d, %s)" % [it, info.dmg, kind], _switch_weapon.bind(it))
	_act("< Назад", _menu)


func _switch_weapon(it: String) -> void:
	_log(G.use_item(it))
	_menu()


func _items_menu() -> void:
	_clear_actions()
	var any := false
	for it in G.p.inv.keys():
		var t: String = D.ITEMS[it].type
		if t in ["heal", "calm", "food"]:
			any = true
			_act("%s ×%d" % [it, G.p.inv[it]], _use_item.bind(it))
	if not any:
		_act("Нечего использовать", func(): pass, false)
	_act("< Назад", _menu)


func _use_item(it: String) -> void:
	busy = true
	_log(G.use_item(it))
	_update_status()
	await _wait(0.4)
	await _round_end()
	_after_enemy()


func _flee() -> void:
	busy = true
	var legs_gone := false
	for p in parts:
		if p.hp <= 0 and p.name in ["Лапы", "Ноги", "Щупальца"]:
			legs_gone = true
	if legs_gone:
		_log("Враг не может преследовать. Вы спокойно уходите.")
		await _wait(0.6)
		_end("fled")
		return
	var dc := 14 + (4 if "Ноги" in G.p.wounds else 0)
	var r := G.roll("Акробатика", dc, "flee")
	_log("Вы подбрасываете монетку... %s" % G.roll_text(r))
	if r.ok:
		_log("[color=%s]Орёл. Вы вырываетесь и бежите.[/color]" % Pal.hex(Pal.G5))
		await _wait(0.6)
		_end("fled")
		return
	_log("[color=%s]Решка. Путь отрезан.[/color]" % Pal.hex(Pal.R3))
	await _wait(0.5)
	await _round_end()
	_after_enemy()


# ---------- спутница ----------

## Конец раунда: сначала стреляет спутница (бесплатно), потом ходит враг.
func _round_end() -> void:
	if G.p.get("companion", "") == "ryzhaya" and not finished:
		await _ally_turn()
		# «Вожак»: раз в бой спутница действует дважды.
		if not leader_used and G.has_perk("Вожак") and not _enemy_dead():
			leader_used = true
			_log("[color=%s]Вы командуете, Рыжая стреляет ещё раз («Вожак»).[/color]" % Pal.hex(Pal.G5))
			await _ally_turn()
		if _enemy_dead():
			await _wait(0.4)
			_victory()
			return
	await _enemy_turn()


func _ally_turn() -> void:
	var alive: Array = parts.filter(func(q): return q.hp > 0)
	if alive.is_empty():
		return
	var tier: int = G.rel_tier("ryzhaya").idx
	# бьёт по той же части, что уже ранена сильнее всего, иначе по случайной
	var target: Dictionary = alive[0]
	for q in alive:
		if float(q.hp) / q.max < float(target.hp) / target.max:
			target = q
	if randf() < 0.35:
		target = alive.pick_random()
	var ch := 0.55 + 0.07 * maxi(0, tier - 1) + 0.03 * int(target.mod)
	if randf() > ch:
		_log("[color=%s]Рыжая стреляет в «%s» — мимо. Ругается сквозь зубы.[/color]" % [Pal.hex(Pal.G3), target.name])
		await _wait(0.4)
		return
	var dmg := maxi(1, randi_range(9, 15) + 2 * maxi(0, tier - 2) - int(E.def))
	target.hp -= dmg
	_log("[color=%s]Рыжая стреляет из револьвера в «%s»: %d урона.[/color]" % [Pal.hex(Pal.G5), target.name, dmg])
	if not target.get("kill", false):
		for q in parts:
			if q.name == "Туловище":
				q.hp -= int(dmg * 0.35)
	if target.hp <= 0:
		_log("[color=%s]«%s» уничтожено.[/color]" % [Pal.hex(Pal.R3), target.name])
	_flash()
	_update_status()
	await _wait(0.5)


# ---------- ход врага ----------

func _available_attacks() -> Array:
	var off: Array = []
	for p in parts:
		if p.hp <= 0:
			off.append_array(p.get("disables", []))
	var res: Array = []
	for a in E.attacks:
		if not (a.name in off):
			res.append(a)
	return res


func _enemy_turn() -> void:
	if finished:
		return
	var atks := _available_attacks()
	if atks.is_empty():
		_log("%s корчится, но больше не может атаковать." % E.name)
		return
	var a: Dictionary = atks.pick_random()
	var roll_w := randf()
	var target := "Туловище"
	if roll_w < 0.15:
		target = "Голова"
	elif roll_w < 0.38:
		target = "Руки"
	elif roll_w < 0.6:
		target = "Ноги"
	var d := randi_range(1, 20)
	if enemy_streak >= 2:
		d = mini(d, randi_range(1, 20))
	var evade := G.evasion() + (4 if defending else 0)
	if a.kind == "mind":
		evade = 9 + G.mod("ВСП")
	var hit := (d + 4 >= evade or d == 20) and d != 1
	enemy_streak = enemy_streak + 1 if hit else 0
	var where := target.to_lower() if a.kind == "body" else "ваш разум"
	if a.kind == "mind":
		where = "вас"
	if not hit:
		_log("%s %s %s — [color=%s]промах[/color]." % [E.name, a.text, where if a.kind == "mind" else _acc(target), Pal.hex(Pal.G3)])
		return
	var dmg := float(a.dmg) * randf_range(0.85, 1.15)
	if target == "Голова" and a.kind == "body":
		dmg *= 1.3
	if defending:
		dmg *= 0.5
	var dealt := G.hurt(int(round(dmg)), a.kind)
	_shake()
	if a.kind == "mind":
		_log("%s %s вас. [color=%s]-%d ООР.[/color]" % [E.name, a.text, Pal.hex(Pal.R3), dealt])
		_check_mind()
	else:
		_log("%s %s %s. [color=%s]-%d ООЗ.[/color]" % [E.name, a.text, _acc(target), Pal.hex(Pal.R3), dealt])
		if Live.has("Вспышки гнева") and rage == 0 and randf() < 0.35:
			rage = 1
			_log("[color=%s][Вспышки гнева][/color] Красная пелена. Следующий ход — только атака, зато сильнее." % Pal.hex(Pal.R3))
		if target == "Голова":
			var m := G.hurt(3, "mind")
			_log("В глазах темнеет: -%d ООР." % m)
			_check_mind()
		if (d >= 18) and target != "Туловище" and not (target in G.p.wounds):
			G.p.wounds.append(target)
			_log("[color=%s]Рана: %s. Нужен хирург.[/color]" % [Pal.hex(Pal.R2), target.to_lower()])
	_update_status()


func _acc(part: String) -> String:
	match part:
		"Голова": return "голову"
		"Руки": return "руку"
		"Ноги": return "ногу"
	return "туловище"


func _check_mind() -> void:
	if G.p.mind <= 0:
		var tr := G.go_mad()
		_log("[color=%s]Рассудок ломается. Новая черта: «%s».[/color]" % [Pal.hex(Pal.R2), tr])


func _after_enemy() -> void:
	if finished:
		return
	if G.p.hp <= 0:
		await _death_saves()
		return
	busy = false
	_menu()


func _death_saves() -> void:
	_clear_actions()
	_log("\n[color=%s]Вы падаете. Три проверки Антисмерти...[/color]" % Pal.hex(Pal.R2))
	await _wait(0.8)
	var res := G.death_saves()
	for r in res.rolls:
		_log(G.roll_text(r))
		await _wait(0.6)
	if not res.alive:
		_log("[color=%s]Сердце останавливается.[/color]" % Pal.hex(Pal.R2))
		await _wait(1.2)
		_end("dead")
		return
	if res.injury != "":
		_log("[color=%s]Вы выжили, но останется травма: «%s».[/color]" % [Pal.hex(Pal.R3), res.injury])
	else:
		_log("[color=%s]Все три проверки пройдены. Вы выжили без последствий.[/color]" % Pal.hex(Pal.G5))
	_log("%s теряет к вам интерес и уходит." % E.name)
	finished = true
	_update_status()
	_clear_actions()
	busy = false
	_act("Очнуться", _end.bind("down"))


# ---------- итоги ----------

func _enemy_dead() -> bool:
	for p in parts:
		if p.get("kill", false) and p.hp <= 0:
			return true
	return false


func _victory() -> void:
	finished = true
	_log("\n[color=%s]%s повержен.[/color]" % [Pal.hex(Pal.G5), E.name])
	var su := randi_range(E.su[0], E.su[1])
	if su > 0:
		G.p.su += su
		_log("Найдено: %d Су." % su)
	for it in E.loot:
		G.add_item(it)
		_log("Найдено: %s." % it)
	if E.has("rare") and randf() < float(E.rare[1]):
		G.add_item(E.rare[0])
		_log("[color=%s]Редкая находка: %s![/color]" % [Pal.hex(Pal.R3), E.rare[0]])
	if E.loot.size() > 0:
		var r := G.roll("Трофей", 13)
		if r.ok:
			G.add_item(E.loot[0])
			_log("%s Аккуратная разделка: ещё один «%s»." % [G.roll_text(r), E.loot[0]])
	if Live.has("Жадность") and E.loot.size() > 0:
		G.add_item(E.loot.pick_random())
		_log("[color=%s][Жадность][/color] Вы обшариваете тело до последней нитки: ещё один трофей." % Pal.hex(Pal.R3))
	if Live.has("Одержимость кровью"):
		G.heal(8)
		_log("[color=%s][Одержимость кровью][/color] Запах крови возвращает силы: +8 ООЗ." % Pal.hex(Pal.R3))
	G.say("Победа: %s." % E.name)
	G.on_kill(enemy_id)
	_update_status()
	_clear_actions()
	busy = false
	_act("Вернуться", _end.bind("win"))


func _end(result: String) -> void:
	finished = true
	queue_free()
	if on_end.is_valid():
		on_end.call(result)


func _flash() -> void:
	var tw := create_tween()
	view.modulate = Color(2, 0.6, 0.6)
	tw.tween_property(view, "modulate", Color.WHITE, 0.25)


func _shake() -> void:
	var tw := create_tween()
	for i in 4:
		tw.tween_property(self, "position", Vector2(randf_range(-4, 4), randf_range(-3, 3)), 0.04)
	tw.tween_property(self, "position", Vector2.ZERO, 0.04)
