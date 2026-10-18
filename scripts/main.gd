extends Node
## Корень игры: переключает экраны, держит слой ЭЛТ и оверлеи.

const Title := preload("res://scripts/title.gd")
const Creator := preload("res://scripts/creator.gd")
const World := preload("res://scripts/world.gd")
const Combat := preload("res://scripts/combat.gd")
const Dialogue := preload("res://scripts/dialogue.gd")
const Pager := preload("res://scripts/pager.gd")
const Shop := preload("res://scripts/shop.gd")
const WorldMap := preload("res://scripts/worldmap.gd")

var screen_root: Node
var ui: Control
var overlay: Control
var crt: ColorRect
var current: Node
var world: Node2D
var crt_on := true
var fullscreen := true

const CRT_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float curve = 0.014;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	// Изгиб «кинескопа» сжат так, чтобы углы картинки оставались на экране целиком.
	uv = 0.5 + (c + c * dot(c, c) * curve * 4.0) / (1.0 + curve * 2.0);
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec2 px = SCREEN_PIXEL_SIZE;
		vec3 col = texture(screen_texture, uv).rgb;
		vec3 glow = texture(screen_texture, uv + vec2(px.x * 2.0, 0.0)).rgb
			+ texture(screen_texture, uv - vec2(px.x * 2.0, 0.0)).rgb
			+ texture(screen_texture, uv + vec2(0.0, px.y * 2.0)).rgb;
		col += glow * 0.07;
		float lines = 1.0 / px.y / 3.0;
		float scan = 0.84 + 0.16 * sin(uv.y * lines * 6.2831);
		col *= scan;
		col *= 1.0 - dot(c, c) * 1.1;
		col *= 0.97 + 0.03 * sin(TIME * 7.0);
		COLOR = vec4(col, 1.0);
	}
}
"""


func _ready() -> void:
	G.set_meta("main", self)
	screen_root = Node.new()
	add_child(screen_root)

	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 5
	add_child(ui_layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = Pal.theme
	ui_layer.add_child(ui)

	var ov_layer := CanvasLayer.new()
	ov_layer.layer = 8
	add_child(ov_layer)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.theme = Pal.theme
	ov_layer.add_child(overlay)

	var crt_layer := CanvasLayer.new()
	crt_layer.layer = 20
	add_child(crt_layer)
	crt = ColorRect.new()
	crt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = CRT_SHADER
	mat.shader = sh
	crt.material = mat
	crt_layer.add_child(crt)
	_load_settings()

	show_title()
	if OS.get_environment("GP_SMOKE") == "1":
		var sm = load("res://tests/smoke.gd").new()
		add_child(sm)
		sm.run(self)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
			set_fullscreen(not fullscreen)
			get_viewport().set_input_as_handled()


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		crt_on = cfg.get_value("video", "crt", true)
		fullscreen = cfg.get_value("video", "fullscreen", true)
	crt.visible = crt_on
	if OS.get_environment("GP_SMOKE") == "1":
		fullscreen = false
	_apply_window()


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "crt", crt_on)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.save("user://settings.cfg")


func set_crt(on: bool) -> void:
	crt_on = on
	crt.visible = on
	_save_settings()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply_window()
	_save_settings()


## Полный экран или окно, которое целиком помещается на мониторе (с учётом масштаба Windows).
func _apply_window() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var scr := DisplayServer.window_get_current_screen()
	var area := DisplayServer.screen_get_usable_rect(scr)
	if area.size.x <= 0 or area.size.y <= 0:
		return
	# Самый крупный масштаб 640×360, который влезает с запасом под рамку окна и панель задач.
	var f := minf((area.size.x - 32) / 640.0, (area.size.y - 64) / 360.0)
	if OS.get_environment("GP_SMOKE") == "1":
		f = 2.0
	f = maxf(0.75, f)
	var sz := Vector2i(roundi(640 * f), roundi(360 * f))
	DisplayServer.window_set_size(sz)
	DisplayServer.window_set_position(area.position + (area.size - sz) / 2)


func _clear() -> void:
	for c in overlay.get_children():
		c.queue_free()
	for c in ui.get_children():
		c.queue_free()
	for c in screen_root.get_children():
		c.queue_free()
	world = null
	current = null


func show_title() -> void:
	_clear()
	current = Title.new()
	ui.add_child(current)


func show_creator() -> void:
	_clear()
	current = Creator.new()
	ui.add_child(current)


## Войти в мир (на карту map). spawn: имя точки появления или пусто — позиция из сохранения.
func show_map() -> void:
	_clear()
	G.p.map = "worldmap"
	current = WorldMap.new()
	ui.add_child(current)
	G.autosave()


func show_world(map: String, spawn: String = "") -> void:
	if map == "worldmap" or map == "map":
		show_map()
		return
	if map == "caldera":
		map = "caldera1"
		if spawn == "":
			spawn = "surface"
	_clear()
	G.p.map = map
	world = World.new()
	world.setup(map, spawn)
	screen_root.add_child(world)
	current = world
	G.autosave()


func has_overlay() -> bool:
	for c in overlay.get_children():
		if not c.is_queued_for_deletion():
			return true
	return false


func open_dialogue(node_id: String, on_close: Callable = Callable()) -> void:
	var d := Dialogue.new()
	d.on_close = on_close
	overlay.add_child(d)
	d.start(node_id)


func open_pager(tab: int = 0) -> void:
	if has_overlay():
		return
	var pg := Pager.new()
	pg.tab = tab
	overlay.add_child(pg)


func open_shop(stock: Array) -> void:
	var s := Shop.new()
	s.stock = stock
	overlay.add_child(s)


## Бой на отдельном экране. on_end(result: String) — "win", "fled", "down", "dead".
func start_combat(enemy_id: String, on_end: Callable) -> void:
	var cb := Combat.new()
	cb.enemy_id = enemy_id
	cb.on_end = on_end
	overlay.add_child(cb)
	if world:
		world.set_paused(true)


## Бой из сцены или с карты мира. После победы открывается узел win_node (если задан).
func battle(enemy_id: String, win_node: String = "", job_id: String = "") -> void:
	start_combat(enemy_id, _battle_end.bind(win_node, job_id))


func _battle_end(result: String, win_node: String, job_id: String) -> void:
	match result:
		"dead":
			game_over("Гений %s погиб в Пустоши. Тело так и не нашли." % G.p.callsign)
			return
		"down":
			var lost := int(G.p.su * 0.25)
			G.p.su -= lost
			G.say("Гений очнулся в пыли. Кто-то обчистил карманы: −%d Су." % lost)
		"win":
			if job_id != "":
				G.job_found(job_id)
			if win_node != "":
				open_dialogue(win_node)
	if world:
		world.set_paused(false)
	G.changed.emit()


## «Изучать пустошь»: прогулка с исходом — новое место, бой, находка или пусто.
func explore() -> void:
	if has_overlay():
		return
	var r := G.explore_roll()
	G.phobia_open(3)
	var txt := ""
	var red := Pal.hex(Pal.R3)
	# «Паранойя» предупреждает о засаде, но каждое третье предупреждение ложное.
	var warn := false
	if G.trait_has("Паранойя"):
		var n := int(G.p.flags.get("paranoia_n", 0))
		if r.kind == "fight" and n % 3 != 2:
			warn = true
			G.p.flags["paranoia_n"] = n + 1
		elif r.kind in ["empty", "loot"] and n % 3 == 2:
			G.p.flags["paranoia_n"] = n + 1
			txt = "[color=%s][Паранойя][/color] [i]Это ловушка. За тем барханом кто-то есть.[/i]\n\nВы долго лежите в пыли и ждёте. Никого.\n\n" % red
	match r.kind:
		"poi":
			if G.trait_has("Любопытство"):
				txt += "[color=%s][Любопытство][/color] [i]Там что-то есть. Ну же, сверни туда.[/i]\n\n" % red
			txt += "Гений бродит по барханам и выходит к месту, которого нет на старых картах: [b]%s[/b].\n\n%s\n\n[color=#7ff07a](Место отмечено на карте мира.)[/color]" % [D.LOCS[r.id].name, D.LOCS[r.id].desc]
			G.say("Найдено новое место: %s." % D.LOCS[r.id].name)
		"fight":
			txt = "Через час ходьбы ветер доносит запах псины и пота. Из-за руин выходит %s." % D.ENEMIES[r.enemy].name.to_lower()
			var chs: Array = [{"t": "К бою!", "fx": [["battle", r.enemy]], "next": "end"}]
			if warn:
				txt = "[color=%s][Паранойя][/color] [i]Это ловушка. Не иди туда.[/i]\n\nВы замираете за обломком стены. Впереди %s ждёт в засаде, но вас не заметил." % [red, D.ENEMIES[r.enemy].name.to_lower()]
				chs = [{"t": "Обойти засаду стороной", "next": "end"}, {"t": "Напасть первым", "fx": [["battle", r.enemy]], "next": "end"}]
			G.temp_nodes["explore"] = {"who": "", "text": txt, "choices": chs}
			open_dialogue("explore")
			return
		"loot":
			var w: Array = r.what
			var what: String = "%d Су в чужом кошельке" % w[1] if w[0] == "su" else "%s ×%d" % [w[0], w[1]]
			txt += "Под ржавым листом железа кто-то устроил тайник и не вернулся за ним.\n\n[color=#7ff07a](Найдено: %s)[/color]" % what
			G.say("Найдено в Пустоши: %s." % what)
		_:
			txt += ["Два часа ходьбы, пепел на зубах и ничего нового. Пустошь умеет быть скучной.",
				"Вы находите только старый указатель «КАЛЬДЕРА 2 КМ» и собственные следы.",
				"Где-то далеко гремит. Небо над руинами на миг становится зелёным, потом снова серым."].pick_random()
	G.temp_nodes["explore"] = {"who": "", "text": txt, "choices": [{"t": "Дальше", "next": "end"}]}
	open_dialogue("explore")


func game_over(text: String) -> void:
	_clear()
	var root := ColorRect.new()
	root.color = Pal.BG
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(root)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(360, 0)
	box.add_theme_constant_override("separation", 6)
	center.add_child(box)
	box.add_child(Pal.label("ЗАПИСЬ ГЕНИЯ ЗАКРЫТА", Pal.R2, 20, true))
	var t := Pal.rich(text, 10)
	t.custom_minimum_size = Vector2(360, 0)
	box.add_child(t)
	var cond := Pal.label("Институт по Этике выражает соболезнования и напоминает: пейджер подлежит возврату.", Pal.G2, 9)
	cond.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cond.custom_minimum_size = Vector2(360, 0)
	box.add_child(cond)
	var last := G.any_save()
	if last >= 0:
		var b := Pal.button("Загрузить последнее сохранение", load_and_play.bind(last))
		b.tooltip_text = "%s: %s" % [G.slot_name(last), G.slot_info(last)]
		box.add_child(b)
		box.add_child(Pal.label("%s · %s" % [G.slot_name(last), G.slot_info(last)], Pal.G3, 8))
	box.add_child(Pal.button("В главное меню", show_title))


func load_and_play(i: int) -> void:
	if G.load_slot(i):
		show_world(G.p.map)
