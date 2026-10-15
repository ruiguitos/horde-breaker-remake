extends MenuDialog
## Runtime-loaded by MenuDialog; attribution text comes from assets/LICENSES.md.

var _panel: Control
var _credits_scroll: ScrollContainer


func _ready() -> void:
	super()
	name = "CreditsDialog"
	_panel = content.get_parent()
	_panel.name = "CreditsFrame"
	get_viewport().size_changed.connect(_size_panel)
	_size_panel()
	content.add_child(UiTheme.title("CREDITS", 36))
	content.add_child(UiTheme.label("HORDE BREAKER / PEOPLE, PLACES & TOOLS", 14, UiTheme.ACCENT, true))
	content.add_child(HSeparator.new())
	_credits_scroll = ScrollContainer.new()
	_credits_scroll.name = "CreditsContent"
	_credits_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_credits_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_credits_scroll.follow_focus = true
	content.add_child(_credits_scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	_credits_scroll.add_child(list)
	list.add_child(UiTheme.title("ISLAND MAPS", 24))
	var osm := UiTheme.label("© OpenStreetMap contributors", 18)
	osm.name = "OpenStreetMapCredit"
	list.add_child(osm)
	list.add_child(UiTheme.label("Berlenga coastlines, paths and building footprints. OpenStreetMap data is available under the Open Database License (ODbL 1.0).", 16, UiTheme.MUTED))
	_link(list, "OpenStreetMap / copyright & licence", "https://www.openstreetmap.org/copyright")
	list.add_child(UiTheme.label("Elevation: AWS Terrain Tiles / Mapzen, based on SRTM, EU-DEM and other open elevation sources.", 16, UiTheme.MUTED))
	list.add_child(HSeparator.new())
	list.add_child(UiTheme.title("NIGHT SKY", 24))
	var sky := UiTheme.label("The Milky Way panorama by ESO/S. Brunier, licensed under CC BY 4.0 and used in original and modified forms.", 18)
	sky.name = "MilkyWayCredit"
	list.add_child(sky)
	list.add_child(UiTheme.label("Sky3D uses the original panorama and a modified star field that keeps the brightest stars.", 16, UiTheme.MUTED))
	_link(list, "ESO / The Milky Way panorama", "https://www.eso.org/public/images/eso0932a/")
	_link(list, "Creative Commons Attribution 4.0", "https://creativecommons.org/licenses/by/4.0/")
	list.add_child(HSeparator.new())
	list.add_child(UiTheme.title("ART, ANIMATION & SOUND", 24))
	list.add_child(UiTheme.label("Quaternius / Stylized Nature MegaKit & Universal Animation Library / CC0\nPoly Haven / island textures & props / CC0\nOvani Sound / Sound FX Starter Pack Vol. 1 / royalty-free", 16))
	list.add_child(HSeparator.new())
	list.add_child(UiTheme.title("TYPEFACES", 24))
	list.add_child(UiTheme.label("Barlow & Barlow Condensed / The Barlow Project Authors (Jeremy Tribby)\nIBM Plex Mono / IBM Corp.\nBoth font families use the SIL Open Font License 1.1.", 16))
	list.add_child(HSeparator.new())
	list.add_child(UiTheme.title("TOOLS & TECHNOLOGY", 24))
	list.add_child(UiTheme.label("Godot Engine / Godot contributors / MIT\nTerrain3D / Cory Petkovsek & Roope Palmroos / MIT\nSky3D / Cory Petkovsek, J. Cuéllar & contributors / MIT\nPhantom Camera / Marcus Skov / MIT\nG.U.I.D.E / Jan Thomä / MIT\nYARD / Elliot Fontaine & contributors / MIT\nDialogue Manager / Nathan Hoad / MIT", 16))
	list.add_child(UiTheme.label("Third-party licence notices are included with their respective assets and tools.", 14, UiTheme.MUTED))
	var navigation := HBoxContainer.new()
	content.add_child(navigation)
	for direction in [-1, 1]:
		var b := UiTheme.button(navigation, "↑ READ ABOVE" if direction < 0 else "↓ READ BELOW", _read.bind(direction))
		b.name = "ScrollUp" if direction < 0 else "ScrollDown"
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 17)
		b.custom_minimum_size.y = 38
	var back := UiTheme.button(content, "BACK", close, true)
	back.name = "Back"
	back.custom_minimum_size.y = 40
	back.add_theme_font_size_override("font_size", 20)
	call_deferred("_focus_back")


func _size_panel() -> void:
	var available: Vector2 = get_viewport_rect().size - Vector2(32, 32)
	_panel.custom_minimum_size = Vector2(minf(860, available.x), minf(580, available.y))


func _link(parent: Control, text: String, url: String) -> void:
	var link := LinkButton.new()
	link.text = text
	link.set_meta("url", url)
	link.tooltip_text = url
	link.add_theme_font_size_override("font_size", 16)
	link.pressed.connect(func() -> void: OS.shell_open(url))
	parent.add_child(link)


func _read(direction: int) -> void:
	_credits_scroll.scroll_vertical += direction * maxi(1, int(_credits_scroll.size.y * 0.8))


func _focus_back() -> void:
	(find_child("Back", true, false) as Button).grab_focus()
