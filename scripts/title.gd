extends Control
## Главное меню: загрузка терминала Института.

const BOOT := [
	"ИНСТИТУТ ПО ЭТИКЕ · ТЕРМИНАЛ ГЕНИЕВ ПОДЗЕМКИ",
	"Проверка связи с Сефирами ........ ОК",
	"Стабилизация Запутанности ........ 61%",
	"Реестр Подземок .................. 44 записи",
	"Узел: КАЛЬДЕРА",
	"",
]

var boot_label: Label
var menu: VBoxContainer
var load_box: VBoxContainer
var t := 0.0
var shown := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Pal.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	boot_label = Pal.label("", Pal.G3, 9)
	boot_label.position = Vector2(24, 18)
	add_child(boot_label)

	var title := Pal.label("ГЕНИИ ПОДЗЕМКИ", Pal.G5, 34, true)
	title.position = Vector2(24, 110)
	add_child(title)
	var sub := Pal.label("КАЛЬДЕРА  ·  версия %s" % G.VERSION, Pal.G3, 11)
	sub.position = Vector2(28, 156)
	add_child(sub)
	var red := ColorRect.new()
	red.color = Pal.R2
	red.position = Vector2(28, 174)
	red.size = Vector2(250, 2)
	add_child(red)

	menu = VBoxContainer.new()
	menu.position = Vector2(28, 190)
	menu.custom_minimum_size = Vector2(220, 0)
	add_child(menu)
	menu.add_child(Pal.button("НОВАЯ ЗАПИСЬ ГЕНИЯ", func(): G.main().show_creator(), 11))
	var last := G.any_save()
	if last >= 0:
		menu.add_child(Pal.button("ПРОДОЛЖИТЬ", _load.bind(last), 11))
		menu.add_child(Pal.button("ЗАГРУЗИТЬ", _toggle_load, 11))
	menu.add_child(Pal.button("ВЫХОД", func(): get_tree().quit(), 11))

	load_box = VBoxContainer.new()
	load_box.position = Vector2(270, 190)
	load_box.custom_minimum_size = Vector2(330, 0)
	load_box.visible = false
	add_child(load_box)
	for i in G.SLOTS:
		var b := Pal.button("Ячейка %d: %s" % [i + 1, G.slot_info(i)], _load.bind(i))
		b.disabled = not FileAccess.file_exists(G.slot_path(i))
		load_box.add_child(b)

	var hint := Pal.label("Управление: мышь · WASD/стрелки — ходьба · E/Пробел — действие · Tab — пейджер", Pal.G2, 8)
	hint.position = Vector2(24, 336)
	add_child(hint)

	var art := TextureRect.new()
	art.texture = Art.portrait_tex({"sex": "Ж", "red": true, "coat": 2, "collar": 8, "freckles": true})
	art.position = Vector2(470, 40)
	art.scale = Vector2(3, 3)
	art.modulate = Color(1, 1, 1, 0.85)
	add_child(art)


func _load(i: int) -> void:
	if G.load_slot(i):
		G.main().show_world(G.p.map)


func _toggle_load() -> void:
	load_box.visible = not load_box.visible


func _process(delta: float) -> void:
	t += delta
	var want := mini(BOOT.size(), int(t / 0.25))
	if want != shown:
		shown = want
		boot_label.text = "\n".join(BOOT.slice(0, shown)) + ("_" if shown < BOOT.size() else "")
