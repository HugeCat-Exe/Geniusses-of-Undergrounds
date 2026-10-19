extends Control
## Мини-игра «Напёрстки» с Пипом: гайка под одной из трёх кружек, кружки меняются местами.

signal done(wins: int)

const ROUNDS := 3
const Y := 200.0

var xs := [200.0, 320.0, 440.0]
var slot := [0, 1, 2]       # какой кружке какая позиция
var cup_x := [200.0, 320.0, 440.0]
var nut := 0                # номер кружки с гайкой
var round_i := 0
var wins := 0
var phase := "reveal"       # reveal / shuffle / pick / result / over
var t := 0.0
var swaps_left := 0
var swap_a := 0
var swap_b := 0
var swap_t := 0.0
var swap_dur := 0.4
var lifted := -1
var info: Label
var auto := OS.get_environment("GP_SMOKE") != ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var title := Pal.label("НАПЁРСТКИ С ПИПОМ", Pal.G5, 14, true)
	title.position = Vector2(0, 40)
	title.size = Vector2(640, 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	info = Pal.label("", Pal.G4, 10)
	info.position = Vector2(0, 66)
	info.size = Vector2(640, 20)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(info)
	_start_round()


func _start_round() -> void:
	nut = randi() % 3
	lifted = nut
	phase = "reveal"
	t = 0.0
	info.text = "Раунд %d из %d. Гайка вот под этой кружкой..." % [round_i + 1, ROUNDS]


func _process(delta: float) -> void:
	t += delta
	match phase:
		"reveal":
			if t > 1.3:
				lifted = -1
				phase = "shuffle"
				swaps_left = 5 + round_i * 2
				swap_dur = 0.42 - round_i * 0.09
				_next_swap()
		"shuffle":
			swap_t += delta
			var k := clampf(swap_t / swap_dur, 0.0, 1.0)
			var xa: float = xs[slot[swap_a]]
			var xb: float = xs[slot[swap_b]]
			cup_x[swap_a] = lerpf(xa, xb, k)
			cup_x[swap_b] = lerpf(xb, xa, k)
			if k >= 1.0:
				var tmp: int = slot[swap_a]
				slot[swap_a] = slot[swap_b]
				slot[swap_b] = tmp
				swaps_left -= 1
				if swaps_left <= 0:
					phase = "pick"
					t = 0.0
					info.text = "Где гайка? Нажмите на кружку."
				else:
					_next_swap()
		"pick":
			if auto and t > 0.3:
				_choose(nut)
		"result":
			if t > 1.2:
				round_i += 1
				if round_i >= ROUNDS:
					phase = "over"
					done.emit(wins)
					queue_free()
					return
				_start_round()
	queue_redraw()


func _next_swap() -> void:
	swap_t = 0.0
	swap_a = randi() % 3
	swap_b = (swap_a + 1 + randi() % 2) % 3


func _gui_input(event: InputEvent) -> void:
	if phase != "pick":
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for c in 3:
			if absf(event.position.x - cup_x[c]) < 34 and absf(event.position.y - (Y - 20)) < 44:
				_choose(c)
				accept_event()
				return


func _choose(c: int) -> void:
	lifted = c
	phase = "result"
	t = 0.0
	if c == nut:
		wins += 1
		info.text = "Угадали! Счёт %d из %d." % [wins, round_i + 1]
	else:
		lifted = nut
		info.text = "Мимо! Гайка была вот тут. Счёт %d из %d." % [wins, round_i + 1]


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(640, 360)), Color(Pal.BG, 0.94))
	draw_rect(Rect2(140, Y + 6, 360, 6), Pal.G1)
	for c in 3:
		var x: float = cup_x[c]
		var lift := 26.0 if lifted == c else 0.0
		if c == nut and lifted == c:
			draw_circle(Vector2(x, Y - 2), 7, Pal.G4)
			draw_circle(Vector2(x, Y - 2), 3, Pal.BG)
		var top := Y - 52 - lift
		var pts := PackedVector2Array([Vector2(x - 20, top), Vector2(x + 20, top), Vector2(x + 30, Y + 4 - lift), Vector2(x - 30, Y + 4 - lift)])
		draw_colored_polygon(pts, Pal.G2)
		draw_polyline(pts + PackedVector2Array([pts[0]]), Pal.G4, 1.0)
		draw_line(Vector2(x - 26, Y - 12 - lift), Vector2(x + 26, Y - 12 - lift), Pal.R2, 2.0)
