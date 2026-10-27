extends Control
## Полоса опыта Гения в правом нижнем углу (как в Fallout 3): уровень, опыт, всплывающее «+N».

var lab: Label
var gain: Label
var shown := 0.0


func _ready() -> void:
	position = Vector2(496, 342)
	size = Vector2(138, 14)
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = "Опыт Гения: бои, тайники, подработки, новые друзья и помощь жителям."
	lab = Pal.label("", Pal.G4, 8)
	lab.position = Vector2(0, -12)
	lab.size = Vector2(138, 12)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lab.add_theme_color_override("font_outline_color", Pal.BG)
	lab.add_theme_constant_override("outline_size", 3)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lab)
	gain = Pal.label("", Pal.G5, 8)
	gain.position = Vector2(0, -24)
	gain.size = Vector2(138, 12)
	gain.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gain.add_theme_color_override("font_outline_color", Pal.BG)
	gain.add_theme_constant_override("outline_size", 3)
	gain.modulate.a = 0.0
	gain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gain)
	G.changed.connect(_refresh)
	G.xp_gained.connect(_on_gain)
	shown = _frac()
	_refresh()


func _frac() -> float:
	return clampf(float(G.p.get("xp", 0)) / float(G.xp_need()), 0.0, 1.0)


func _refresh() -> void:
	if G.p.is_empty():
		return
	lab.text = "УР. %d · %d/%d" % [int(G.p.get("level", 1)), int(G.p.get("xp", 0)), G.xp_need()]
	queue_redraw()


func _on_gain(n: int) -> void:
	gain.text = "+%d опыта" % n
	gain.position.y = -24
	var tw := gain.create_tween()
	tw.tween_property(gain, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(gain, "position:y", -30.0, 1.2)
	tw.tween_property(gain, "modulate:a", 0.0, 0.5)


func _process(delta: float) -> void:
	var f := _frac()
	if absf(f - shown) > 0.002:
		# после нового уровня полоса не уезжает назад, а сразу начинается с нуля
		shown = f if f < shown else move_toward(shown, f, delta * 0.8)
		queue_redraw()
	# выбор навыка ждёт, пока не закроются окна
	if int(G.p.get("picks", 0)) > 0 and not G.main().has_overlay() and not get_tree().paused:
		G.main().open_skill_pick()


func _draw() -> void:
	draw_rect(Rect2(0, 3, size.x, 7), Pal.BG)
	draw_rect(Rect2(1, 4, (size.x - 2) * shown, 5), Pal.G3)
	draw_rect(Rect2(0, 3, size.x, 7), Pal.G2, false, 1)
	for i in range(1, 10):
		var x := size.x * i / 10.0
		draw_line(Vector2(x, 4), Vector2(x, 9), Color(Pal.BG, 0.6), 1)
