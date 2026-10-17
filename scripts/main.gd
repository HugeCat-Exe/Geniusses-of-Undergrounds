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

const CRT_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float curve = 0.025;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	uv = uv + c * dot(c, c) * curve * 4.0;
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
			var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
			get_viewport().set_input_as_handled()


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		crt_on = cfg.get_value("video", "crt", true)
	crt.visible = crt_on


func set_crt(on: bool) -> void:
	crt_on = on
	crt.visible = on
	var cfg := ConfigFile.new()
	cfg.set_value("video", "crt", on)
	cfg.save("user://settings.cfg")


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


func show_world(map: String, spawn: String = "") -> void:
	if map == "worldmap" or map == "map":
		show_map()
		return
	_clear()
	G.p.map = map
	world = World.new()
	world.setup(map, spawn)
	screen_root.add_child(world)
	current = world


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


func game_over(text: String) -> void:
	_clear()
	var root := ColorRect.new()
	root.color = Pal.BG
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(root)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(170, 90)
	box.custom_minimum_size = Vector2(300, 0)
	root.add_child(box)
	box.add_child(Pal.label("ЗАПИСЬ ГЕНИЯ ЗАКРЫТА", Pal.R2, 20, true))
	var t := Pal.rich(text, 10)
	t.custom_minimum_size = Vector2(300, 0)
	box.add_child(t)
	box.add_child(Pal.label("Институт по Этике выражает соболезнования\nи напоминает: пейджер подлежит возврату.", Pal.G2, 9))
	var last := G.any_save()
	if last >= 0:
		box.add_child(Pal.button("Загрузить последнее сохранение", load_and_play.bind(last)))
	box.add_child(Pal.button("В главное меню", show_title))


func load_and_play(i: int) -> void:
	if G.load_slot(i):
		show_world(G.p.map)
