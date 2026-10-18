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
	cr.desc.text = "[b]Рыжие волосы[/b]\n" + cr._trait_info("Рыжие волосы", D.PHYS["Рыжие волосы"])
	await _wait(0.3)
	await _shot("04_creator_traits")
	cr._on_meta("ЛВК")
	await _wait(0.2)
	await _shot("04b_creator_stat_hover")
	cr.step = 8
	cr._build()
	await _wait(0.3)
	await _shot("04c_creator_skills")
	print("SMOKE stats ", D.ATTRS.map(func(k): return "%s=%d(%+d)" % [k, G.stat(k, cr.c), G.mod(k, cr.c)]), " hp ", G.max_hp(cr.c), " mind ", G.max_mind(cr.c), " perks ", G.perks(cr.c), " mains ", G.main_count(cr.c))
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
	await _shot("07_floor1")
	print("SMOKE map ", G.p.map, " pos ", G.p.pos)
	M.open_dialogue("res_kid")
	await _wait(1.5)
	await _shot("07b_kid")
	_close_overlays()
	M.open_dialogue("lift")
	await _wait(0.8)
	await _shot("07c_lift")
	_close_overlays()
	M.show_world("caldera2", "down1")
	await _wait(0.8)
	await _shot("08_floor2")
	M.world.ppos = Vector2i(10, 10)
	M.world.pf = Vector2(10, 10)
	await _wait(0.6)
	await _shot("08b_floor2_shaft")
	M.open_dialogue("surgeon_start")
	await _wait(2.0)
	await _shot("09_surgeon_rel")
	_close_overlays()
	G.p.hp = 40
	M.open_dialogue("autodoc")
	await _wait(1.0)
	await _shot("09b_autodoc")
	_close_overlays()
	# голос черты и исход
	M.open_dialogue("trader_start")
	await _wait(0.3)
	var dlg = _dialogue()
	dlg.voice = {"trait": "Жадность", "line": "На нём вещей на сотню Су. Он может заплатить больше."}
	dlg._show("trader_start")
	await _wait(2.0)
	await _shot("09c_voice")
	dlg._live({"live": ["voice", "Жадность"]})
	await _wait(0.5)
	await _shot("09d_voice_result")
	_close_overlays()
	M.open_dialogue("board")
	await _wait(1.0)
	await _shot("10_board")
	var offers := G.board_offers()
	print("SMOKE offers ", offers.size())
	for o in offers:
		G.take_job(o)
	_close_overlays()
	M.open_pager(2)
	await _wait(0.4)
	await _shot("10b_pager_jobs")
	_close_overlays()
	M.open_pager(0)
	await _wait(0.4)
	for c in M.overlay.get_children():
		if c.has_method("_on_meta"):
			c._on_meta("Ловкач" if G.has_perk("Ловкач") else "ВСП")
	await _wait(0.2)
	await _shot("11_pager_sheet")
	_close_overlays()
	M.open_pager(4)
	await _wait(0.4)
	await _shot("11b_pager_system")
	_close_overlays()
	M.open_shop(preload("res://scripts/story.gd").SHOPS.guns, "ОРУЖЕЙНАЯ САВЫ КЛИНА")
	await _wait(0.4)
	for c in M.overlay.get_children():
		if c.has_method("_show_about"):
			c._show_about("Землерой")
	await _wait(0.2)
	await _shot("12_shop_guns")
	_close_overlays()
	M.open_pager(1)
	await _wait(0.4)
	await _shot("12b_pager_inventory")
	_close_overlays()
	M.show_world("caldera3", "down2")
	await _wait(0.8)
	await _shot("13_floor3")
	M.world.ppos = Vector2i(17, 4)
	M.world.pf = Vector2(17, 4)
	await _wait(0.6)
	await _shot("13b_bar")
	M.open_dialogue("ry_start")
	await _wait(2.0)
	await _shot("14_ryzhaya")
	_close_overlays()
	# поручения Рыжей
	M.open_dialogue("ry_job0_offer")
	await _wait(0.3)
	_choose_first()
	await _wait(0.3)
	print("SMOKE ry job ", G.job_by_id("ry_0") != null)
	G.on_kill("pes")
	G.on_kill("pes")
	print("SMOKE ry job state ", G.job_by_id("ry_0").state, " jobs ", G.p.jobs.size())
	M.open_dialogue("ry_menu")
	await _wait(0.5)
	await _shot("14b_turnin")
	_close_overlays()
	G.turn_in("ry_0")
	G.p.flags["ry_errands"] = 2
	G.rel_add("ryzhaya", 8)
	print("SMOKE ry rel ", G.rel_points("ryzhaya"), " ", G.rel_tier("ryzhaya").name)
	M.open_dialogue("ry_test_1")
	await _wait(1.5)
	await _shot("15_ry_test")
	_close_overlays()
	G.rel_add("ryzhaya", 9)
	M.open_dialogue("ry_test_end")
	await _wait(0.5)
	_choose_first()
	await _wait(0.6)
	print("SMOKE companion ", G.p.companion)
	_close_overlays()
	G.refresh_world()
	await _wait(0.8)
	var ry_n := 0
	for o in M.world.objs:
		if o.type == "npc" and o.id == "ryzhaya":
			ry_n += 1
	print("SMOKE ryzhaya npcs on map after join ", ry_n, " map ", G.p.map, " mate ", M.world.has_mate())
	await _shot("15b_after_join")
	M.open_pager(5)
	await _wait(0.4)
	await _shot("15c_social")
	_close_overlays()
	G.save(0)
	M.show_world("waste", "road")
	await _wait(1.0)
	await _shot("16_waste_road")
	var w = M.world
	print("SMOKE waste mate ", w.has_mate())
	w._path_to(Vector2i(6, 6))
	await _wait(2.0)
	await _shot("16b_mate_follow")
	# бой со спутницей
	_close_overlays()
	G.p.hp = 999
	M.start_combat("pes", func(r): print("SMOKE combat result ", r))
	await _wait(1.8)
	var cb = _overlay_of_type("Combat")
	if cb:
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
		await _shot("17_combat_mate")
	_close_overlays()
	G.p.hp = G.max_hp()
	# изучение пустоши
	for i in 4:
		M.explore()
		await _wait(0.8)
		if i == 0:
			await _shot("18a_explore_ask")
		for c in M.overlay.get_children():
			if c.has_method("_choose") and c.current_id == "explore_ask":
				c._choose(c.nodes["explore_ask"].choices[0])
		await _wait(0.8)
		var cbx = _overlay_of_type("Combat")
		if cbx == null:
			for c in M.overlay.get_children():
				if c.has_method("_choose") and c.current_id == "explore":
					var nd: Dictionary = c.nodes["explore"]
					if nd.choices[0].has("fx"):
						c._choose(nd.choices[0])
		await _wait(1.6)
		if i == 0:
			await _shot("18_explore")
		cbx = _overlay_of_type("Combat")
		if cbx:
			cbx._end("win")
		_close_overlays()
		await _wait(0.3)
	print("SMOKE known after explore ", G.p.known, " day ", G.p.day, " h ", G.p.hour)
	# серьга в логове
	G.take_job(G._make_job(D.RY_EARRING, RandomNumberGenerator.new(), "ry_earring"))
	M.show_map()
	await _wait(0.8)
	await _shot("19_worldmap")
	# прогулки по открытым местам
	var views := {"station": Vector2i(7, 8), "river": Vector2i(17, 16), "tower": Vector2i(13, 11), "den": Vector2i(13, 6)}
	for id in views:
		if not (id in G.p.known):
			G.p.known.append(id)
		G.p.map_at = id
		M.show_world("poi_" + id, "enter")
		await _wait(0.8)
		for m in M.world.mobs:
			m.stun = 999.0
		await _shot("20_poi_%s_enter" % id)
		M.world.ppos = views[id]
		M.world.pf = Vector2(views[id])
		await _wait(0.8)
		await _shot("20_poi_%s" % id)
		print("SMOKE poi ", id, " objs ", M.world.objs.size(), " mobs ", M.world.mobs.size())
	# Собачий Муэдзин
	G.take_job(G._make_job(D.SPECIAL_JOBS.muezzin_gunsmith, RandomNumberGenerator.new(), "muezzin_gunsmith"))
	M.start_combat("muezzin", M._battle_end.bind("", ""))
	await _wait(1.2)
	await _shot("20b_muezzin")
	var cbm = _overlay_of_type("Combat")
	if cbm:
		cbm._victory()
		await _wait(0.5)
		cbm._end("win")
	await _wait(0.5)
	_close_overlays()
	print("SMOKE muezzin trophy ", G.has("Глотка Муэдзина"), " job ", G.job_by_id("muezzin_gunsmith").state)
	G.turn_in("muezzin_gunsmith")
	print("SMOKE unlock sword ", G.flag("job_done_muezzin_gunsmith"))
	# голод: не убивает
	var mh: int = G.max_hp()
	G.p.food = 1
	for k in 20:
		G.step(true)
	print("SMOKE starving ", G.starving(), " max_hp ", mh, " -> ", G.max_hp(), " hp ", G.p.hp, " map ", G.p.map)
	G.feed(50)
	G.add_item("Каска шахтёра")
	G.add_item("Камень души")
	print(G.use_item("Каска шахтёра"), " ", G.use_item("Камень души"), " armor ", G.armor_total())
	M.world.ppos = Vector2i(23, 16)
	M.world.pf = Vector2(23, 16)
	M.show_map()
	await _wait(0.6)
	M.open_dialogue("poi_den")
	await _wait(1.0)
	await _shot("20_den")
	G.temp_nodes["find_ok"] = {"who": "", "text": "x", "choices": [{"t": "ok", "next": "end"}]}
	for c in M.overlay.get_children():
		if c.has_method("_choose"):
			c._choose({"t": "x", "fx": [["find_job", "ry_earring"]], "next": "end"})
	await _wait(1.5)
	var cbe = _overlay_of_type("Combat")
	if cbe:
		cbe._end("win")
	await _wait(0.6)
	print("SMOKE earring ", G.has("Серьга Рыжей"), " state ", G.job_by_id("ry_earring").state)
	_close_overlays()
	_check_story()
	print("SMOKE load ok: ", G.load_slot(0), " map ", G.p.map)
	M.show_world(G.p.map)
	await _wait(0.6)
	await _shot("21_loaded")
	# смерть в Пустоши и загрузка с экрана гибели
	M.show_world("waste", "road")
	await _wait(0.6)
	var before_hp: int = G.p.hp
	M.start_combat("pes", M._battle_end.bind("", ""))
	await _wait(1.0)
	var cbd = _overlay_of_type("Combat")
	G.p.hp = -20
	cbd._end("dead")
	await _wait(0.6)
	await _shot("22_game_over")
	var load_btn: Button = null
	for b in M.ui.find_children("*", "Button", true, false):
		if b.text.begins_with("Загрузить"):
			load_btn = b
	print("SMOKE game over load button ", load_btn != null, " newest slot ", G.any_save())
	if load_btn:
		load_btn.pressed.emit()
		await _wait(0.8)
		print("SMOKE after death load map ", G.p.map, " hp ", G.p.hp, " (before ", before_hp, ") world ", M.world != null)
		await _shot("23_after_death_load")
	M.show_title()
	await _wait(1.8)
	await _shot("24_title_again")
	print("SMOKE DONE")
	get_tree().quit()


func _dialogue():
	for c in M.overlay.get_children():
		if c.has_method("_choose") and not c.is_queued_for_deletion():
			return c
	return null


func _choose_first() -> void:
	for c in M.overlay.get_children():
		if c.has_method("_choose"):
			var live: Array = []
			for b in c.choices.get_children():
				if not b.is_queued_for_deletion():
					live.append(b)
			if live.size() > 0:
				live[0].pressed.emit()


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
	for m in ["caldera1", "caldera2", "caldera3", "waste", "poi_station", "poi_river", "poi_tower", "poi_den"]:
		for o in mp.get_map(m).objs:
			if o.get("action", "") != "" and not o.action.begins_with("go:") and not nodes.has(o.action):
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
