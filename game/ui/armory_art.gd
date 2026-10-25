extends RefCounted
## Original monochrome UI symbols for the Armory, drawn here as SVG and
## rasterised through UiTheme (no third-party icon set, so no licence to
## track). White shapes on transparency: tint them with `modulate`.
## Kept separate from input icons, which follow the player's platform.

const SB := "fill='none' stroke='#fff' stroke-linecap='round' stroke-linejoin='round'"
const S := SB + " stroke-width='3.2'"
const S_BOLD := "fill='none' stroke='#fff' stroke-width='5' stroke-linecap='round' stroke-linejoin='round'"
const F := "fill='#fff'"
const FE := "fill='#fff' fill-rule='evenodd'"

# --- 48 x 48 symbols ------------------------------------------------------------
const CROSSHAIR := "<g " + S + "><circle cx='24' cy='24' r='14'/><path d='M24 3v11M24 34v11M3 24h11M34 24h11'/></g><circle " + F + " cx='24' cy='24' r='3.5'/>"
const SKULL_SIGHT := "<g " + S + "><circle cx='24' cy='24' r='18'/><path d='M24 1v8M24 39v8M1 24h8M39 24h8'/></g><path " + FE + " d='M24 12.5c-6.3 0-10.5 4.3-10.5 9.8 0 3.1 1.4 5.4 3.4 6.8V34h3.4v-2.6h2.3V34h2.8v-2.6h2.3V34h3.4v-4.9c2-1.4 3.4-3.7 3.4-6.8 0-5.5-4.2-9.8-10.5-9.8zM19.4 19.8a2.9 2.9 0 1 0 0 5.8a2.9 2.9 0 1 0 0-5.8zM28.6 19.8a2.9 2.9 0 1 0 0 5.8a2.9 2.9 0 1 0 0-5.8zM24 25.6l-1.7 3h3.4z'/>"
const BULLETS := "<path " + FE + " d='M8 43V25c0-6 2.6-11 4.5-14.5C14.4 14 17 19 17 25v18zM8 30h9v2H8zM19.5 43V25c0-6 2.6-11 4.5-14.5C25.9 14 28.5 19 28.5 25v18zM19.5 30h9v2h-9zM31 43V25c0-6 2.6-11 4.5-14.5C37.4 14 40 19 40 25v18zM31 30h9v2h-9z'/>"
const VOLLEY := "<path " + FE + " d='M4 44V27c0-5 2-9 3.5-12C9 18 11 22 11 27v17zM4 32h7v2H4zM14 44V27c0-5 2-9 3.5-12 1.5 3 3.5 7 3.5 12v17zM14 32h7v2h-7zM24 44V27c0-5 2-9 3.5-12 1.5 3 3.5 7 3.5 12v17zM24 32h7v2h-7zM34 44V27c0-5 2-9 3.5-12 1.5 3 3.5 7 3.5 12v17zM34 32h7v2h-7z'/><g " + SB + " stroke-width='2.6'><path d='M7.5 9V4M17.5 9V3M27.5 9V3M37.5 9V4'/></g>"
const RUNNER := "<circle " + F + " cx='31' cy='8' r='4.6'/><g " + S_BOLD + "><path d='M28 16l-6 12M22 28l-8 3-4 8M22 28l8 6-1 9M27 17l6 6 6-1M27 17l-8 1-4 6'/></g>"
const FLEET := "<g transform='translate(4 0)'>" + RUNNER + "</g><g " + SB + " stroke-width='2.6'><path d='M2 16h9M4 23h8M2 30h7'/></g>"
const SHIELD := "<path " + FE + " d='M24 3l17 6.5V22c0 11.5-8 18.5-17 23C15 40.5 7 33.5 7 22V9.5zM24 8.3L11.5 13v9c0 9 6 14.6 12.5 18.3C30.5 36.6 36.5 31 36.5 22v-9z'/><path " + F + " d='M24 12.5l-9 3.5v6c0 7 4.3 11.5 9 14.5z'/>"
const SHIELD_LINE := "<path " + S + " d='M24 4l16 6v12c0 11-8 18-16 22C16 40 8 33 8 22V10z'/>"
const BURST := "<path " + F + " d='M24 2l4.2 14.5L40 7l-5.8 15.2L47 25l-13.6 4.3L38 42l-12-8.6L24 47l-2-13.6L10 42l4.6-12.7L1 25l12.8-2.8L8 7l11.8 9.5z'/>"
const BURST_LINE := "<path " + SB + " stroke-width='2.8' d='M24 4l3.8 13L38 9l-5 13.5L45 25l-12.2 3.6L37 40l-10.6-7.4L24 45l-2.4-12.4L11 40l4.2-11.4L3 25l12-2.5L10 9l10.2 8z'/>"
const IMPACT := "<g transform='translate(6 0) scale(0.75)'>" + BURST + "</g><g " + S + "><path d='M4 44h40M8 40l-4-4M40 40l4-4'/></g>"
const RAM := "<g transform='rotate(-32 24 24)'><path " + FE + " d='M1 19h29v10H1zM8 19h2.4v10H8zM18 19h2.4v10H18z'/><path " + F + " d='M31 15.5h9l4 3.5v10l-4 3.5h-9z'/></g><g " + SB + " stroke-width='2.6'><path d='M41 5l3-3M45 12l3-.5M35 3l.5-3'/></g>"
const ANCHOR := "<g " + S + "><circle cx='24' cy='7.5' r='4'/><path d='M24 11.5V44M15 18h18M8 29c1 8.5 7.5 15 16 15s15-6.5 16-15'/><path d='M4 33l4-4.5 4.5 4M35.5 32.5l4.5-4 4 4.5'/></g>"
const CROSS := "<path " + F + " d='M18 5h12v13h13v12H30v13H18V30H5V18h13z'/>"
const DYNAMITE := "<g transform='rotate(-24 24 27)'><path " + FE + " d='M8 16h9v28H8zM8 31h9v2.2H8zM19.5 16h9v28h-9zM19.5 31h9v2.2h-9zM31 16h9v28h-9zM31 31h9v2.2h-9z'/></g><path " + SB + " stroke-width='2.6' d='M23 14c1-6 6-9 11-8'/><path " + F + " d='M38 1l1.7 4 4 1.7-4 1.7L38 12.4l-1.7-4-4-1.7 4-1.7z'/>"
const GRENADE := "<path " + FE + " d='M24 14c-8 0-13 6.5-13 14.5S16 45 24 45s13-8.5 13-16.5S32 14 24 14zM14 25.5h20v2H14zM13.5 33.5h21v2h-21zM22.8 17.5h2.4v24.5h-2.4z'/><path " + F + " d='M19 8h10v5H19z'/><path " + SB + " stroke-width='2.6' d='M29 10c5 0 8 3 8 8'/><circle " + SB + " stroke-width='2.4' cx='14.5' cy='9.5' r='3.5'/>"
const BULWARK := "<path " + FE + " d='M9 4h30v21c0 10-7.5 16.5-15 20C16.5 41.5 9 35 9 25zM22 11h4v8h8v4h-8v11h-4V23h-8v-4h8z'/>"
const MEGAPHONE := "<path " + F + " d='M5 19h8l17-10v30L13 29H5z'/><path " + F + " d='M10 30h6.5l3.5 10h-6.5z'/><g " + S + "><path d='M35 18c2.7 2.5 2.7 9.5 0 12M40 13c5.3 4.5 5.3 17.5 0 22'/></g>"
const CHAIN := "<g " + SB + " stroke-width='4.2'><rect x='5' y='25' width='24' height='12' rx='6' transform='rotate(-45 17 31)'/><rect x='19' y='11' width='24' height='12' rx='6' transform='rotate(-45 31 17)'/></g>"
const PACK := "<path " + FE + " d='M15 13c0-4 3-7 6.5-7h5c3.5 0 6.5 3 6.5 7v1.2c3.3 1.2 5.5 4.3 5.5 7.8v19c0 2-1.2 3-3 3H12.5c-1.8 0-3-1-3-3V22c0-3.5 2.2-6.6 5.5-7.8zM19.2 13.6h9.6c-.2-2.2-1.6-3.4-3.3-3.4h-3c-1.7 0-3.1 1.2-3.3 3.4zM14 21h20v2H14zM15 27h18v12H15z'/><path " + F + " d='M18 30h12v6H18z'/>"
const PISTOL := "<path " + F + " d='M4 13h39v9H29l-1.5 3.2h-7L17.5 39c-.3 1.3-1.3 2-2.6 2H8.6c-1.6 0-2.6-1.5-2.2-3L10 22H4z'/><path " + SB + " stroke-width='2.6' d='M20.5 25c-.5 4 1.5 6.5 5 6.5'/><g " + SB + " stroke-width='2.4'><path d='M33 29h10M36 34h8'/></g>"
const CAN := "<path " + FE + " d='M11 11c0-3.2 5.8-5.5 13-5.5S37 7.8 37 11v27c0 3.2-5.8 5.5-13 5.5S11 41.2 11 38zM11 16.5c0 3.2 5.8 5.5 13 5.5s13-2.3 13-5.5v2.2c0 3.2-5.8 5.5-13 5.5s-13-2.3-13-5.5zM16 28h16v9H16z'/><path " + F + " d='M19 30.5h10v4H19z'/>"
const BINOCULARS := "<path " + F + " d='M8 15c0-3.3 2.2-5.5 5.5-5.5h3c2.2 0 3.5 1.3 3.5 3.5v6.5h8V13c0-2.2 1.3-3.5 3.5-3.5h3c3.3 0 5.5 2.2 5.5 5.5l4.5 14H29.5l-1.5-5.5h-8L18.5 29H3.5z'/><path " + FE + " d='M12.5 26a9.5 9.5 0 1 0 0 19a9.5 9.5 0 1 0 0-19zM12.5 30.5a5 5 0 1 0 0 10a5 5 0 1 0 0-10zM35.5 26a9.5 9.5 0 1 0 0 19a9.5 9.5 0 1 0 0-19zM35.5 30.5a5 5 0 1 0 0 10a5 5 0 1 0 0-10z'/>"
const FOLDER := "<path " + F + " d='M4 11c0-1.7 1.3-3 3-3h11l4 4h19c1.7 0 3 1.3 3 3v3H4z'/><path " + F + " d='M3 21h42l-3.4 18c-.3 1.7-1.7 3-3.4 3H9.8c-1.7 0-3.1-1.3-3.4-3z'/>"
const HOME := "<path " + F + " d='M24 5L3 24h6.5v19H21V32h6v11h11.5V24H45z'/>"
const PLUS := "<path " + SB + " stroke-width='3.6' d='M24 9v30M9 24h30'/>"
const UPGRADE := "<g " + SB + " stroke-width='4.4'><path d='M11 24l13-11 13 11M11 37l13-11 13 11'/></g>"
const CRATE := "<g " + S + "><path d='M6 13h36v24H6zM6 21h36M6 29h36M24 13v24'/></g>"

# --- 120 x 40 weapon silhouettes (side view, muzzle to the right) --------------
const W_RIFLE := "<path " + F + " d='M2 15h15l8 3.5V27h-6l-10 8H3.5l4-9.5H2z'/><path " + F + " d='M24 13.5h43v12H24zM67 15h26v8H67zM93 17.3h20v3.2H93zM111 15.8h7v6.2h-7z'/><path " + F + " d='M47 25.5h9.5l4 12.5H52zM31 25.5h7.5l-3 11H28z'/><path " + F + " d='M35 8h20v3H35zM37 8h3v6h-3zM87 9h3v6h-3z'/>"
const W_MACHINE_GUN := "<path " + F + " d='M2 13h16l7 4v9h-6l-12 6.5H3.5l2.5-8.5H2z'/><path " + F + " d='M25 12h42v13H25zM67 14.5h30v8H67zM97 17h18v3.4H97zM113 15h6v7.4h-6z'/><path " + F + " d='M38 25h15v10H38zM58 25h7.5l-3 10.5H55z'/><path " + F + " d='M28 7.5h26v4H28zM71 8h12v2.6H71zM71 8h2.6v6.5H71zM80.4 8h2.6v6.5h-2.6z'/><g " + SB + " stroke-width='2.6'><path d='M92 22l-7 16M95 22l6 16'/></g>"
const W_MARKSMAN := "<path " + F + " d='M2 17h19l7 3v7h-8L8 34H3.5l3.5-8.5H2z'/><path " + F + " d='M28 16.5h34v10H28zM62 18h26v7H62zM88 19.6h26v2.8H88zM112 18.4h7v5.2h-7z'/><path " + F + " d='M35 26.5h7.5l-3 9.5H32zM48 26.5h8v6h-8z'/><path " + F + " d='M36 7h30a3 3 0 0 1 0 6H36a3 3 0 0 1 0-6zM31 5.5h7a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2h-7zM63 5.5h7v11h-7a2 2 0 0 1-2-2v-7a2 2 0 0 1 2-2zM42 12h3v5h-3zM57 12h3v5h-3z'/>"
const W_SHOTGUN := "<path " + F + " d='M2 16h20l7 3.5V26h-8L9 34H3.5l3.5-9H2z'/><path " + F + " d='M28 15h25v11H28zM53 15.5h64v4.4H53zM53 21.5h50v4H53zM66 20h26v8.5H66z'/><path " + F + " d='M33 26h7.5l-3 10H30z'/><path " + F + " d='M112 13h3v3h-3z'/>"
const W_SMG := "<path " + F + " d='M6 16h14v3.4H9.4v6.2H20V29H6z'/><path " + F + " d='M20 14.5h42v11H20zM62 17.5h22v4.6H62zM82 16.5h6v6.6h-6z'/><path " + F + " d='M42 25.5h8v15h-8zM27 25.5h7.5l-3 11H24z'/><path " + F + " d='M24 10.5h7v4h-7zM53 10.5h5v4h-5z'/>"


static func icon(id: StringName, size: int = 40) -> Texture2D:
	var bodies: Dictionary = {
		&"combat": CROSSHAIR, &"survival": SHIELD_LINE, &"breaker": BURST_LINE,
		&"head_hunter": SKULL_SIGHT, &"body_count": BULLETS, &"steady_grip": CROSSHAIR,
		&"skirmisher": RUNNER, &"opening_volley": VOLLEY, &"kill_chain": CHAIN,
		&"thick_skin": SHIELD, &"fleet_footed": FLEET, &"pack_rat": PACK,
		&"quick_draw": PISTOL, &"trail_rations": CAN, &"surveyor": BINOCULARS,
		&"long_breaker": RAM, &"crowd_anchor": ANCHOR, &"recovery": CROSS,
		&"heavy_impact": IMPACT, &"demolitions": DYNAMITE, &"concussion_blast": GRENADE,
		&"bulwark": BULWARK, &"intimidating_cry": MEGAPHONE, &"grenade": GRENADE,
		&"war_cry": MEGAPHONE, &"folder": FOLDER, &"home": HOME, &"plus": PLUS,
		&"upgrade": UPGRADE,
		&"logistics": CRATE, &"supply_run": CRATE, &"quick_hands": RUNNER, &"archivist": FOLDER,
		&"resupply_drop": BULLETS, &"first_find": PLUS, &"spare_rerolls": UPGRADE,
	}
	if WEAPONS.has(id):
		return weapon(id, size * 3, size)
	var body: String = bodies.get(id, CROSSHAIR)
	return UiTheme._icon("armory_%s_%d" % [id, size], "<g transform='scale(%f)'>%s</g>" % [size / 48.0, body], size, size)


const WEAPONS: Dictionary = {
	&"rifle": W_RIFLE, &"machine_gun": W_MACHINE_GUN, &"marksman": W_MARKSMAN,
	&"shotgun": W_SHOTGUN, &"smg": W_SMG,
}


## Side silhouette of a weapon, `width` x `height` (drawn on a 120 x 40 grid).
static func weapon(id: StringName, width: int = 120, height: int = 40) -> Texture2D:
	var body: String = WEAPONS.get(id, W_RIFLE)
	var k: float = minf(width / 120.0, height / 40.0)
	var offset := Vector2((width - 120.0 * k) * 0.5, (height - 40.0 * k) * 0.5)
	return UiTheme._icon("armory_weapon_%s_%dx%d" % [id, width, height],
		"<g transform='translate(%f %f) scale(%f)'>%s</g>" % [offset.x, offset.y, k, body], width, height)


static func image(id: StringName, size: int, color: Color = UiTheme.TEXT) -> TextureRect:
	var image := TextureRect.new()
	image.texture = icon(id, size)
	image.custom_minimum_size = Vector2(size, size)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.modulate = color
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image


## A weapon silhouette as a TextureRect, tinted.
static func weapon_image(id: StringName, width: int, height: int, color: Color = UiTheme.TEXT) -> TextureRect:
	var image := TextureRect.new()
	image.texture = weapon(id, width, height)
	image.custom_minimum_size = Vector2(width, height)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.modulate = color
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image


## Portuguese azulejo motif (original drawing): cobalt on lime-wash, a
## four-petal flower with quarter rosettes in the corners, so tiles repeat.
static func tile(size: int = 36) -> Texture2D:
	var petals: String = ""
	for angle in [0, 90, 180, 270]:
		petals += "<ellipse cx='18' cy='9.6' rx='3.6' ry='6.4' transform='rotate(%d 18 18)'/>" % angle
		petals += "<ellipse cx='18' cy='7.2' rx='1.6' ry='3.4' transform='rotate(%d 18 18)'/>" % (angle + 45)
	var corners: String = "<path d='M0 0h8a8 8 0 0 1-8 8zM36 0v8a8 8 0 0 1-8-8zM36 36h-8a8 8 0 0 1 8-8zM0 36v-8a8 8 0 0 1 8 8z'/>"
	var body: String = "<rect width='36' height='36' fill='#e8e2cf'/><g fill='#21508a'>%s%s</g>" % [petals, corners] \
		+ "<circle cx='18' cy='18' r='3.4' fill='#e8e2cf'/><circle cx='18' cy='18' r='1.7' fill='#21508a'/>" \
		+ "<g fill='none' stroke='#21508a' stroke-width='0.9'><circle cx='18' cy='18' r='12.6'/><rect x='0.6' y='0.6' width='34.8' height='34.8'/></g>" \
		+ "<g fill='#6f95c4'><circle cx='18' cy='1.8' r='1'/><circle cx='18' cy='34.2' r='1'/><circle cx='1.8' cy='18' r='1'/><circle cx='34.2' cy='18' r='1'/></g>"
	return UiTheme._icon("armory_azulejo_%d" % size, "<g transform='scale(%f)'>%s</g>" % [size / 36.0, body], size, size)
