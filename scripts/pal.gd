extends Node
## Палитра «старого терминала» и общая тема интерфейса.

const BG := Color("050d07")
const G0 := Color("0b2412")
const G1 := Color("14421f")
const G2 := Color("24702f")
const G3 := Color("3fae47")
const G4 := Color("7ff07a")
const G5 := Color("d2ffc8")
const R1 := Color("5a0d0d")
const R2 := Color("c42424")
const R3 := Color("ff6650")
const CLEAR := Color(0, 0, 0, 0)

## Символы, которыми рисуются спрайты в art.gd.
var chars := {
	".": CLEAR, "0": BG, "1": G0, "2": G1, "3": G2, "4": G3, "5": G4, "6": G5,
	"r": R1, "R": R2, "o": R3,
}

var font: Font
var font_bold: Font
var font_title: Font
var theme: Theme


func _ready() -> void:
	var mono: FontFile = load("res://fonts/DejaVuSansMono.ttf")
	var plex: FontFile = load("res://fonts/IBMPlexMono-Medium.ttf")
	plex.fallbacks = [mono]
	plex.hinting = TextServer.HINTING_LIGHT
	font = plex
	var bold: FontFile = load("res://fonts/IBMPlexMono-Bold.ttf")
	bold.fallbacks = [mono]
	bold.hinting = TextServer.HINTING_LIGHT
	font_bold = bold
	font_title = bold
	theme = _make_theme()


func box(bg: Color, border: Color, bw: int = 1, pad: int = 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.content_margin_left = pad + 2
	s.content_margin_right = pad + 2
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	s.anti_aliasing = false
	return s


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 10
	for cls in ["Label", "Button", "LineEdit", "RichTextLabel", "CheckBox"]:
		t.set_color("font_color", cls, G4)
	t.set_color("default_color", "RichTextLabel", G4)
	t.set_font("bold_font", "RichTextLabel", font_bold)
	t.set_font("normal_font", "RichTextLabel", font)

	t.set_stylebox("normal", "Button", box(G0, G2))
	t.set_stylebox("hover", "Button", box(G1, G4))
	t.set_stylebox("pressed", "Button", box(G3, G5))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), G4))
	t.set_stylebox("disabled", "Button", box(BG, G1))
	t.set_color("font_hover_color", "Button", G5)
	t.set_color("font_pressed_color", "Button", BG)
	t.set_color("font_focus_color", "Button", G5)
	t.set_color("font_disabled_color", "Button", G2)
	t.set_color("font_hover_pressed_color", "Button", BG)

	t.set_stylebox("panel", "Panel", box(BG, G3))
	t.set_stylebox("panel", "PanelContainer", box(Color(BG, 0.94), G3, 1, 6))

	t.set_stylebox("normal", "LineEdit", box(G0, G3))
	t.set_stylebox("focus", "LineEdit", box(G0, G5))
	t.set_color("caret_color", "LineEdit", G5)
	t.set_color("font_placeholder_color", "LineEdit", G2)
	t.set_color("selection_color", "LineEdit", G2)

	var sb := StyleBoxFlat.new()
	sb.bg_color = G0
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	var grab := StyleBoxFlat.new()
	grab.bg_color = G3
	grab.content_margin_left = 3
	grab.content_margin_right = 3
	t.set_stylebox("scroll", "VScrollBar", sb)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_stylebox("separator", "HSeparator", box(G2, G2, 0, 0))
	t.set_constant("separation", "HSeparator", 6)
	t.set_constant("separation", "VBoxContainer", 3)
	t.set_constant("separation", "HBoxContainer", 4)
	return t


## Мелкие помощники для сборки интерфейса кодом.
func label(text: String, color: Color = G4, size: int = 10, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	if bold:
		l.add_theme_font_override("font", font_bold)
	return l


func button(text: String, cb: Callable, size: int = 10) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func rich(text: String = "", size: int = 10) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.text = text
	return r


func hex(c: Color) -> String:
	return "#" + c.to_html(false)
