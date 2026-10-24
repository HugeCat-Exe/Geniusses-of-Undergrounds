extends Node
## Простые звуки, собранные прямо в коде (без файлов): щелчок кнопки, писк пейджера,
## перезвон достижения, гул Подземки, ветер, дождь и пыльная буря.

const RATE := 22050

var vol := 0.7
var _cache: Dictionary = {}
var _shots: Array = []
var _amb: AudioStreamPlayer
var _wx: AudioStreamPlayer
var _amb_name := ""
var _wx_name := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 4:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_shots.append(p)
	_amb = AudioStreamPlayer.new()
	add_child(_amb)
	_wx = AudioStreamPlayer.new()
	add_child(_wx)


func set_vol(v: float) -> void:
	vol = clampf(v, 0.0, 1.0)
	_amb.volume_db = _db(_amb_gain(_amb_name))
	_wx.volume_db = _db(_amb_gain(_wx_name))


func _db(g: float) -> float:
	return linear_to_db(maxf(0.0001, g * vol))


func play(name: String, gain: float = 1.0) -> void:
	if vol <= 0.0:
		return
	var p: AudioStreamPlayer = null
	for s in _shots:
		if not s.playing:
			p = s
			break
	if p == null:
		p = _shots[0]
	p.stream = _stream(name)
	p.volume_db = _db(gain)
	p.play()


## Фон места: "hum" — Подземка, "wind" — Пустошь, "" — тишина.
func ambience(name: String) -> void:
	_switch(_amb, name, "_amb_name")


## Погода поверх фона: "rain", "storm" или "".
func weather(name: String) -> void:
	_switch(_wx, name, "_wx_name")


func _amb_gain(name: String) -> float:
	return {"hum": 0.55, "wind": 0.6, "rain": 0.5, "storm": 0.75}.get(name, 0.0)


func _switch(pl: AudioStreamPlayer, name: String, field: String) -> void:
	if get(field) == name:
		return
	set(field, name)
	var tw := create_tween()
	if pl.playing:
		tw.tween_property(pl, "volume_db", -60.0, 0.6)
	tw.tween_callback(func():
		if name == "":
			pl.stop()
			return
		pl.stream = _stream(name)
		pl.volume_db = -60.0
		pl.play())
	if name != "":
		tw.tween_property(pl, "volume_db", _db(_amb_gain(name)), 1.2)


func _stream(name: String) -> AudioStreamWAV:
	if not _cache.has(name):
		_cache[name] = _make(name)
	return _cache[name]


func _make(name: String) -> AudioStreamWAV:
	var s := PackedFloat32Array()
	var loop := false
	match name:
		"click":
			s = _click()
		"notify":
			s = _notify()
		"achieve":
			s = _achieve()
		"hum":
			s = _hum()
			loop = true
		"wind":
			s = _wind(0.55, 6.0)
			loop = true
		"storm":
			s = _wind(1.0, 6.0)
			loop = true
		"rain":
			s = _rain()
			loop = true
	return _wav(s, loop)


func _wav(s: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = s.size()
	return w


func _buf(sec: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(int(sec * RATE))
	return s


## Короткий сухой щелчок, как у кнопки пейджера.
func _click() -> PackedFloat32Array:
	var s := _buf(0.035)
	for i in s.size():
		var t := float(i) / RATE
		var env := exp(-t * 160.0)
		s[i] = (randf_range(-1, 1) * 0.5 + sin(TAU * 2100.0 * t) * 0.5) * env * 0.35
	return s


## Двойной писк пейджера: кто-то сказал что-то новое.
func _notify() -> PackedFloat32Array:
	var s := _buf(0.2)
	for i in s.size():
		var t := float(i) / RATE
		var f := 1046.0 if t < 0.085 else 1568.0
		var lt := fmod(t, 0.1)
		var env := minf(1.0, lt * 300.0) * exp(-lt * 28.0)
		if t >= 0.085 and t < 0.1:
			env = 0.0
		s[i] = (sin(TAU * f * t) + 0.25 * sin(TAU * f * 2.0 * t)) * env * 0.16
	return s


## Перезвон достижения: мажорное арпеджио с мягким хвостом.
func _achieve() -> PackedFloat32Array:
	var s := _buf(1.1)
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for i in s.size():
		var t := float(i) / RATE
		var v := 0.0
		for k in notes.size():
			var st: float = k * 0.09
			if t >= st:
				var lt := t - st
				var env := minf(1.0, lt * 200.0) * exp(-lt * 4.5)
				v += (sin(TAU * notes[k] * lt) + 0.3 * sin(TAU * notes[k] * 3.0 * lt) * exp(-lt * 9.0)) * env
		s[i] = v * 0.11
	return s


## Гул Подземки: низкий фон вентиляции с биением, шум и редкие капли. Петля 4 с.
func _hum() -> PackedFloat32Array:
	var s := _buf(4.0)
	var lp := 0.0
	var drips := [0.7, 2.35, 3.3]
	for i in s.size():
		var t := float(i) / RATE
		lp += (randf_range(-1, 1) - lp) * 0.02
		var v := sin(TAU * 55.0 * t) * 0.10 + sin(TAU * 55.25 * t) * 0.06 + sin(TAU * 110.0 * t) * 0.03 + lp * 0.5
		for d in drips:
			if t >= d and t < d + 0.25:
				var lt: float = t - d
				v += sin(TAU * (1500.0 - lt * 1800.0) * lt) * exp(-lt * 30.0) * 0.08
		s[i] = v
	return s


## Ветер: шум через фильтр, у которого «дышит» частота среза и громкость. Петля без шва по модуляции.
func _wind(power: float, sec: float) -> PackedFloat32Array:
	var s := _buf(sec)
	var lp := 0.0
	var lp2 := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var m := 0.5 + 0.3 * sin(TAU * t / sec) + 0.2 * sin(TAU * 3.0 * t / sec + 1.3)
		var a := 0.01 + 0.05 * m * power
		lp += (randf_range(-1, 1) - lp) * a
		lp2 += (lp - lp2) * a
		var grit := randf_range(-1, 1) * 0.03 * power * power
		s[i] = (lp2 * (2.2 + 2.0 * m) + grit) * 0.5 * (0.5 + 0.5 * power)
	return s


## Дождь: шипение высоких частот и россыпь капель. Петля 4 с.
func _rain() -> PackedFloat32Array:
	var s := _buf(4.0)
	var lp := 0.0
	var drop := 0.0
	for i in s.size():
		var n := randf_range(-1, 1)
		lp += (n - lp) * 0.3
		if randf() < 0.0025:
			drop = randf_range(0.2, 0.5)
		drop *= 0.992
		s[i] = (n - lp) * 0.18 + randf_range(-1, 1) * drop * 0.25
	return s
