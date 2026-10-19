extends Node
## Пиксель-арт, нарисованный кодом: тайлы, предметы, персонажи, портреты, враги.
## Уровни цвета: 0 фон, 1..6 зелёные от тёмного к светлому, 7..9 красные.

const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
const TW := 32
const TH := 16

var colors: Array = []
var cache := {}


func _ready() -> void:
	colors = [Pal.BG, Pal.G0, Pal.G1, Pal.G2, Pal.G3, Pal.G4, Pal.G5, Pal.R1, Pal.R2, Pal.R3]


class Canvas:
	const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	var w: int
	var h: int
	var px: PackedInt32Array

	func _init(width: int, height: int) -> void:
		w = width
		h = height
		px = PackedInt32Array()
		px.resize(w * h)
		px.fill(-1)

	func put(x: int, y: int, c: int) -> void:
		if x >= 0 and y >= 0 and x < w and y < h:
			px[y * w + x] = c

	func get_px(x: int, y: int) -> int:
		if x >= 0 and y >= 0 and x < w and y < h:
			return px[y * w + x]
		return -1

	## Уровень с учётом освещения сверху-слева и точечного дизеринга.
	func lit(base: int, t: float, x: int, y: int) -> int:
		if base < 0:
			return -1
		var b: float = (BAYER[(y % 4) * 4 + (x % 4)] / 16.0) - 0.5
		var v := base + int(round(t * 1.4 + b))
		if base >= 7:
			return clampi(v, 7, 9)
		return clampi(v, 1, 6)

	func ellipse(cx: float, cy: float, rx: float, ry: float, base: int, shade := true) -> void:
		for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
			for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
				var ox := (x + 0.5 - cx) / rx
				var oy := (y + 0.5 - cy) / ry
				if ox * ox + oy * oy <= 1.0:
					var t := -(ox * 0.6 + oy * 0.8) if shade else 0.0
					put(x, y, lit(base, t, x, y))

	func rect(x0: int, y0: int, rw: int, rh: int, base: int, shade := true) -> void:
		for y in range(y0, y0 + rh):
			for x in range(x0, x0 + rw):
				var t := 0.0
				if shade:
					t = -(((x - x0) / maxf(1.0, rw - 1.0)) * 2.0 - 1.0) * 0.5 - (((y - y0) / maxf(1.0, rh - 1.0)) * 2.0 - 1.0) * 0.4
				put(x, y, lit(base, t, x, y))

	func poly(points: PackedVector2Array, base: int, shade := true) -> void:
		var r := Rect2(points[0], Vector2.ZERO)
		for pt in points:
			r = r.expand(pt)
		for y in range(int(r.position.y), int(r.end.y) + 1):
			for x in range(int(r.position.x), int(r.end.x) + 1):
				if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), points):
					var t := 0.0
					if shade:
						t = -(((x - r.position.x) / maxf(1.0, r.size.x)) * 2.0 - 1.0) * 0.5 - (((y - r.position.y) / maxf(1.0, r.size.y)) * 2.0 - 1.0) * 0.5
					put(x, y, lit(base, t, x, y))

	func line(x0: float, y0: float, x1: float, y1: float, c: int, thick := 1) -> void:
		var n := int(maxf(absf(x1 - x0), absf(y1 - y0))) + 1
		for i in n + 1:
			var t := i / float(n)
			var x := int(round(lerpf(x0, x1, t)))
			var y := int(round(lerpf(y0, y1, t)))
			for dy in thick:
				for dx in thick:
					put(x + dx, y + dy, c)

	## Тёмный контур вокруг заполненных пикселей.
	func outline(c: int = 0) -> void:
		var src := px.duplicate()
		for y in h:
			for x in w:
				if src[y * w + x] != -1:
					continue
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var xx: int = x + d.x
					var yy: int = y + d.y
					if xx >= 0 and yy >= 0 and xx < w and yy < h and src[yy * w + xx] != -1 and src[yy * w + xx] != c:
						px[y * w + x] = c
						break


func to_tex(cv: Canvas) -> ImageTexture:
	var img := Image.create(cv.w, cv.h, false, Image.FORMAT_RGBA8)
	for y in cv.h:
		for x in cv.w:
			var c := cv.px[y * cv.w + x]
			img.set_pixel(x, y, Color(0, 0, 0, 0) if c < 0 else colors[c])
	return ImageTexture.create_from_image(img)


func cached(key: String, maker: Callable) -> Texture2D:
	if not cache.has(key):
		cache[key] = maker.call()
	return cache[key]


# ---------------- Тайлы ----------------

func _in_diamond(x: int, y: int) -> bool:
	return absf(x + 0.5 - TW / 2.0) / (TW / 2.0) + absf(y + 0.5 - TH / 2.0) / (TH / 2.0) <= 1.0


func floor_tex(kind: String, variant: int = 0) -> Texture2D:
	return cached("floor_%s_%d" % [kind, variant], func(): return _floor(kind, variant))


func _floor(kind: String, variant: int) -> ImageTexture:
	var cv := Canvas.new(TW, TH)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind) + variant * 7919
	for y in TH:
		for x in TW:
			if not _in_diamond(x, y):
				continue
			var c := 2
			# координаты вдоль осей изометрии
			var u := x / 2 + y
			var v := x / 2 - y + 16
			match kind:
				"metal":
					c = 2
					if u % 8 == 0 or v % 8 == 0:
						c = 1
					elif (u + v) % 4 == 0 and rng.randf() < 0.3:
						c = 3
				"concrete":
					c = 2 if rng.randf() > 0.12 else (1 if rng.randf() < 0.6 else 3)
					if variant == 1 and (u % 16 == 0):
						c = 1
				"tile":
					c = 3 if ((u / 8) + (v / 8)) % 2 == 0 else 2
					if u % 8 == 0 or v % 8 == 0:
						c = 1
				"sand":
					c = 3
					var n := sin(x * 0.4 + variant) + cos(y * 0.9 + variant * 2.0)
					if n > 1.1:
						c = 4
					elif n < -1.2:
						c = 2
					if rng.randf() < 0.05:
						c = 4
				"ash":
					c = 2
					if rng.randf() < 0.15:
						c = 3
					if rng.randf() < 0.06:
						c = 1
				"rug":
					c = 7 if (u % 6 < 3) != (v % 6 < 3) else 2
					if u < 2 or v < 2 or u > 29 or v > 29:
						c = 3
				"grate":
					c = 3 if (u % 4 == 0 or v % 4 == 0) else 1
					if u % 16 == 0 or v % 16 == 0:
						c = 4
				"stairs":
					# ступени поперёк оси u: светлая кромка и тёмный подступенок
					var st := u % 6
					c = 4 if st == 0 else (3 if st < 3 else 2)
					if v < 2 or v > 29:
						c = 1
				"asphalt":
					c = 1 if rng.randf() > 0.1 else 2
					if v >= 15 and v <= 16 and (u / 4) % 2 == 0:
						c = 5 if variant != 2 else 1
				"water":
					c = 1
					var wv := sin(u * 0.7 + variant * 2.1) + sin(v * 0.35 + u * 0.15)
					if wv > 1.3:
						c = 4
					elif wv > 0.7:
						c = 2
					elif wv < -1.4:
						c = 0
				"moss":
					c = 2
					var mv := sin(x * 0.55 + variant * 1.7) * cos(y * 0.8 + variant)
					if mv > 0.45:
						c = 3
					elif mv < -0.6:
						c = 1
					if rng.randf() < 0.04:
						c = 4
				"planks":
					c = 3 if (v / 4) % 2 == 0 else 2
					if v % 4 == 0:
						c = 1
					if rng.randf() < 0.04:
						c = 0
				"plaza":
					c = 2
					if (u % 8 == 0) != (v % 8 == 0):
						c = 3
					if rng.randf() < 0.05:
						c = 1
			cv.put(x, y, c)
	return to_tex(cv)


## Блок стены: ширина 32, высота 16 + hgt.
func wall_tex(kind: String, hgt: int = 22, variant: int = 0) -> Texture2D:
	return cached("wall_%s_%d_%d" % [kind, hgt, variant], func(): return _wall(kind, hgt, variant))


func _wall(kind: String, hgt: int, variant: int) -> ImageTexture:
	var cv := Canvas.new(TW, TH + hgt)
	var rng := RandomNumberGenerator.new()
	rng.seed = variant * 31 + hgt
	var top_l := 4
	var left_l := 2
	var right_l := 3
	if kind == "ruin":
		top_l = 3
		left_l = 1
		right_l = 2
	for y in TH + hgt:
		for x in TW:
			var cx := x + 0.5 - TW / 2.0
			# верхняя грань — ромб в [0, TH]
			if absf(cx) / (TW / 2.0) + absf(y + 0.5 - TH / 2.0) / (TH / 2.0) <= 1.0:
				var c := top_l
				if kind == "ruin" and rng.randf() < 0.2:
					c = 2
				cv.put(x, y, c)
				continue
			# боковые грани
			var edge := TH / 2.0 + (TW / 2.0 - absf(cx)) / 2.0  # нижний край ромба
			if y + 0.5 >= edge and y + 0.5 <= edge + hgt:
				var depth := y + 0.5 - edge
				var c2 := left_l if cx < 0 else right_l
				# кирпичная кладка / панели
				if kind == "brick" or kind == "ruin":
					if int(depth) % 5 == 0:
						c2 -= 1
					elif (int(absf(cx)) + (int(depth) / 5) * 4) % 8 == 0:
						c2 -= 1
				elif kind == "panel":
					if int(absf(cx)) % 8 == 0 or int(depth) == 3:
						c2 -= 1
					if int(depth) == hgt - 4 and int(absf(cx)) % 4 == 1:
						c2 += 1
				if kind == "ruin" and rng.randf() < 0.08:
					c2 = 1
				cv.put(x, y, clampi(c2, 1, 6))
	if kind == "ruin":
		# обломанный верх
		for i in 6:
			var bx := rng.randi_range(2, TW - 3)
			var by := rng.randi_range(0, 6)
			for yy in range(by, by + 4):
				for xx in range(bx - 2, bx + 2):
					if cv.get_px(xx, yy) == top_l or cv.get_px(xx, yy) == 2:
						cv.put(xx, yy, -1)
	cv.outline(0)
	return to_tex(cv)


# ---------------- Предметы обстановки ----------------

func prop_tex(kind: String) -> Texture2D:
	return cached("prop_" + kind, func(): return _prop(kind))


func _prop(kind: String) -> ImageTexture:
	var cv: Canvas
	match kind:
		"counter":
			cv = Canvas.new(32, 30)
			cv.poly(PackedVector2Array([Vector2(16, 6), Vector2(31, 13), Vector2(16, 21), Vector2(1, 13)]), 4)
			cv.poly(PackedVector2Array([Vector2(1, 13), Vector2(16, 21), Vector2(16, 29), Vector2(1, 21)]), 2)
			cv.poly(PackedVector2Array([Vector2(16, 21), Vector2(31, 13), Vector2(31, 21), Vector2(16, 29)]), 3)
			cv.line(4, 12, 10, 9, 6)
		"bed":
			cv = Canvas.new(32, 24)
			cv.poly(PackedVector2Array([Vector2(16, 4), Vector2(31, 11), Vector2(16, 19), Vector2(1, 11)]), 3)
			cv.poly(PackedVector2Array([Vector2(1, 11), Vector2(16, 19), Vector2(16, 23), Vector2(1, 15)]), 1)
			cv.poly(PackedVector2Array([Vector2(16, 19), Vector2(31, 11), Vector2(31, 15), Vector2(16, 23)]), 2)
			cv.ellipse(22, 9, 5, 3, 5)
			cv.poly(PackedVector2Array([Vector2(4, 11), Vector2(16, 5), Vector2(20, 7), Vector2(9, 14)]), 7)
		"crate":
			cv = Canvas.new(20, 22)
			cv.poly(PackedVector2Array([Vector2(10, 1), Vector2(19, 5), Vector2(10, 9), Vector2(1, 5)]), 4)
			cv.poly(PackedVector2Array([Vector2(1, 5), Vector2(10, 9), Vector2(10, 21), Vector2(1, 16)]), 2)
			cv.poly(PackedVector2Array([Vector2(10, 9), Vector2(19, 5), Vector2(19, 16), Vector2(10, 21)]), 3)
			cv.line(1, 5, 10, 21, 1)
			cv.line(19, 5, 10, 21, 1)
		"barrel":
			cv = Canvas.new(14, 20)
			cv.rect(1, 3, 12, 15, 3)
			cv.ellipse(7, 3, 6, 2.5, 4, false)
			cv.ellipse(7, 18, 6, 2, 2, false)
			cv.line(1, 8, 12, 8, 1)
			cv.line(1, 13, 12, 13, 1)
			cv.put(5, 3, 8)
			cv.put(6, 3, 8)
		"lamp":
			cv = Canvas.new(12, 34)
			cv.ellipse(6, 5, 5, 5, 5, false)
			cv.ellipse(6, 5, 3, 3, 6, false)
			cv.line(6, 9, 6, 32, 2, 1)
			cv.line(4, 32, 8, 32, 2)
		"table":
			cv = Canvas.new(26, 20)
			cv.poly(PackedVector2Array([Vector2(13, 2), Vector2(25, 7), Vector2(13, 12), Vector2(1, 7)]), 4)
			cv.line(4, 8, 4, 18, 2)
			cv.line(22, 8, 22, 18, 2)
			cv.line(13, 12, 13, 19, 2)
			cv.ellipse(12, 6, 2, 1, 6, false)
		"terminal":
			cv = Canvas.new(18, 28)
			cv.rect(2, 2, 14, 24, 2)
			cv.rect(4, 5, 10, 8, 5, false)
			for i in 3:
				cv.line(5, 7 + i * 2, 5 + (i * 3 + 4) % 8, 7 + i * 2, 6)
			cv.put(6, 18, 8)
			cv.put(9, 18, 4)
			cv.put(12, 18, 4)
		"gate":
			cv = Canvas.new(40, 56)
			cv.rect(2, 4, 36, 50, 2)
			cv.rect(6, 10, 28, 44, 1, false)
			for i in 6:
				cv.line(7, 14 + i * 7, 33, 14 + i * 7, 3)
			cv.line(20, 10, 20, 53, 0)
			cv.ellipse(20, 6, 3, 2, 9, false)
		"pipe":
			cv = Canvas.new(12, 40)
			cv.rect(3, 0, 6, 40, 3)
			cv.rect(2, 10, 8, 3, 4)
			cv.rect(2, 28, 8, 3, 4)
		"tree":
			cv = Canvas.new(28, 40)
			cv.line(14, 39, 14, 12, 2, 2)
			cv.line(14, 20, 5, 10, 2)
			cv.line(14, 16, 24, 6, 2)
			cv.line(5, 10, 3, 3, 2)
			cv.line(24, 6, 26, 2, 2)
			cv.line(14, 12, 12, 2, 2)
		"rocks":
			cv = Canvas.new(24, 14)
			cv.ellipse(8, 8, 7, 5, 3)
			cv.ellipse(17, 9, 6, 4, 2)
			cv.ellipse(12, 5, 4, 3, 4)
		"bones":
			cv = Canvas.new(20, 10)
			cv.line(2, 7, 16, 3, 5)
			cv.ellipse(3, 7, 2, 1.5, 6, false)
			cv.ellipse(16, 3, 2, 1.5, 6, false)
			cv.ellipse(12, 7, 3, 2, 5)
		"wreck":
			cv = Canvas.new(40, 30)
			cv.poly(PackedVector2Array([Vector2(4, 14), Vector2(26, 4), Vector2(38, 10), Vector2(16, 22)]), 3)
			cv.poly(PackedVector2Array([Vector2(4, 14), Vector2(16, 22), Vector2(16, 28), Vector2(4, 20)]), 1)
			cv.poly(PackedVector2Array([Vector2(16, 22), Vector2(38, 10), Vector2(38, 16), Vector2(16, 28)]), 2)
			cv.ellipse(10, 23, 3, 3, 1, false)
			cv.ellipse(30, 17, 3, 3, 1, false)
			cv.line(14, 12, 26, 8, 8)
		"cache":
			cv = Canvas.new(20, 22)
			cv.poly(PackedVector2Array([Vector2(10, 1), Vector2(19, 5), Vector2(10, 9), Vector2(1, 5)]), 5)
			cv.poly(PackedVector2Array([Vector2(1, 5), Vector2(10, 9), Vector2(10, 21), Vector2(1, 16)]), 3)
			cv.poly(PackedVector2Array([Vector2(10, 9), Vector2(19, 5), Vector2(19, 16), Vector2(10, 21)]), 4)
			cv.rect(4, 10, 3, 3, 8, false)
			cv.line(5, 9, 5, 14, 9)
			cv.line(3, 11, 7, 11, 9)
		"pot":
			cv = Canvas.new(20, 24)
			cv.ellipse(10, 15, 8, 7, 2)
			cv.ellipse(10, 9, 8, 2.5, 5, false)
			cv.line(6, 6, 6, 1, 4)
			cv.line(11, 5, 12, 0, 4)
			cv.line(15, 6, 15, 2, 4)
		"shelf":
			cv = Canvas.new(26, 34)
			cv.rect(1, 2, 24, 31, 1, false)
			for i in 4:
				cv.line(1, 9 + i * 7, 24, 9 + i * 7, 3)
				for j in 5:
					if (i + j) % 3 != 0:
						cv.rect(3 + j * 4, 4 + i * 7, 3, 5, 3 + (i * j) % 3)
		"sign":
			cv = Canvas.new(30, 14)
			cv.rect(1, 1, 28, 12, 1, false)
			cv.rect(2, 2, 26, 10, 2, false)
			cv.line(5, 7, 24, 7, 8)
		"rail":
			cv = Canvas.new(32, 18)
			cv.line(1, 9, 16, 2, 4)
			cv.line(16, 2, 31, 9, 4)
			for px in [3, 9, 16, 23, 29]:
				cv.line(px, 2 + absf(px - 16) / 2.0, px, 2 + absf(px - 16) / 2.0 + 7, 3)
			cv.line(1, 15, 16, 8, 2)
			cv.line(16, 8, 31, 15, 2)
		"stairs_down":
			cv = Canvas.new(32, 26)
			cv.poly(PackedVector2Array([Vector2(16, 10), Vector2(31, 17), Vector2(16, 25), Vector2(1, 17)]), 1, false)
			for i in 4:
				var yy := 12 + i * 3
				cv.line(8 + i * 2, yy, 24 - i * 2, yy + 1, 3 - (i / 2))
			cv.rect(2, 0, 2, 16, 3)
			cv.rect(28, 0, 2, 16, 3)
			cv.line(2, 1, 29, 1, 4)
			cv.rect(10, 3, 12, 5, 8, false)
			cv.line(13, 5, 19, 5, 9)
		"stairs_up":
			cv = Canvas.new(32, 34)
			for i in 6:
				var yy := 30 - i * 4
				cv.poly(PackedVector2Array([Vector2(4 + i, yy - 3), Vector2(28 - i, yy - 3), Vector2(28 - i, yy), Vector2(4 + i, yy)]), 3 + (i % 2))
			cv.line(3, 30, 9, 6, 4)
			cv.line(29, 30, 23, 6, 4)
			cv.ellipse(16, 3, 3, 2, 9, false)
		"lift":
			cv = Canvas.new(30, 52)
			cv.rect(1, 2, 28, 49, 1, false)
			cv.rect(3, 6, 24, 43, 2)
			for i in 7:
				cv.line(3 + i * 4, 6, 3 + i * 4, 48, 3)
			cv.line(3, 14, 26, 14, 3)
			cv.line(3, 30, 26, 30, 3)
			cv.rect(1, 0, 28, 4, 4)
			cv.rect(12, 1, 6, 2, 8, false)
		"shack":
			cv = Canvas.new(40, 44)
			cv.poly(PackedVector2Array([Vector2(1, 16), Vector2(20, 26), Vector2(20, 43), Vector2(1, 33)]), 2)
			cv.poly(PackedVector2Array([Vector2(20, 26), Vector2(39, 16), Vector2(39, 33), Vector2(20, 43)]), 3)
			cv.poly(PackedVector2Array([Vector2(0, 15), Vector2(20, 4), Vector2(40, 15), Vector2(20, 26)]), 4)
			for i in 5:
				cv.line(4 + i * 4, 18 + i * 2, 4 + i * 4, 34 + i * 2, 1)
			cv.poly(PackedVector2Array([Vector2(25, 26), Vector2(32, 22), Vector2(32, 35), Vector2(25, 39)]), 1, false)
			cv.put(30, 30, 9)
			cv.line(8, 8, 28, 8, 3)
		"tent":
			cv = Canvas.new(34, 30)
			cv.poly(PackedVector2Array([Vector2(17, 2), Vector2(33, 22), Vector2(17, 29), Vector2(1, 22)]), 3)
			cv.poly(PackedVector2Array([Vector2(17, 2), Vector2(17, 29), Vector2(1, 22)]), 2)
			cv.poly(PackedVector2Array([Vector2(17, 12), Vector2(22, 25), Vector2(17, 28)]), 1, false)
			cv.line(17, 0, 17, 3, 4)
		"laundry":
			cv = Canvas.new(32, 40)
			cv.line(2, 6, 2, 39, 2)
			cv.line(30, 6, 30, 39, 2)
			cv.line(2, 8, 30, 10, 3)
			cv.rect(6, 9, 5, 8, 5)
			cv.rect(13, 10, 6, 6, 8)
			cv.rect(21, 10, 5, 10, 3)
		"board":
			cv = Canvas.new(30, 36)
			cv.line(4, 14, 4, 35, 2, 2)
			cv.line(25, 14, 25, 35, 2, 2)
			cv.rect(1, 1, 28, 20, 2)
			cv.rect(3, 3, 7, 8, 6, false)
			cv.rect(12, 4, 6, 6, 5, false)
			cv.rect(20, 3, 7, 9, 6, false)
			cv.rect(6, 12, 8, 7, 5, false)
			cv.rect(17, 13, 8, 6, 8, false)
			for pin in [Vector2i(6, 3), Vector2i(15, 4), Vector2i(23, 3), Vector2i(10, 12), Vector2i(21, 13)]:
				cv.put(pin.x, pin.y, 9)
		"autodoc":
			cv = Canvas.new(26, 42)
			cv.rect(2, 8, 22, 33, 2)
			cv.rect(5, 12, 16, 9, 1, false)
			cv.line(7, 16, 10, 16, 5)
			cv.line(10, 16, 12, 13, 5)
			cv.line(12, 13, 14, 19, 5)
			cv.line(14, 19, 19, 16, 5)
			cv.rect(6, 25, 4, 3, 8, false)
			cv.rect(12, 25, 4, 3, 4, false)
			cv.line(13, 8, 13, 2, 3)
			cv.line(13, 2, 22, 2, 3)
			cv.line(22, 2, 22, 7, 4)
			cv.put(22, 8, 9)
		"gunrack":
			cv = Canvas.new(28, 36)
			cv.rect(1, 2, 26, 33, 1, false)
			for i in 4:
				cv.line(4 + i * 6, 6, 6 + i * 6, 30, 4)
				cv.rect(3 + i * 6, 22, 4, 6, 3)
			cv.line(1, 32, 26, 32, 3)
		"clothes":
			cv = Canvas.new(30, 36)
			cv.line(2, 4, 28, 4, 4)
			cv.line(3, 4, 3, 35, 2)
			cv.line(27, 4, 27, 35, 2)
			var cols := [3, 8, 5, 2, 4]
			for i in 5:
				cv.rect(4 + i * 5, 5, 4, 14 + (i % 2) * 6, cols[i])
		"bar":
			cv = Canvas.new(32, 34)
			cv.poly(PackedVector2Array([Vector2(16, 10), Vector2(31, 17), Vector2(16, 25), Vector2(1, 17)]), 3)
			cv.poly(PackedVector2Array([Vector2(1, 17), Vector2(16, 25), Vector2(16, 33), Vector2(1, 25)]), 1)
			cv.poly(PackedVector2Array([Vector2(16, 25), Vector2(31, 17), Vector2(31, 25), Vector2(16, 33)]), 2)
			for bx in [6, 10, 22]:
				cv.rect(bx, 9, 2, 6, 5 if bx != 10 else 8, false)
			cv.line(4, 26, 15, 31, 8)
		"bottles":
			cv = Canvas.new(26, 34)
			cv.rect(1, 2, 24, 31, 1, false)
			for i in 3:
				cv.line(1, 11 + i * 9, 24, 11 + i * 9, 3)
				for j in 6:
					if (i * 3 + j) % 4 != 1:
						cv.rect(3 + j * 4, 5 + i * 9, 2, 6, [5, 8, 4, 9][(i + j) % 4], false)
		"stool":
			cv = Canvas.new(12, 14)
			cv.ellipse(6, 3, 5, 2, 4)
			cv.line(3, 4, 2, 13, 2)
			cv.line(9, 4, 10, 13, 2)
		"neon":
			cv = Canvas.new(34, 16)
			cv.rect(1, 1, 32, 14, 1, false)
			cv.rect(2, 2, 30, 12, 7, false)
			# «БАР»
			cv.line(6, 4, 11, 4, 9)
			cv.line(6, 4, 6, 11, 9)
			cv.line(6, 7, 10, 7, 9)
			cv.line(6, 11, 10, 11, 9)
			cv.line(11, 8, 11, 10, 9)
			cv.line(14, 11, 17, 4, 9)
			cv.line(17, 4, 20, 11, 9)
			cv.line(15, 8, 19, 8, 9)
			cv.line(23, 4, 23, 11, 9)
			cv.line(23, 4, 27, 4, 9)
			cv.line(27, 4, 27, 7, 9)
			cv.line(23, 7, 27, 7, 9)
		"vent":
			cv = Canvas.new(22, 20)
			cv.ellipse(11, 10, 10, 9, 2)
			cv.ellipse(11, 10, 7, 6, 1, false)
			cv.line(5, 10, 17, 10, 3)
			cv.line(11, 4, 11, 16, 3)
			cv.ellipse(11, 10, 2, 2, 4, false)
		"hatch":
			cv = Canvas.new(40, 40)
			cv.poly(PackedVector2Array([Vector2(20, 18), Vector2(38, 27), Vector2(20, 36), Vector2(2, 27)]), 2)
			cv.ellipse(20, 27, 12, 6, 1, false)
			cv.ellipse(20, 27, 8, 4, 0, false)
			for i in 3:
				cv.line(14 + i * 6, 25, 14 + i * 6, 29, 3)
			cv.rect(4, 2, 3, 26, 3)
			cv.rect(33, 2, 3, 26, 3)
			cv.line(4, 3, 35, 3, 4)
			cv.rect(17, 0, 6, 3, 8, false)
		"roadend":
			cv = Canvas.new(34, 46)
			cv.poly(PackedVector2Array([Vector2(4, 32), Vector2(20, 24), Vector2(32, 30), Vector2(26, 38), Vector2(12, 42)]), 1)
			cv.line(8, 35, 24, 29, 5)
			cv.line(17, 34, 17, 6, 3, 2)
			cv.rect(6, 2, 22, 12, 7)
			cv.rect(8, 4, 18, 8, 8, false)
			cv.line(10, 8, 23, 8, 9)
			cv.line(20, 6, 23, 8, 9)
			cv.line(20, 10, 23, 8, 9)
		"cable":
			cv = Canvas.new(32, 40)
			cv.line(2, 2, 2, 39, 2)
			for i in 9:
				var t := i / 8.0
				cv.put(2 + int(t * 28), 4 + int(sin(t * PI) * 10), 3)
			cv.line(30, 2, 30, 39, 2)
			cv.put(10, 11, 8)
			cv.put(22, 11, 9)
		"bus":
			cv = _big_bus()
		"tower":
			cv = _big_tower()
		"bigburrow":
			cv = _big_burrow()
		"ryhouse":
			cv = _big_ryhouse()
		"bigtree":
			cv = _big_tree()
		"jobscreen":
			cv = Canvas.new(34, 44)
			cv.line(8, 30, 8, 43, 2, 2)
			cv.line(26, 30, 26, 43, 2, 2)
			cv.rect(1, 1, 32, 30, 1)
			cv.rect(3, 3, 28, 24, 0)
			for i in 5:
				cv.line(5, 6 + i * 4, 5 + 6 + (i * 7) % 16, 6 + i * 4, 4 if i != 2 else 8)
			cv.rect(24, 5, 4, 3, 9)
			cv.line(3, 27, 30, 27, 3)
			cv.put(16, 29, 5)
		"herb":
			cv = Canvas.new(18, 16)
			for i in 5:
				cv.line(9, 15, 3 + i * 3, 4 + (i % 2) * 3, 4 if i % 2 == 0 else 3)
			cv.put(3, 4, 6)
			cv.put(15, 4, 6)
			cv.put(9, 3, 9)
		"roots":
			cv = Canvas.new(24, 14)
			cv.ellipse(12, 9, 10, 4, 2)
			cv.line(4, 9, 1, 3, 3, 2)
			cv.line(12, 8, 13, 1, 3, 2)
			cv.line(20, 9, 23, 4, 3, 2)
			cv.put(13, 1, 5)
			cv.put(1, 3, 5)
		"door":
			cv = Canvas.new(20, 40)
			cv.rect(1, 1, 18, 38, 1)
			cv.rect(3, 3, 14, 35, 3)
			cv.rect(5, 6, 10, 12, 2, false)
			cv.rect(5, 22, 10, 12, 2, false)
			cv.put(14, 20, 9)
			cv.put(14, 21, 8)
		"pump":
			cv = Canvas.new(16, 32)
			cv.rect(2, 6, 12, 24, 3)
			cv.rect(4, 9, 8, 6, 1, false)
			cv.line(5, 11, 10, 11, 6)
			cv.rect(1, 3, 14, 4, 7)
			cv.line(14, 16, 15, 26, 2)
			cv.put(15, 27, 4)
			cv.rect(3, 29, 10, 2, 1, false)
		"pylon":
			cv = Canvas.new(22, 60)
			cv.line(11, 59, 11, 6, 2, 2)
			cv.rect(1, 2, 20, 14, 2, false)
			cv.rect(2, 3, 18, 12, 7)
			cv.rect(4, 6, 3, 6, 9, false)
			cv.rect(9, 6, 3, 6, 9, false)
			cv.rect(14, 6, 3, 6, 9, false)
		"burrow":
			cv = Canvas.new(30, 16)
			cv.ellipse(15, 9, 14, 6, 3)
			cv.ellipse(15, 9, 9, 4, 0, false)
			cv.ellipse(15, 8, 9, 3, 1, false)
			cv.put(7, 12, 6)
			cv.put(23, 5, 6)
		"reeds":
			cv = Canvas.new(20, 24)
			for i in 7:
				var rx := 2 + i * 3
				cv.line(rx, 23, rx + (i % 3) - 1, 6 + (i * 5) % 9, 3 if i % 2 == 0 else 2)
				cv.put(rx + (i % 3) - 1, 5 + (i * 5) % 9, 4)
		"post":
			cv = Canvas.new(28, 30)
			cv.rect(3, 4, 3, 25, 2)
			cv.rect(22, 4, 3, 25, 2)
			cv.line(4, 8, 13, 13, 4)
			cv.line(13, 13, 23, 8, 4)
			cv.rect(10, 18, 8, 9, 3)
			cv.line(10, 18, 17, 18, 5)
		"stump":
			cv = Canvas.new(26, 46)
			cv.rect(4, 6, 18, 39, 2)
			cv.line(4, 6, 21, 6, 3)
			cv.line(8, 6, 6, 1, 2)
			cv.line(18, 6, 20, 2, 2)
			for k in 4:
				cv.line(5, 14 + k * 8, 20, 12 + k * 8, 1)
		_:
			cv = Canvas.new(8, 8)
			cv.rect(0, 0, 8, 8, 4)
	cv.outline(0)
	return to_tex(cv)


# ---------------- Большие предметы ----------------
## След предмета w×h клеток; нижняя вершина следа — на нижней кромке картинки (так их ставит world.gd).

func _foot(w: int, h: int, top: int) -> Dictionary:
	var cw := (w + h) * 16
	var ch := 8 * (w + h) + top + 2
	return {"cv": Canvas.new(cw, ch), "o": Vector2(h * 16, ch - 2 - 8 * (w + h))}


func _ip(o: Vector2, gx: float, gy: float, z: float) -> Vector2:
	return o + Vector2((gx - gy) * 16.0, (gx + gy) * 8.0 - z)


## Опрокинутый автобус: 5×2 клетки, колёса кверху, ряд окон у земли, ржавая полоса.
func _big_bus() -> Canvas:
	var f := _foot(5, 2, 30)
	var cv: Canvas = f.cv
	var o: Vector2 = f.o
	var x0 := 0.2
	var x1 := 4.8
	var y0 := 0.25
	var y1 := 1.75
	var z := 24.0
	# тень на песке
	cv.poly(PackedVector2Array([_ip(o, x0 - 0.1, y0, 0), _ip(o, x1 + 0.3, y0, 0), _ip(o, x1 + 0.3, y1 + 0.3, 0), _ip(o, x0 - 0.1, y1 + 0.3, 0)]), 1, false)
	# длинный бок (к камере слева)
	cv.poly(PackedVector2Array([_ip(o, x0, y1, z), _ip(o, x1, y1, z), _ip(o, x1, y1, 0), _ip(o, x0, y1, 0)]), 3)
	# торец (к камере справа)
	cv.poly(PackedVector2Array([_ip(o, x1, y1, z), _ip(o, x1, y0, z), _ip(o, x1, y0, 0), _ip(o, x1, y1, 0)]), 2)
	# днище, ставшее крышей
	cv.poly(PackedVector2Array([_ip(o, x0, y0, z), _ip(o, x1, y0, z), _ip(o, x1, y1, z), _ip(o, x0, y1, z)]), 2)
	# окна у земли (автобус вверх колёсами)
	for i in 7:
		var gx := x0 + 0.35 + i * 0.6
		cv.poly(PackedVector2Array([_ip(o, gx, y1, 10), _ip(o, gx + 0.42, y1, 10), _ip(o, gx + 0.42, y1, 3), _ip(o, gx, y1, 3)]), 1, false)
		if i % 3 == 1:
			cv.line(_ip(o, gx + 0.1, y1, 9).x, _ip(o, gx + 0.1, y1, 9).y, _ip(o, gx + 0.3, y1, 4).x, _ip(o, gx + 0.3, y1, 4).y, 4)
	# ржавая полоса
	var a := _ip(o, x0, y1, 16)
	var b := _ip(o, x1, y1, 16)
	cv.line(a.x, a.y, b.x, b.y, 8, 2)
	# окно водителя на торце
	cv.poly(PackedVector2Array([_ip(o, x1, y1 - 0.2, 12), _ip(o, x1, y0 + 0.2, 12), _ip(o, x1, y0 + 0.2, 3), _ip(o, x1, y1 - 0.2, 3)]), 1, false)
	# колёса и мосты кверху
	for wx in [x0 + 0.7, x1 - 0.9]:
		var p1 := _ip(o, wx, y0 + 0.3, z)
		var p2 := _ip(o, wx, y1 - 0.3, z)
		cv.line(p1.x, p1.y - 2, p2.x, p2.y - 2, 1, 2)
		for p in [p1, p2]:
			cv.ellipse(p.x, p.y - 4, 5, 4, 1)
			cv.ellipse(p.x, p.y - 4, 2, 1.5, 4, false)
	return cv


## Ретрансляционная вышка Института: 3×3 клетки, решётчатые ноги, площадка, антенна и красный огонь.
func _big_tower() -> Canvas:
	var f := _foot(3, 3, 170)
	var cv: Canvas = f.cv
	var o: Vector2 = f.o
	# бетонное основание
	cv.poly(PackedVector2Array([_ip(o, 0.1, 0.1, 0), _ip(o, 2.9, 0.1, 0), _ip(o, 2.9, 2.9, 0), _ip(o, 0.1, 2.9, 0)]), 2)
	cv.poly(PackedVector2Array([_ip(o, 0.1, 2.9, 0), _ip(o, 2.9, 2.9, 0), _ip(o, 2.9, 2.9, -4), _ip(o, 0.1, 2.9, -4)]), 1, false)
	var feet := [Vector2(0.4, 0.4), Vector2(2.6, 0.4), Vector2(2.6, 2.6), Vector2(0.4, 2.6)]
	var top := 140.0
	var tops: Array = []
	for ft in feet:
		tops.append(Vector2(1.5, 1.5) + (ft - Vector2(1.5, 1.5)) * 0.22)
	var levels := [0.0, 0.2, 0.38, 0.54, 0.68, 0.8, 0.9, 1.0]
	# дальние ноги темнее, ближние светлее
	for idx in [0, 1, 3, 2]:
		var c := 2 if idx == 0 else (3 if idx != 2 else 4)
		var a: Vector2 = feet[idx]
		var b: Vector2 = tops[idx]
		var pa := _ip(o, a.x, a.y, 0)
		var pb := _ip(o, b.x, b.y, top)
		cv.line(pa.x, pa.y, pb.x, pb.y, c, 2)
	for li in levels.size() - 1:
		var t0: float = levels[li]
		var t1: float = levels[li + 1]
		for k in 4:
			var i0: int = k
			var i1: int = (k + 1) % 4
			var c2 := 2 if (k == 0 or k == 3) else 3
			var a0: Vector2 = (feet[i0] as Vector2).lerp(tops[i0], t0)
			var b0: Vector2 = (feet[i1] as Vector2).lerp(tops[i1], t0)
			var a1: Vector2 = (feet[i0] as Vector2).lerp(tops[i0], t1)
			var b1: Vector2 = (feet[i1] as Vector2).lerp(tops[i1], t1)
			var q0 := _ip(o, a0.x, a0.y, top * t0)
			var q1 := _ip(o, b0.x, b0.y, top * t0)
			var q2 := _ip(o, a1.x, a1.y, top * t1)
			var q3 := _ip(o, b1.x, b1.y, top * t1)
			cv.line(q0.x, q0.y, q1.x, q1.y, c2)
			cv.line(q0.x, q0.y, q3.x, q3.y, c2)
			cv.line(q1.x, q1.y, q2.x, q2.y, c2)
	# площадка и антенны
	var pl := PackedVector2Array()
	for t in tops:
		var tv: Vector2 = Vector2(1.5, 1.5) + ((t as Vector2) - Vector2(1.5, 1.5)) * 1.6
		pl.append(_ip(o, tv.x, tv.y, top))
	cv.poly(pl, 4)
	var m0 := _ip(o, 1.5, 1.5, top)
	cv.line(m0.x, m0.y, m0.x, m0.y - 26, 4, 2)
	cv.line(m0.x - 6, m0.y - 14, m0.x + 6, m0.y - 18, 3)
	cv.ellipse(m0.x - 9, m0.y - 8, 5, 6, 5)
	cv.ellipse(m0.x - 9, m0.y - 8, 2, 3, 2, false)
	cv.ellipse(m0.x + 1, m0.y - 28, 2, 2, 9, false)
	cv.put(int(m0.x) + 1, int(m0.y) - 31, 8)
	# будка у подножия
	var bx := _ip(o, 2.75, 2.3, 0)
	cv.rect(int(bx.x) - 8, int(bx.y) - 16, 14, 16, 3)
	cv.rect(int(bx.x) - 5, int(bx.y) - 12, 5, 7, 1, false)
	return cv


## Огромное дерево Запутанного леса: 2×2 клетки, ствол как труба, корни наружу, крона уходит вверх.
func _big_tree() -> Canvas:
	var f := _foot(2, 2, 120)
	var cv: Canvas = f.cv
	var o: Vector2 = f.o
	var c := _ip(o, 1.0, 1.0, 0)
	# корни
	for k in 6:
		var a := k * 1.05
		var e := c + Vector2(cos(a) * 26, sin(a) * 12)
		cv.line(c.x, c.y - 4, e.x, e.y, 2, 3)
	# ствол
	cv.rect(int(c.x) - 9, int(c.y) - 96, 18, 94, 2)
	cv.rect(int(c.x) - 9, int(c.y) - 96, 6, 94, 1)
	for k in 7:
		cv.line(c.x - 6 + (k % 3) * 5, c.y - 10 - k * 12, c.x - 4 + (k % 3) * 5, c.y - 18 - k * 12, 3)
	# крона
	cv.ellipse(c.x, c.y - 104, 30, 16, 3)
	cv.ellipse(c.x - 12, c.y - 98, 16, 9, 2)
	cv.ellipse(c.x + 10, c.y - 112, 18, 9, 4)
	for k in 5:
		cv.put(int(c.x) - 20 + k * 10, int(c.y) - 104 + (k % 2) * 6, 6)
	return cv


## Домик Рыжей: 3×2 клетки, листовой металл, косая крыша, красная занавеска и дверь к камере.
func _big_ryhouse() -> Canvas:
	var f := _foot(3, 2, 44)
	var cv: Canvas = f.cv
	var o: Vector2 = f.o
	var x0 := 0.15
	var x1 := 2.85
	var y0 := 0.15
	var y1 := 1.85
	var z := 26.0
	# левый бок — к камере, с дверью и окном
	cv.poly(PackedVector2Array([_ip(o, x0, y1, z), _ip(o, x1, y1, z), _ip(o, x1, y1, 0), _ip(o, x0, y1, 0)]), 3)
	# правый торец
	cv.poly(PackedVector2Array([_ip(o, x1, y1, z), _ip(o, x1, y0, z), _ip(o, x1, y0, 0), _ip(o, x1, y1, 0)]), 2)
	# швы листов металла
	for i in 6:
		var gx := x0 + 0.4 + i * 0.42
		var a := _ip(o, gx, y1, z - 1)
		var b := _ip(o, gx, y1, 1)
		cv.line(a.x, a.y, b.x, b.y, 2)
	# крыша: скат к камере
	cv.poly(PackedVector2Array([_ip(o, x0 - 0.1, y0, z + 14), _ip(o, x1 + 0.1, y0, z + 14), _ip(o, x1 + 0.1, y1 + 0.2, z - 2), _ip(o, x0 - 0.1, y1 + 0.2, z - 2)]), 4)
	cv.poly(PackedVector2Array([_ip(o, x1 + 0.1, y0, z + 14), _ip(o, x1 + 0.1, y1 + 0.2, z - 2), _ip(o, x1, y1, z), _ip(o, x1, y0, z)]), 1, false)
	var r0 := _ip(o, x0 - 0.1, y1 + 0.2, z - 2)
	var r1 := _ip(o, x1 + 0.1, y1 + 0.2, z - 2)
	cv.line(r0.x, r0.y, r1.x, r1.y, 5)
	# дверь
	cv.poly(PackedVector2Array([_ip(o, 1.9, y1, 20), _ip(o, 2.4, y1, 20), _ip(o, 2.4, y1, 0), _ip(o, 1.9, y1, 0)]), 1)
	var kn := _ip(o, 2.3, y1, 10)
	cv.put(int(kn.x), int(kn.y), 8)
	# окно с красной занавеской и тёплым светом
	cv.poly(PackedVector2Array([_ip(o, 0.6, y1, 19), _ip(o, 1.3, y1, 19), _ip(o, 1.3, y1, 9), _ip(o, 0.6, y1, 9)]), 6)
	cv.poly(PackedVector2Array([_ip(o, 0.6, y1, 19), _ip(o, 0.85, y1, 19), _ip(o, 0.85, y1, 9), _ip(o, 0.6, y1, 9)]), 8)
	cv.poly(PackedVector2Array([_ip(o, 1.1, y1, 19), _ip(o, 1.3, y1, 19), _ip(o, 1.3, y1, 9), _ip(o, 1.1, y1, 9)]), 9)
	# труба на крыше
	var ch := _ip(o, 2.2, 0.6, z + 10)
	cv.rect(int(ch.x) - 2, int(ch.y) - 12, 5, 12, 2)
	cv.put(int(ch.x), int(ch.y) - 15, 3)
	cv.put(int(ch.x) + 1, int(ch.y) - 18, 2)
	return cv


## Главная нора логова: 2×2 клетки, насыпь с чёрным провалом и костями.
func _big_burrow() -> Canvas:
	var f := _foot(2, 2, 26)
	var cv: Canvas = f.cv
	var o: Vector2 = f.o
	var c := _ip(o, 1.0, 1.0, 0)
	cv.ellipse(c.x, c.y - 6, 30, 14, 3)
	cv.ellipse(c.x, c.y - 10, 22, 10, 4)
	cv.ellipse(c.x + 2, c.y - 6, 13, 7, 0, false)
	cv.ellipse(c.x + 2, c.y - 8, 12, 5, 1, false)
	for k in 4:
		var bp := c + Vector2(-24 + k * 15, 4 - (k % 2) * 6)
		cv.line(bp.x, bp.y, bp.x + 7, bp.y - 2, 5)
		cv.put(int(bp.x), int(bp.y), 6)
		cv.put(int(bp.x) + 7, int(bp.y) - 2, 6)
	return cv


# ---------------- Человечки на карте ----------------

## look: {hair, coat, skin, accent, race, hat}
func person_tex(look: Dictionary, frame: int = 0) -> Texture2D:
	var key := "person_%s_%d" % [str(look.hash()), frame]
	return cached(key, func(): return _person(look, frame))


func _person(look: Dictionary, frame: int) -> ImageTexture:
	var cv := Canvas.new(16, 28)
	var coat: int = look.get("coat", 3)
	var skin: int = look.get("skin", 5)
	var hair: int = look.get("hair", 2)
	var race: String = look.get("race", "Человек")
	# тень
	for x in range(3, 13):
		cv.put(x, 27, 0)
	# ноги
	var l1 := 0
	var l2 := 0
	if frame == 1:
		l1 = -1
		l2 = 1
	cv.rect(5 + l1, 19, 2, 7, 1, false)
	cv.rect(9 + l2, 19, 2, 7, 1, false)
	# туловище
	cv.rect(4, 11, 8, 9, coat)
	cv.line(8, 11, 8, 19, coat - 1)
	# руки
	cv.rect(2, 12, 2, 7, coat - 1, false)
	cv.rect(12, 12, 2, 7, coat - 1, false)
	cv.put(2, 19, skin)
	cv.put(13, 19, skin)
	if look.has("accent"):
		cv.line(4, 13, 11, 13, look.accent)
	# голова
	if race == "Машина":
		cv.rect(4, 3, 8, 8, 3)
		cv.line(5, 6, 10, 6, 9)
	elif race == "Инсектид":
		cv.ellipse(8, 7, 4, 4.5, 3)
		cv.put(6, 6, 9)
		cv.put(10, 6, 9)
		cv.line(6, 3, 4, 0, 3)
		cv.line(10, 3, 12, 0, 3)
	else:
		cv.ellipse(8, 7, 3.6, 4, skin)
		cv.put(7, 7, 1)
		cv.put(10, 7, 1)
		# волосы
		if look.get("hat", false):
			cv.rect(3, 2, 10, 3, coat + 1)
		elif race == "Флореанин":
			cv.ellipse(8, 3.5, 5, 2.5, 4)
			cv.put(3, 2, 5)
			cv.put(13, 2, 5)
		else:
			cv.ellipse(8, 4, 4, 2.4, hair)
			if look.get("long", false):
				cv.rect(4, 4, 2, 7, hair, false)
				cv.rect(11, 4, 2, 7, hair, false)
		if race == "Крысолюд":
			cv.ellipse(4, 3, 1.5, 1.5, skin - 1, false)
			cv.ellipse(12, 3, 1.5, 1.5, skin - 1, false)
		if race == "Ангел":
			cv.ellipse(8, 0.8, 3, 0.8, 6, false)
	cv.outline(0)
	return to_tex(cv)


# ---------------- Портреты для сцен-новелл ----------------

## Портрет 48x56. look: sex, race, hair, coat, skin, traits[], extra
func portrait_tex(look: Dictionary) -> Texture2D:
	return cached("portrait_" + str(look.hash()), func(): return _portrait(look))


func _portrait(look: Dictionary) -> ImageTexture:
	var cv := Canvas.new(48, 56)
	var traits: Array = look.get("traits", [])
	var race: String = look.get("race", "Человек")
	var sex: String = look.get("sex", "М")
	var skin: int = look.get("skin", 4)
	var hair: int = look.get("hair", 2)
	var coat: int = look.get("coat", 2)
	if "Пепельная кожа" in traits or "Белый рецидив" in traits:
		skin = 5
	if "Красная кожа" in traits:
		skin = 8
	var head_ry := 13.0
	var head_cy := 24.0
	if "Большой лоб" in traits:
		head_ry = 14.5
		head_cy = 23.0
	var head_rx := 10.5 if sex == "Ж" else 11.5
	if "Тонкие кости" in traits or "Истощение" in traits:
		head_rx -= 1.0
	if "Полнота" in traits or "Толстые кости" in traits:
		head_rx += 1.5

	# плечи и одежда
	cv.poly(PackedVector2Array([Vector2(4, 56), Vector2(8, 44), Vector2(18, 39), Vector2(30, 39), Vector2(40, 44), Vector2(44, 56)]), coat)
	cv.poly(PackedVector2Array([Vector2(18, 39), Vector2(24, 48), Vector2(30, 39)]), coat + 2)
	if look.has("collar"):
		cv.line(18, 40, 24, 48, look.collar)
		cv.line(30, 40, 24, 48, look.collar)
	# шея
	cv.rect(20, 34, 8, 7, skin - 1, false)

	if race == "Машина":
		cv.rect(13, 10, 22, 26, 3)
		cv.rect(15, 19, 18, 5, 0, false)
		cv.line(16, 21, 31, 21, 9)
		cv.line(17, 22, 30, 22, 8)
		for i in 4:
			cv.line(17 + i * 4, 28, 17 + i * 4, 33, 2)
		cv.line(24, 10, 24, 4, 3)
		cv.ellipse(24, 3, 2, 2, 9, false)
		cv.outline(0)
		return to_tex(cv)

	if race == "Инсектид":
		cv.ellipse(24, 24, 11, 13, 3)
		cv.ellipse(18, 21, 4, 5, 8)
		cv.ellipse(30, 21, 4, 5, 8)
		cv.put(17, 19, 9)
		cv.put(29, 19, 9)
		cv.line(20, 33, 17, 38, 4, 2)
		cv.line(28, 33, 31, 38, 4, 2)
		cv.line(19, 12, 12, 1, 4)
		cv.line(29, 12, 36, 1, 4)
		cv.outline(0)
		return to_tex(cv)

	# уши
	if race == "Крысолюд" or "Уши крысолюда" in traits:
		cv.ellipse(12, 12, 5, 6, skin - 1)
		cv.ellipse(36, 12, 5, 6, skin - 1)
		cv.ellipse(12, 12, 2.5, 3.5, 7, false)
		cv.ellipse(36, 12, 2.5, 3.5, 7, false)
	elif "Большие уши" in traits:
		cv.ellipse(12, 24, 3.5, 5, skin - 1)
		cv.ellipse(36, 24, 3.5, 5, skin - 1)
	else:
		cv.ellipse(13.5, 25, 2, 3, skin - 1)
		cv.ellipse(34.5, 25, 2, 3, skin - 1)
	# крылья ангела
	if race == "Ангел" or "Крылья" in traits:
		cv.poly(PackedVector2Array([Vector2(8, 44), Vector2(0, 20), Vector2(3, 18), Vector2(12, 38)]), 5)
		cv.poly(PackedVector2Array([Vector2(40, 44), Vector2(48, 20), Vector2(45, 18), Vector2(36, 38)]), 5)

	# голова
	cv.ellipse(24, head_cy, head_rx, head_ry, skin)

	# волосы
	var red_hair: bool = "Рыжие волосы" in traits or look.get("red", false)
	var hc := hair
	if red_hair:
		hc = 8
	elif "Белые волосы" in traits:
		hc = 6
	if race == "Флореанин":
		for i in 7:
			var a := PI + i * PI / 6.0
			cv.ellipse(24 + cos(a) * 11, head_cy - 6 + sin(a) * 9, 4, 3, 4 + i % 2)
	elif look.get("bald", false):
		pass
	elif look.get("helmet", false):
		cv.ellipse(24, head_cy - 6, head_rx + 2, 9, 3)
		cv.rect(12, int(head_cy) - 6, 25, 3, 2)
	else:
		cv.ellipse(24, head_cy - 9, head_rx + 1, 7, hc)
		cv.rect(int(24 - head_rx), int(head_cy) - 10, 4, 6, hc)
		cv.rect(int(24 + head_rx) - 3, int(head_cy) - 10, 4, 6, hc)
		if sex == "Ж" or look.get("long", false):
			cv.rect(int(24 - head_rx) - 1, int(head_cy) - 6, 4, 20, hc)
			cv.rect(int(24 + head_rx) - 2, int(head_cy) - 6, 4, 20, hc)
	if race == "Ангел":
		cv.ellipse(24, head_cy - head_ry - 3, 9, 2, 6, false)
		cv.ellipse(24, head_cy - head_ry - 3, 6, 0.8, -1, false)

	# глаза
	var ey := int(head_cy) + 1
	var eye_c := 1
	if "Белые глаза" in traits:
		eye_c = 6
	for ex in [19, 29]:
		cv.rect(ex - 2, ey, 4, 2, 6, false)
		cv.put(ex, ey, eye_c)
		cv.put(ex - 1, ey + 1, eye_c)
		if "Змеиные глаза" in traits:
			cv.rect(ex - 2, ey, 4, 2, 5, false)
			cv.line(ex, ey - 1, ex, ey + 2, 0)
		cv.line(ex - 2, ey - 2, ex + 2, ey - 2, hc if not red_hair else 7)
	if race == "Крысолюд":
		cv.put(19, ey, 8)
		cv.put(29, ey, 8)
	if look.get("glasses", false):
		cv.line(15, ey - 1, 33, ey - 1, 1)
		cv.rect(16, ey - 1, 6, 4, -1, false)
		cv.line(16, ey + 3, 21, ey + 3, 1)
		cv.line(27, ey + 3, 32, ey + 3, 1)
	# нос и рот
	cv.line(24, ey + 2, 23, ey + 6, skin - 1)
	var mouth_y := ey + 9
	cv.line(21, mouth_y, 27, mouth_y, 7 if sex == "Ж" else skin - 2)
	if race == "Крысолюд" or "Зубы крысолюда" in traits:
		cv.rect(23, mouth_y + 1, 2, 2, 6, false)
	if look.get("beard", false):
		cv.ellipse(24, mouth_y + 3, 7, 5, hair)
		cv.line(21, mouth_y, 27, mouth_y, skin - 2)
	if look.get("mask", false):
		cv.rect(16, ey + 4, 17, 9, 5, false)
		cv.line(16, ey + 4, 12, ey + 1, 4)
		cv.line(32, ey + 4, 36, ey + 1, 4)
	# черты
	if "Веснушки на коже" in traits or look.get("freckles", false):
		for f in [Vector2i(17, 31), Vector2i(19, 32), Vector2i(29, 31), Vector2i(31, 32), Vector2i(21, 31), Vector2i(27, 32)]:
			cv.put(f.x, ey + (f.y - 30), 7 if red_hair else skin - 2)
	if "Ножевые шрамы" in traits or look.get("scar", false):
		cv.line(28, ey - 5, 33, ey + 8, 8)
	if "Запутанные шрамы" in traits:
		cv.line(15, ey - 6, 20, ey + 4, 9)
		cv.line(20, ey + 4, 17, ey + 9, 9)
	if "Пулевые шрамы" in traits:
		cv.ellipse(31, ey + 6, 1.5, 1.5, 7, false)
	if "Ожоги шрамы" in traits:
		for i in 10:
			cv.put(14 + (i * 7) % 8, ey - 2 + (i * 5) % 9, 7)
	if "Морщины" in traits or look.get("old", false):
		cv.line(18, ey + 5, 19, ey + 8, skin - 1)
		cv.line(30, ey + 5, 29, ey + 8, skin - 1)
		cv.line(20, int(head_cy) - 6, 28, int(head_cy) - 6, skin - 1)
	if "Металлический протез" in traits:
		cv.rect(26, ey - 3, 9, 8, 3)
		cv.ellipse(30, ey + 1, 2, 2, 9, false)
	if "Растительная кожа" in traits:
		cv.line(15, 32, 19, 38, 4)
		cv.line(33, 30, 30, 37, 4)
	if "Чешуйчатая кожа" in traits:
		for i in 6:
			cv.put(15 + i, 33 + (i % 2), skin - 2)
	cv.outline(0)
	return to_tex(cv)


# ---------------- Враги для экрана боя ----------------

## Возвращает {tex, parts: {имя части: Rect2}} — прямоугольники для подсветки цели.
func enemy_art(kind: String) -> Dictionary:
	if cache.has("enemy_" + kind):
		return cache["enemy_" + kind]
	var cv := Canvas.new(64, 64)
	var parts := {}
	match kind:
		"dog":
			cv.ellipse(30, 36, 18, 10, 3)
			for lx in [16, 22, 36, 42]:
				cv.line(lx, 42, lx - 2 + (lx % 3), 58, 2, 3)
			cv.line(12, 32, 4, 26, 2, 2)
			cv.ellipse(50, 28, 9, 8, 3)
			cv.poly(PackedVector2Array([Vector2(52, 30), Vector2(63, 33), Vector2(60, 40), Vector2(50, 37)]), 8)
			for i in 4:
				cv.put(53 + i * 2, 33, 6)
				cv.put(53 + i * 2, 37, 6)
			cv.line(46, 21, 44, 15, 3, 2)
			for i in 5:
				cv.line(20 + i * 5, 27, 22 + i * 5, 31, 2)
			parts = {"Голова": Rect2(41, 19, 15, 14), "Туловище": Rect2(13, 26, 34, 20),
				"Пасть": Rect2(50, 29, 14, 12), "Лапы": Rect2(12, 44, 34, 16)}
		"raider":
			cv.ellipse(32, 12, 7, 8, 4)
			cv.rect(25, 4, 14, 4, 2)
			cv.rect(27, 11, 10, 3, 0, false)
			cv.put(29, 12, 9)
			cv.put(34, 12, 9)
			cv.poly(PackedVector2Array([Vector2(20, 22), Vector2(44, 22), Vector2(42, 44), Vector2(22, 44)]), 2)
			cv.line(22, 30, 42, 30, 8)
			cv.line(32, 22, 32, 44, 1)
			cv.line(20, 23, 10, 36, 3, 4)
			cv.line(10, 36, 16, 40, 3, 3)
			cv.rect(14, 37, 9, 4, 1, false)
			cv.line(44, 23, 54, 34, 3, 4)
			cv.line(54, 34, 58, 18, 5, 3)
			cv.rect(24, 44, 6, 18, 1)
			cv.rect(34, 44, 6, 18, 1)
			parts = {"Голова": Rect2(24, 3, 16, 18), "Туловище": Rect2(20, 22, 24, 23),
				"Правая рука": Rect2(8, 22, 16, 22), "Левая рука": Rect2(42, 16, 18, 22)}
		"muezzin":
			# пёс-вожак: горб, выгнутый хребет, пасть до груди
			cv.ellipse(28, 34, 20, 13, 2)
			cv.ellipse(22, 24, 11, 9, 3)
			for lx in [12, 19, 34, 41]:
				cv.line(lx, 42, lx - 3 + (lx % 4), 60, 2, 3)
			cv.line(8, 30, 1, 20, 2, 2)
			cv.ellipse(48, 26, 11, 10, 3)
			cv.poly(PackedVector2Array([Vector2(46, 26), Vector2(63, 18), Vector2(63, 46), Vector2(44, 40)]), 7)
			cv.poly(PackedVector2Array([Vector2(49, 28), Vector2(62, 23), Vector2(62, 41), Vector2(48, 37)]), 0, false)
			for i in 6:
				cv.line(50 + i * 2, 26 - i, 51 + i * 2, 30 - i, 6)
				cv.line(50 + i * 2, 39 + i / 2, 51 + i * 2, 35 + i / 2, 6)
			cv.line(44, 17, 40, 7, 3, 2)
			cv.line(50, 17, 53, 8, 3, 2)
			for i in 7:
				cv.line(10 + i * 5, 20 + absi(i - 3), 12 + i * 5, 14 + absi(i - 3), 4)
			parts = {"Голова": Rect2(37, 14, 22, 16), "Туловище": Rect2(8, 18, 40, 28),
				"Пасть": Rect2(44, 18, 20, 28), "Лапы": Rect2(8, 42, 38, 20)}
		"warped":
			cv.ellipse(32, 40, 16, 18, 2)
			cv.ellipse(32, 18, 10, 11, 4)
			cv.line(22, 22, 24, 30, 1)
			for i in 5:
				var a := 0.4 + i * 0.55
				cv.line(32 + cos(a) * 12, 46, 32 + cos(a) * 30, 60 - sin(a * 2.0) * 6, 3, 2)
			cv.line(18, 32, 4, 20, 3, 2)
			cv.line(46, 32, 60, 24, 3, 2)
			cv.line(4, 20, 2, 10, 3, 2)
			for e in [Vector2(27, 15), Vector2(37, 15), Vector2(32, 10), Vector2(24, 36), Vector2(38, 42)]:
				cv.ellipse(e.x, e.y, 2.5, 2, 6, false)
				cv.put(int(e.x), int(e.y), 8)
			cv.line(26, 23, 38, 23, 8)
			for i in 6:
				cv.put(27 + i * 2, 24, 6)
			parts = {"Лицо": Rect2(22, 7, 20, 22), "Туловище": Rect2(16, 28, 32, 26),
				"Щупальца": Rect2(0, 18, 64, 46), "Глаза": Rect2(23, 8, 18, 10)}
		"slepysh":
			# бледный, на длинных руках, безглазый
			cv.ellipse(30, 40, 14, 9, 4)
			cv.ellipse(46, 30, 8, 7, 5)
			cv.line(36, 40, 50, 50, 4, 2)
			cv.line(50, 50, 58, 60, 4, 2)
			cv.line(24, 40, 14, 52, 4, 2)
			cv.line(14, 52, 8, 62, 4, 2)
			cv.line(20, 46, 22, 60, 3, 2)
			cv.line(34, 47, 36, 60, 3, 2)
			for i in 4:
				cv.put(57 + (i % 2), 60 + i / 2, 6)
				cv.put(7 + (i % 2), 61 + i / 2, 6)
			cv.line(41, 33, 52, 33, 0)
			for i in 5:
				cv.put(42 + i * 2, 34, 6)
			for i in 4:
				cv.line(20 + i * 5, 34, 21 + i * 5, 37, 3)
			parts = {"Голова": Rect2(37, 22, 18, 16), "Туловище": Rect2(16, 31, 30, 18), "Руки": Rect2(4, 40, 58, 24)}
		"slepets":
			# взрослый слепыш: выше, четыре руки, костяные наросты на спине
			cv.ellipse(28, 36, 15, 12, 4)
			cv.ellipse(44, 18, 9, 9, 5)
			cv.line(38, 30, 54, 40, 4, 2)
			cv.line(54, 40, 60, 56, 4, 2)
			cv.line(36, 38, 50, 52, 3, 2)
			cv.line(50, 52, 52, 63, 3, 2)
			cv.line(18, 36, 8, 48, 4, 2)
			cv.line(8, 48, 4, 62, 4, 2)
			cv.line(22, 44, 16, 60, 3, 2)
			cv.line(30, 46, 32, 62, 3, 2)
			for i in 5:
				cv.poly(PackedVector2Array([Vector2(14 + i * 6, 27 - (i % 2) * 2), Vector2(17 + i * 6, 18 - (i % 2) * 3), Vector2(20 + i * 6, 27)]), 2)
			cv.line(38, 21, 51, 21, 0)
			cv.line(39, 22, 50, 22, 9)
			for i in 6:
				cv.put(39 + i * 2, 23, 6)
			for i in 4:
				cv.put(59 + (i % 2), 56 + i, 6)
				cv.put(3 + (i % 2), 60 + i / 2, 6)
			parts = {"Голова": Rect2(35, 9, 19, 19), "Туловище": Rect2(13, 24, 31, 24), "Руки": Rect2(2, 30, 60, 34)}
		"plant":
			cv.line(32, 63, 32, 34, 3, 3)
			for i in 6:
				var a := -2.6 + i * 0.5
				cv.line(32, 58, 32 + cos(a) * 28, 58 + sin(a) * 10, 2, 2)
			cv.ellipse(32, 24, 14, 12, 7)
			cv.ellipse(32, 26, 9, 6, 0)
			for i in 6:
				cv.put(25 + i * 3, 22, 6)
				cv.put(25 + i * 3, 30, 6)
			for i in 5:
				var a2 := -2.8 + i * 0.6
				cv.ellipse(32 + cos(a2) * 15, 24 + sin(a2) * 13, 4, 3, 8)
			parts = {"Бутон": Rect2(18, 12, 28, 26), "Стебель": Rect2(27, 36, 10, 28), "Лозы": Rect2(2, 46, 60, 18)}
	cv.outline(0)
	var res := {"tex": to_tex(cv), "parts": parts}
	cache["enemy_" + kind] = res
	return res
