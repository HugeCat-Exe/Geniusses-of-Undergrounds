extends Control
## Чтение книги: обложка слева, текст справа.

const Books := preload("res://scripts/books.gd")

var item := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var body := Panel.new()
	body.position = Vector2(40, 30)
	body.size = Vector2(560, 300)
	add_child(body)
	var bk: Dictionary = D.BOOKS[item]
	add_child(cover(bk.cover, Vector2(56, 46), Vector2(180, 240)))
	var title := Pal.label(bk.full, Pal.G5, 10, true)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.position = Vector2(252, 46)
	title.size = Vector2(332, 30)
	add_child(title)
	var sc := ScrollContainer.new()
	sc.position = Vector2(252, 84)
	sc.size = Vector2(332, 196)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	var txt := Pal.rich(G.book_text(item) + "\n\n[color=%s]%s +2 на сутки.[/color]" % [Pal.hex(Pal.R3), bk.get("stat", bk.get("skill", ""))], 9)
	txt.custom_minimum_size = Vector2(320, 0)
	sc.add_child(txt)
	var close_b := Pal.button("ЗАКРЫТЬ", queue_free, 10)
	close_b.position = Vector2(488, 298)
	close_b.size = Vector2(96, 20)
	add_child(close_b)


## Обложка в рамке терминала. Используется и в лавке библиотекаря.
static func cover(id: String, pos: Vector2, size: Vector2) -> Control:
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", Pal.box(Pal.G0, Pal.G3, 2, 0))
	frame.position = pos - Vector2(3, 3)
	frame.size = size + Vector2(6, 6)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tr := TextureRect.new()
	tr.texture = Books.texture(id)
	# сначала режим растяжения, потом размер: иначе TextureRect не даст сжать картинку меньше её родного размера
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.position = Vector2(3, 3)
	tr.size = size
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	frame.add_child(tr)
	return frame


func _unhandled_key_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
		queue_free()
		get_viewport().set_input_as_handled()
