extends Control
## Генератор, узел 3: перезапустить предохранители в правильном порядке.
## Лампочки над предохранителями мигают по очереди; нужно повторить порядок щелчками.
## Ошибка – короткое замыкание. Механика замедляет показ.

signal done(ok: bool)

const N := 6
const LEN := 5

var order: Array = []
var step := 0
var phase := "show"   # show / input / over
var t := 0.0
var lit := -1
var show_i := 0
var gap := 0.7
var ok := false
var info: Label
var auto := OS.get_environment("GP_SMOKE") != ""
var auto_t := 0.0
var flash := {}       # предохранитель -> сколько ещё подсвечен


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var skill := G.skill_bonus("Механика")
	gap = clampf(0.7 + skill * 0.08, 0.45, 1.1)
	for i in LEN:
		var f := randi() % N
		while not order.is_empty() and order[-1] == f:
			f = randi() % N
		order.append(f)
	var title := Pal.label("ПЕРЕЗАПУСТИТЬ ПРЕДОХРАНИТЕЛИ", Pal.G5, 14, true)
	title.position = Vector2(0, 30)
	title.size = Vector2(640, 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	info = Pal.label("Запомните, в каком порядке мигают лампы над предохранителями (%d вспышек). Показ медленнее с хорошей Механикой (%+d)." % [LEN, skill], Pal.G4, 9)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.position = Vector2(60, 54)
	info.size = Vector2(520, 30)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(info)


func _fx(i: int) -> float:
	return 320.0 - (N - 1) * 30.0 + i * 60.0


func _gui_input(ev: InputEvent) -> void:
	if phase != "input" or not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	for i in N:
		if Rect2(_fx(i) - 16, 170, 32, 90).has_point(ev.position):
			_press(i)
			return


func _press(i: int) -> void:
	flash[i] = 0.25
	if order[step] != i:
		_finish(false)
		return
	step += 1
	if step >= LEN:
		_finish(true)


func _process(delta: float) -> void:
	t += delta
	for k in flash.keys():
		flash[k] -= delta
		if flash[k] <= 0.0:
			flash.erase(k)
	if phase == "show":
		var k := int(t / gap) - 1
		if k >= 0 and k < LEN:
			lit = order[k] if fmod(t, gap) < gap * 0.7 else -1
		elif k >= LEN:
			lit = -1
			phase = "input"
			info.text = "Теперь щёлкайте предохранители в том же порядке."
	elif phase == "input" and auto:
		auto_t += delta
		if auto_t > 0.3:
			auto_t = 0.0
			_press(order[step])
	queue_redraw()


func _finish(win: bool) -> void:
	phase = "over"
	ok = win
	info.text = "Предохранители держат. Генератор оживает." if win else "Хлопок, вспышка. Короткое замыкание."
	queue_redraw()
	await get_tree().create_timer(0.9).timeout
	done.emit(win)
	queue_free()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(640, 360)), Color(Pal.BG, 0.95))
	draw_rect(Rect2(_fx(0) - 30, 110, (N - 1) * 60 + 60, 170), Pal.G0)
	draw_rect(Rect2(_fx(0) - 30, 110, (N - 1) * 60 + 60, 170), Pal.G2, false, 1.0)
	for i in N:
		var x := _fx(i)
		var on := lit == i or flash.has(i)
		draw_circle(Vector2(x, 134), 8.0, Pal.G5 if on else Pal.G1)
		draw_rect(Rect2(x - 10, 170, 20, 80), Pal.G1)
		draw_rect(Rect2(x - 7, 180 if not flash.has(i) else 200, 14, 40), Pal.G3 if not flash.has(i) else Pal.G4)
	for k in LEN:
		draw_rect(Rect2(320 - LEN * 9 + k * 18, 300, 12, 12), Pal.G4 if k < step else Pal.G1)
	if phase == "over" and not ok:
		draw_rect(Rect2(Vector2.ZERO, Vector2(640, 360)), Color(Pal.R2, 0.18))
