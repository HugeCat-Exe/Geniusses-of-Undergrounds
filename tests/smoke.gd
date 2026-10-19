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
	M.open_pager(5)
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
	M.open_pager(3)
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
	var views := {"station": Vector2i(7, 8), "river": Vector2i(17, 16), "tower": Vector2i(13, 11), "den": Vector2i(13, 6), "ruins": Vector2i(6, 7), "forest": Vector2i(14, 13)}
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
		var howl: Dictionary = D.ENEMIES.muezzin.attacks[1]
		var mind0: int = G.p.mind
		cbm._prayer(howl)
		await _wait(1.6)
		await _shot("20c_prayer")
		await _wait(4.0)
		print("SMOKE prayer mind ", mind0, " -> ", G.p.mind)
		cbm._victory()
		await _wait(0.5)
		cbm._end("win")
	await _wait(0.5)
	_close_overlays()
	print("SMOKE muezzin trophy ", G.has("Глотка Муэдзина"), " job ", G.job_by_id("muezzin_gunsmith").state)
	G.turn_in("muezzin_gunsmith")
	print("SMOKE unlock sword ", G.flag("job_done_muezzin_gunsmith"))
	var mp2 = preload("res://scripts/maps.gd").new()
	var cnt := func():
		var k := 0
		for o in mp2.get_map("poi_den").objs:
			if o.get("enemy", "") == "muezzin" and not (o.id in G.p.killed):
				k += 1
		return k
	var d0: int = G.p.day
	print("SMOKE muezzin dead_day ", G.p.flags.get("muezzin_dead_day"), " now ", cnt.call())
	G.p.day = d0 + 3
	print("SMOKE muezzin after 3 days ", cnt.call())
	G.p.day = d0
	# ярус 4 и домик Рыжей
	M.show_world("caldera4", "lift")
	await _wait(0.8)
	await _shot("25_floor4")
	G.p.rel["ryzhaya"] = 0
	M.open_dialogue("ry_door")
	await _wait(0.5)
	await _shot("25b_door_shut")
	_close_overlays()
	G.p.rel["ryzhaya"] = 30
	M.open_dialogue("ry_door")
	await _wait(0.5)
	await _shot("25c_door_open")
	_choose_first()
	await _wait(0.8)
	print("SMOKE ry home map ", G.p.map)
	await _shot("25d_ry_home")
	G.set_companion("")
	for dd in 4:
		G.p.day = d0 + dd
		var in_home := 0
		var in_bar := 0
		for o in mp2.get_map("caldera_ryhome").objs:
			if o.get("id", "") == "ryzhaya":
				in_home += 1
		for o in mp2.get_map("caldera3").objs:
			if o.get("id", "") == "ryzhaya":
				in_bar += 1
		print("SMOKE ry day ", G.p.day, " home ", in_home, " bar ", in_bar)
	G.p.day = d0
	G.set_companion("ryzhaya")
	await _wait(0.4)
	# спасение бедолаги
	for j in G.p.jobs.duplicate():
		print("SMOKE job before rescue ", j.id, " ", j.kind, " ", j.state)
		if j.kind == "escort":
			G.p.jobs.erase(j)
	G.take_job(G._make_job(D.RESCUE_JOB, RandomNumberGenerator.new(), "rescue_test"))
	var su0: int = G.p.su
	M.show_world("poi_ruins", "enter")
	await _wait(0.6)
	var strays := 0
	for o in M.world.objs:
		if o.get("id", "") == "stray":
			strays += 1
	M.open_dialogue("stray_start")
	await _wait(0.4)
	_choose_first()
	await _wait(0.8)
	_close_overlays()
	M.world.ppos = Vector2i(10, 6)
	M.world.pf = Vector2(10, 6)
	M.world.esc_pos = Vector2(8, 6)
	for k in 4:
		M.world.path.append(Vector2i(10 + k + 1, 6))
	await _wait(1.5)
	await _shot("26_escort")
	print("SMOKE escort strays ", strays, " state ", G.escort_job().state)
	M.show_world("caldera1", "surface")
	await _wait(0.6)
	print("SMOKE escort done ", G.escort_job() == null, " su ", su0, " -> ", G.p.su, " rescued ", G.flag("rescued_once"))
	# ---- 0.8 ----
	G.p.su += 500
	# обвесы
	G.add_item("Тяжёлая рукоять")
	print("SMOKE mod melee ", G.use_item("Тяжёлая рукоять"), " mult ", G.melee_mult(G.p.melee))
	G.add_item("Прицел (карабин)")
	print("SMOKE mod wrong ", G.use_item("Прицел (карабин)"))
	print("SMOKE weapon class ", G.p.weapon, " ", G.weapon_class(G.p.weapon), " mag ", G.mag_size(G.p.weapon), " reload ", G.reload_time(G.p.weapon))
	for nm in D.ITEMS:
		if D.ITEMS[nm].get("type", "") == "mod" and D.ITEMS[nm].fits == G.weapon_class(G.p.weapon) and D.ITEMS[nm].mod == "mag":
			G.add_item(nm)
			print("SMOKE mod mag ", G.use_item(nm), " mag ", G.mag_size(G.p.weapon))
	# рейд
	M.show_world("caldera4", "lift")
	await _wait(0.4)
	M.open_dialogue("raid_hatch")
	await _wait(0.4)
	await _shot("27_hatch_sealed")
	_close_overlays()
	M.open_dialogue("miron_hatch")
	await _wait(0.4)
	_choose_first()
	await _wait(0.6)
	_close_overlays()
	print("SMOKE raid open ", G.flag("raid_open"))
	M.show_world("raid1", "top")
	await _wait(0.8)
	for m in M.world.mobs:
		m.stun = 999.0
	await _shot("28_raid1")
	M.open_dialogue("raid_c1")
	await _wait(0.6)
	await _shot("28b_raid_loot")
	_close_overlays()
	M.open_dialogue("raid_c1")
	await _wait(0.4)
	print("SMOKE raid c1 empty ", _dialogue().current_id if _dialogue() else "?")
	_close_overlays()
	M.show_world("raid2", "top")
	await _wait(0.8)
	for m in M.world.mobs:
		m.stun = 999.0
	await _shot("29_raid2")
	M.start_combat("slepysh", M._battle_end.bind("", ""))
	await _wait(1.0)
	await _shot("29b_slepysh")
	var cbs = _overlay_of_type("Combat")
	if cbs:
		cbs._end("win")
	await _wait(0.5)
	_close_overlays()
	# экран заданий
	G.p.flags["board_done"] = 0
	M.show_world("caldera2", "down1")
	await _wait(0.4)
	M.open_dialogue("board")
	await _wait(0.6)
	await _shot("30_jobscreen_locked")
	_close_overlays()
	G.p.flags["board_done"] = 3
	M.open_dialogue("board")
	await _wait(0.6)
	await _shot("30b_jobscreen")
	print("SMOKE specials ", G.special_offers().size())
	_close_overlays()
	# крафт
	G.add_item("Шкура пса", 4)
	G.add_item("Мусор", 2)
	M.open_dialogue("craft_gunsmith")
	await _wait(0.6)
	await _shot("31_craft")
	_close_overlays()
	var before_r: int = G.p.inv.get("Тяжёлая рукоять", 0)
	G.craft("gunsmith", 0)
	print("SMOKE craft ", before_r, " -> ", G.p.inv.get("Тяжёлая рукоять", 0))
	# слухи
	print("SMOKE rumor ", G.buy_rumor(), " cache ", G.p.flags.get("rumor_cache", ""))
	G.p.flags["rumor_cache"] = "station"
	var mp3 = preload("res://scripts/maps.gd").new()
	var rc := 0
	for o in mp3.get_map("poi_station").objs:
		if o.get("action", "") == "rumor_cache":
			rc += 1
	print("SMOKE rumor cache on map ", rc)
	# специи
	G.set_flag("cook_met")
	print("SMOKE spice ready ", G.spice_ready())
	G.quest("spice", "active")
	var herbs := 0
	for m in ["waste", "poi_den", "poi_forest"]:
		for o in mp3.get_map(m).objs:
			if str(o.get("action", "")).begins_with("herb_"):
				herbs += 1
	print("SMOKE herbs on maps ", herbs)
	for hb in D.HERBS:
		G.add_item(hb)
	M.show_world("caldera3", "down2")
	await _wait(0.4)
	M.open_dialogue("spice_done")
	await _wait(0.5)
	_close_overlays()
	print("SMOKE spice done ", G.flag("spice_done"), " ", G.p.quests.get("spice"))
	# мини-игры
	M.open_minigame("recipe")
	await _wait(2.5)
	await _shot("32_recipe")
	await _wait(5.5)
	_close_overlays()
	print("SMOKE recipe su ", G.p.su)
	M.open_minigame("cups")
	await _wait(2.4)
	await _shot("33_cups")
	await _wait(12.0)
	_close_overlays()
	G.add_item("Бинт", 2)
	G.p.hp = 30
	M.open_minigame("needle")
	await _wait(1.0)
	await _shot("34_needle")
	await _wait(3.0)
	_close_overlays()
	print("SMOKE needle hp ", G.p.hp)
	# ночь
	G.p.hour = 23
	M.show_world("poi_forest", "enter")
	await _wait(1.0)
	await _shot("35_night_forest")
	G.p.hour = 12
	M.show_world("poi_forest", "enter")
	await _wait(1.0)
	await _shot("35b_day_forest")
	G.p.hour = 14
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
	await _smoke_09()
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


## Проверки версии 0.9.
func _smoke_09() -> void:
	# старое сохранение: счётчик заданий пересчитывается по флагам
	G.p.flags.erase("save_ver")
	G.p.flags["board_done"] = 0
	for k in ["job_done_d1_0", "job_done_d2_3", "job_done_d3_1"]:
		G.p.flags[k] = true
	G._migrate()
	print("SMOKE 09 migrate board_done ", G.p.flags.board_done)
	# кулдауны
	G.p.flags["jobcd_1"] = G.p.day
	var mistel := false
	for o in G.board_offers():
		if o.giver == "mistel":
			mistel = true
	print("SMOKE 09 cooldown mistel ", G.job_cooldown(1), " offered ", mistel)
	# тайник для задания в случайном месте
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var j := G._make_job(D.JOBS[5], rng, "d99_5")
	G.take_job(j)
	M.show_world("poi_" + j.poi, "enter")
	await _wait(0.8)
	var spot = null
	for o in M.world.objs:
		if str(o.get("action", "")).begins_with("jobspot:"):
			spot = o
	print("SMOKE 09 spot poi ", j.poi, " found ", spot != null, " text ", j.text.substr(0, 60))
	await _shot("40_jobspot")
	if spot != null:
		M.world._interact(spot)
		await _wait(0.6)
		await _shot("41_jobspot_dlg")
		_close_overlays()
		G.job_found(j.id)
	print("SMOKE 09 spot job ", G.job_by_id("d99_5").state if G.job_by_id("d99_5") != null else "none")
	# лечение черт
	var ph: String = D.PHYS.keys()[0]
	var ps: String = D.PSY.keys()[0]
	G.p.got_phys.append(ph)
	G.p.got_psy.append(ps)
	G.p.su += 400
	M.open_dialogue("autodoc")
	await _wait(0.8)
	await _shot("42_autodoc")
	var dl = M.overlay.get_child(M.overlay.get_child_count() - 1)
	print("SMOKE 09 cure phys ", dl._cure("phys", ph).substr(0, 40), " left ", G.p.got_phys.size())
	_close_overlays()
	M.show_world("poi_forest", "enter")
	await _wait(0.6)
	var st := false
	for o in M.world.objs:
		if o.get("id", "") == "stranger":
			st = true
	M.open_dialogue("stranger_start")
	await _wait(1.0)
	await _shot("43_stranger")
	dl = M.overlay.get_child(M.overlay.get_child_count() - 1)
	print("SMOKE 09 stranger ", st, " cure psy ", dl._cure("psy", ps).substr(0, 30), " left ", G.p.got_psy.size())
	_close_overlays()
	# отношения: скидка и приветствие
	G.p.rel["trader"] = 50
	G.shop_who = "trader"
	print("SMOKE 09 rel price 100 -> ", G.price(100), " greet ", G.rel_greeting("trader", "Бартоломей", false).substr(0, 30))
	G.shop_who = ""
	M.open_shop(preload("res://scripts/story.gd").SHOPS.trader, "ЛАВКА", "trader")
	await _wait(0.5)
	await _shot("44_shop_rel")
	_close_overlays()
	# шестой ярус: слепцы
	M.show_world("raid2", "top")
	await _wait(0.6)
	var sl := 0
	for m in M.world.mobs:
		if m.enemy == "slepets":
			sl += 1
	print("SMOKE 09 raid2 slepets ", sl)
	# «!» и задержка перед боем
	if not M.world.mobs.is_empty():
		var mb = M.world.mobs[0]
		M.world.start_encounter(mb)
		await _wait(0.15)
		await _shot("45_alert")
		await _wait(0.8)
		print("SMOKE 09 encounter opened ", M.has_overlay())
		await _shot("46_slepets_combat")
		var cb = M.overlay.get_child(M.overlay.get_child_count() - 1)
		if cb.has_method("_attack"):
			cb.busy = false
			cb._attack(true, cb.parts[1])
			await _wait(0.2)
			await _shot("47_combat_pop")
			await _wait(3.0)
		_close_overlays()
	# пейджер: имущество не вылезает за экран
	G.add_item("Бинт")
	G.add_item("Прицел (пистолет)")
	M.open_pager(1)
	await _wait(0.5)
	var pg = M.overlay.get_child(M.overlay.get_child_count() - 1)
	print("SMOKE 09 pager content width ", pg.content.size.x, " scroll ", pg.scroll.size.x)
	await _shot("48_pager_inv")
	_close_overlays()
	await _wait(0.2)


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
	for m in ["caldera1", "caldera2", "caldera3", "caldera4", "caldera_ryhome", "waste", "poi_station", "poi_river", "poi_tower", "poi_den", "poi_ruins", "poi_forest", "raid1", "raid2"]:
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
