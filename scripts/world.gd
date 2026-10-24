extends Node2D
## Изометрическая карта: ходьба мышью и клавишами, NPC, предметы, монстры, HUD.

const Maps := preload("res://scripts/maps.gd")
const ArtLib := preload("res://scripts/art.gd")
const WALLS := {"#": "panel", "B": "brick", "R": "ruin"}
const FLOORS := {".": "metal", ",": "concrete", "_": "tile", "=": "rug", "s": "sand", "a": "ash",
	"g": "grate", "/": "stairs", "p": "plaza", "k": "asphalt", "w": "water", "h": "planks", "m": "moss"}
const SPEED := 5.5

var map: Dictionary
var grid: Array
var W := 0
var H := 0
var waste := false
var light := 12.0
var astar := AStarGrid2D.new()
var floors: Array = []
var walls: Array = []
var objs: Array = []
var mobs: Array = []
var obj_at := {}
var voids: Array = []
var depth := 0
var mate_pos := Vector2.ZERO
var mate_trail: Array = []
var esc_pos := Vector2.ZERO   # спасённый бедолага идёт следом
var esc_trail: Array = []
# у спутников своё направление взгляда и шаг: раньше они разворачивались вместе с Гением и «дёргались»
var mate_flip := false
var esc_flip := false
var mate_walk := 0.0
var esc_walk := 0.0
var clock_t := 0.0
var night_rect: ColorRect
var night_amt := 0.0

## Ночь в Пустоши: окружение будто вывернуто наизнанку, по краям лёгкие тени.
const NIGHT_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float amount = 1.0;
void fragment() {
	vec3 c = texture(screen_texture, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 bg = vec3(0.02, 0.05, 0.027);
	float inv = l < 0.08 ? 0.0 : 1.0 - l;
	vec3 night = mix(bg, vec3(0.24, 0.62, 0.27), inv * 0.72);
	if (c.r > c.g * 1.4) {
		night = mix(night, c, 0.6);
	}
	vec2 d = (SCREEN_UV - vec2(0.5, 0.47)) * vec2(1.78, 1.0);
	float v = smoothstep(0.22, 0.95, length(d));
	night *= 1.0 - v * 0.6;
	COLOR = vec4(mix(c, night, amount), 1.0);
}
"""

const Live := preload("res://scripts/live.gd")
const MIND_WORLD := [
	"Тени по углам стали чуть гуще. Вы стараетесь на них не смотреть.",
	"Пол под ногами иногда пружинит. Вы делаете вид, что не замечаете.",
	"Шаги за спиной повторяют ваши. Когда вы останавливаетесь, они тоже.",
	"Мир дрожит по краям, как картинка на старом экране. Нужен отдых. Или успокоительное.",
	"Вы забываете, куда шли, а потом и зачем. Рассудок вот-вот лопнет.",
]

const WEATHER_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float dust = 0.0;
uniform float rain = 0.0;
uniform float reach = 0.3;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	vec3 c = texture(screen_texture, SCREEN_UV).rgb;
	vec2 d = (SCREEN_UV - vec2(0.5, 0.47)) * vec2(1.78, 1.0);
	float r = length(d);
	float nn = n(SCREEN_UV * vec2(7.0, 4.0) + vec2(TIME * 0.8, TIME * 0.12)) * 0.6 + n(SCREEN_UV * vec2(24.0, 14.0) + vec2(TIME * 2.4, 0.0)) * 0.4;
	vec3 dc = vec3(0.40, 0.38, 0.20) * (0.7 + nn * 0.5);
	float k = clamp(smoothstep(reach * 0.4, reach + 0.25, r) * 0.92 + nn * 0.2, 0.0, 0.96);
	c = mix(c, dc, k * dust);
	vec2 uv = SCREEN_UV + vec2(SCREEN_UV.y * 0.08, 0.0);
	float col = floor(uv.x * 170.0);
	float sp = 0.9 + h(vec2(col, 1.0)) * 0.8;
	float y = fract(uv.y * 2.5 - TIME * sp * 1.4 + h(vec2(col, 7.0)));
	float streak = step(fract(uv.x * 170.0), 0.4) * step(y, 0.045) * step(0.6, h(vec2(col, 3.0)));
	c = mix(c * (1.0 - 0.15 * rain), vec3(0.62, 0.9, 0.38), streak * rain * 0.6);
	COLOR = vec4(c, 1.0);
}
"""

var tracker: RichTextLabel
var wx_rect: ColorRect = null
var wx := "clear"          # погода на этой карте сейчас
var wx_amt := Vector2.ZERO # x — пыль, y — дождь (плавно)
var wx_ok := false         # прошёл проверку «Погоды» на эту бурю/дождь
var acid_t := 0.0

var ppos := Vector2i.ZERO
var pf := Vector2.ZERO
var path: Array = []
var pending = null
var anim_t := 0.0
var frame := 0
var flip := false
var mob_t := 0.0
var cur_mob = null
var cam: Camera2D
var shake_amt := 0.0      # толчок камеры, гаснет сам
var wt := 0.0             # время на карте: для «дыхания», мерцания ламп и пыли
var motes: Array = []     # пылинки (в Кальдере) или песок (в Пустоши)
var puffs: Array = []     # облачка пыли из-под ног
var cam_look := Vector2.ZERO
var enc_wait := 0.0       # пауза между «!» над врагом и началом боя
var cut_active := false   # идёт катсцена: управление у сценария
var cam_override = null   # клетка, куда смотрит камера в катсцене
var emotes := {}          # кто -> [значок, сколько ещё висит]
var dark := false         # подвал (ярусы 5–6): всегда ночь, свет только у ламп
var lamp_pos: Array = []
const GLOWS := ["lamp", "neon", "terminal", "jobscreen", "autodoc", "bar", "lift"]

var hud: Control
var hud_text: RichTextLabel
var log_text: RichTextLabel
var hover: Label
var place: Label


func setup(map_name: String, spawn: String) -> void:
	map = Maps.new().get_map(map_name)
	grid = map.floor
	H = grid.size()
	W = grid[0].size()
	waste = map.waste
	light = map.light
	depth = map.get("depth", 0)
	dark = map.get("dark", false)
	astar.region = Rect2i(0, 0, W, H)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	var wall_h := 14 if waste else 22
	for y in H:
		for x in W:
			var ch: String = grid[y][x]
			if ch == " ":
				astar.set_point_solid(Vector2i(x, y), true)
			elif ch == "v":
				astar.set_point_solid(Vector2i(x, y), true)
				voids.append({"pos": Vector2i(x, y), "tex": Art.floor_tex("plaza" if depth == 1 else "concrete", (x * 3 + y) % 3)})
			elif WALLS.has(ch):
				astar.set_point_solid(Vector2i(x, y), true)
				walls.append({"pos": Vector2i(x, y), "tex": Art.wall_tex(WALLS[ch], wall_h, (x * 7 + y * 3) % 4)})
			else:
				floors.append({"pos": Vector2i(x, y), "tex": Art.floor_tex(FLOORS.get(ch, "metal"), (x * 5 + y * 11) % 3)})
				if ch == "w":
					astar.set_point_solid(Vector2i(x, y), true)
	for o in map.objs:
		if o.type == "mob":
			if o.id in G.p.killed:
				continue
			var m: Dictionary = o.duplicate()
			m.pos = Vector2i(o.x, o.y)
			m.fpos = Vector2(o.x, o.y)
			m.stun = 0.0
			m.home = m.pos
			mobs.append(m)
			continue
		var ob: Dictionary = o.duplicate()
		ob.pos = Vector2i(o.x, o.y)
		ob.kind = str(o.get("tex", ""))
		ob.ph = float(absi(hash(str(o.get("id", o.title)) + str(o.x))) % 1000) / 159.0
		if ob.type == "npc":
			ob.tex = Art.person_tex(ob.look)
		else:
			ob.tex = Art.prop_tex(o.tex)
		objs.append(ob)
		# Большие предметы (автобус, вышка) занимают несколько клеток: o.w по x, o.h по y.
		for t in _cells(ob):
			obj_at[t] = ob
			if ob.block:
				astar.set_point_solid(t, true)
	for ob in objs:
		if ob.get("kind", "") == "lamp":
			lamp_pos.append(Vector2(ob.pos))
	if spawn != "" and map.spawns.has(spawn):
		ppos = map.spawns[spawn]
	else:
		ppos = Vector2i(G.p.pos[0], G.p.pos[1])
		# Старое сохранение с прежней, большой картой: ставим Гения на ближайшую точку появления.
		if not in_bounds(ppos) or astar.is_point_solid(ppos):
			ppos = map.spawns.values()[0]
	pf = Vector2(ppos)
	G.p.pos = [ppos.x, ppos.y]
	_place_job_spots()
	if not waste:
		_sched_tick(0.0)
	mate_pos = pf + Vector2(-1, 0)
	esc_pos = pf + Vector2(0, -1)


## Вещи для подработок «найти» лежат не в одном месте, а в случайном углу локации
## (своём для каждого задания): нужно пройтись и поискать.
func _place_job_spots() -> void:
	var poi: String = map.get("poi", "")
	if poi == "":
		return
	for j in G.p.jobs:
		if j.kind != "find" or j.state != "active" or not j.get("spot", false) or j.poi != poi:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(j.id) + "spot")
		var cands: Array = []
		for f in floors:
			var t: Vector2i = f.pos
			if obj_at.has(t) or astar.is_point_solid(t) or _cheb(t, ppos) < 5:
				continue
			var open := true
			for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not walkable(t + dv):
					open = false
			if open and astar.get_id_path(ppos, t).size() > 0:
				cands.append(t)
		if cands.is_empty():
			continue
		var t: Vector2i = cands[rng.randi() % cands.size()]
		var ob := {"type": "prop", "tex": Art.prop_tex("cache"), "title": "Тайник: %s?" % j.item, "action": "jobspot:" + str(j.id),
			"block": false, "pos": t, "x": t.x, "y": t.y, "reach": 1}
		objs.append(ob)
		obj_at[t] = ob


# ---------------- катсцены ----------------

## Найти участника сцены: житель на карте по id.
func cut_find(who: String) -> Variant:
	for o in objs:
		if o.type == "npc" and o.get("id", "") == who:
			return o
	return null


func add_cut_actor(who: String, t: Vector2i) -> void:
	if cut_find(who) != null:
		return
	var ob := {"type": "npc", "id": who, "pos": t, "x": t.x, "y": t.y, "title": preload("res://scripts/story.gd").WHO.get(who, {}).get("name", who),
		"action": "", "block": false, "reach": 1, "look": Maps.NPC_LOOKS[who].person, "kind": "", "ph": 0.0, "cut_temp": true}
	ob.tex = Art.person_tex(ob.look)
	objs.append(ob)
	obj_at[t] = ob


func remove_cut_actor(o) -> void:
	if o == null:
		return
	objs.erase(o)
	if obj_at.get(o.pos) == o:
		obj_at.erase(o.pos)
	if o.get("block", false):
		astar.set_point_solid(o.pos, false)


func cut_face(who: String, left: bool) -> void:
	if who == "genius":
		flip = left
	elif who == "mate":
		mate_flip = left
	else:
		var o = cut_find(who)
		if o != null:
			o["face"] = left


func cut_emote(who: String, e: String) -> void:
	emotes[who] = [e, 1.4]


## Пройти к клетке по-настоящему, клетка за клеткой.
func cut_walk(who: String, t: Vector2i) -> void:
	if who == "genius":
		_path_to(t)
		while not path.is_empty() and is_inside_tree():
			await get_tree().process_frame
		return
	if who == "mate":
		for c in astar.get_id_path(Vector2i(mate_pos.round()), t):
			while mate_pos.distance_to(Vector2(c)) > 0.01:
				var r := _follow(mate_pos, Vector2(c), get_process_delta_time() * SPEED * 0.8, mate_flip)
				mate_pos = r[0]
				mate_flip = r[1]
				mate_walk += get_process_delta_time()
				await get_tree().process_frame
		mate_walk = 0.0
		return
	var o = cut_find(who)
	if o == null:
		return
	var was_solid: bool = o.get("block", false)
	astar.set_point_solid(o.pos, false)
	obj_at.erase(o.pos)
	var ids := astar.get_id_path(o.pos, t)
	var fp := Vector2(o.pos)
	for i in range(1, ids.size()):
		var c := Vector2(ids[i])
		var lr := (c - fp).x - (c - fp).y
		if absf(lr) > 0.05:
			o["face"] = lr < 0
		while fp.distance_to(c) > 0.01:
			fp = fp.move_toward(c, get_process_delta_time() * SPEED * 0.6)
			o["cpos"] = fp
			o["walk"] = o.get("walk", 0.0) + get_process_delta_time()
			await get_tree().process_frame
	o.pos = t
	o.erase("cpos")
	o["walk"] = 0.0
	obj_at[t] = o
	if was_solid:
		astar.set_point_solid(t, true)


## Сердце готово и сцена происходит здесь: запускаем.
func _check_heart() -> void:
	var h = G.heart_here(G.p.map)
	if h == null:
		return
	play_cutscene(h.scene, func(): G.heart_done(h.who))


func play_cutscene(list: Array, on_done: Callable = Callable()) -> void:
	var cs = preload("res://scripts/cutscene.gd").new()
	add_child(cs)
	if on_done.is_valid():
		cs.finished.connect(on_done)
	cs.play(self, list)


func _ready() -> void:
	cam = Camera2D.new()
	add_child(cam)
	cam.position = iso(pf) + Vector2(0, -10)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	cam.reset_smoothing.call_deferred()
	_init_motes()
	_check_heart.call_deferred()
	cam.position_smoothing_speed = 8.0
	_build_hud()
	if waste:
		var nl := CanvasLayer.new()
		nl.layer = 2
		add_child(nl)
		night_rect = ColorRect.new()
		night_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		night_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = NIGHT_SHADER
		mat.shader = sh
		night_rect.material = mat
		nl.add_child(night_rect)
		night_amt = 1.0 if G.is_night() else 0.0
		night_rect.visible = night_amt > 0.0
		if G.is_night():
			G.say("Ночь. Пустошь выворачивается наизнанку, и врагов в темноте не видно.")
		wx_rect = ColorRect.new()
		wx_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		wx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var wm := ShaderMaterial.new()
		var wsh := Shader.new()
		wsh.code = WEATHER_SHADER
		wm.shader = wsh
		wx_rect.material = wm
		nl.add_child(wx_rect)
		_weather_change(true)
	G.changed.connect(_update_hud)
	G.logged.connect(func(_t): _update_log())
	_update_hud()
	_update_log()
	if not G.flag("intro"):
		G.set_flag("intro")
		G.main().open_dialogue.call_deferred("intro")
	elif waste and not G.flag("waste_seen"):
		G.set_flag("waste_seen")
		G.say("Ветер несёт пепел. Где-то воют псы.")


func iso(v: Vector2) -> Vector2:
	return Vector2((v.x - v.y) * 16.0, (v.x + v.y) * 8.0)


func to_grid(w: Vector2) -> Vector2i:
	var gx := (w.x / 16.0 + w.y / 8.0) / 2.0
	var gy := (w.y / 8.0 - w.x / 16.0) / 2.0
	return Vector2i(roundi(gx), roundi(gy))


func _cells(o: Dictionary) -> Array:
	var res: Array = []
	for dy in int(o.get("h", 1)):
		for dx in int(o.get("w", 1)):
			res.append(Vector2i(o.pos) + Vector2i(dx, dy))
	return res


## Расстояние от клетки до предмета с учётом его размера.
func _odist(o: Dictionary, t: Vector2i) -> int:
	var best := 99
	for c in _cells(o):
		best = mini(best, _cheb(c, t))
	return best


func in_bounds(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < W and t.y < H


func walkable(t: Vector2i) -> bool:
	return in_bounds(t) and not astar.is_point_solid(t)


func set_paused(_v: bool) -> void:
	path.clear()


func blocked() -> bool:
	return cut_active or enc_wait > 0.0 or G.main().has_overlay()


# ---------------- ввод ----------------

func _unhandled_input(event: InputEvent) -> void:
	if blocked():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var t := to_grid(get_global_mouse_position())
		if not in_bounds(t):
			return
		var target = _target_at(t)
		if target != null:
			pending = target
			_path_near(target, target.get("reach", 1))
		elif walkable(t):
			pending = null
			_path_to(t)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB:
				G.main().open_pager(0)
			KEY_ESCAPE:
				G.main().open_pager(5)
			KEY_I:
				G.main().open_pager(1)
			KEY_E, KEY_SPACE, KEY_ENTER:
				_interact_near()


func _target_at(t: Vector2i):
	if has_mate() and Vector2i(mate_pos.round()) == t:
		var dn: bool = G.p.companion == "patrol"
		return {"type": "mate", "pos": t, "title": "Дана" if dn else "Рыжая", "reach": 1, "action": "dana_start" if dn else "ry_start"}
	for m in mobs:
		if m.pos == t:
			return m
	if obj_at.has(t):
		var o: Dictionary = obj_at[t]
		if o.type == "npc" or o.action != "":
			return o
	return null


func _path_to(t: Vector2i) -> void:
	var ids := astar.get_id_path(ppos, t)
	path = []
	for i in range(1, ids.size()):
		path.append(ids[i])


func _path_near(o: Dictionary, reach: int) -> void:
	if _odist(o, ppos) <= reach:
		path.clear()
		return
	var best: Array = []
	var tiles: Array = _cells(o)
	for t in tiles:
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var c: Vector2i = t + Vector2i(dx, dy)
				if c in tiles or not walkable(c):
					continue
				var ids := astar.get_id_path(ppos, c)
				if ids.size() > 0 and (best.is_empty() or ids.size() < best.size()):
					best = ids
	path = []
	for i in range(1, best.size()):
		path.append(best[i])


func has_escort() -> bool:
	var j = G.escort_job()
	return j != null and j.state == "escort"


func has_mate() -> bool:
	return G.p.get("companion", "") in ["ryzhaya", "patrol"]


func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _interact_near() -> void:
	var best = null
	var bd := 99
	for o in objs:
		if o.type != "npc" and o.action == "":
			continue
		var d := _odist(o, ppos)
		if d <= o.get("reach", 1) and d < bd:
			bd = d
			best = o
	if best != null:
		_interact(best)


func _interact(o: Dictionary) -> void:
	pending = null
	path.clear()
	flip = o.pos.x - o.pos.y < ppos.x - ppos.y
	if o.type == "mob":
		start_encounter(o)
		return
	if o.type == "mate":
		G.main().open_dialogue(o.action)
		return
	if o.action.begins_with("jobspot:"):
		var jid: String = o.action.get_slice(":", 1)
		var j = G.job_by_id(jid)
		objs.erase(o)
		for t in _cells(o):
			obj_at.erase(t)
		if j == null:
			return
		var risk := "\n\nНо рядом кто-то есть: %s." % D.ENEMIES[j.guard].name.to_lower() if j.guard != "" else ""
		G.temp_nodes["jobspot"] = {"who": "", "text": "Под ржавым листом, в куче хлама, что-то лежит. Похоже, это [b]%s[/b].%s" % [j.item, risk],
			"choices": [{"t": "Забрать", "fx": [["find_job", jid]], "next": "end"}]}
		G.main().open_dialogue("jobspot")
		return
	if o.action.begins_with("go:"):
		var parts: PackedStringArray = o.action.split(":")
		G.say("%s." % o.title)
		G.main().show_world.call_deferred(parts[1], parts[2])
		return
	G.main().open_dialogue(o.action)


# ---------------- цикл ----------------

func _process(delta: float) -> void:
	wt += delta
	if enc_wait > 0.0:
		enc_wait -= delta
		if enc_wait <= 0.0:
			enc_wait = 0.0
			_begin_encounter()
	shake_amt = move_toward(shake_amt, 0.0, delta * 9.0)
	cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amt
	for m in mobs:
		if m.get("alert", 0.0) > 0.0:
			m.alert -= delta
	_update_fx(delta)
	for k in emotes.keys():
		emotes[k][1] -= delta
		if emotes[k][1] <= 0.0:
			emotes.erase(k)
	if cut_active:
		_move(delta)
	var stop := blocked()
	if not stop:
		G.tick(delta)
		clock_t += delta
		if clock_t > 1.0:
			clock_t = 0.0
			_update_hud()
		_move(delta)
		mob_t += delta
		if mob_t >= 0.38:
			mob_t = 0.0
			_mobs_think()
	for m in mobs:
		m.fpos = m.fpos.move_toward(Vector2(m.pos), delta * 3.5)
		if m.stun > 0.0 and not stop:
			m.stun -= delta
	if has_mate() and not mate_trail.is_empty():
		var r := _follow(mate_pos, Vector2(mate_trail[0]), delta * SPEED * 0.95, mate_flip)
		mate_pos = r[0]
		mate_flip = r[1]
		mate_walk = mate_walk + delta if r[2] else 0.0
	if has_escort() and not esc_trail.is_empty():
		var r2 := _follow(esc_pos, Vector2(esc_trail[0]), delta * SPEED * 0.9, esc_flip)
		esc_pos = r2[0]
		esc_flip = r2[1]
		esc_walk = esc_walk + delta if r2[2] else 0.0
	# камера чуть забегает вперёд по ходу движения
	var look := Vector2.ZERO
	if not path.is_empty():
		look = (iso(Vector2(path[0])) - iso(pf)).normalized() * 14.0
	cam_look = cam_look.lerp(look, minf(1.0, delta * 2.5))
	cam.position = iso(pf) + Vector2(0, -10) + cam_look
	if cam_override != null:
		cam.position = iso(cam_override) + Vector2(0, -10)
	if wx_rect != null:
		_weather_tick(delta)
	# жители сами идут к ночным местам и обратно (sched.gd)
	if not waste and not cut_active:
		_sched_tick(0.0 if stop else delta)
	if night_rect != null:
		night_amt = move_toward(night_amt, 1.0 if G.is_night() else 0.0, delta * 0.5)
		night_rect.visible = night_amt > 0.01
		(night_rect.material as ShaderMaterial).set_shader_parameter("amount", night_amt)
	_update_hover()
	queue_redraw()


func _move(delta: float) -> void:
	if path.is_empty() and cut_active:
		return
	if path.is_empty():
		var dir := _key_dir()
		if dir != Vector2i.ZERO:
			var n := ppos + dir
			var diag_ok := dir.x == 0 or dir.y == 0 or (walkable(ppos + Vector2i(dir.x, 0)) and walkable(ppos + Vector2i(0, dir.y)))
			if walkable(n) and diag_ok:
				path.append(n)
				pending = null
		elif pending != null:
			var reach: int = pending.get("reach", 1)
			if _odist(pending, ppos) <= reach:
				_interact(pending)
			else:
				pending = null
		return
	var target: Vector2 = Vector2(path[0])
	if (target - pf).x - (target - pf).y != 0:
		flip = (target - pf).x - (target - pf).y < 0
	pf = pf.move_toward(target, delta * SPEED * (0.6 if G.starving() else 1.0))
	anim_t += delta
	if anim_t > 0.14:
		anim_t = 0.0
		frame = 1 - frame
	if pf.distance_to(target) < 0.001:
		mate_trail.append(ppos)
		if mate_trail.size() > 2:
			mate_trail.pop_front()
		esc_trail.append(ppos)
		if esc_trail.size() > (4 if has_mate() else 2):
			esc_trail.pop_front()
		ppos = path.pop_front()
		G.p.pos = [ppos.x, ppos.y]
		if waste or map.get("raid", false):
			for k in 2:
				puffs.append({"p": iso(pf) + Vector2(randf_range(-4, 4), randf_range(1, 3)), "t": 0.0, "v": Vector2(randf_range(-6, 6), randf_range(-5, -1))})
		_on_step()
		if path.is_empty():
			frame = 0


func _key_dir() -> Vector2i:
	var d := Vector2i.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		d += Vector2i(-1, -1)
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		d += Vector2i(1, 1)
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		d += Vector2i(-1, 1)
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		d += Vector2i(1, -1)
	return Vector2i(clampi(d.x, -1, 1), clampi(d.y, -1, 1))


func _on_step() -> void:
	G.step(waste)
	for m in mobs:
		if m.stun <= 0.0 and _cheb(m.pos, ppos) <= 1:
			path.clear()
			start_encounter(m)
			return


func _mobs_think() -> void:
	for m in mobs:
		if m.stun > 0.0:
			continue
		var d := _cheb(m.pos, ppos)
		if d <= 1:
			path.clear()
			start_encounter(m)
			return
		if D.ENEMIES[m.enemy].get("static", false):
			continue
		var goal: Vector2i = m.home
		if d <= m.aggro:
			goal = ppos
		if m.pos == goal:
			continue
		var ids := astar.get_id_path(m.pos, goal)
		if ids.size() > 1:
			var nxt: Vector2i = ids[1]
			var free := nxt != ppos
			for o in mobs:
				if o != m and o.pos == nxt:
					free = false
			if free:
				m.pos = nxt


# ---------------- встречи ----------------

func start_encounter(m: Dictionary) -> void:
	if blocked():
		return
	cur_mob = m
	# Рядом с врагом могут быть такие же: честно предупреждаем, что бой будет не один.
	var pack := _pack_of(m)
	if pack.size() > 0 and m.enemy != "muezzin":
		G.say("Осторожно: рядом ещё %s (%d). После этого боя они нападут следом." % [D.ENEMIES[pack[0].enemy].name.to_lower(), pack.size()])
		for o in pack:
			o["warned"] = true
	_alert(m)
	path.clear()
	pending = null
	enc_wait = 0.45


func _begin_encounter() -> void:
	var m = cur_mob
	if m == null or G.main().has_overlay():
		return
	if m.enemy == "padal" and not G.flag("talked_" + m.id):
		G.set_flag("talked_" + m.id)
		G.main().open_dialogue("raider_meet")
		return
	fight_current()


func fight_current() -> void:
	if cur_mob == null:
		return
	G.main().start_combat(cur_mob.enemy, _on_combat_end)


## Моб уходит без боя (откупились или запугали).
func spare_current() -> void:
	if cur_mob == null:
		return
	G.p.killed.append(cur_mob.id)
	mobs.erase(cur_mob)
	cur_mob = null


func _on_combat_end(result: String) -> void:
	var m = cur_mob
	cur_mob = null
	match result:
		"win":
			if m != null:
				G.p.killed.append(m.id)
				mobs.erase(m)
				_add_body(m)
				_after_win(m)
		"fled":
			if m != null:
				m.stun = 6.0
		"down":
			var lost := int(G.p.su * 0.25)
			G.p.su -= lost
			G.say("Вы очнулись в пыли. Кто-то взломал ваш пейджер и перевёл себе %d Су." % lost)
			if m != null:
				m.stun = 20.0
				m.pos = m.home
		"dead":
			G.main().game_over("Гений %s погиб в Пустоши. Тело так и не нашли." % G.p.callsign)
			return
	_update_hud()


## Другие подвижные враги в трёх клетках от этого.
func _pack_of(m: Dictionary) -> Array:
	var res: Array = []
	for o in mobs:
		if o != m and not D.ENEMIES[o.enemy].get("static", false) and _cheb(o.pos, m.pos) <= 3:
			res.append(o)
	return res


## После победы: соседям даётся передышка, чтобы новый бой не начался в ту же секунду.
## Без Муэдзина стая разбегается и не возвращается до завтра.
func _after_win(m: Dictionary) -> void:
	if m.enemy == "muezzin":
		var fled := 0
		for o in mobs.duplicate():
			if o.enemy == "pes":
				G.p.killed.append(o.id)
				mobs.erase(o)
				fled += 1
		if fled > 0:
			G.say("Лишившись Муэдзина, псы с визгом разбегаются по норам.")
		return
	var near := 0
	for o in mobs:
		if _cheb(o.pos, ppos) <= 3 and not D.ENEMIES[o.enemy].get("static", false):
			o.stun = maxf(o.stun, 2.5)
			near += 1
	if near > 0:
		G.say("Это был не последний: рядом ещё %d. Есть пара секунд, чтобы отойти." % near)


## «!» над врагом и короткий толчок камеры, когда он замечает Гения.
func _alert(m: Dictionary) -> void:
	m["alert"] = 0.6
	shake_amt = 3.0


## Шаг спутника к точке следа: [новая позиция, взгляд, идёт ли]. Поворачивается только при заметном сдвиге.
func _follow(pos: Vector2, target: Vector2, step: float, fl: bool) -> Array:
	var d := target - pos
	if d.length() < 0.02:
		return [target, fl, false]
	var lr := d.x - d.y
	if absf(lr) > 0.05:
		fl = lr < 0
	return [pos.move_toward(target, step), fl, true]


## Кадр ходьбы спутника по его собственному шагу.
func _walk_frame(t: float) -> int:
	return 0 if t <= 0.0 else int(t / 0.14) % 2


## Пыль в воздухе: в Кальдере медленно всплывает, в Пустоши ветер гонит песок.
func _init_motes() -> void:
	motes.clear()
	for i in 46:
		motes.append(_new_mote(true))


func _new_mote(anywhere: bool) -> Dictionary:
	var c := iso(pf) + Vector2(0, -10)
	var pos := c + Vector2(randf_range(-340, 340), randf_range(-200, 200))
	if not anywhere:
		pos.x = c.x - 340 if waste else pos.x
		if not waste:
			pos.y = c.y + 200
	var v := Vector2(randf_range(40, 90), randf_range(-4, 6)) if waste else Vector2(randf_range(-3, 3), randf_range(-9, -3))
	return {"p": pos, "v": v, "ph": randf() * TAU, "a": randf_range(0.25, 0.7)}


func _update_fx(delta: float) -> void:
	var c := iso(pf) + Vector2(0, -10)
	for i in motes.size():
		var m: Dictionary = motes[i]
		m.p += m.v * delta + Vector2(sin(wt * 0.8 + m.ph) * 4.0 * delta, 0)
		if absf(m.p.x - c.x) > 360 or absf(m.p.y - c.y) > 220:
			motes[i] = _new_mote(false)
	for pz in puffs:
		pz.t += delta
		pz.p += pz.v * delta
	puffs = puffs.filter(func(q): return q.t < 0.45)


## Пол под лампами и экранами чуть светится и мерцает.
func _draw_glows() -> void:
	for o in objs:
		if not (o.get("kind", "") in GLOWS):
			continue
		var ph: float = o.get("ph", 0.0)
		var f := 0.8 + 0.2 * sin(wt * 11.0 + ph * 5.0) * sin(wt * 6.3 + ph)
		if fmod(wt + ph * 3.0, 9.0) < 0.1:
			f = 0.35
		var c := iso(Vector2(o.pos))
		var col := Pal.R2 if o.kind in ["neon", "bar"] else Pal.G5
		draw_set_transform(c + Vector2(0, 2), 0.0, Vector2(1.0, 0.5))
		var k := 2.2 if dark and o.kind == "lamp" else 1.0
		draw_circle(Vector2.ZERO, 34.0 * (1.4 if k > 1.0 else 1.0), Color(col, 0.035 * f * k))
		draw_circle(Vector2.ZERO, 20.0, Color(col, 0.05 * f * k))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _shadow(pos: Vector2, rx: float = 6.0) -> void:
	draw_set_transform(iso(pos) + Vector2(0, 3), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, rx, Color(0, 0, 0, 0.38))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Покачивание на месте: раз в пару секунд фигура «вдыхает» на пиксель вверх.
func _breath(ph: float) -> float:
	return -1.0 if sin(wt * 2.1 + ph) > 0.55 else 0.0


## Значки над головами в катсценах: «!», «?», «♥», «...».
func _draw_emotes() -> void:
	for who in emotes:
		var pos := pf
		if who == "mate":
			pos = mate_pos
		elif who != "genius":
			var o = cut_find(who)
			if o == null:
				continue
			pos = o.get("cpos", Vector2(o.pos))
		var e: String = emotes[who][0]
		var t: float = emotes[who][1]
		var c := iso(pos) + Vector2(0, -34 - minf(1.0, (1.4 - t) * 4.0) * 4.0)
		draw_rect(Rect2(c - Vector2(7, 6), Vector2(14, 12)), Pal.BG)
		draw_rect(Rect2(c - Vector2(7, 6), Vector2(14, 12)), Pal.G3, false, 1.0)
		match e:
			"!":
				draw_rect(Rect2(c + Vector2(-1, -4), Vector2(2, 5)), Pal.R3)
				draw_rect(Rect2(c + Vector2(-1, 2), Vector2(2, 2)), Pal.R3)
			"♥":
				for r in [[-4, -3, 3, 2], [1, -3, 3, 2], [-5, -2, 10, 2], [-4, 0, 8, 2], [-2, 2, 4, 1], [-1, 3, 2, 1]]:
					draw_rect(Rect2(c + Vector2(r[0], r[1]), Vector2(r[2], r[3])), Pal.R3)
			"?":
				for r in [[-2, -4, 4, 1], [2, -3, 1, 2], [0, -1, 2, 1], [0, 0, 1, 2], [0, 3, 1, 1]]:
					draw_rect(Rect2(c + Vector2(r[0], r[1]), Vector2(r[2], r[3])), Pal.G5)
			_:
				for k in 3:
					draw_rect(Rect2(c + Vector2(-4 + k * 3, 0), Vector2(2, 2)), Pal.G5)


func _draw_motes() -> void:
	for m in motes:
		var a: float = m.a * (0.6 + 0.4 * sin(wt * 2.0 + m.ph))
		if dark:
			a *= 0.3
		if waste:
			draw_line(m.p, m.p - m.v.normalized() * 3.0, Color(Pal.G3, a * 0.6), 1.0)
		else:
			draw_rect(Rect2(m.p.round(), Vector2(1, 1)), Color(Pal.G4, a * 0.7))
	for pz in puffs:
		var k: float = pz.t / 0.45
		draw_circle(pz.p, 1.5 + k * 3.0, Color(Pal.G3, 0.35 * (1.0 - k)))


# ---------------- отрисовка ----------------

func _shade(pos: Vector2) -> Color:
	var d := pos.distance_to(pf)
	if dark:
		var f2 := _lit(pos)
		return Color(f2, f2, f2, 1.0)
	var f := clampf(1.0 - maxf(0.0, d - light) / 7.0, 0.28, 1.0)
	return Color(f, f, f, 1.0)


## Освещённость в подвале: фонарик Гения на пару клеток и пятна света у ламп.
func _lit(pos: Vector2) -> float:
	var f := clampf(1.0 - maxf(0.0, pos.distance_to(pf) - light) / 2.5, 0.06, 1.0)
	for lp in lamp_pos:
		var ph: float = fmod(lp.x * 1.7 + lp.y, 6.0)
		var fl := 0.9 + 0.1 * sin(wt * 9.0 + ph)
		f = maxf(f, clampf(1.0 - maxf(0.0, pos.distance_to(lp) - 1.6) / 2.2, 0.0, 1.0) * fl)
	return f


func _draw() -> void:
	# шахта: сквозь неё виден нижний ярус, тёмный и далёкий
	for vd in voids:
		var c0 := iso(Vector2(vd.pos))
		draw_colored_polygon(PackedVector2Array([c0 + Vector2(0, -8), c0 + Vector2(16, 0), c0 + Vector2(0, 8), c0 + Vector2(-16, 0)]), Pal.BG)
	for vd in voids:
		draw_texture(vd.tex, iso(Vector2(vd.pos)) + Vector2(-16, 48), Color(0.5, 0.5, 0.5))
	for vd in voids:
		var vp: Vector2i = vd.pos
		var c1 := iso(Vector2(vp))
		if _solid_floor(vp + Vector2i(0, -1)):
			draw_colored_polygon(PackedVector2Array([c1 + Vector2(0, -8), c1 + Vector2(16, 0), c1 + Vector2(16, 56), c1 + Vector2(0, 48)]), Pal.G1)
			draw_line(c1 + Vector2(0, 16), c1 + Vector2(16, 24), Pal.G2, 1.0)
		if _solid_floor(vp + Vector2i(-1, 0)):
			draw_colored_polygon(PackedVector2Array([c1 + Vector2(-16, 0), c1 + Vector2(0, -8), c1 + Vector2(0, 48), c1 + Vector2(-16, 56)]), Pal.G2)
			draw_line(c1 + Vector2(-16, 24), c1 + Vector2(0, 16), Pal.G3, 1.0)
	for f in floors:
		var p: Vector2i = f.pos
		draw_texture(f.tex, iso(Vector2(p)) - Vector2(16, 8), _shade(Vector2(p)))
	_draw_glows()
	_draw_bodies()
	_draw_loot_marks()
	# подсветка клетки под курсором
	var mt := to_grid(get_global_mouse_position())
	if in_bounds(mt) and not blocked():
		var c := iso(Vector2(mt))
		var col := Pal.R2 if _target_at(mt) != null else Pal.G4
		draw_polyline(PackedVector2Array([c + Vector2(0, -8), c + Vector2(16, 0), c + Vector2(0, 8), c + Vector2(-16, 0), c + Vector2(0, -8)]), Color(col, 0.6), 1.0)
	if not path.is_empty():
		for t in path:
			draw_rect(Rect2(iso(Vector2(t)) - Vector2(1, 1), Vector2(2, 2)), Color(Pal.G5, 0.5))

	_draw_rails()
	var items: Array = []
	var pdepth := pf.x + pf.y
	for w in walls:
		var p: Vector2i = w.pos
		var a := 1.0
		var dd := p.x + p.y - pdepth
		if dd > 0.5 and dd <= 4.0 and absf((p.x - p.y) - (pf.x - pf.y)) <= 2.5:
			a = 0.3
		items.append([p.x + p.y, p.x, w.tex, iso(Vector2(p)) - Vector2(16, 8 + w.tex.get_height() - 16), a, Vector2(p), false])
	for o in objs:
		var p: Vector2i = o.pos
		var tex: Texture2D = o.tex
		var ow: int = o.get("w", 1)
		var oh: int = o.get("h", 1)
		if ow > 1 or oh > 1:
			# Нижняя вершина «следа» предмета лежит на нижней кромке картинки.
			var anchor := Vector2(oh * 16, tex.get_height() - 8 * (ow + oh))
			var front := Vector2(p.x + ow - 1, p.y + oh - 1)
			items.append([front.x + front.y, front.x, tex, iso(Vector2(p)) - Vector2(0, 8) - anchor, 1.0, Vector2(p) + Vector2(ow - 1, oh - 1) * 0.5, false])
			continue
		var off := Vector2(-tex.get_width() / 2.0, 6 - tex.get_height())
		var oflip := false
		if o.type == "npc":
			var wk: float = o.get("walk", 0.0)
			if wk > 0.0:
				tex = Art.person_tex(o.look, _walk_frame(wk))
			off = Vector2(-8, 4 - 28 + (_breath(o.get("ph", 0.0)) if wk <= 0.0 else (-1.0 if _walk_frame(wk) == 1 else 0.0)))
			# жители поворачиваются к Гению, когда он рядом (в катсцене — куда скажет сценарий)
			if o.has("face"):
				oflip = o.face
			elif _cheb(p, ppos) <= 3:
				oflip = (p.x - p.y) > (pf.x - pf.y) + 0.3
		if o.type == "npc":
			var cp: Vector2 = o.get("cpos", Vector2(p))
			items.append([cp.x + cp.y, cp.x, tex, iso(cp) + off, 1.0, cp, oflip, 6.0])
		else:
			items.append([p.x + p.y, p.x, tex, iso(Vector2(p)) + off, 1.0, Vector2(p), oflip])
	for m in mobs:
		# ночью в Пустоши и в тёмном подвале врагов не видно, пока они не подойдут вплотную
		if m.fpos.distance_to(pf) > sight() and (not dark or _lit(m.fpos) < 0.45):
			continue
		var tex := _mob_tex(m)
		var dd: float = clampf(m.fpos.distance_to(Vector2(m.pos)), 0.0, 1.0)
		var hop := -sin(dd * PI) * 2.0 if dd > 0.01 else _breath(float(absi(hash(m.id)) % 100) / 16.0)
		items.append([m.fpos.x + m.fpos.y + 0.1, m.fpos.x, tex, iso(m.fpos) + Vector2(-tex.get_width() / 2.0, 4 - tex.get_height() + hop), 1.0, m.fpos, false, 8.0 if m.enemy == "muezzin" else 6.0])
	if has_mate():
		var mtex := Art.person_tex(Maps.NPC_LOOKS[G.p.companion].person, _walk_frame(mate_walk))
		var mb := (-1.0 if _walk_frame(mate_walk) == 1 else 0.0) if mate_walk > 0.0 else _breath(1.7)
		items.append([mate_pos.x + mate_pos.y + 0.04, mate_pos.x, mtex, iso(mate_pos) + Vector2(-8, 4 - 28 + mb), 1.0, mate_pos, mate_flip, 6.0])
	if has_escort():
		var etex := Art.person_tex(Maps.NPC_LOOKS.stray.person, _walk_frame(esc_walk))
		var eb := (-1.0 if _walk_frame(esc_walk) == 1 else 0.0) if esc_walk > 0.0 else _breath(3.1)
		items.append([esc_pos.x + esc_pos.y + 0.03, esc_pos.x, etex, iso(esc_pos) + Vector2(-8, 4 - 28 + eb), 1.0, esc_pos, esc_flip, 6.0])
	var ptex := Art.person_tex(G.person_look(), frame)
	var bob := (-1.0 if frame == 1 else 0.0) if not path.is_empty() else _breath(0.0)
	items.append([pdepth + 0.05, pf.x, ptex, iso(pf) + Vector2(-8, 4 - 28 + bob), 1.0, pf, flip, 6.0])
	# Тени встают в общую очередь прямо перед своим хозяином: раньше они рисовались вместе с полом,
	# и большие предметы (автобус, дома) перекрывали тень, хотя сам персонаж стоял перед ними.
	var shadows: Array = []
	for it in items:
		if it.size() > 7:
			shadows.append([it[0] - 0.0005, it[1], null, it[5], it[7], it[5], false])
	items.append_array(shadows)
	items.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	for it in items:
		if it[2] == null:
			_shadow(it[3], it[4])
			continue
		var col := _shade(it[5])
		col.a = it[4]
		if it[6]:
			# Зеркалим вокруг середины картинки: прямоугольник с отрицательной шириной Godot рисует
			# со сдвигом на ширину спрайта, отчего житель «отпрыгивал», а тень оставалась на месте.
			var w: float = it[2].get_width()
			draw_set_transform(Vector2(it[3].x * 2.0 + w, 0.0), 0.0, Vector2(-1, 1))
			draw_texture(it[2], it[3], col)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_texture(it[2], it[3], col)
	# «!» над врагом, который заметил Гения
	for m in mobs:
		if m.get("alert", 0.0) > 0.0:
			var tex2 := _mob_tex(m)
			var top := iso(m.fpos) + Vector2(-1, 4 - tex2.get_height() - 12 - (0.6 - m.alert) * 6.0)
			draw_rect(Rect2(top - Vector2(1, 1), Vector2(4, 11)), Pal.BG)
			draw_rect(Rect2(top, Vector2(2, 6)), Pal.R3)
			draw_rect(Rect2(top + Vector2(0, 7), Vector2(2, 2)), Pal.R3)
	_draw_emotes()
	_draw_motes()


const READ_DIST := 3


## Тайники, грузы, травы, коренья — то, что лежит и что можно забрать.
func _lootable(o: Dictionary) -> bool:
	var a: String = str(o.get("action", ""))
	return o.get("kind", "") in ["cache", "roots", "herb_ash", "herb_mint", "herb_pepper"] or a.begins_with("jobspot:") \
		or a.begins_with("raid_c") or a in ["mini_bus_trunk", "mini_bus_case", "mini_camp_stash", "mini_camp_tent"] or a.begins_with("herb_") or a.begins_with("forest_forage") or a.ends_with("_cache") or a.begins_with("cache_")


## Уже обысканное не подсвечиваем.
func _looted(a: String) -> bool:
	match a:
		"cache_med": return G.flag("med_taken")
		"cache_ruin": return G.flag("ruin_open")
		"river_cache": return G.flag("river_cache")
		"ruins_cache": return G.flag("ruins_looted")
	if a.begins_with("mini_"):
		return G.mini_done(a)
	if a.begins_with("raid_c"):
		return G.flag(G.raid_key(a.substr(5)))
	if a.begins_with("forest_forage"):
		return G.flag(G.raid_key(a.substr(7)))
	if a.begins_with("herb_"):
		return G.has(["", "Пепельный тимьян", "Собачья мята", "Звёздный перец"][int(a.substr(5))])
	return false


## Подсветка того, что лежит рядом: мягко пульсирующий ромб под предметом.
func _draw_loot_marks() -> void:
	var pulse := 0.35 + 0.25 * sin(wt * 3.0)
	for o in objs:
		if o.type != "prop" or not _lootable(o) or _odist(o, ppos) > READ_DIST:
			continue
		if _looted(str(o.action)):
			continue
		var c := iso(Vector2(o.pos))
		draw_polyline(PackedVector2Array([c + Vector2(0, -8), c + Vector2(16, 0), c + Vector2(0, 8), c + Vector2(-16, 0), c + Vector2(0, -8)]), Color(Pal.R3, pulse), 1.0)


# ---------------- распорядок жителей ----------------

const Sched := preload("res://scripts/sched.gd")
const SCHED_TALK := {"kid": "res_kid", "smoker": "stairs_smoker", "ian": "stairs_ian", "beggar": "res_beggar",
	"patrol": "dana_start", "zoya": "zoya_start", "pip": "pip_start", "miron": "miron_start"}
var sched_paths: Dictionary = {}


func _sched_tick(delta: float) -> void:
	for id in Sched.ROUTINE:
		var o = cut_find(id)
		if id == G.p.get("companion", ""):
			if o != null:
				_sched_remove(o)
			continue
		var st := Sched.state(id)
		if st.map != G.p.map:
			if o != null:
				_sched_remove(o)
			continue
		if o == null:
			var c0: Vector2i = st.leg.a if st.walk else st.cell
			o = _sched_add(id, c0)
		if st.walk:
			_sched_walk(o, st, delta)
		elif o.has("cpos") or o.pos != st.cell:
			_sched_put(o, st.cell)


func _sched_add(id: String, t: Vector2i) -> Dictionary:
	var w: Dictionary = preload("res://scripts/story.gd").WHO[id]
	var ob := {"type": "npc", "id": id, "pos": t, "x": t.x, "y": t.y, "title": str(w.name).get_slice(",", 0),
		"action": SCHED_TALK.get(id, ""), "block": true, "reach": 1, "look": Maps.NPC_LOOKS[id].person, "kind": "",
		"ph": float(absi(hash(id)) % 1000) / 159.0}
	ob.tex = Art.person_tex(ob.look)
	objs.append(ob)
	_sched_put(ob, t)
	return ob


func _sched_remove(o: Dictionary) -> void:
	objs.erase(o)
	if obj_at.get(o.pos) == o:
		obj_at.erase(o.pos)
	if o.get("block", false):
		astar.set_point_solid(o.pos, false)


## Встать на клетку: снова твёрдый, снова поворачивается к Гению.
func _sched_put(o: Dictionary, t: Vector2i) -> void:
	if obj_at.get(o.pos) == o:
		obj_at.erase(o.pos)
	astar.set_point_solid(o.pos, false)
	o.pos = t
	o.erase("cpos")
	o.erase("face")
	o["walk"] = 0.0
	o.block = true
	if not obj_at.has(t):
		obj_at[t] = o
	astar.set_point_solid(t, true)


## Идти по отрезку распорядка: путь считаем один раз, место — по доле прошедшего времени.
func _sched_walk(o: Dictionary, st: Dictionary, delta: float) -> void:
	var lg: Dictionary = st.leg
	var key := "%s|%s|%s" % [o.id, str(lg.a), str(lg.b)]
	if not sched_paths.has(key):
		var sa := astar.is_point_solid(lg.a)
		var sb := astar.is_point_solid(lg.b)
		astar.set_point_solid(lg.a, false)
		astar.set_point_solid(lg.b, false)
		var cells: Array = astar.get_id_path(lg.a, lg.b)
		astar.set_point_solid(lg.a, sa)
		astar.set_point_solid(lg.b, sb)
		if cells.size() < 2:
			cells = [lg.a, lg.b]
		sched_paths[key] = cells
	var cells: Array = sched_paths[key]
	var s: float = clampf(st.f, 0.0, 1.0) * (cells.size() - 1)
	var i := mini(int(s), cells.size() - 2)
	var fp: Vector2 = Vector2(cells[i]).lerp(Vector2(cells[i + 1]), s - i)
	if o.get("block", false):
		astar.set_point_solid(o.pos, false)
		o.block = false
	var prev: Vector2 = o.get("cpos", fp)
	var d := fp - prev
	if absf(d.x - d.y) > 0.001:
		o["face"] = (d.x - d.y) < 0
	o["cpos"] = fp
	o["walk"] = float(o.get("walk", 0.0)) + delta
	var cell := Vector2i(fp.round())
	if cell != o.pos:
		if obj_at.get(o.pos) == o:
			obj_at.erase(o.pos)
		o.pos = cell
		if not obj_at.has(cell):
			obj_at[cell] = o


func _cap(t: String) -> String:
	return t.substr(0, 1).to_upper() + t.substr(1)


func _free_near(t: Vector2i) -> Vector2i:
	for r in 4:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c := t + Vector2i(dx, dy)
				if in_bounds(c) and not astar.is_point_solid(c) and not obj_at.has(c):
					return c
	return t


## Смена погоды: проверка «Погоды» решает, насколько Гению от неё плохо.
func _weather_change(first: bool) -> void:
	wx = G.weather()
	wx_ok = false
	Sfx.weather({"dust": "storm", "acid": "rain"}.get(wx, ""))
	if first:
		wx_amt = Vector2(1.0 if wx == "dust" else 0.0, 1.0 if wx == "acid" else 0.0)
	if wx == "clear":
		if not first:
			G.say("Небо проясняется. Пустошь снова видно до горизонта.")
	else:
		# один бросок на всю бурю: перезаход на карту его не меняет
		var key := "%d_%d" % [int(G.p.day), int(G.p.hour) / 6]
		var prev: String = str(G.p.flags.get("wx_roll", ""))
		if prev.begins_with(key + ":"):
			wx_ok = prev.ends_with(":1")
			if first:
				G.say("%s всё ещё не стихает." % _cap(G.WEATHER_NAME[wx]))
			_update_hud()
			return
		var r := G.roll("Погода", 12, "")
		wx_ok = r.ok
		G.p.flags["wx_roll"] = key + (":1" if r.ok else ":0")
		if wx == "dust":
			G.say(("Пыльная буря. Вы натягиваете ворот на лицо и щуритесь: видно чуть дальше вытянутой руки. " if r.ok else "Пыльная буря. Песок забивает глаза, дальше пары шагов ничего не видно. ") + G.roll_text(r))
		else:
			G.say(("Кислотный дождь. Вы знаете, как укрываться: капли почти не достают. " if r.ok else "Кислотный дождь. Капли жгут кожу, пока вы под открытым небом. ") + G.roll_text(r))
	_update_hud()


## Как далеко видно врагов и предметы (в клетках). Ночь и пыль сужают обзор.
func sight() -> float:
	var s := 99.0
	if wx == "dust":
		s = 4.0 if wx_ok else 2.5
	if night_amt > 0.5 or dark:
		s = minf(s, 1.6)
	return s


func _weather_tick(delta: float) -> void:
	if G.weather() != wx:
		_weather_change(false)
	wx_amt.x = move_toward(wx_amt.x, 1.0 if wx == "dust" else 0.0, delta * 0.4)
	wx_amt.y = move_toward(wx_amt.y, 1.0 if wx == "acid" else 0.0, delta * 0.4)
	wx_rect.visible = wx_amt.x > 0.01 or wx_amt.y > 0.01
	var mat := wx_rect.material as ShaderMaterial
	mat.set_shader_parameter("dust", wx_amt.x)
	mat.set_shader_parameter("rain", wx_amt.y)
	mat.set_shader_parameter("reach", 0.32 if wx_ok else 0.2)
	if wx != "acid" or blocked():
		return
	acid_t += delta
	# раз в игровые полчаса кислота разъедает кожу; «Погода» помогает, совсем не убивает
	if acid_t >= 30.0:
		acid_t = 0.0
		var hit := 1 if wx_ok else randi_range(2, 3)
		if G.p.get("gear", {}).get("head", "") != "":
			hit = maxi(0, hit - 1)
		hit = mini(hit, int(G.p.hp) - 1)
		if hit > 0:
			G.p.hp -= hit
			G.changed.emit()
			G.say("Кислота разъедает кожу: -%d ООЗ. Лучше переждать в укрытии." % hit)


## Убитые лежат на месте боя до конца дня, вокруг — кровь (G.p.bodies, чистится в new_day).
func _add_body(m: Dictionary) -> void:
	if not G.p.has("bodies"):
		G.p.bodies = []
	G.p.bodies.append({"map": G.p.map, "x": m.fpos.x, "y": m.fpos.y, "enemy": m.enemy, "s": absi(hash(m.id)) % 1000})
	queue_redraw()


func _draw_bodies() -> void:
	for b in G.p.get("bodies", []):
		if b.map != G.p.map:
			continue
		var bp := Vector2(b.x, b.y)
		if bp.distance_to(pf) > sight() + 1.0 and (not dark or _lit(bp) < 0.45):
			continue
		var c := iso(bp) + Vector2(0, 2)
		var rng := RandomNumberGenerator.new()
		rng.seed = int(b.s)
		var blood := Color(0.36, 0.04, 0.03, 0.85)
		# лужа: несколько сплющенных пятен и брызги
		for i in 5:
			var o := Vector2(rng.randf_range(-9, 9), rng.randf_range(-4, 4))
			var r := rng.randf_range(3.0, 7.0)
			draw_set_transform(c + o, 0.0, Vector2(1.0, 0.5))
			draw_circle(Vector2.ZERO, r, blood)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for i in 6:
			var o2 := Vector2(rng.randf_range(-16, 16), rng.randf_range(-7, 7))
			draw_rect(Rect2(c + o2, Vector2(1, 1)), blood)
		# тело на боку, темнее живого
		var tex := _mob_tex({"enemy": b.enemy})
		var sc := 0.85 if b.enemy == "muezzin" else 1.0
		draw_set_transform(c + Vector2(0, -2), PI * 0.5 * (1 if int(b.s) % 2 == 0 else -1), Vector2(sc, sc))
		draw_texture(tex, Vector2(-tex.get_width() / 2.0, -tex.get_height() / 2.0), Color(0.45, 0.4, 0.38, 1.0))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _solid_floor(t: Vector2i) -> bool:
	return in_bounds(t) and grid[t.y][t.x] != "v" and not WALLS.has(grid[t.y][t.x])


## Перила по краю шахты: поручень на высоте 9 px и стойки.
func _draw_rails() -> void:
	var edges := [[Vector2i(0, -1), Vector2(0, -8), Vector2(16, 0)], [Vector2i(-1, 0), Vector2(-16, 0), Vector2(0, -8)],
		[Vector2i(0, 1), Vector2(-16, 0), Vector2(0, 8)], [Vector2i(1, 0), Vector2(0, 8), Vector2(16, 0)]]
	for vd in voids:
		var c := iso(Vector2(vd.pos))
		for e in edges:
			if not _solid_floor(vd.pos + e[0]):
				continue
			var a: Vector2 = c + e[1]
			var b: Vector2 = c + e[2]
			var up := Vector2(0, -9)
			var col := _shade(Vector2(vd.pos))
			draw_line(a + up, b + up, Pal.G4 * col, 1.0)
			draw_line(a + up * 0.45, b + up * 0.45, Pal.G2 * col, 1.0)
			for k in 3:
				var q := a.lerp(b, k / 2.0)
				draw_line(q, q + up, Pal.G3 * col, 1.0)


func _mob_tex(m: Dictionary) -> Texture2D:
	match m.enemy:
		"pes":
			return Art.cached("mob_pes", func(): return _small_dog())
		"muezzin":
			return Art.cached("mob_muezzin", func(): return _big_dog())
		"padal":
			return Art.person_tex(Maps.NPC_LOOKS.raider.person, frame)
		"slepysh":
			return Art.cached("mob_slepysh", func(): return _small_slepysh())
		"slepets":
			return Art.cached("mob_slepets", func(): return _small_slepets())
		"plant":
			return Art.cached("mob_plant", func(): return _small_plant())
		_:
			return Art.cached("mob_iskaz", func(): return _small_warped())


func _small_dog() -> Texture2D:
	var cv := ArtLib.Canvas.new(22, 16)
	cv.ellipse(10, 9, 7, 3.5, 3)
	cv.ellipse(17, 6, 3.5, 3, 3)
	cv.put(20, 7, 8)
	cv.put(19, 7, 8)
	for lx in [5, 8, 12, 15]:
		cv.line(lx, 11, lx, 15, 2)
	cv.line(3, 8, 0, 5, 2)
	cv.outline(0)
	return Art.to_tex(cv)


func _big_dog() -> Texture2D:
	var cv := ArtLib.Canvas.new(40, 30)
	cv.ellipse(17, 17, 13, 7, 2)
	cv.ellipse(13, 11, 7, 5, 3)
	cv.ellipse(30, 12, 6, 6, 3)
	cv.poly(PackedVector2Array([Vector2(30, 12), Vector2(39, 7), Vector2(39, 22), Vector2(29, 18)]), 7)
	cv.poly(PackedVector2Array([Vector2(32, 13), Vector2(38, 10), Vector2(38, 19), Vector2(31, 17)]), 0, false)
	for lx in [7, 12, 21, 26]:
		cv.line(lx, 21, lx, 29, 2, 2)
	cv.line(4, 15, 0, 9, 2)
	cv.put(35, 11, 6)
	cv.put(35, 18, 6)
	cv.outline(0)
	return Art.to_tex(cv)


func _small_slepysh() -> Texture2D:
	var cv := ArtLib.Canvas.new(24, 16)
	cv.ellipse(10, 9, 7, 3.5, 4)
	cv.ellipse(18, 6, 4, 3.5, 5)
	cv.line(14, 9, 21, 15, 4)
	cv.line(6, 9, 2, 15, 4)
	cv.line(17, 7, 21, 7, 0)
	cv.outline(0)
	return Art.to_tex(cv)


func _small_slepets() -> Texture2D:
	var cv := ArtLib.Canvas.new(28, 22)
	cv.ellipse(12, 13, 8, 5, 4)
	cv.ellipse(21, 7, 5, 4.5, 5)
	cv.line(17, 13, 25, 21, 4)
	cv.line(15, 15, 20, 21, 4)
	cv.line(6, 13, 2, 21, 4)
	cv.line(9, 15, 7, 21, 4)
	for i in 3:
		cv.line(7 + i * 4, 9, 8 + i * 4, 6, 2)
	cv.line(19, 8, 25, 8, 9)
	cv.outline(0)
	return Art.to_tex(cv)


func _small_plant() -> Texture2D:
	var cv := ArtLib.Canvas.new(22, 26)
	cv.line(11, 25, 11, 12, 3, 2)
	cv.line(11, 22, 3, 18, 2)
	cv.line(11, 22, 19, 18, 2)
	cv.ellipse(11, 9, 6, 5, 7)
	cv.ellipse(11, 10, 3, 2, 0)
	cv.put(9, 9, 6)
	cv.put(13, 9, 6)
	cv.outline(0)
	return Art.to_tex(cv)


func _small_warped() -> Texture2D:
	var cv := ArtLib.Canvas.new(20, 28)
	cv.ellipse(10, 18, 7, 8, 2)
	cv.ellipse(10, 8, 5, 5, 4)
	cv.put(8, 7, 8)
	cv.put(12, 7, 8)
	cv.put(10, 5, 9)
	cv.line(3, 16, 0, 26, 3)
	cv.line(17, 16, 19, 27, 3)
	cv.line(7, 25, 6, 27, 3)
	cv.outline(0)
	return Art.to_tex(cv)


# ---------------- HUD ----------------

func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	G.main().ui.add_child(hud)
	var panel := PanelContainer.new()
	panel.position = Vector2(4, 4)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(panel)
	hud_text = Pal.rich("", 9)
	hud_text.custom_minimum_size = Vector2(178, 0)
	hud_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hud_text)

	place = Pal.label(map.name.to_upper(), Pal.G4, 10, true)
	place.position = Vector2(260, 6)
	place.size = Vector2(374, 14)
	place.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(place)
	var pb := Pal.button("ПЕЙДЖЕР [Tab]", func(): G.main().open_pager(0), 9)
	pb.position = Vector2(536, 22)
	pb.size = Vector2(98, 18)
	hud.add_child(pb)

	if waste and not map.get("mini", false):
		var eb := Pal.button("ИЗУЧАТЬ ПУСТОШЬ", _explore, 9)
		eb.position = Vector2(484, 44)
		eb.size = Vector2(150, 18)
		hud.add_child(eb)

	tracker = Pal.rich("", 8)
	tracker.fit_content = true
	tracker.position = Vector2(394, 80 if waste else 56)
	tracker.size = Vector2(240, 0)
	tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tracker.add_theme_color_override("font_outline_color", Pal.BG)
	tracker.add_theme_constant_override("outline_size", 3)
	hud.add_child(tracker)

	log_text = Pal.rich("", 8)
	log_text.fit_content = false
	log_text.position = Vector2(6, 316)
	log_text.size = Vector2(560, 40)
	log_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(log_text)

	hover = Pal.label("", Pal.G5, 9)
	hover.add_theme_color_override("font_outline_color", Pal.BG)
	hover.add_theme_constant_override("outline_size", 4)
	hover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hover)


func _explore() -> void:
	if blocked():
		return
	path.clear()
	G.main().explore()


func _bar(v: int, mx: int, n: int = 10) -> String:
	var f := clampi(roundi(float(v) / maxf(1.0, mx) * n), 0, n)
	return "█".repeat(f) + "░".repeat(n - f)


func _update_hud() -> void:
	if hud_text == null:
		return
	var p := G.p
	var s := "[b]%s[/b]  [color=%s]%s[/color]\n" % [p.callsign, Pal.hex(Pal.G3), D.FACTIONS[p.faction].short]
	s += "[color=%s]ООЗ %s %d/%d[/color]\n" % [Pal.hex(Pal.R3), _bar(p.hp, G.max_hp()), p.hp, G.max_hp()]
	s += "[color=%s]ООР %s %d/%d[/color]\n" % [Pal.hex(Pal.G5), _bar(p.mind, G.max_mind()), p.mind, G.max_mind()]
	s += "СЫТ %s %d\n" % [_bar(p.food, 100), p.food]
	s += "День %d · %s%s\n" % [p.day, G.clock(), "  [color=%s]ночь[/color]" % Pal.hex(Pal.G3) if G.is_night() else ""]
	if waste and wx != "clear":
		s += "[color=%s]%s[/color]\n" % [Pal.hex(Pal.R3 if wx == "acid" else Pal.G3), _cap(G.WEATHER_NAME[wx])]
	var wtxt := "—"
	if p.weapon != "":
		wtxt = "%s %d/%d · %d" % [p.weapon, p.mag, G.mag_size(p.weapon), G.ammo_left() - p.mag]
	s += "Су %d\nОружие: %s" % [p.su, wtxt]
	if p.wounds.size() > 0:
		s += "\n[color=%s]Раны: %s[/color]" % [Pal.hex(Pal.R3), ", ".join(p.wounds)]
	hud_text.text = s
	var tl: Array = G.tracker_lines()
	var tt := ""
	for i in mini(4, tl.size()):
		tt += "[right][color=%s]▪ %s[/color][/right]\n" % [Pal.hex(Pal.G4), tl[i]]
	if tl.size() > 4:
		tt += "[right][color=%s]и ещё %d — в пейджере[/color][/right]" % [Pal.hex(Pal.G3), tl.size() - 4]
	tracker.text = tt
	# пороги рассудка: при каждом новом падении — тревожная строка
	var st := Live.mind_step()
	if st > int(p.flags.get("mind_step", 0)):
		G.say("[Рассудок %d] %s" % [int(p.mind), MIND_WORLD[st - 1]])
	p.flags["mind_step"] = st


func _update_log() -> void:
	if log_text == null:
		return
	var lines: Array = G.log_lines.slice(maxi(0, G.log_lines.size() - 3))
	log_text.text = "\n".join(lines)


func _update_hover() -> void:
	if blocked():
		hover.text = ""
		return
	var t := to_grid(get_global_mouse_position())
	var tg = _target_at(t)
	var txt := ""
	var o = obj_at.get(t, null)
	if tg != null:
		o = tg
	if o != null and o.type in ["npc", "mob"]:
		txt = o.title
	elif o != null and o.type == "prop":
		txt = o.title
		# то, что можно подобрать, издалека не разобрать: надо подойти на пару шагов
		if _lootable(o) and _odist(o, ppos) > READ_DIST:
			txt = "Что-то лежит"
	hover.text = txt
	hover.position = get_viewport().get_mouse_position() + Vector2(10, -4)
