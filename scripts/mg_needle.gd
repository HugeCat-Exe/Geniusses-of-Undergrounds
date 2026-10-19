extends Control
## Мини-игра «Зашить рану»: провести кончик иглы через точки шва по порядку.
## Чем ниже Медицина, тем сильнее дрожит игла.

signal done(stitched: int)

const POINTS := 6
const TIME := 10.0
const HIT := 7.0

var pts: Array = []
var next := 0
var t := 0.0
var shake := 6.0
var tip := Vector2(320, 300)
var jitter := Vector2.ZERO
var over := false
var info: Label
var auto := OS.get_environment("GP_SMOKE") != ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var skill := G.skill_bonus("Медицина")
	shake = clampf(9.0 - skill * 1.8, 1.0, 12.0)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in POINTS:
		var x := 210.0 + i * 44.0
		pts.append(Vector2(x, 190.0 + sin(i * 1.3 + rng.randf()) * 26.0))
	var title := Pal.label("ЗАШИТЬ РАНУ", Pal.G5, 14, true)
	title.position = Vector2(0, 40)
	title.size = Vector2(640, 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	info = Pal.label("Ведите мышью: кончик иглы должен коснуться каждой точки по порядку. Дрожь иглы зависит от Медицины (%+d)." % skill, Pal.G4, 9)
	info.position = Vector2(0, 66)
	info.size = Vector2(640, 30)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(info)


func _process(delta: float) -> void:
	if over:
		return
	t += delta
	var target := get_local_mouse_position()
	if auto and next < POINTS:
		target = pts[next]
	jitter = Vector2(sin(t * 13.0) + sin(t * 31.0) * 0.6, cos(t * 11.0) + sin(t * 27.0) * 0.6) * shake * 0.6
	tip = target + jitter
	if next < POINTS and tip.distance_to(pts[next]) <= HIT:
		next += 1
	if next >= POINTS or t >= TIME:
		_finish()
	queue_redraw()


func _finish() -> void:
	over = true
	info.text = "Зашито точек: %d из %d." % [next, POINTS]
	await get_tree().create_timer(0.9).timeout
	done.emit(next)
	queue_free()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(640, 360)), Color(Pal.BG, 0.94))
	# рана
	for i in POINTS - 1:
		draw_line(pts[i], pts[i + 1], Pal.R1, 9.0)
	for i in POINTS - 1:
		draw_line(pts[i], pts[i + 1], Pal.R2 if i >= next - 1 else Pal.G2, 2.0)
	for i in POINTS:
		var col := Pal.G4 if i < next else (Pal.G5 if i == next else Pal.G2)
		draw_circle(pts[i], 5.0 if i == next else 4.0, col)
	# время
	var left := clampf(1.0 - t / TIME, 0.0, 1.0)
	draw_rect(Rect2(170, 280, 300, 6), Pal.G1)
	draw_rect(Rect2(170, 280, 300 * left, 6), Pal.G4 if left > 0.3 else Pal.R2)
	# игла: кончик в tip, ушко сзади
	var back := tip + Vector2(26, -20)
	draw_line(back, tip, Pal.G5, 2.0)
	draw_circle(tip, 1.5, Pal.R3)
	draw_arc(back, 3.0, 0, TAU, 10, Pal.G5, 1.0)
