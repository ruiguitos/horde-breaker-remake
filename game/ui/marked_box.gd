class_name MarkedBox
extends StyleBox
## A panel/button box that can also be dashed and carry a small mark (a tick
## or a padlock texture). It wraps a StyleBoxFlat for the fill and rounded
## corners and draws the extras on top, so the states differ by shape and not
## only by colour: SELECTED = tick, DISABLED = dashed outline, LOCKED = dashed
## outline + padlock. Build it through UiTheme, which calls sync_margins().

enum Place { AUTO, LEFT, TOP_RIGHT }
## AUTO uses LEFT on boxes up to this height and TOP_RIGHT on taller ones
## (cards whose content would sit under a centred mark).
const AUTO_CARD_HEIGHT := 72.0

## Fill, rounded corners and solid border; its content margins are reused.
@export var base: StyleBoxFlat
@export var dashed: bool = false
@export var dash_color: Color = Color("2a5662")
@export var dash_width: float = 2.0
@export var dash_length: float = 8.0
@export var dash_gap: float = 5.0
## White icon tinted with mark_color; null = no mark.
@export var mark_texture: Texture2D
@export var mark_color: Color = Color("7fc8b8")
@export var mark_size: float = 18.0
## Colour of the mark inside the TOP_RIGHT badge disc.
@export var badge_ink: Color = Color("0d1216")
## LEFT: vertically centred before the text (buttons, list rows). TOP_RIGHT:
## a badge on the top-right corner (cards and panels). AUTO: LEFT for short boxes, TOP_RIGHT
## for tall ones.
@export var place: Place = Place.AUTO


func _init(p_base: StyleBoxFlat = null) -> void:
	base = p_base if p_base != null else StyleBoxFlat.new()


## Copies the base's content margins; a LEFT mark gets room on both sides so
## centred text stays centred.
func sync_margins() -> void:
	var extra: float = mark_size + 8.0 if mark_texture != null and place != Place.TOP_RIGHT else 0.0
	content_margin_left = base.content_margin_left + extra
	content_margin_right = base.content_margin_right + extra
	content_margin_top = base.content_margin_top
	content_margin_bottom = base.content_margin_bottom


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	base.draw(to_canvas_item, rect)
	if dashed:
		draw_dashed_rect(to_canvas_item, rect, dash_color, dash_width, dash_length, dash_gap)
	if mark_texture == null:
		return
	var size := Vector2.ONE * mark_size
	var left: bool = place == Place.LEFT or (place == Place.AUTO and rect.size.y <= AUTO_CARD_HEIGHT)
	if left:
		var at := Vector2(rect.position.x + base.content_margin_left, rect.get_center().y - mark_size * 0.5)
		RenderingServer.canvas_item_add_texture_rect(to_canvas_item, Rect2(at, size), mark_texture.get_rid(), false, mark_color)
		return
	# Corner badge: a filled disc sitting on the top border, half outside the
	# box, so the card's own content (art, text) cannot hide it.
	var center := Vector2(rect.end.x - mark_size - 4.0, rect.position.y)
	RenderingServer.canvas_item_add_circle(to_canvas_item, center, mark_size * 0.75, mark_color, true)
	RenderingServer.canvas_item_add_texture_rect(to_canvas_item, Rect2(center - size * 0.5, size), mark_texture.get_rid(), false, badge_ink)


## Dashed outline along the inside of `rect`. Also usable from a Control's
## _draw(): MarkedBox.draw_dashed_rect(get_canvas_item(), rect, color).
static func draw_dashed_rect(ci: RID, rect: Rect2, color: Color, width: float = 2.0, dash: float = 8.0, gap: float = 5.0) -> void:
	var r := rect
	_dash_line(ci, r.position, Vector2(r.end.x, r.position.y), color, width, dash, gap)
	_dash_line(ci, Vector2(r.position.x, r.end.y - width), Vector2(r.end.x, r.end.y - width), color, width, dash, gap)
	_dash_line(ci, r.position, Vector2(r.position.x, r.end.y), color, width, dash, gap)
	_dash_line(ci, Vector2(r.end.x - width, r.position.y), Vector2(r.end.x - width, r.end.y), color, width, dash, gap)


static func _dash_line(ci: RID, from: Vector2, to: Vector2, color: Color, width: float, dash: float, gap: float) -> void:
	var horizontal: bool = is_equal_approx(from.y, to.y)
	var total: float = (to.x - from.x) if horizontal else (to.y - from.y)
	var d: float = 0.0
	while d < total:
		var piece: float = minf(dash, total - d)
		var rect := Rect2(from.x + d, from.y, piece, width) if horizontal else Rect2(from.x, from.y + d, width, piece)
		RenderingServer.canvas_item_add_rect(ci, rect, color)
		d += dash + gap
