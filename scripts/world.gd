extends Node2D
## Изометрическая карта: ходьба мышью и клавишами, NPC, предметы, монстры, HUD.

const Maps := preload("res://scripts/maps.gd")
const ArtLib := preload("res://scripts/art.gd")
const WALLS := {"#": "panel", "B": "brick", "R": "ruin"}
const FLOORS := {".": "metal", ",": "concrete", "_": "tile", "=": "rug", "s": "sand", "a": "ash",
	"g": "grate", "/": "stairs", "p": "plaza", "k": "asphalt", "w": "water", "h": "planks"}
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
	if spawn != "" and map.spawns.has(spawn):
		ppos = map.spawns[spawn]
	else:
		ppos = Vector2i(G.p.pos[0], G.p.pos[1])
		# Старое сохранение с прежней, большой картой: ставим Гения на ближайшую точку появления.
		if not in_bounds(ppos) or astar.is_point_solid(ppos):
			ppos = map.spawns.values()[0]
	pf = Vector2(ppos)
	G.p.pos = [ppos.x, ppos.y]
	mate_pos = pf + Vector2(-1, 0)


func _ready() -> void:
	cam = Camera2D.new()
	add_child(cam)
	cam.position = iso(pf)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	_build_hud()
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
	return G.main().has_overlay()


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
				G.main().open_pager(4)
			KEY_I:
				G.main().open_pager(1)
			KEY_E, KEY_SPACE, KEY_ENTER:
				_interact_near()


func _target_at(t: Vector2i):
	if has_mate() and Vector2i(mate_pos.round()) == t:
		return {"type": "mate", "pos": t, "title": "Рыжая", "reach": 1, "action": "ry_start"}
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


func has_mate() -> bool:
	return G.p.get("companion", "") == "ryzhaya"


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
		G.main().open_dialogue("ry_start")
		return
	if o.action.begins_with("go:"):
		var parts: PackedStringArray = o.action.split(":")
		G.say("%s." % o.title)
		G.main().show_world.call_deferred(parts[1], parts[2])
		return
	G.main().open_dialogue(o.action)


# ---------------- цикл ----------------

func _process(delta: float) -> void:
	var stop := blocked()
	if not stop:
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
		mate_pos = mate_pos.move_toward(Vector2(mate_trail[0]), delta * SPEED * 0.95)
	cam.position = iso(pf) + Vector2(0, -10)
	_update_hover()
	queue_redraw()


func _move(delta: float) -> void:
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
		ppos = path.pop_front()
		G.p.pos = [ppos.x, ppos.y]
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
		"fled":
			if m != null:
				m.stun = 6.0
		"down":
			var lost := int(G.p.su * 0.25)
			G.p.su -= lost
			G.say("Вы очнулись в пыли. Кто-то обчистил карманы: -%d Су." % lost)
			if m != null:
				m.stun = 20.0
				m.pos = m.home
		"dead":
			G.main().game_over("Гений %s погиб в Пустоши. Тело так и не нашли." % G.p.callsign)
			return
	_update_hud()


# ---------------- отрисовка ----------------

func _shade(pos: Vector2) -> Color:
	var d := pos.distance_to(pf)
	var f := clampf(1.0 - maxf(0.0, d - light) / 7.0, 0.28, 1.0)
	return Color(f, f, f, 1.0)


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
		if o.type == "npc":
			off = Vector2(-8, 4 - 28)
		items.append([p.x + p.y, p.x, tex, iso(Vector2(p)) + off, 1.0, Vector2(p), false])
	for m in mobs:
		var tex := _mob_tex(m)
		items.append([m.fpos.x + m.fpos.y + 0.1, m.fpos.x, tex, iso(m.fpos) + Vector2(-tex.get_width() / 2.0, 4 - tex.get_height()), 1.0, m.fpos, false])
	if has_mate():
		var mtex := Art.person_tex(Maps.NPC_LOOKS.ryzhaya.person, frame)
		items.append([mate_pos.x + mate_pos.y + 0.04, mate_pos.x, mtex, iso(mate_pos) + Vector2(-8, 4 - 28), 1.0, mate_pos, flip])
	var ptex := Art.person_tex(G.person_look(), frame)
	items.append([pdepth + 0.05, pf.x, ptex, iso(pf) + Vector2(-8, 4 - 28), 1.0, pf, flip])
	items.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	for it in items:
		var col := _shade(it[5])
		col.a = it[4]
		if it[6]:
			draw_texture_rect(it[2], Rect2(it[3] + Vector2(it[2].get_width(), 0), Vector2(-it[2].get_width(), it[2].get_height())), false, col)
		else:
			draw_texture(it[2], it[3], col)


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

	if waste:
		var eb := Pal.button("ИЗУЧАТЬ ПУСТОШЬ", _explore, 9)
		eb.position = Vector2(484, 44)
		eb.size = Vector2(150, 18)
		hud.add_child(eb)

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
	var wtxt := "—"
	if p.weapon != "":
		wtxt = "%s %d/%d" % [p.weapon, p.mag, G.ammo_left() - p.mag]
	s += "Су %d   %s" % [p.su, wtxt]
	if p.wounds.size() > 0:
		s += "\n[color=%s]Раны: %s[/color]" % [Pal.hex(Pal.R3), ", ".join(p.wounds)]
	hud_text.text = s


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
	if tg != null:
		txt = tg.title
	elif obj_at.has(t):
		txt = obj_at[t].title
	hover.text = txt
	hover.position = get_viewport().get_mouse_position() + Vector2(10, -4)
