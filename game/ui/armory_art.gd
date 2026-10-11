extends RefCounted
## Original monochrome UI symbols, rasterised from SVG through UiTheme.
## Kept separate from input icons, which follow the player's platform.

const TARGET := "<circle cx='24' cy='24' r='15'/><path d='M24 3v12m0 18v12M3 24h12m18 0h12'/><circle cx='24' cy='24' r='3'/>"
const SHIELD := "<path d='M24 5l15 6v13c0 10-15 19-15 19S9 34 9 24V11z'/><path d='M24 12l8 4v9c0 5-8 11-8 11s-8-6-8-11v-9z'/>"
const BURST := "<path d='M24 3l4 15 12-9-6 15 12 4-14 4 4 12-12-9-12 9 4-12-14-4 12-4L8 9l12 9z'/>"
const BULLETS := "<path d='M8 39V18l4-11 4 11v21zm12 0V18l4-11 4 11v21zm12 0V18l4-11 4 11v21z'/><path d='M8 30h8m4 0h8m4 0h8'/>"
const RUNNER := "<circle cx='30' cy='8' r='4'/><path d='M15 15l10-2 8 11 8 1M25 14l-7 13-8 9m9-9 11 7-5 9M18 18l-9 5'/>"
const PACK := "<rect x='10' y='14' width='28' height='29' rx='5'/><path d='M17 14V8h14v6M10 26h28M18 32h12v6H18z'/>"
const CROSS := "<path d='M18 5h12v13h13v12H30v13H18V30H5V18h13z'/>"
const CHAIN := "<path d='M19 28l10-10m-13 3-3 3a9 9 0 0 0 12 12l3-3m4-6 3-3a9 9 0 0 0-12-12l-3 3'/>"
const GRENADE := "<path d='M18 10h12v7l8 10-3 15H13l-3-15 8-10zM17 5h17l5 7M11 27h26M24 18v23'/>"
const BINOCULARS := "<path d='M9 12h10l3 24H4zm20 0h10l5 24H26zM19 22h10'/><circle cx='13' cy='36' r='9'/><circle cx='35' cy='36' r='9'/>"
const CAN := "<path d='M14 10h20v33H14zM19 10V5h10v5M14 17h20M19 27h10v10H19z'/>"
const RIFLE := "<path d='M3 24h9l5-5h20v-4h3v9h5v4H29l-3 10h-6l2-10h-8l-4 6H3zM19 20v-6h10v5'/>"
const MACHINE_GUN := "<path d='M3 21h9l4-4h24v6h6v3H29v13H18V27h-6l-5 7H3zM18 17V12h14v5M35 26l6 15m-6-15-5 15'/><path d='M20 30h6m-6 5h6'/>"
const MARKSMAN := "<path d='M3 24l11-3h17v-3h3v5h12v3H26l-3 9h-5l2-9h-7l-8 6H3zM18 15h12v5H18z'/>"
const SHOTGUN := "<path d='M3 21h12l5-3h26v5H28v5H16l-8 7H3zM31 18v9h10v-9'/><path d='M16 24h12'/>"


static func icon(id: StringName, size: int = 40) -> Texture2D:
	var bodies: Dictionary = {
		&"combat": TARGET, &"survival": SHIELD, &"breaker": BURST,
		&"head_hunter": TARGET, &"body_count": BULLETS, &"steady_grip": TARGET,
		&"skirmisher": RUNNER, &"opening_volley": BULLETS, &"kill_chain": CHAIN,
		&"thick_skin": SHIELD, &"fleet_footed": RUNNER, &"pack_rat": PACK,
		&"quick_draw": RIFLE, &"trail_rations": CAN, &"surveyor": BINOCULARS,
		&"long_breaker": BURST, &"crowd_anchor": SHIELD, &"recovery": CROSS,
		&"heavy_impact": BURST, &"demolitions": GRENADE, &"concussion_blast": BURST,
		&"bulwark": SHIELD, &"intimidating_cry": BURST, &"grenade": GRENADE,
		&"war_cry": SHIELD, &"rifle": RIFLE, &"machine_gun": MACHINE_GUN,
		&"smg": RIFLE, &"shotgun": SHOTGUN, &"marksman": MARKSMAN,
	}
	var body: String = bodies.get(id, TARGET)
	return UiTheme._icon("armory_%s_%d" % [id, size], "<g transform='scale(%f)' fill='none' stroke='#fff' stroke-width='2.4' stroke-linecap='round' stroke-linejoin='round'>%s</g>" % [size / 48.0, body], size, size)


static func image(id: StringName, size: int, color: Color = UiTheme.TEXT) -> TextureRect:
	var image := TextureRect.new()
	image.texture = icon(id, size)
	image.custom_minimum_size = Vector2(size, size)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.modulate = color
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image


static func tile() -> Texture2D:
	return UiTheme._icon("armory_azulejo", "<rect width='36' height='36' fill='#ece6d3'/><g fill='#27546c'><path d='M18 3l4 10-4 5-4-5zm15 15-10 4-5-4 5-4zM18 33l-4-10 4-5 4 5zM3 18l10-4 5 4-5 4z'/><path d='M2 2h8v2H4v6H2zm24 0h8v8h-2V4h-6zM2 26h2v6h6v2H2zm30 0h2v8h-8v-2h6z'/></g>", 36, 36)
