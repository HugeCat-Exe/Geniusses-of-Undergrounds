extends Node

const Sched := preload("res://scripts/sched.gd")
const Live := preload("res://scripts/live.gd")
const Ach := preload("res://scripts/ach.gd")
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
	cr.approve.text = "Принимаю"
	cr._refresh()
	await _wait(0.3)
	await _shot("05_creator_verdict")
	cr._next()
	await _wait(1.5)
	await _shot("06_intro")
	_close_overlays()
	await _wait(0.8)
	if OS.get_environment("GP_ONLY") == "013":
		await _smoke_013()
		_check_story()
		print("SMOKE DONE")
		get_tree().quit()
		return
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
	if G.p.weapon != "":
		var am: String = D.ITEMS[G.p.weapon].ammo
		G.add_item(am)
		var before := G.ammo_left()
		G.p.mag = maxi(0, G.mag_size(G.p.weapon) - 1)
		var total := G.ammo_left()
		G.reload()
		print("SMOKE ammo reload ok=", G.ammo_left() == total and G.p.mag == G.mag_size(G.p.weapon), " before ", before, " total ", total, " after ", G.ammo_left(), " loose ", G.p.loose)
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
	await _smoke_091()
	await _smoke_010()
	await _smoke_011()
	await _smoke_012()
	await _smoke_013()
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


## Проверки версии 0.9.1.
func _smoke_091() -> void:
	# Дана: спутница-защитница
	G.p.rel["patrol"] = 30
	M.show_world("caldera2", "")
	await _wait(0.6)
	M.open_dialogue("dana_start")
	await _wait(0.8)
	await _shot("50_dana")
	_close_overlays()
	G.set_companion("patrol")
	await _wait(0.8)
	print("SMOKE 091 dana companion ", G.p.companion, " mate ", M.world.has_mate(), " dana npc on map ", M.world.cut_find("patrol") != null)
	await _shot("51_dana_follow")
	M.start_combat("pes", func(_r): pass)
	await _wait(1.2)
	var cb = M.overlay.get_child(M.overlay.get_child_count() - 1)
	await cb._dana_turn()
	await _wait(0.3)
	await _shot("52_dana_combat")
	print("SMOKE 091 dana skip ", cb.enemy_skip)
	_close_overlays()
	G.set_companion("")
	await _wait(0.6)
	# HUD
	M.world._update_hud()
	print("SMOKE 091 hud ", M.world.hud_text.text.get_slice("Оружие", 1).substr(0, 30))
	# сердца
	G.p.rel["ryzhaya"] = 50
	print("SMOKE 091 hearts ry ", G.heart_state("ryzhaya").text, " | dana ", G.heart_state("patrol").text)
	M.open_pager(3)
	await _wait(0.5)
	await _shot("53_hearts")
	_close_overlays()
	# катсцена (тестовая, не из игры)
	M.show_world("caldera2", "")
	await _wait(0.6)
	var done := [false]
	M.world.play_cutscene([["spawn", "patrol", 10, 6], ["cam", 10, 6], ["walk", "patrol", 12, 6], ["face", "patrol", "left"],
		["emote", "patrol", "♥"], ["say", "patrol", "— Тестовая сцена. Сердца пишет Михаил."], ["say", "", "Авторский текст."], ["cam"]], func(): done[0] = true)
	await _wait(1.6)
	await _shot("54_cutscene")
	for k in 40:
		if done[0]:
			break
		await _wait(0.25)
	print("SMOKE 091 cutscene done ", done[0], " blocked ", M.world.blocked())
	# свойство постсмертия
	var lvk := D.KEYS.find("ЛВК")
	var bad := ""
	for tr in D.PHYS:
		if D.PHYS[tr][lvk] <= -4:
			bad = tr
	if bad != "":
		for k in 3:
			G.p.got_phys.append(bad)
	print("SMOKE 091 perk cause ", bad, " -> ", G.perk_cause("Неуклюжий"), " perks ", G.perks())
	G.p.got_phys.clear()
	# подвал: всегда ночь
	M.show_world("raid1", "top")
	await _wait(0.8)
	print("SMOKE 091 raid dark ", M.world.dark, " lamps ", M.world.lamp_pos.size())
	await _shot("55_raid_dark")
	# травы
	G.quest("spice", "active")
	M.show_world("waste", "")
	await _wait(0.6)
	await _shot("56_herb")


func _smoke_010() -> void:
	_close_overlays()
	G.p.hour = 12
	# книжник и обложки
	M.show_world("caldera4", "down3")
	await _wait(0.8)
	await _shot("60_floor4_books")
	M.open_dialogue("lib_start")
	await _wait(0.8)
	await _shot("61_librarian")
	_dialogue()._choose({"t": "x", "fx": [["shop", "library"]], "next": "end"})
	await _wait(0.6)
	var sh = M.overlay.get_child(M.overlay.get_child_count() - 1)
	print("SMOKE 010 lib stock ", G.lib_stock())
	if sh.has_method("_show_cover"):
		sh._show_cover(G.lib_stock()[0])
	await _wait(0.3)
	await _shot("62_library_shop")
	_close_overlays()
	var int0 := G.stat("ИНТ")
	G.add_item("«Интеллект»")
	G.use_item("«Интеллект»")
	await _wait(0.6)
	print("SMOKE 010 book INT ", int0, " -> ", G.stat("ИНТ"), " buffs ", G.active_buffs(), " left ", G.has("«Интеллект»"))
	await _shot("63_book_read")
	_close_overlays()
	# старьёвщик не берёт патроны
	G.add_item("Пистолетные патроны")
	G.add_item("Шкура пса")
	M.open_dialogue("trader_start")
	await _wait(0.5)
	_dialogue()._choose({"t": "x", "fx": [["shop", "trader"]], "next": "end"})
	await _wait(0.6)
	print("SMOKE 010 buy_k trader ammo ", G.buy_k("trader", "Пистолетные патроны"), " hide ", G.buy_k("trader", "Шкура пса"), " gunsmith hide ", G.buy_k("gunsmith", "Шкура пса"))
	await _shot("64_trader_sell")
	_close_overlays()
	# реплики: фракция, рассудок, черты
	G.p.mind = 30
	G.p.flags.erase("fg_cook")
	M.open_dialogue("cook_start")
	await _wait(1.2)
	var dl = _dialogue()
	if dl:
		dl.text.visible_characters = -1
	await _shot("65_dialogue_mind")
	_close_overlays()
	G.p.mind = G.max_mind()
	# намерение врага
	M.show_world("waste", "road")
	await _wait(0.6)
	M.start_combat("pes", func(_r): pass)
	await _wait(1.6)
	var cb = _overlay_of_type("Combat")
	if cb:
		print("SMOKE 010 intent ", cb.intent.get("name", "-"))
		if cb.intent.is_empty():
			cb._plan()
	await _shot("66_combat_intent")
	_close_overlays()
	await _wait(0.4)
	# тела и кровь
	M.world._add_body({"fpos": M.world.pf + Vector2(2, 0), "enemy": "pes", "id": "pes_test"})
	M.world._add_body({"fpos": M.world.pf + Vector2(1, 2), "enemy": "slepets", "id": "sl_test"})
	await _wait(0.4)
	await _shot("67_bodies")
	# такси у входа
	M.open_dialogue("taxi_start")
	await _wait(0.8)
	await _shot("68_taxi")
	_dialogue()._choose({"t": "x", "fx": [["taxi"]], "next": "end"})
	await _wait(0.8)
	await _shot("69_taxi_map")
	_close_overlays()
	G.p.flags.erase("taxi_ride")
	# погода: ищем день с бурей и с дождём
	var found := {}
	for d in range(2, 60):
		for h in [8, 14]:
			G.p.day = d
			G.p.hour = h
			var w := G.weather()
			if w != "clear" and not found.has(w):
				found[w] = [d, h]
	print("SMOKE 010 weather days ", found)
	for w in found:
		G.p.day = found[w][0]
		G.p.hour = found[w][1]
		M.show_world("waste", "road")
		await _wait(3.0)
		print("SMOKE 010 weather ", w, " world ", M.world.wx, " sight ", M.world.sight())
		await _shot("70_weather_" + w)
	G.p.hour = 12
	G.new_day()
	print("SMOKE 010 bodies after new day ", G.p.bodies.size())
	# ночь в Кальдере
	G.p.hour = 23
	M.show_world("caldera3", "down2")
	await _wait(0.8)
	print("SMOKE 010 night smoker on caldera3 ", M.world.cut_find("smoker") != null)
	await _shot("71_night_bar")
	G.p.hour = 12
	# трекер
	M.show_world("raid1", "top")
	await _wait(0.8)
	M.world._update_hud()
	print("SMOKE 010 tracker ", G.tracker_lines())
	await _shot("72_tracker_raid")
	_close_overlays()


func _smoke_011() -> void:
	_close_overlays()
	G.p.hour = 12
	# все предметы мини-историй и подарков существуют
	var missing := []
	for k in G.MINI_LOOT:
		for l in G.MINI_LOOT[k]:
			if l[0] != "su" and not D.ITEMS.has(l[0]):
				missing.append(l[0])
	for it in D.WANDER_POOL:
		if not D.ITEMS.has(it):
			missing.append(it)
	print("SMOKE 011 missing items ", missing)
	# будка Даны на первом ярусе, вход по отношению
	M.show_world("caldera1", "start")
	await _wait(0.8)
	await _shot("80_floor1_booth")
	G.p.rel["patrol"] = 30
	M.open_dialogue("dana_door")
	await _wait(0.6)
	var dl = _dialogue()
	print("SMOKE 011 dana door open ", dl != null)
	await _shot("81_dana_door")
	_close_overlays()
	M.show_world("caldera_danahome", "door")
	await _wait(0.8)
	await _shot("82_dana_home")
	# распорядок: в 20:20 жители идут, в 23 стоят на ночных местах
	G.p.hour = 20
	G.p.minf = 30.0
	for id in Sched.ROUTINE:
		print("SMOKE 011 sched 20:30 ", id, " ", Sched.state(id))
	M.show_world("caldera2", "down1")
	await _wait(1.5)
	await _shot("83_evening_walk")
	G.p.hour = 23
	G.p.minf = 0.0
	print("SMOKE 011 night patrol home ", Sched.at_home("patrol", "caldera_danahome"), " kid ", Sched.state("kid"))
	G.p.hour = 6
	G.p.minf = 20.0
	print("SMOKE 011 morning smoker ", Sched.state("smoker"))
	G.p.hour = 12
	G.p.minf = 0.0
	# рассудок по доле
	G.p.mind = int(G.max_mind() * 0.88)
	print("SMOKE 011 mind ", G.p.mind, "/", G.max_mind(), " step ", Live.mind_step())
	G.p.mind = int(G.max_mind() * 0.2)
	print("SMOKE 011 mind ", G.p.mind, "/", G.max_mind(), " step ", Live.mind_step())
	G.p.mind = G.max_mind()
	# странник
	var wd := -1
	for d in range(2, 40):
		if G.wander_here(d):
			wd = d
			break
	G.p.day = wd
	print("SMOKE 011 wanderer day ", wd, " stock ", G.wander_stock())
	M.show_world("waste", "road")
	await _wait(0.8)
	print("SMOKE 011 wanderer on map ", M.world.cut_find("wanderer") != null)
	await _shot("84_wanderer")
	G.p.su += 500
	M.open_dialogue("wander_start")
	await _wait(0.5)
	_dialogue()._choose({"t": "x", "fx": [["shop", "wanderer"]], "next": "end"})
	await _wait(0.6)
	var sh = M.overlay.get_child(M.overlay.get_child_count() - 1)
	await _shot("85_wanderer_shop")
	var first: String = G.wander_left()[0]
	var q0 := G.wander_qty(first)
	if sh.has_method("_buy"):
		sh._buy(first)
	print("SMOKE 011 bought ", first, " qty ", q0, " -> ", G.wander_qty(first), " has ", G.has(first))
	_close_overlays()
	# подарки
	G.add_item("Перочинный нож")
	G.add_item("Серьги-капли")
	var r0 := int(G.p.rel.get("patrol", 0))
	print("SMOKE 011 can gift patrol ", G.can_gift("patrol"))
	G.temp_nodes["gift_result"] = {"who": "patrol", "text": G.give_gift("patrol", "Перочинный нож"), "choices": [{"t": "ok", "next": "end"}]}
	print("SMOKE 011 gift patrol rel ", r0, " -> ", G.p.rel.patrol, " again ", G.can_gift("patrol"))
	M.open_dialogue("gift_result")
	await _wait(0.8)
	await _shot("86_gift")
	_close_overlays()
	var ry0 := int(G.p.rel.get("ryzhaya", 0))
	print("SMOKE 011 gift ryzhaya ", G.give_gift("ryzhaya", "Серьги-капли").length() > 0, " rel ", ry0, " -> ", G.p.rel.ryzhaya)
	# вкладки вещей
	print("SMOKE 012 tabs ", G.item_tabs(G.p.inv.keys()), " ", G.sort_items(G.p.inv.keys()).slice(0, 4))
	M.open_pager(1)
	await _wait(0.6)
	await _shot("87_inventory_sort")
	_close_overlays()
	# достижения
	M.toast("Глядя собаке в глаза", "не видал ли ты своих?", "обычное", "achieve")
	await _wait(0.6)
	await _shot("88_achievement_toast")
	for i in 10:
		Ach.add("drink")
	print("SMOKE 011 ach drunk ", Ach.has("drunk"), " count ", Ach.count("drink"))
	# мини-истории: карты и путь с возвратом
	for mid in ["mini_bus", "mini_dogs", "mini_camp"]:
		G.p.flags["mini_n"] = int(G.p.flags.get("mini_n", 0)) + 1
		M.show_world(mid, "enter")
		await _wait(0.8)
		await _shot("89_" + mid)
	M.show_map()
	await _wait(0.6)
	var wm = M.current
	wm.walk("river" if "river" in G.p.known else G.p.known[0])
	wm.walk_t = 0.4
	wm.player_pos = wm.walk_from.lerp(wm.walk_to, 0.4)
	wm._fire({"kind": "story", "id": "mini_bus"})
	await _wait(0.6)
	await _shot("90_mini_ask")
	_dialogue()._choose({"t": "x", "fx": [["mini_go", "mini_bus"]], "next": "end"})
	await _wait(1.0)
	print("SMOKE 011 mini map ", G.p.map, " resume ", G.p.flags.get("walk_resume", ""))
	M.open_dialogue("mini_bus_trunk")
	await _wait(0.4)
	_dialogue()._choose({"t": "x", "fx": [["mini_flag", "trunk"], ["mini_loot", "bus"]], "next": "end"})
	await _wait(0.4)
	print("SMOKE 011 mini loot ", G.last_note, " done ", G.mini_done("trunk"))
	M.open_dialogue("leave_poi")
	await _wait(0.4)
	_dialogue()._choose({"t": "x", "fx": [["goto", "map", ""]], "next": "end"})
	await _wait(1.0)
	print("SMOKE 011 back on map walking ", M.current.walking if "walking" in M.current else "?", " target ", M.current.walk_target)
	await _shot("91_resume_walk")
	M.current.walking = false
	M.show_world("caldera1", "start")
	await _wait(0.6)
	# главное меню и список достижений
	M.show_title()
	await _wait(1.0)
	M.current._toggle_ach()
	await _wait(0.6)
	await _shot("92_title_achievements")
	M.current._toggle_ach()
	M.show_world("waste", "road")
	await _wait(0.6)


func _smoke_012() -> void:
	# уровни: до пятого, полоса и плашка
	M.show_world("caldera2", "start")
	await _wait(0.6)
	G.p.level = 1
	G.p.xp = 0
	G.add_xp(640)
	await _wait(0.8)
	print("SMOKE 012 level ", G.p.level, " xp ", G.p.xp, "/", G.xp_need())
	await _shot("93_level_up")
	# десятый уровень: выбор навыка открывается сам
	G.p.level = 9
	G.p.xp = 0
	G.add_xp(G.xp_need())
	await _wait(1.0)
	var sp = null
	for c in M.overlay.get_children():
		if c.has_method("_confirm"):
			sp = c
	print("SMOKE 012 skill pick open ", sp != null, " picks ", G.p.picks)
	await _shot("94_skill_pick")
	if sp:
		var main0: String = G.p.main[0] if G.p.main.size() > 0 else "Поиск"
		var b0 := G.skill_bonus(main0)
		sp._choose(D.SKILLS.filter(func(x): return x[0] == main0)[0])
		sp._confirm()
		print("SMOKE 012 picked ", main0, " x", G.main_times(main0), " bonus ", b0, " -> ", G.skill_bonus(main0))
	await _wait(0.6)
	_close_overlays()
	# вкладки у оружейника
	var gst: Array = []
	for it in D.ITEMS:
		if D.ITEMS[it].type in ["weapon", "ammo", "mod"] and gst.size() < 40:
			gst.append(it)
	M.open_shop(gst, "ОРУЖЕЙНИК", "gunsmith")
	await _wait(0.6)
	await _shot("95_shop_tabs")
	for c in M.overlay.get_children():
		if c.has_method("_set_tab"):
			c._set_tab("Патроны")
	await _wait(0.4)
	await _shot("96_shop_tab_ammo")
	_close_overlays()
	# внешность при первой встрече и «Осмотреть»
	G.p.flags.erase("look_taxi")
	M.open_dialogue("taxi_start")
	await _wait(1.2)
	await _shot("97_taxi_first_look")
	_close_overlays()
	M.open_dialogue("taxi_start")
	await _wait(1.2)
	await _shot("98_taxi_again")
	_close_overlays()
	M.open_dialogue("autodoc")
	await _wait(1.0)
	await _shot("99_autodoc")
	_close_overlays()
	# события Пустоши
	M.show_map()
	await _wait(0.6)
	var wm = M.current
	wm.walk("river" if "river" in G.p.known else G.p.known[0])
	wm.walk_t = 0.4
	for ev in [{"kind": "dogs", "n": 2}, {"kind": "story", "id": "riders"}, {"kind": "story", "id": "caravan"}, {"kind": "story", "id": "mini_bones"}]:
		wm._fire(ev)
		await _wait(0.8)
		await _shot("100_ev_" + str(ev.get("id", "dogs")))
		_close_overlays()
		await _wait(0.3)
	# две собаки по очереди
	wm.ev_fight("pes", 2)
	await _wait(1.0)
	var c1 = _overlay_of_type("Combat")
	if c1:
		c1._end("win")
	await _wait(1.0)
	var c2 = _overlay_of_type("Combat")
	print("SMOKE 012 chain second fight ", c2 != null)
	if c2:
		c2._end("win")
	await _wait(0.6)
	wm.walking = false
	wm.paused = false
	# гигантские кости
	G.p.flags["mini_n"] = int(G.p.flags.get("mini_n", 0)) + 1
	M.show_world("mini_bones", "enter")
	await _wait(0.8)
	await _shot("101_bones")
	print("SMOKE 012 bones ach ", preload("res://scripts/ach.gd").has("bones"))
	var hp0: int = G.p.hp
	print("SMOKE 012 pray ", G.bones_pray("Гебура").left(60), " hp ", hp0, " -> ", G.p.hp, " done ", G.mini_done("bones_pray"))
	print("SMOKE 012 pray other ", G.bones_pray("Бина").left(40))
	M.open_dialogue("bones_shard_3")
	await _wait(0.8)
	await _shot("102_bones_shard")
	_close_overlays()
	print("SMOKE 012 shards ", G.p.inv.get("Обломок гигантской кости", 0))
	M.show_title()
	await _wait(1.2)
	await _shot("103_title")
	M.current._toggle_ach()
	await _wait(0.6)
	await _shot("104_title_ach")
	M.current._toggle_ach()
	M.show_world("waste", "road")
	await _wait(0.6)


## Проверки версии 0.13: портреты и квест «Венок из ветвей барбариса» от начала до конца.
func _smoke_013() -> void:
	for who in ["trader", "taxi", "wanderer", "ryzhaya", "nikki", "tauros", "barbaris"]:
		var t: Texture2D = Art.who_portrait(who)
		print("SMOKE 013 portrait ", who, " ", t.get_width() if t != null else -1)
	var nodes: Dictionary = preload("res://scripts/story.gd").nodes()
	var dash := 0
	for id in nodes:
		var txt := str(nodes[id].get("text", ""))
		for ch in nodes[id].get("choices", []):
			txt += str(ch.get("t", ""))
		if "—" in txt:
			dash += 1
			print("SMOKE 013 em dash in ", id)
	print("SMOKE 013 nodes with em dash: ", dash)
	# Артир предлагает работу с пятого уровня
	G.p.level = 5
	G.p.su += 400
	G.p.quests.erase("vb")
	M.show_world("waste", "road")
	await _wait(0.6)
	G.p.flags["look_taxi"] = true
	M.open_dialogue("taxi_start")
	await _wait(1.0)
	await _shot("110_taxi_offer")
	_close_overlays()
	M.open_dialogue("vb_artir_go")
	await _wait(0.8)
	await _shot("111_artir_go")
	var dlg = _dialogue()
	if dlg:
		dlg._choose({"t": "x", "fx": [["vb", "start"]], "next": "end"})
	await _wait(2.6)
	await _shot("112_ride")
	for k in 40:
		if G.p.map == "star_camp":
			break
		await _wait(0.5)
	await _wait(1.0)
	await _shot("113_camp_arrive")
	await _wait(5.0)
	_close_overlays()
	print("SMOKE 013 camp map ", G.p.map, " arrived ", G.flag("vb_arrived"), " quest ", G.p.quests.get("vb", ""))
	await _shot("114_camp")
	G.set_flag("vb_nikki")
	G.set_flag("vb_tauros")
	G.set_flag("vb_gate_open")
	for id in ["vb_sutura_start", "vb_ferro", "vb_berberis", "vb_scribl"]:
		M.open_dialogue(id)
		await _wait(0.8)
		await _shot("115_" + id)
		_close_overlays()
	M.open_minigame("sutura")
	await _wait(3.0)
	await _shot("115_sutura_after")
	_close_overlays()
	# этаж 1: псы лезут, рыцари стреляют
	M.show_world("star1", "up")
	await _wait(3.0)
	_close_overlays()
	await _wait(5.0)
	await _fights()
	await _shot("116_floor1")
	print("SMOKE 013 f1 mobs ", M.world.mobs.size(), " kills ", G.p.flags.get("vb_k1_pes_cave", 0), " tracker ", G.tracker_lines())
	G.p.flags["vb_k1_pes_cave"] = 5
	M.world.star._check_clear()
	await _wait(4.0)
	await _fights()
	print("SMOKE 013 f1 clear ", G.flag("vb_f1"), " burrows now ", M.world.map.burrows.size())
	await _shot("117_floor1_clear")
	# этаж 2: вывести троих к лифту
	M.show_world("star2", "up")
	await _wait(4.0)
	_close_overlays()
	for id in ["pimm", "vella", "kort"]:
		M.world.star.follow(id)
	await _wait(0.5)
	for c in [Vector2i(8, 8), Vector2i(5, 11), Vector2i(3, 12)]:
		M.world._path_to(c)
		await _wait(2.0)
		await _fights()
	await _shot("118_escort")
	await _wait(2.0)
	print("SMOKE 013 saved ", preload("res://scripts/story_vb.gd").saved())
	G.p.flags["vb_k2_pes_cave"] = 4
	M.world.star._check_clear()
	await _wait(3.0)
	print("SMOKE 013 f2 clear ", G.flag("vb_f2"))
	# этажи 3–4: волны
	G.set_flag("vb_f3")
	M.show_world("star4", "up")
	await _wait(4.0)
	_close_overlays()
	await _wait(4.0)
	await _fights()
	await _shot("119_waves")
	G.p.flags["vb_wave"] = 2
	M.world.star.wave_left = 0
	for m in M.world.mobs.duplicate():
		M.world.mobs.erase(m)
	await _wait(1.0)
	print("SMOKE 013 f4 clear ", G.flag("vb_f4"), " wave ", G.p.flags.get("vb_wave"))
	await _wait(3.0)
	# этаж 5: генератор
	M.show_world("star5", "up")
	await _wait(4.0)
	_close_overlays()
	M.open_dialogue("vb_generator")
	await _wait(0.8)
	await _shot("120_generator")
	_close_overlays()
	M._generator_node(1, false)
	await _wait(0.8)
	await _shot("121_gen_fail")
	_close_overlays()
	for gid in ["wires", "pressure", "fuses"]:
		M.open_minigame(gid)
		await _wait(0.9)
		await _shot("122_mg_" + gid)
		for k in 20:
			if _dialogue() != null:
				break
			await _wait(0.5)
		var d = _dialogue()
		if d:
			d._choose({"t": "x", "next": "end"})
		await _wait(0.5)
	await _wait(5.0)
	_close_overlays()
	print("SMOKE 013 gens ", G.flag("vb_gen1"), G.flag("vb_gen2"), G.flag("vb_gen3"), " f5 ", G.flag("vb_f5"))
	await _wait(1.0)
	await _shot("123_power")
	M.open_dialogue("vb_hermo")
	await _wait(0.8)
	await _shot("124_hermo")
	var hd = _dialogue()
	if hd:
		hd._choose({"t": "x", "fx": [["flag", "vb_deep"], ["vb", "goto", "star6", "up"]], "next": "end"})
	await _wait(4.0)
	_close_overlays()
	print("SMOKE 013 deep map ", G.p.map)
	await _shot("125_floor6")
	G.p.flags["vb_k6_pes_cave"] = 3
	G.p.flags["vb_k6_pustobreh"] = 2
	M.world.star._check_clear()
	await _wait(3.0)
	_close_overlays()
	G.set_flag("vb_f7")
	M.show_world("star8", "up")
	await _wait(4.0)
	_close_overlays()
	await _shot("126_boss")
	M.world.star.on_kill({"vb": true, "enemy": "muezzin_cave", "id": "vb8_boss"})
	await _wait(5.0)
	_close_overlays()
	M.show_world("star9", "up")
	await _wait(3.0)
	_close_overlays()
	print("SMOKE 013 f8 ", G.flag("vb_f8"), " f9 ", G.flag("vb_f9"))
	M.show_world("star10", "up")
	await _wait(6.0)
	_close_overlays()
	await _shot("127_lab")
	M.open_dialogue("vb_terminal")
	await _wait(0.8)
	await _shot("128_terminal")
	_close_overlays()
	M.open_dialogue("vb_door")
	await _wait(0.8)
	print("SMOKE 013 gun ", G.has("Импульсная пушка"))
	_close_overlays()
	M.show_world("star11", "in")
	await _wait(1.0)
	M.open_dialogue("vb_f11_enter")
	await _wait(1.0)
	await _shot("129_barbaris")
	_close_overlays()
	M.open_dialogue("vb_barb_join")
	await _wait(0.8)
	await _shot("130_barb_join")
	var jd = _dialogue()
	if jd:
		jd._choose({"t": "x", "next": "vb_barb_join_2"})
	await _wait(1.0)
	_close_overlays()
	M.show_world("star10", "door")
	await _wait(4.0)
	_close_overlays()
	print("SMOKE 013 gun back ", G.flag("vb_gun_back"), " has gun ", G.has("Импульсная пушка"))
	M.show_world("star5", "up")
	await _wait(5.0)
	_close_overlays()
	print("SMOKE 013 quest ", G.p.quests.get("vb", ""), " farewell ", G.flag("vb_farewell"), " ach ", Ach.has("vb_done"), Ach.has("vb_berries"))
	M.show_world("star3", "up")
	await _wait(3.0)
	_close_overlays()
	await _shot("131_star_after")
	# Барбарис в лесу и в напарниках
	M.show_world("poi_forest", "enter")
	await _wait(0.8)
	M.open_dialogue("vb_barb_forest")
	await _wait(0.8)
	await _shot("132_barb_forest")
	_close_overlays()
	G.set_companion("barbaris")
	await _wait(0.8)
	M.show_world("caldera2", "start")
	await _wait(1.0)
	await _shot("133_barb_mate")
	G.p.flags.erase("ask_barb_trader")
	M.open_dialogue("trader_start")
	await _wait(0.8)
	await _shot("134_ask_barb")
	_close_overlays()
	M.open_shop(preload("res://scripts/story.gd").SHOPS.vb_ferro, "ОРУЖЕЙНАЯ ФЕРРО", "gunsmith")
	await _wait(0.6)
	await _shot("135_shop_scared")
	_close_overlays()
	M.start_combat("pes", M._battle_end.bind("", ""))
	await _wait(1.0)
	await _shot("136_barb_combat")
	var cb = _overlay_of_type("Combat")
	if cb:
		cb._end("win")
	await _wait(0.6)
	_close_overlays()
	G.set_companion("")
	await _wait(0.8)
	# домой с юга
	G.p.flags["vb_ride"] = "north"
	M.show_map()
	await _wait(2.5)
	await _shot("137_ride_north")
	for k in 30:
		if G.p.map == "waste":
			break
		await _wait(0.5)
	print("SMOKE 013 home map ", G.p.map)
	M.show_world("waste", "road")
	await _wait(0.6)


## Закрыть все бои, которые успели начаться (собаки добежали до Гения).
func _fights() -> void:
	for k in 4:
		var cb = _overlay_of_type("Combat")
		if cb == null:
			return
		cb._end("win")
		await _wait(0.8)


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
	for m in ["caldera1", "caldera2", "caldera3", "caldera4", "caldera_ryhome", "caldera_danahome", "mini_bus", "mini_dogs", "mini_camp", "mini_bones", "waste", "poi_station", "poi_river", "poi_tower", "poi_den", "poi_ruins", "poi_forest", "raid1", "raid2",
			"star_camp", "star1", "star2", "star3", "star4", "star5", "star6", "star7", "star8", "star9", "star10", "star11"]:
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
