extends Control
## Лавка старьёвщика: покупка и продажа.

var stock: Array = []
var buy_box: VBoxContainer
var sell_box: VBoxContainer
var money: Label
var title_text := "ЛАВКА"
var about: RichTextLabel
var cover_box: Control
## Библиотекарь: товар штучный, купленное на сегодня из лавки пропадает.
var limited := false
var sort_btn: Button


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
	limited = G.shop_who == "librarian"
	if not limited:
		var hs := Pal.label("ПРОДАТЬ (половина цены, трофеи — полная)", Pal.G3, 9, true)
		hs.position = Vector2(330, 44)
		add_child(hs)
	var sort_b := Pal.button("Сортировка: %s" % G.SORT_NAMES[G.sort_mode.shop], func():
		G.next_sort("shop")
		sort_btn.text = "Сортировка: %s" % G.SORT_NAMES[G.sort_mode.shop]
		_fill(), 8)
	sort_b.position = Vector2(44, 318)
	sort_b.custom_minimum_size = Vector2(150, 0)
	add_child(sort_b)
	sort_btn = sort_b
	# у книжника справа обложка, как витрина: видно, что покупаешь
	cover_box = Control.new()
	cover_box.position = Vector2(400, 56)
	cover_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cover_box)
	for side in 2:
		if side == 1 and limited:
			break
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
	var base: float = info.price if info.type == "trophy" else info.price / 2.0
	return G.sell_price(roundi(base * G.buy_k(G.shop_who, it)))


func _fill() -> void:
	var m := G.mod("ХАР")
	money.text = "%d Су" % G.p.su
	if m != 0:
		money.text += "  ·  ХАР: цены %+d%%" % (-3 * m)
	var rk := G.rel_price_k(G.shop_who)
	if rk != 1.0:
		money.text += "  ·  отношение: %+d%%" % roundi((rk - 1.0) * 100)
	for c in buy_box.get_children() + (sell_box.get_children() if sell_box else []):
		c.queue_free()
	if limited:
		stock = G.lib_stock()
		if stock.is_empty():
			buy_box.add_child(Pal.label("Сегодня всё раскупили.\nЗавтра будут новые книги.", Pal.G3, 9))
	var wander := G.shop_who == "wanderer"
	if wander:
		stock = G.wander_left()
		if stock.is_empty():
			buy_box.add_child(Pal.label("Мешки пусты: всё раскупили.", Pal.G3, 9))
	for it in G.sort_items(stock, "shop"):
		var price: int = _buy_price(it)
		var deal: bool = it == G.p.get("deal_today", "")
		var line := "%s — %d Су%s" % [it, price, "  ★ для своих −25%" if deal else ""]
		if wander:
			var base: int = G.price(D.ITEMS[it].price, it)
			var cmp := "дешевле рынка" if price < base * 0.95 else ("дороже рынка" if price > base * 1.05 else "как на рынке")
			line = "%s ×%d — %d Су · %s" % [it, G.wander_qty(it), price, cmp]
		var b := Pal.button(line, _buy.bind(it), 9)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.mouse_entered.connect(_show_about.bind(it))
		b.disabled = G.p.su < price
		buy_box.add_child(b)
	if limited:
		if not stock.is_empty():
			_show_about(stock[0])
		return
	var keys: Array = G.sort_items(G.p.inv.keys(), "shop")
	for it in keys:
		var info: Dictionary = D.ITEMS[it]
		if info.type in ["quest", "tool"]:
			continue
		var takes: bool = G.buy_k(G.shop_who, it) > 0.0
		var line := "%s ×%d — %d Су" % [it, G.p.inv[it], _sell_price(it)] if takes else "%s ×%d — %s" % [it, G.p.inv[it], D.REFUSE_TEXT.get(G.shop_who, "не берёт")]
		var b := Pal.button(line, _sell.bind(it), 9)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.mouse_entered.connect(_show_about.bind(it))
		var equipped: bool = G.equipped(it)
		b.disabled = (equipped and G.p.inv[it] <= 1) or not takes
		sell_box.add_child(b)


func _show_about(it: String) -> void:
	about.text = "[b]%s[/b]\n%s" % [it, D.item_desc(it)]
	for c in cover_box.get_children():
		c.queue_free()
	if limited and D.BOOKS.has(it):
		cover_box.add_child(preload("res://scripts/bookview.gd").cover(D.BOOKS[it].cover, Vector2.ZERO, Vector2(141, 188)))


func _exit_tree() -> void:
	G.shop_who = ""


func _buy_price(it: String) -> int:
	if G.shop_who == "wanderer":
		return G.wander_price(it)
	return G.price(D.ITEMS[it].price, it)


func _buy(it: String) -> void:
	var price: int = _buy_price(it)
	if G.p.su < price:
		return
	if G.shop_who == "wanderer" and G.wander_qty(it) <= 0:
		return
	G.p.su -= price
	G.add_item(it)
	if limited:
		G.set_flag("lib_%d_%s" % [G.p.day, it])
	if G.shop_who == "wanderer":
		G.wander_take(it)
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
