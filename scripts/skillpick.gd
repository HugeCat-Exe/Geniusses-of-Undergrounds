extends Control
## Каждый 10-й уровень: Гений осваивает ещё один основной навык. Повторный выбор удваивает бонус.

var chosen := ""
var info: RichTextLabel
var ok_b: Button
var grid: GridContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var body := Panel.new()
	body.position = Vector2(30, 22)
	body.size = Vector2(580, 316)
	add_child(body)
	var title := Pal.label("УРОВЕНЬ %d · НОВЫЙ ОСНОВНОЙ НАВЫК" % int(G.p.level), Pal.G5, 12, true)
	title.position = Vector2(46, 32)
	add_child(title)
	var sub := Pal.label("Выберите навык: он станет основным и получит +%d. Если выбрать уже основной навык, бонус удвоится." % G.main_bonus(), Pal.G3, 8)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.position = Vector2(46, 50)
	sub.size = Vector2(548, 20)
	add_child(sub)
	grid = GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(46, 76)
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 3)
	add_child(grid)
	for sk in D.SKILLS:
		var t := G.main_times(sk[0])
		var b := Pal.button("%s%s %+d" % [sk[0], (" ★×%d" % t) if t > 1 else (" ★" if t == 1 else ""), G.skill_bonus(sk[0])], _choose.bind(sk), 8)
		b.custom_minimum_size = Vector2(134, 20)
		b.toggle_mode = true
		b.set_meta("sk", sk[0])
		b.mouse_entered.connect(_describe.bind(sk))
		grid.add_child(b)
	info = Pal.rich("", 9)
	info.position = Vector2(46, 242)
	info.size = Vector2(548, 50)
	add_child(info)
	ok_b = Pal.button("ВЫБРАТЬ", _confirm, 10)
	ok_b.position = Vector2(482, 302)
	ok_b.size = Vector2(112, 22)
	ok_b.disabled = true
	add_child(ok_b)
	Sfx.play("achieve")


func _describe(sk: Array) -> void:
	var t := G.main_times(sk[0])
	var now := "сейчас основной ×%d" % t if t > 0 else "сейчас не основной"
	info.text = "[b]%s[/b] (%s): %s\n[color=%s]%s; после выбора бонус основного навыка: +%d.[/color]" % [
		sk[0], sk[1], sk[2], Pal.hex(Pal.G3), now, G.main_bonus() * (t + 1)]


func _choose(sk: Array) -> void:
	chosen = sk[0]
	for b in grid.get_children():
		b.button_pressed = b.get_meta("sk") == chosen
	ok_b.disabled = false
	_describe(sk)


func _confirm() -> void:
	if chosen == "":
		return
	G.pick_skill(chosen)
	G.main().toast("Навык освоен", chosen, "", "achieve")
	queue_free()
