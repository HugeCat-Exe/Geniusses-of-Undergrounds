extends Node
## Автопрогон для проверки: запускается, только если задан GP_SMOKE.

var out := ""
var M: Node


func run(main: Node) -> void:
	M = main
	out = OS.get_environment("GP_SHOTS")
	await _wait(1.6)
	await _shot("01_title")
	M.show_creator()
	await _wait(0.3)
	var cr = M.current
	await _shot("02_creator_name")
	cr.c.callsign = "Ржавчина"
	cr.c.name = "Мира Кольт"
	cr.c.motive = "Ничего личного, только Су."
	cr.c.sex = "Ж"
	cr.c.faction = 5
	cr.c.race = "Человек"
	cr.c.age = "Взрослый"
	cr.c.birth = "Змеиная Яма"
	cr.c.phys = ["Рыжие волосы", "Веснушки на коже", "Ножевые шрамы", "Высокий рост"]
	cr.c.psy = ["Жадность", "Любопытство"]
	cr.c.main = ["Убеждение", "Анализ"]
	cr.step = 3
	cr._build()
	await _wait(0.3)
	await _shot("03_creator_faction")
	cr.step = 6
	cr._build()
	await _wait(0.3)
	await _shot("04_creator_traits")
	cr.step = 9
	cr._build()
	cr.approve.text = "О"
	cr._refresh()
	await _wait(0.3)
	await _shot("05_creator_verdict")
	cr._next()
	await _wait(1.5)
	await _shot("06_intro")
	_close_overlays()
	await _wait(0.8)
	await _shot("07_caldera")
	M.open_dialogue("emirra_start")
	await _wait(2.5)
	await _shot("08_emirra")
	_close_overlays()
	M.open_dialogue("surgeon_start")
	await _wait(2.5)
	await _shot("09_surgeon")
	_close_overlays()
	M.open_pager(0)
	await _wait(0.4)
	await _shot("10_pager_sheet")
	_close_overlays()
	M.open_pager(1)
	await _wait(0.4)
	await _shot("11_pager_inv")
	_close_overlays()
	M.open_shop(preload("res://scripts/story.gd").SHOPS.trader)
	await _wait(0.4)
	await _shot("12_shop")
	_close_overlays()
	G.save(0)
	M.show_world("waste", "gate")
	await _wait(1.0)
	await _shot("13_waste")
	var w = M.world
	w._path_to(Vector2i(7, 7))
	await _wait(2.5)
	print("SMOKE walked to ", w.ppos, " steps ", G.p.steps)
	w.ppos = Vector2i(13, 13)
	w.pf = Vector2(13, 13)
	await _wait(1.2)
	print("SMOKE near dog -> overlay: ", M.has_overlay())
	var cb0 = _overlay_of_type("Combat")
	if cb0:
		cb0._end("win")
	await _wait(0.3)
	print("SMOKE dog killed: ", "pes_1" in G.p.killed, " mobs left ", w.mobs.size())
	w.ppos = Vector2i(13, 5)
	w.pf = Vector2(13, 5)
	await _wait(1.2)
	print("SMOKE near raider -> overlay: ", M.has_overlay())
	await _shot("13b_raider")
	for c in M.overlay.get_children():
		if c.has_method("_choose"):
			c._choose({"t": "x", "fx": [["fight"]], "next": "end"})
	await _wait(0.5)
	print("SMOKE raider fight overlay: ", _overlay_of_type("Combat") != null)
	_close_overlays()
	w.cur_mob = null
	await _wait(0.2)
	# бой
	G.p.hp = 999
	M.start_combat("pes", func(r): print("SMOKE combat result ", r))
	await _wait(1.8)
	var cb = _overlay_of_type("Combat")
	await _shot("14_combat")
	if cb:
		print("SMOKE ov ", M.overlay.size, " cb rect ", cb.get_global_rect(), " bg ", cb.get_child(0).get_global_rect(), " vis ", cb.get_child(0).visible, " col ", cb.get_child(0).color)
	if cb:
		cb._pick_target(false)
		await _wait(0.2)
		await _shot("15_combat_target")
		for i in 12:
			if cb.finished or not is_instance_valid(cb):
				break
			while cb.busy:
				await _wait(0.1)
			var alive: Array = cb.parts.filter(func(p): return p.hp > 0)
			if alive.is_empty():
				break
			cb._attack(true, alive[0])
			await _wait(0.2)
			while is_instance_valid(cb) and cb.busy:
				await _wait(0.1)
		await _shot("16_combat_end")
	_close_overlays()
	G.p.hp = G.max_hp()
	M.start_combat("iskaz", func(r): print("SMOKE combat2 ", r))
	await _wait(1.8)
	await _shot("17_combat_warped")
	_close_overlays()
	_close_overlays()
	# смена оружия в бою
	G.add_item("Красный")
	M.start_combat("pes", func(r): print("SMOKE combat3 ", r))
	await _wait(1.6)
	var cb3 = _overlay_of_type("Combat")
	if cb3:
		print("SMOKE spare weapons ", cb3._spare_weapons())
		cb3._weapons_menu()
		await _wait(0.3)
		await _shot("17b_weapon_menu")
		cb3._switch_weapon("Красный")
		await _wait(0.3)
		print("SMOKE weapon now ", G.p.weapon)
	_close_overlays()
	# карта мира
	M.show_map()
	await _wait(0.8)
	await _shot("19_worldmap")
	var wm = M.current
	wm.select("outskirts")
	await _wait(0.3)
	await _shot("20_map_info")
	var food0 = G.p.food
	wm.select_point(Vector2(420, 120))
	wm.walk("")
	for i in 60:
		await _wait(0.2)
		var cbx = _overlay_of_type("Combat")
		if cbx:
			print("SMOKE map fight")
			await _shot("21_map_fight")
			cbx._end("win")
		if not wm.walking:
			break
	print("SMOKE scouted at ", G.p.map_at, " known ", G.p.known, " food ", food0, "->", G.p.food, " day ", G.p.day, " h ", G.p.hour)
	G.p.known.append("river")
	wm.select("river")
	wm.walk("river")
	for i in 60:
		await _wait(0.2)
		var cbx = _overlay_of_type("Combat")
		if cbx:
			cbx._end("win")
		if not wm.walking:
			break
	wm.enter("river")
	await _wait(1.5)
	await _shot("22_river")
	_close_overlays()
	G.p.su = 500
	wm.select("caldera")
	wm.taxi("caldera")
	await _wait(0.8)
	print("SMOKE taxi -> map ", G.p.map, " su ", G.p.su)
	await _shot("23_back_caldera")
	G.save(1)
	M.show_map()
	await _wait(0.4)
	print("SMOKE load map slot ", G.load_slot(1), " map ", G.p.map)
	_check_story()
	print("SMOKE load ok: ", G.load_slot(0))
	M.show_world(G.p.map)
	await _wait(0.6)
	await _shot("18_loaded")
	print("SMOKE DONE")
	get_tree().quit()


func _overlay_of_type(_t: String):
	for c in M.overlay.get_children():
		if c.get("enemy_id") != null:
			return c
	return null


func _close_overlays() -> void:
	for c in M.overlay.get_children():
		c.queue_free()


func _check_story() -> void:
	var nodes: Dictionary = preload("res://scripts/story.gd").nodes()
	var bad := 0
	for id in nodes:
		var n: Dictionary = nodes[id]
		var targets: Array = []
		for r in n.get("route", []):
			targets.append(r[r.size() - 1])
		for ch in n.get("choices", []):
			for k in ["next", "ok", "fail"]:
				if ch.has(k):
					targets.append(ch[k])
		if n.has("next"):
			targets.append(n.next)
		for t in targets:
			if t != "end" and not nodes.has(t):
				print("SMOKE BAD LINK ", id, " -> ", t)
				bad += 1
	var mp = preload("res://scripts/maps.gd").new()
	for m in ["caldera", "waste"]:
		for o in mp.get_map(m).objs:
			if o.get("action", "") != "" and not nodes.has(o.action):
				print("SMOKE BAD ACTION ", o.action)
				bad += 1
	print("SMOKE story nodes: ", nodes.size(), " bad links: ", bad)


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(name: String) -> void:
	if out == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out + "/" + name + ".png")
