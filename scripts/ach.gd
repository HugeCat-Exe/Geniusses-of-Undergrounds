extends RefCounted
## Достижения. Общие для всех Гениев на этом компьютере: хранятся в user://achievements.json.
## Список и тексты – из «Достижения.txt» Михаила: две строки названия, описание, редкость.

const LIST := [
	{"id": "dog", "t1": "Глядя собаке в глаза", "t2": "не видал ли ты своих?", "d": "Убейте любую собаку в Пустоши.", "r": "обычное"},
	{"id": "drunk", "t1": "В попытке потеряться", "t2": "ты сам себя найдёшь на дне", "d": "Выпейте 10 алкогольных напитков.", "r": "редкое", "count": "drink", "need": 10},
	{"id": "muezzin", "t1": "Богохульник", "t2": "собачьих богов", "d": "Убейте любого Собачьего Муэдзина.", "r": "редкое"},
	{"id": "den", "t1": "Там, где воют собаки", "t2": "срывая глотки", "d": "Посетите Собачье Логово.", "r": "обычное"},
	{"id": "forest", "t1": "Оазис", "t2": "для упокоения", "d": "Посетите Запутанный Лес.", "r": "обычное"},
]
const PATH := "user://achievements.json"

static var _data: Dictionary = {}


static func _load() -> Dictionary:
	if _data.is_empty():
		_data = {"got": {}, "count": {}}
		if FileAccess.file_exists(PATH):
			var j = JSON.parse_string(FileAccess.get_file_as_string(PATH))
			if j is Dictionary:
				_data.got = j.get("got", {})
				_data.count = j.get("count", {})
	return _data


static func _save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_load()))


static func find(id: String) -> Dictionary:
	for a in LIST:
		if a.id == id:
			return a
	return {}


static func has(id: String) -> bool:
	return _load().got.has(id)


static func count(key: String) -> int:
	return int(_load().count.get(key, 0))


## Получить достижение: один раз, с плашкой и перезвоном.
static func unlock(id: String) -> void:
	if has(id) or find(id).is_empty():
		return
	_load().got[id] = Time.get_unix_time_from_system()
	_save()
	var a := find(id)
	var m = G.main()
	if m and m.has_method("toast"):
		m.toast(a.t1, a.t2, a.r, "achieve")


## Прибавить к счётчику; достижения со счётчиком открываются сами.
static func add(key: String, n: int = 1) -> void:
	_load().count[key] = count(key) + n
	_save()
	for a in LIST:
		if a.get("count", "") == key and count(key) >= int(a.need):
			unlock(a.id)


## Плашка достижения: две строки названия (первая крупнее), описание, редкость.
static func plate(a: Dictionary, got: bool, width: float = 300.0) -> PanelContainer:
	var rare: bool = a.r == "редкое"
	var edge: Color = (Pal.R3 if rare else Pal.G4) if got else Pal.G1
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", Pal.box(Pal.G0 if got else Pal.BG, edge, 2, 6))
	pc.custom_minimum_size = Vector2(width, 0)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	pc.add_child(vb)
	var top := HBoxContainer.new()
	vb.add_child(top)
	var l1 := Pal.label(a.t1, Pal.G5 if got else Pal.G2, 12, true)
	l1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(l1)
	var rl := Pal.label(a.r.to_upper(), (Pal.R3 if rare else Pal.G3) if got else Pal.G1, 7)
	rl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(rl)
	vb.add_child(Pal.label(a.t2, Pal.G4 if got else Pal.G2, 9))
	if a.d != "":
		var d := Pal.label(a.d, Pal.G3 if got else Pal.G1, 8)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(width - 16, 0)
		vb.add_child(d)
	if a.has("need") and not got:
		vb.add_child(Pal.label("Прогресс: %d из %d" % [mini(count(a.count), int(a.need)), int(a.need)], Pal.G2, 7))
	return pc
