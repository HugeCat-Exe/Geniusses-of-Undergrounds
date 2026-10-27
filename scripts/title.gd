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
var ach_panel: ScrollContainer = null
var menu: VBoxContainer
var load_box: VBoxContainer
var full_btn: Button
var t := 0.0
var shown := 0
var gen_box: Control
var phrase_label: Label
var phrase := ""
var typed := 0
## Реплики идут «колодой»: перемешаны, без повторов, пока не покажутся все.
var deck: Array = []
var last := -1
var phrase_t := 0.0
var erasing := false
const PHRASE_EVERY := 40.0

## Реплики Женевьевы на главном экране: каждый запуск – новая, как сплэш в Майнкрафте.
const PHRASES := [
	"Слежу за тобой, милый. Не сдохни от смущения хи-хи",
	"Если бы я могла отправить тебе пачку бинтов... Я могу конечно, но не стану!",
	"Никогда бы не подумала, что ты станешь таким выдающимся и знаменитым Гением. Как там тебя?",
	"Институт напоминает: смерть не освобождает от уплаты взносов.",
	"Сефиры сегодня в хорошем настроении. Это не про тебя, милый.",
	"Твой пульс на мониторе такой милый. Особенно когда прерывается.",
	"Отчёт о твоих подвигах занял полстроки. Я округлила вниз.",
	"Пейджер пищит не от сбоя. Это я соскучилась. Немного.",
	"Институт по Этике не убивает Гениев. Это делает Пустошь, а мы ведём учёт.",
	"Опять ты? Я уже написала тебе некролог. Придётся переписывать.",
	"Умрёшь красиво – поставлю тебе «удовлетворительно». Лично.",
	"Собачий Муэдзин передаёт привет. Я тоже, но мой привет вежливее.",
	"Не забывай есть, Гений. Голодные трупы плохо смотрятся в отчётах.",
	"Я поставила на тебя пять Су. Не подведи, мне ещё на кофе.",
	"Твоя анкета лежит у меня на столе. Под кружкой.",
	"Не смотри на меня так. Я всего лишь интерфейс. Красивый интерфейс.",
	"Институт ценит каждого Гения. Особенно тех, кто возвращает пейджер.",
	"Сегодня в Пустоши ясно, ветер умеренный, шанс умереть высокий.",
	"Я слышала, как ты разговариваешь с Рыжей. Мило. Записала.",
	"Пейджер выдерживает падение с пятого яруса Подземки. Тебе тоже следует попробовать.",
	"Хочешь совет от Института? Не ходи туда. Любое «туда».",
	"Мне нравится, как ты держишь оружие. Неправильно, но с душой.",
	"Слепцы слышат сердце. Твоё бьётся слишком громко, когда ты видишь меня.",
	"Я не ревную тебя к Дане. Я просто отметила её в отчёте как угрозу.",
	"Запутанность сегодня спокойная. Подозрительно спокойная. Иди уже.",
	"Если станет страшно, вспомни: я смотрю. И смеюсь, но смотрю.",
	"Су не пахнут. А вот ты после логова псов очень.",
	"Будь хорошим Гением, и я, может быть, отправлю тебе пару листов бумаги, которые подержала в руках.",
]


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
	menu.add_child(Pal.button("ДОСТИЖЕНИЯ", _toggle_ach, 11))
	full_btn = Pal.button("", _toggle_full, 11)
	menu.add_child(full_btn)
	_full_text()
	menu.add_child(Pal.button("ВЫХОД", func(): get_tree().quit(), 11))

	load_box = VBoxContainer.new()
	load_box.position = Vector2(270, 214)
	load_box.custom_minimum_size = Vector2(330, 0)
	load_box.visible = false
	add_child(load_box)
	for i in G.SLOTS + 1:
		var b := Pal.button("%s: %s" % [G.slot_name(i), G.slot_info(i)], _load.bind(i), 9)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.disabled = not FileAccess.file_exists(G.slot_path(i))
		load_box.add_child(b)

	var hint := Pal.label("Управление: мышь · WASD/стрелки – ходьба · E/Пробел – действие · Tab – пейджер", Pal.G2, 8)
	hint.position = Vector2(24, 336)
	add_child(hint)

	# Женевьева, Институт по Этике
	gen_box = Control.new()
	gen_box.position = Vector2(384, 12)
	add_child(gen_box)
	var frame := ColorRect.new()
	frame.color = Pal.G2
	frame.position = Vector2(6, 0)
	frame.size = Vector2(228, 228)
	gen_box.add_child(frame)
	var art := TextureRect.new()
	art.texture = preload("res://scripts/genevieve.gd").texture()
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.position = Vector2(8, 2)
	art.size = Vector2(224, 224)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	gen_box.add_child(art)
	var cap := Pal.label("Женевьева – Институт по Этике", Pal.G4, 9, true)
	cap.position = Vector2(0, 232)
	cap.size = Vector2(240, 14)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gen_box.add_child(cap)
	phrase_label = Pal.label("", Pal.G3, 9)
	phrase_label.position = Vector2(0, 250)
	phrase_label.size = Vector2(240, 60)
	phrase_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	phrase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gen_box.add_child(phrase_label)
	_next_phrase()


func _load(i: int) -> void:
	if G.load_slot(i):
		G.main().show_world(G.p.map)


func _toggle_full() -> void:
	G.main().set_fullscreen(not G.main().fullscreen)
	_full_text()


func _full_text() -> void:
	full_btn.text = "ПОЛНЫЙ ЭКРАН: %s" % ("ВКЛ" if G.main().fullscreen else "ВЫКЛ")


## Список достижений справа от меню: полученные светятся, остальные тусклые.
func _toggle_ach() -> void:
	if ach_panel != null:
		ach_panel.queue_free()
		ach_panel = null
		gen_box.visible = true
		return
	load_box.visible = false
	gen_box.visible = false
	var Ach := preload("res://scripts/ach.gd")
	ach_panel = ScrollContainer.new()
	ach_panel.position = Vector2(318, 10)
	ach_panel.size = Vector2(312, 340)
	ach_panel.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(ach_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	ach_panel.add_child(vb)
	var n := 0
	for a in Ach.LIST:
		if Ach.has(a.id):
			n += 1
	vb.add_child(Pal.label("ДОСТИЖЕНИЯ · получено %d из %d" % [n, Ach.LIST.size()], Pal.G5, 10, true))
	for a in Ach.LIST:
		vb.add_child(Ach.plate(a, Ach.has(a.id), 300.0))


func _toggle_load() -> void:
	if ach_panel != null:
		ach_panel.queue_free()
		ach_panel = null
	load_box.visible = not load_box.visible
	gen_box.visible = not load_box.visible


func _process(delta: float) -> void:
	t += delta
	var want := mini(BOOT.size(), int(t / 0.25))
	if want != shown:
		shown = want
		boot_label.text = "\n".join(BOOT.slice(0, shown)) + ("_" if shown < BOOT.size() else "")
	# реплика печатается по букве после загрузки терминала, через 40 секунд стирается и сменяется
	if t < BOOT.size() * 0.25:
		return
	phrase_t += delta
	var blink := "_" if int(t * 3.0) % 2 == 0 else " "
	if erasing:
		typed = maxi(0, typed - 2)
		phrase_label.text = phrase.substr(0, typed) + "_"
		if typed == 0:
			erasing = false
			phrase_t = 0.0
			_next_phrase()
		return
	var n := mini(phrase.length(), int(phrase_t / 0.035))
	typed = n
	phrase_label.text = phrase.substr(0, n) + (blink if n == phrase.length() else "_")
	if phrase_t > PHRASE_EVERY:
		erasing = true


func _next_phrase() -> void:
	if deck.is_empty():
		deck = range(PHRASES.size())
		deck.shuffle()
		if deck[0] == last and deck.size() > 1:
			deck.push_back(deck.pop_front())
	last = deck.pop_front()
	phrase = "«%s»" % PHRASES[last]
