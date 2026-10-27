extends Control
## Мини-игра «Сопротивление собачьей молитве»: круг расширяется из центра,
## нужно трижды нажать вовремя, пока его край в красном кольце. Ошибка – вой проходит.

signal done(ok: bool)

const CENTER := Vector2(320, 190)
const TARGET := 64.0
const ROUNDS := 3

var band := 8.0          # полуширина кольца, растёт с ВСП
var speed := 60.0        # пикселей в секунду, с каждым кругом быстрее
var r := 0.0
var round_i := 0
var results: Array = []
var flash := 0.0
var flash_ok := true
var pause := 0.0
var over := false
var auto := OS.get_environment("GP_SMOKE") != ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	band = clampf(8.0 + G.mod("ВСП") * 1.5, 5.0, 14.0)
	var title := Pal.label("СОПРОТИВЛЕНИЕ СОБАЧЬЕЙ МОЛИТВЕ", Pal.R3, 14, true)
	title.position = Vector2(0, 40)
	title.size = Vector2(640, 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var hint := Pal.label("Вой лезет в голову. Жмите ПРОБЕЛ или ЛКМ, когда круг коснётся красного кольца.\nНужно выдержать все три волны.", Pal.G4, 9)
	hint.position = Vector2(0, 62)
	hint.size = Vector2(640, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)


func _process(delta: float) -> void:
	if over:
		return
	flash = maxf(0.0, flash - delta)
	if pause > 0.0:
		pause -= delta
		if pause <= 0.0:
			_next_round()
		queue_redraw()
		return
	r += speed * delta
	if auto and absf(r - TARGET) < band * 0.5:
		_press()
	elif r > TARGET + band + 2.0:
		_resolve(false)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_press()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_E, KEY_ENTER]:
		_press()
		get_viewport().set_input_as_handled()


func _press() -> void:
	if over or pause > 0.0:
		return
	_resolve(absf(r - TARGET) <= band)


func _resolve(ok: bool) -> void:
	results.append(ok)
	flash = 0.35
	flash_ok = ok
	pause = 0.45
	if not ok:
		pause = 0.7


func _next_round() -> void:
	round_i += 1
	if round_i >= ROUNDS or results.has(false):
		over = true
		var ok := not results.has(false)
		await get_tree().create_timer(0.25).timeout
		done.emit(ok)
		queue_free()
		return
	r = 0.0
	speed *= 1.3


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(640, 360)), Color(Pal.BG, 0.92))
	# красное кольцо-цель
	draw_arc(CENTER, TARGET, 0, TAU, 64, Pal.R1, band * 2.0)
	draw_arc(CENTER, TARGET - band, 0, TAU, 64, Pal.R2, 1.0)
	draw_arc(CENTER, TARGET + band, 0, TAU, 64, Pal.R2, 1.0)
	# пасть в центре
	draw_circle(CENTER, 10, Pal.G0)
	draw_arc(CENTER, 10, 0, TAU, 24, Pal.R2, 1.0)
	# волна воя
	if pause <= 0.0 and not over:
		var near := absf(r - TARGET) <= band
		draw_arc(CENTER, maxf(1.0, r), 0, TAU, 64, Pal.G5 if near else Pal.G4, 2.0)
	if flash > 0.0:
		var c := Pal.G4 if flash_ok else Pal.R3
		draw_arc(CENTER, TARGET, 0, TAU, 64, Color(c, flash * 2.5), band * 2.0 + 4.0)
	# отметки волн
	for i in ROUNDS:
		var p := Vector2(CENTER.x - 30 + i * 30, CENTER.y + TARGET + 32)
		var col := Pal.G1
		if i < results.size():
			col = Pal.G4 if results[i] else Pal.R2
		draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), col)
		draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), Pal.G2, false, 1.0)
