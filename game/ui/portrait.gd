class_name Portrait
extends Control
## Speaker portrait for the dialogue box and the HUD radio, drawn in code
## (flat shapes in the palette) until there is real art. To swap in art,
## drop a square PNG at ART_DIR + "<id>.png" (ids in LOOKS): it is used
## instead of the drawing, with the same frame. Unknown speakers get a
## radio-static silhouette.
##
## The mouth opens on each voice blip (talk()) and closes by itself, so the
## portrait reads as "this one is speaking" even with the voice off.

const ART_DIR: String = "res://game/ui/art/portraits/"
## Speaker name (as written in the .dialogue files) -> look.
const LOOKS: Dictionary = {
	"Director Hale": {"id": "hale", "skin": Color("d6a682"), "hair": Color("a9aba6"), "body": Color("262c31"),
		"trim": Color("ece6d3"), "tie": Color("b0432f"), "kind": "suit"},
	"Surveyor": {"id": "surveyor", "skin": Color("c79270"), "hair": Color("3b2a22"), "body": Color("55603f"),
		"trim": Color("8f9a6a"), "tie": Color("6fa6e6"), "kind": "hood"},
	"Contractor": {"id": "contractor", "skin": Color("b98563"), "hair": Color("2d3236"), "body": Color("3d4a44"),
		"trim": Color("6b7a70"), "tie": Color("f2b23a"), "kind": "helmet"},
}

var speaker: String = "":
	set(value):
		speaker = value
		_art = null
		var look: Dictionary = LOOKS.get(value, {})
		if not look.is_empty():
			var path: String = ART_DIR + String(look["id"]) + ".png"
			if ResourceLoader.exists(path):
				_art = load(path) as Texture2D
		queue_redraw()
## Frame and scanlines behind the face (off in the HUD, which has no panels).
var framed: bool = true
var _art: Texture2D
var _mouth: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(96, 96)
	resized.connect(queue_redraw)


## Opens the mouth for a moment (called on each voice blip).
func talk() -> void:
	_mouth = 1.0
	queue_redraw()


## Which look a speaker gets: its id in LOOKS, or "unknown".
static func look_id(name: String) -> String:
	return String(LOOKS.get(name, {}).get("id", "unknown"))


func _process(delta: float) -> void:
	if _mouth > 0.0:
		_mouth = maxf(0.0, _mouth - delta * 9.0)
		queue_redraw()


func _draw() -> void:
	var side: float = minf(size.x, size.y)
	var origin := (size - Vector2(side, side)) * 0.5
	var k: float = side / 100.0  # the drawing is designed on a 100 x 100 grid
	if framed:
		draw_rect(Rect2(origin, Vector2(side, side)), UiTheme.PANEL_RAISED)
		for y in range(0, int(side), maxi(2, int(4 * k))):
			draw_line(origin + Vector2(0, y), origin + Vector2(side, y), Color(1, 1, 1, 0.035), 1.0)
	if _art != null:
		draw_texture_rect(_art, Rect2(origin, Vector2(side, side)), false)
	else:
		var look: Dictionary = LOOKS.get(speaker, {})
		if look.is_empty():
			_draw_unknown(origin, k)
		else:
			_draw_bust(look, origin, k)
	if framed:
		draw_rect(Rect2(origin, Vector2(side, side)), UiTheme.LINE, false, maxf(1.0, k))


func _p(origin: Vector2, k: float, x: float, y: float) -> Vector2:
	return origin + Vector2(x, y) * k


func _poly(origin: Vector2, k: float, pts: Array, color: Color) -> void:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(origin + p * k)
	draw_colored_polygon(out, color)


func _ellipse(center: Vector2, rx: float, ry: float, color: Color, segments: int = 28) -> void:
	var pts := PackedVector2Array()
	for i in segments:
		var a: float = TAU * i / segments
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)


## Head and shoulders: body by kind (suit, hood, helmet), then the face.
func _draw_bust(look: Dictionary, o: Vector2, k: float) -> void:
	var skin: Color = look["skin"]
	var hair: Color = look["hair"]
	var body: Color = look["body"]
	var kind: String = look["kind"]
	# Shoulders.
	_poly(o, k, [Vector2(6, 100), Vector2(12, 80), Vector2(30, 70), Vector2(70, 70), Vector2(88, 80), Vector2(94, 100)], body)
	_poly(o, k, [Vector2(6, 100), Vector2(12, 80), Vector2(30, 70), Vector2(34, 72), Vector2(20, 84), Vector2(16, 100)], body.lightened(0.12))
	match kind:
		"suit":
			_poly(o, k, [Vector2(40, 70), Vector2(60, 70), Vector2(50, 90)], look["trim"])  # shirt
			_poly(o, k, [Vector2(47.5, 72), Vector2(52.5, 72), Vector2(54, 88), Vector2(50, 94), Vector2(46, 88)], look["tie"])
			_poly(o, k, [Vector2(30, 70), Vector2(40, 70), Vector2(50, 94), Vector2(38, 86)], body.lightened(0.18))  # lapels
			_poly(o, k, [Vector2(70, 70), Vector2(60, 70), Vector2(50, 94), Vector2(62, 86)], body.lightened(0.08))
		"hood":
			_poly(o, k, [Vector2(26, 74), Vector2(30, 34), Vector2(50, 18), Vector2(70, 34), Vector2(74, 74), Vector2(64, 70), Vector2(50, 78), Vector2(36, 70)], body.darkened(0.15))
			draw_line(_p(o, k, 44, 74), _p(o, k, 42, 96), look["trim"], 2.0 * k)  # hood strings
			draw_line(_p(o, k, 56, 74), _p(o, k, 58, 96), look["trim"], 2.0 * k)
		"helmet":
			_poly(o, k, [Vector2(30, 72), Vector2(70, 72), Vector2(74, 100), Vector2(26, 100)], body.darkened(0.2))  # vest
			draw_rect(Rect2(_p(o, k, 36, 80), Vector2(10, 8) * k), look["trim"])
			draw_rect(Rect2(_p(o, k, 54, 80), Vector2(10, 8) * k), look["trim"])
	# Neck and head (the shadow side is a darker half).
	draw_rect(Rect2(_p(o, k, 44, 56), Vector2(12, 16) * k), skin.darkened(0.25))
	_ellipse(_p(o, k, 50, 42), 15.0 * k, 19.0 * k, skin)
	_poly(o, k, [Vector2(57, 25), Vector2(64, 36), Vector2(64, 48), Vector2(58, 59), Vector2(52, 61), Vector2(58, 44)], skin.darkened(0.12))
	match kind:
		"suit":  # grey, slicked back, receding
			_poly(o, k, [Vector2(35, 40), Vector2(34, 30), Vector2(40, 22), Vector2(52, 20), Vector2(62, 24), Vector2(66, 32), Vector2(65, 41), Vector2(61, 31), Vector2(54, 28), Vector2(44, 29), Vector2(38, 34)], hair)
		"hood":
			_poly(o, k, [Vector2(35, 36), Vector2(40, 26), Vector2(50, 23), Vector2(60, 26), Vector2(65, 36), Vector2(58, 31), Vector2(42, 31)], hair)
			draw_rect(Rect2(_p(o, k, 36, 27), Vector2(28, 6) * k), Color("1d2629"))  # goggles up on the forehead
			draw_circle(_p(o, k, 43, 30), 3.5 * k, Color("6fa6e6").darkened(0.3))
			draw_circle(_p(o, k, 57, 30), 3.5 * k, Color("6fa6e6").darkened(0.3))
		"helmet":
			_poly(o, k, [Vector2(31, 38), Vector2(32, 26), Vector2(40, 18), Vector2(50, 16), Vector2(60, 18), Vector2(68, 26), Vector2(69, 38), Vector2(72, 40), Vector2(28, 40)], body.lightened(0.05))
			draw_line(_p(o, k, 28, 40), _p(o, k, 72, 40), body.darkened(0.3), 2.0 * k)
	# Eyes, brows, glasses for Hale.
	var eye := Color("151a1d")
	draw_rect(Rect2(_p(o, k, 41.5, 42), Vector2(4, 2.5) * k), eye)
	draw_rect(Rect2(_p(o, k, 54.5, 42), Vector2(4, 2.5) * k), eye)
	draw_line(_p(o, k, 40, 38.5), _p(o, k, 47, 38), hair.darkened(0.35), 1.6 * k)
	draw_line(_p(o, k, 53, 38), _p(o, k, 60, 38.5), hair.darkened(0.35), 1.6 * k)
	if kind == "suit":
		draw_rect(Rect2(_p(o, k, 38.5, 39.5), Vector2(10, 7) * k), eye, false, 1.6 * k)
		draw_rect(Rect2(_p(o, k, 51.5, 39.5), Vector2(10, 7) * k), eye, false, 1.6 * k)
		draw_line(_p(o, k, 48.5, 42), _p(o, k, 51.5, 42), eye, 1.4 * k)
	draw_line(_p(o, k, 50, 44), _p(o, k, 48.5, 50), skin.darkened(0.3), 1.4 * k)  # nose
	# Mouth: a line, an open oval while talking.
	if _mouth > 0.05:
		_ellipse(_p(o, k, 50, 54.5), 4.0 * k, (1.0 + 2.2 * _mouth) * k, Color("3a1f1c"), 16)
	else:
		draw_line(_p(o, k, 45.5, 54.5), _p(o, k, 54.5, 54), skin.darkened(0.45), 1.6 * k)


## Unknown voice on the radio: a dark silhouette over static.
func _draw_unknown(o: Vector2, k: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(speaker)
	for i in 40:
		var y: float = rng.randf_range(4, 96)
		var x: float = rng.randf_range(4, 80)
		draw_line(_p(o, k, x, y), _p(o, k, x + rng.randf_range(4, 16), y), Color(UiTheme.TEXT_MUTED, 0.18), 1.0)
	var shade := Color("0b1418")
	_poly(o, k, [Vector2(10, 100), Vector2(16, 80), Vector2(32, 70), Vector2(68, 70), Vector2(84, 80), Vector2(90, 100)], shade)
	_ellipse(_p(o, k, 50, 42), 15.0 * k, 19.0 * k, shade)
	var font: Font = UiTheme.heading_font()
	draw_string(font, _p(o, k, 50, 52) - Vector2(8, 0) * k, "?", HORIZONTAL_ALIGNMENT_CENTER, 16.0 * k, int(26 * k), UiTheme.TEXT_MUTED)
