extends Control
## Мини-игра «Рецепт» на кухне Греты: запомнить порядок продуктов и повторить.

signal done(score: int)

const FOODS := ["Лук", "Грибы", "Крысятина", "Соль", "Коренья", "Вода", "Жир", "Сухари"]
const LEN := 5

var seq: Array = []
var shown := -1
var t := 0.0
var phase := "show"   # show / input / over
var pos := 0
var buttons: Array = []
var info: Label
var auto := OS.get_environment("GP_SMOKE") != ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in LEN:
		seq.append(rng.randi() % FOODS.size())
	var bg := ColorRect.new()
	bg.color = Color(Pal.BG, 0.94)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title := Pal.label("РЕЦЕПТ МАТУШКИ ГРЕТЫ", Pal.G5, 14, true)
	title.position = Vector2(0, 40)
	title.size = Vector2(640, 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	info = Pal.label("Смотрите, что Грета кидает в котёл...", Pal.G4, 10)
	info.position = Vector2(0, 66)
	info.size = Vector2(640, 20)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(info)
	for i in FOODS.size():
		var b := Pal.button(FOODS[i], _pick.bind(i), 10)
		b.position = Vector2(80 + (i % 4) * 124, 170 + (i / 4) * 44)
		b.size = Vector2(116, 34)
		b.disabled = true
		add_child(b)
		buttons.append(b)


func _process(delta: float) -> void:
	t += delta
	if phase == "show":
		var k := int(t / 0.9)
		if k != shown:
			shown = k
			for b in buttons:
				b.modulate = Color(1, 1, 1, 0.25)
			if k < LEN:
				buttons[seq[k]].modulate = Color(1.6, 1.6, 1.6, 1.0)
				info.text = "В котёл: %s  (%d из %d)" % [FOODS[seq[k]], k + 1, LEN]
			else:
				phase = "input"
				t = 0.0
				for b in buttons:
					b.modulate = Color.WHITE
					b.disabled = false
				info.text = "Теперь ваша очередь: повторите порядок."
	elif phase == "input" and auto and t > 0.3:
		t = 0.0
		_pick(seq[pos])


func _pick(i: int) -> void:
	if phase != "input":
		return
	if i != seq[pos]:
		info.text = "Не то! Нужно было: %s." % FOODS[seq[pos]]
		_finish()
		return
	pos += 1
	info.text = "Верно: %d из %d." % [pos, LEN]
	if pos >= LEN:
		info.text = "Готово! Похлёбка булькает правильно."
		_finish()


func _finish() -> void:
	phase = "over"
	for b in buttons:
		b.disabled = true
	await get_tree().create_timer(1.0).timeout
	done.emit(pos)
	queue_free()
