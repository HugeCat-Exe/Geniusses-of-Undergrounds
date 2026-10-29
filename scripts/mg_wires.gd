extends Control
## Генератор, узел 1: соединить провода по схеме.
## Слева клеммы со значками, справа гнёзда с номерами, наверху схема «значок – номер».
## Ошибка бьёт током; время зависит от Механики.

signal done(ok: bool)

const N := 4
const LX := 190.0
const RX := 450.0

var shapes := [0, 1, 2, 3]     # значок клеммы слева (по порядку сверху вниз)
var need := [0, 1, 2, 3]       # номер гнезда для каждого значка
var linked := {}               # клемма -> гнездо
var pick := -1
var t := 0.0
var limit := 18.0
var over := false
var ok := false
var info: Label
var auto := OS.get_environment("GP_SMOKE") != ""
var auto_t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var skill := G.skill_bonus("Механика")
	limit = clampf(18.0 + skill * 2.5, 10.0, 30.0)
	shapes.shuffle()
	need.shuffle()
	var title := Pal.label("СОЕДИНИТЬ ПРОВОДА ПО СХЕМЕ", Pal.G5, 14, true)
	title.position = Vector2(0, 30)
	title.size = Vector2(640, 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	info = Pal.label("Щёлкните клемму слева, потом гнездо справа: значок к номеру, как на схеме. Ошибка бьёт током. Время зависит от Механики (%+d)." % skill, Pal.G4, 9)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.position = Vector2(60, 54)
	info.size = Vector2(520, 30)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(info)


func _ly(i: int) -> float:
	return 150.0 + i * 42.0


func _gui_input(ev: InputEvent) -> void:
	if over or not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	var p: Vector2 = ev.position
	for i in N:
		if p.distance_to(Vector2(LX, _ly(i))) < 14.0 and not linked.has(i):
			pick = i
			return
		if p.distance_to(Vector2(RX, _ly(i))) < 14.0 and pick >= 0:
			_link(pick, i)
			return


func _link(i: int, socket: int) -> void:
	if need[shapes[i]] != socket:
		_finish(false)
		return
	linked[i] = socket
	pick = -1
	if linked.size() >= N:
		_finish(true)


func _process(delta: float) -> void:
	if over:
		return
	t += delta
	if auto:
		auto_t += delta
		if auto_t > 0.3:
			auto_t = 0.0
			for i in N:
				if not linked.has(i):
					_link(i, need[shapes[i]])
					break
	if not over and t >= limit:
		_finish(false)
	queue_redraw()


func _finish(win: bool) -> void:
	over = true
	ok = win
	info.text = "Провода на месте. Узел ожил." if win else "Треск, искры, запах палёной изоляции."
	queue_redraw()
	await get_tree().create_timer(0.9).timeout
	done.emit(win)
	queue_free()


func _shape(c: Vector2, s: int, col: Color) -> void:
	match s:
		0:
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, 5), c + Vector2(-6, 5)]), col)
		1:
			draw_rect(Rect2(c - Vector2(5, 5), Vector2(10, 10)), col)
		2:
			draw_circle(c, 6.0, col)
		3:
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(6, 0), c + Vector2(0, 7), c + Vector2(-6, 0)]), col)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(640, 360)), Color(Pal.BG, 0.95))
	var font: Font = Pal.font_bold
	# схема
	draw_rect(Rect2(230, 92, 180, 34), Pal.G0)
	draw_rect(Rect2(230, 92, 180, 34), Pal.G2, false, 1.0)
	for s in N:
		var c := Vector2(252 + s * 42, 109)
		_shape(c - Vector2(8, 0), s, Pal.G4)
		draw_string(font, c + Vector2(2, 4), str(need[s] + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Pal.G5)
	# клеммы и гнёзда
	for i in N:
		var l := Vector2(LX, _ly(i))
		var r := Vector2(RX, _ly(i))
		draw_rect(Rect2(l - Vector2(13, 11), Vector2(26, 22)), Pal.G1 if i != pick else Pal.G3)
		_shape(l, shapes[i], Pal.G5 if not linked.has(i) else Pal.G2)
		draw_rect(Rect2(r - Vector2(13, 11), Vector2(26, 22)), Pal.G1)
		draw_string(font, r + Vector2(-4, 5), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.G5)
	for i in linked:
		var a := Vector2(LX + 13, _ly(i))
		var b := Vector2(RX - 13, _ly(linked[i]))
		draw_line(a, b, Pal.G4, 3.0)
	if pick >= 0:
		draw_line(Vector2(LX + 13, _ly(pick)), get_local_mouse_position(), Color(Pal.G4, 0.6), 2.0)
	var left := clampf(1.0 - t / limit, 0.0, 1.0)
	draw_rect(Rect2(170, 330, 300, 6), Pal.G1)
	draw_rect(Rect2(170, 330, 300 * left, 6), Pal.G4 if left > 0.3 else Pal.R2)
	if over and not ok:
		draw_rect(Rect2(Vector2.ZERO, Vector2(640, 360)), Color(Pal.R2, 0.18))
