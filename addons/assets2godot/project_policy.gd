@tool
extends RefCounted
## Project integration, 2026-11-14. GPL-2.0, like the containing addon.
## Editor preferences are shared across projects; they cannot authorize a
## helper download/process in this project without its own explicit opt-in.

const CLIENT_PERMISSION: String = "assets2godot/allow_blendkit_client"


static func allows_client(requested: bool) -> bool:
	var permission: Variant = ProjectSettings.get_setting(CLIENT_PERMISSION, false)
	return requested and permission is bool and permission == true
