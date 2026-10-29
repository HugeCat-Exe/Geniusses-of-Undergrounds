extends Control
## Генератор, узел 2: выставить давление в котле.
## Стрелка манометра ходит туда-сюда; щелчок или пробел фиксирует её. Три фиксации в зелёной зоне,
## два промаха подряд – прорыв пара. Скорость стрелки зависит от Механики.

signal done(ok: bool)

const NEED := 3
const C := Vector2(320, 230)
const R := 80.0

var v := 0.0          # положение стрелки 0..1
var dir := 1.0
var speed := 0.9
var band := Vector2(0.6, 0.75)
var hits := 0
var miss := 0
var flash := 0.0
var flash_ok := true
var over := false
var ok := false
var info: Label
var auto := OS.get_environment("GP_SMOKE") != ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var skill := G.skill_bonus("Механика")
	speed = clampf(1.0 - skill * 0.1, 0.5, 1.4)
	_new_band()
	var title := Pal.label("ВЫСТАВИТЬ ДАВЛЕНИЕ В КОТЛЕ", Pal.G5, 14, true)
	title.position = Vector2(0, 30)
	title.size = Vector2(640, 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	info = Pal.label("", Pal.G4, 9)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.position = Vector2(60, 54)
	info.size = Vector2(520, 30)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(info)
	_info()


func _info() -> void:
	info.text = "Щелчок или пробел фиксирует стрелку. Нужно %d раза попасть в зелёную зону, два промаха подряд – прорыв пара. Скорость стрелки зависит от Механики (%+d).\nЗафиксировано: %d из %d." % [NEED, G.skill_bonus("Механика"), hits, NEED]


func _new_band() -> void:
	var wdt := 0.16 - hits * 0.025
	var a := randf_range(0.15, 0.85 - wdt)
	band = Vector2(a, a + wdt)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_lock()


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode in [KEY_SPACE, KEY_ENTER, KEY_E]:
		_lock()
		get_viewport().set_input_as_handled()


func _lock() -> void:
	if over or flash > 0.0:
		return
	flash = 0.35
	if v >= band.x and v <= band.y:
		hits += 1
		miss = 0
		flash_ok = true
		if hits >= NEED:
			_finish(true)
			return
		_new_band()
	else:
		miss += 1
		flash_ok = false
		if miss >= 2:
			_finish(false)
			return
	_info()


func _process(delta: float) -> void:
	if over:
		return
	flash = maxf(0.0, flash - delta)
	v += dir * delta * speed * (1.0 + hits * 0.25)
	if v >= 1.0:
		v = 1.0
		dir = -1.0
	elif v <= 0.0:
		v = 0.0
		dir = 1.0
	if auto and flash <= 0.0 and v >= band.x + 0.01 and v <= band.y - 0.01:
		_lock()
	queue_redraw()


func _finish(win: bool) -> void:
	over = true
	ok = win
	info.text = "Давление ровное. Котёл гудит." if win else "Клапан срывает, струя пара бьёт в лицо."
	queue_redraw()
	await get_tree().create_timer(0.9).timeout
	done.emit(win)
	queue_free()


func _ang(x: float) -> float:
	return PI + x * PI


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(640, 360)), Color(Pal.BG, 0.95))
	draw_arc(C, R, PI, TAU, 40, Pal.G2, 6.0)
	draw_arc(C, R, _ang(band.x), _ang(band.y), 12, Pal.G4, 8.0)
	draw_arc(C, R, _ang(0.9), TAU, 8, Pal.R2, 6.0)
	for k in 11:
		var a := _ang(k / 10.0)
		draw_line(C + Vector2(cos(a), sin(a)) * (R - 12), C + Vector2(cos(a), sin(a)) * (R - 4), Pal.G3, 1.0)
	var a2 := _ang(v)
	draw_line(C, C + Vector2(cos(a2), sin(a2)) * (R - 6), Pal.G5, 2.0)
	draw_circle(C, 5.0, Pal.G4)
	if flash > 0.0:
		draw_circle(C + Vector2(0, 40), 6.0, Pal.G4 if flash_ok else Pal.R3)
	for k in NEED:
		draw_rect(Rect2(296 + k * 18, 290, 12, 12), Pal.G4 if k < hits else Pal.G1)
	if over and not ok:
		draw_rect(Rect2(Vector2.ZERO, Vector2(640, 360)), Color(Pal.G5, 0.12))
