extends SceneTree
## The optional asset-browser client must not start from a global editor preference.
## The project must explicitly opt in; malformed project settings remain off.

const POLICY_PATH: String = "res://addons/assets2godot/project_policy.gd"
const CLIENT_SETTING: String = "assets2godot/allow_blendkit_client"


func _initialize() -> void:
	if not FileAccess.file_exists(POLICY_PATH):
		print("TEST FAIL: asset browser project client policy is missing")
		quit(1)
		return
	var policy: Variant = load(POLICY_PATH)
	var connection_script: Script = load("res://addons/assets2godot/client_connection.gd")
	if connection_script == null or not connection_script.can_instantiate():
		print("TEST FAIL: asset browser client script could not compile")
		quit(1)
		return
	var previous: Variant = ProjectSettings.get_setting(CLIENT_SETTING)
	var failures: int = 0
	ProjectSettings.set_setting(CLIENT_SETTING, null)
	if policy.allows_client(true):
		print("TEST FAIL: missing project permission started the optional client")
		failures += 1
	ProjectSettings.set_setting(CLIENT_SETTING, false)
	if policy.allows_client(true):
		print("TEST FAIL: a global editor preference bypassed the project policy")
		failures += 1
	ProjectSettings.set_setting(CLIENT_SETTING, "false")
	if policy.allows_client(true):
		print("TEST FAIL: malformed project permission enabled the optional client")
		failures += 1
	ProjectSettings.set_setting(CLIENT_SETTING, true)
	if not policy.allows_client(true) or policy.allows_client(false):
		print("TEST FAIL: the client requires both project permission and editor request")
		failures += 1
	ProjectSettings.set_setting(CLIENT_SETTING, previous)
	if failures == 0:
		print("TEST: Assets2Godot optional client respects explicit project permission")
	quit(0 if failures == 0 else 1)
