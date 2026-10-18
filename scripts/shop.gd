extends Control
## Лавка старьёвщика: покупка и продажа.

var stock: Array = []
var buy_box: VBoxContainer
var sell_box: VBoxContainer
var money: Label
var title_text := "ЛАВКА"
var about: RichTextLabel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var body := Panel.new()
	body.position = Vector2(30, 16)
	body.size = Vector2(580, 328)
	add_child(body)
	var title := Pal.label(title_text, Pal.G5, 12, true)
	title.position = Vector2(44, 22)
	add_child(title)
	money = Pal.label("", Pal.G5, 11, true)
	money.position = Vector2(420, 24)
	add_child(money)
	var hb := Pal.label("КУПИТЬ", Pal.G3, 9, true)
	hb.position = Vector2(44, 44)
	add_child(hb)
	var hs := Pal.label("ПРОДАТЬ (половина цены, трофеи — полная)", Pal.G3, 9, true)
	hs.position = Vector2(330, 44)
	add_child(hs)
	for side in 2:
		var sc := ScrollContainer.new()
		sc.position = Vector2(44 if side == 0 else 330, 60)
		sc.size = Vector2(270, 186)
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		add_child(sc)
		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(vb)
		if side == 0:
			buy_box = vb
		else:
			sell_box = vb
	# Описание предмета под курсором: у оружия — характеристики и текст из хранилища.
	about = Pal.rich("[color=%s]Наведите курсор на предмет, чтобы прочитать описание.[/color]" % Pal.hex(Pal.G3), 8)
	about.fit_content = false
	about.position = Vector2(44, 250)
	about.size = Vector2(440, 86)
	add_child(about)
	var close_b := Pal.button("УЙТИ", queue_free, 10)
	close_b.position = Vector2(500, 316)
	close_b.size = Vector2(96, 20)
	add_child(close_b)
	_fill()


func _sell_price(it: String) -> int:
	var info: Dictionary = D.ITEMS[it]
	if info.type == "trophy":
		return G.sell_price(info.price)
	return G.sell_price(int(info.price / 2))


func _fill() -> void:
	var m := G.mod("ХАР")
	money.text = "%d Су" % G.p.su
	if m != 0:
		money.text += "  ·  ХАР: цены %+d%%" % (-3 * m)
	for c in buy_box.get_children() + sell_box.get_children():
		c.queue_free()
	for it in stock:
		var price: int = G.price(D.ITEMS[it].price)
		var b := Pal.button("%s — %d Су" % [it, price], _buy.bind(it), 9)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.mouse_entered.connect(_show_about.bind(it))
		b.disabled = G.p.su < price
		buy_box.add_child(b)
	var keys: Array = G.p.inv.keys()
	keys.sort()
	for it in keys:
		var info: Dictionary = D.ITEMS[it]
		if info.type in ["quest", "tool"]:
			continue
		var b := Pal.button("%s ×%d — %d Су" % [it, G.p.inv[it], _sell_price(it)], _sell.bind(it), 9)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.mouse_entered.connect(_show_about.bind(it))
		var equipped: bool = G.equipped(it)
		b.disabled = equipped and G.p.inv[it] <= 1
		sell_box.add_child(b)


func _show_about(it: String) -> void:
	about.text = "[b]%s[/b]\n%s" % [it, D.item_desc(it)]


func _buy(it: String) -> void:
	var price: int = G.price(D.ITEMS[it].price)
	if G.p.su < price:
		return
	G.p.su -= price
	G.add_item(it)
	_fill()


func _sell(it: String) -> void:
	if G.remove_item(it):
		G.p.su += _sell_price(it)
		G.changed.emit()
	_fill()


func _unhandled_key_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
		queue_free()
		get_viewport().set_input_as_handled()
