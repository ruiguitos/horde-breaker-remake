class_name DevTestPanel
extends VBoxContainer
## DEV · TESTS (docs/design/DEV_MENU.md, zona 3): runs the test scripts from the
## title screen. Each test runs as its own run_all process with a filter, so the
## timeout, the classification and the Windows exit codes are the runner's own.
## Debug builds only. Stop kills the running test; leaving the panel stops it too.

const LOG_DIR: String = "user://dev_tests"
const RUNNER: String = "res://tests/run_all.gd"
const PASS_COLOR: Color = Color("6fbf8e")
const FAIL_COLOR: Color = Color("e0644f")
const RUN_COLOR: Color = Color("f2b23a")

var _rows: Dictionary = {}  ## test path -> {"check": CheckBox, "status": Label}
var _queue: Array[String] = []
var _pid: int = -1
var _current: String = ""
var _log_path: String = ""
var _passed: int = 0
var _failed: int = 0
var _done: int = 0
var _total: int = 0
var _summary: Label
var _filter: LineEdit
var _run_all: Button
var _run_selected: Button
var _stop: Button
var _list: VBoxContainer


## The test scripts run by the runner: tests/ and spikes/*/tests/, sorted.
static func discover() -> Array[String]:
	var found: Array[String] = []
	_tests_in("res://tests", found)
	var spikes := DirAccess.open("res://spikes")
	if spikes != null:
		var names := spikes.get_directories()
		names.sort()
		for spike_name: String in names:
			_tests_in("res://spikes/%s/tests" % spike_name, found)
	return found


static func _tests_in(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	var files := dir.get_files()
	files.sort()
	for file_name: String in files:
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			out.append("%s/%s" % [dir_path, file_name])


## The verdict the runner printed for `test_path` in `log_text`: "PASS", "FAIL",
## or "" when the log has no line for it (the run did not finish).
static func result_for(log_text: String, test_path: String) -> String:
	for raw: String in log_text.split("\n"):
		var line: String = raw.strip_edges()
		if line.contains(test_path) and (line.begins_with("PASS ") or line.begins_with("FAIL ")):
			return line.substr(0, 4)
	return ""


## Opens the test panel over `parent`, in a dialog like the title's other dev entries.
static func open(parent: Node) -> MenuDialog:
	var dialog := MenuDialog.new()
	parent.add_child(dialog)
	dialog.content.add_child(UiTheme.title("DEV · TESTS", 36))
	dialog.content.add_child(UiTheme.label("Development builds only. Each test runs as its own headless process, as in run_all.", 14, UiTheme.MUTED))
	dialog.content.add_child(DevTestPanel.new())
	return dialog


func _ready() -> void:
	name = "DevTests"
	add_theme_constant_override("separation", 8)
	var bar := HBoxContainer.new()
	add_child(bar)
	_filter = LineEdit.new()
	_filter.placeholder_text = "Filter by name"
	_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filter.text_changed.connect(func(_text: String) -> void: _apply_filter())
	bar.add_child(_filter)
	_run_all = UiTheme.button(self, "RUN ALL", _run_everything)
	_run_all.name = "RunAll"
	_run_selected = UiTheme.button(self, "RUN SELECTED", _run_checked)
	_run_selected.name = "RunSelected"
	_stop = UiTheme.button(self, "STOP", _stop_run)
	_stop.name = "Stop"
	_summary = UiTheme.label("", 13, UiTheme.MUTED)
	add_child(_summary)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 280
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	for path: String in discover():
		_add_row(path)
	_refresh_summary()


func _exit_tree() -> void:
	_kill_current()


func is_running() -> bool:
	return _pid != -1


func _add_row(path: String) -> void:
	var row := HBoxContainer.new()
	var check := CheckBox.new()
	check.button_pressed = true
	row.add_child(check)
	var label := Label.new()
	label.text = path.trim_prefix("res://")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	row.add_child(label)
	var status := Label.new()
	status.text = "Waiting"
	status.custom_minimum_size.x = 96
	status.add_theme_color_override("font_color", UiTheme.MUTED)
	row.add_child(status)
	_list.add_child(row)
	_rows[path] = {"check": check, "status": status, "label": label}


func _apply_filter() -> void:
	var needle: String = _filter.text.to_lower()
	for path: String in _rows:
		var row: Dictionary = _rows[path]
		(row["label"] as Label).get_parent().visible = needle.is_empty() or path.to_lower().contains(needle)


func _run_everything() -> void:
	var paths: Array[String] = []
	for path: String in _rows:
		paths.append(path)
	paths.sort()
	_start_queue(paths)


func _run_checked() -> void:
	var paths: Array[String] = []
	for path: String in _rows:
		var row: Dictionary = _rows[path]
		if (row["check"] as CheckBox).button_pressed:
			paths.append(path)
	paths.sort()
	_start_queue(paths)


func _start_queue(paths: Array[String]) -> void:
	if is_running() or paths.is_empty():
		return
	_queue = paths
	_passed = 0
	_failed = 0
	_done = 0
	_total = paths.size()
	for path: String in paths:
		_set_status(path, "Waiting", UiTheme.MUTED)
	_next()


func _next() -> void:
	if _queue.is_empty():
		_current = ""
		_refresh_summary()
		return
	_current = _queue.pop_front()
	_set_status(_current, "Running", RUN_COLOR)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LOG_DIR))
	_log_path = ProjectSettings.globalize_path("%s/%s.log" % [LOG_DIR, _current.trim_prefix("res://").replace("/", "__")])
	var args := PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--log-file", _log_path, "--script", RUNNER, "--", "--filter=" + _current,
	])
	_pid = OS.create_process(OS.get_executable_path(), args)
	if _pid == -1:
		_finish_current("FAIL")
		_next()  # the process could not start: move on, do not stall the queue
		return
	_refresh_summary()


func _process(_delta: float) -> void:
	if _pid == -1 or OS.is_process_running(_pid):
		return
	_pid = -1
	var log_text: String = FileAccess.get_file_as_string(_log_path)
	var verdict: String = result_for(log_text, _current)
	_finish_current(verdict if verdict != "" else "FAIL")
	_next()


func _finish_current(verdict: String) -> void:
	_done += 1
	if verdict == "PASS":
		_passed += 1
		_set_status(_current, "Passed", PASS_COLOR)
	else:
		_failed += 1
		_set_status(_current, "Failed", FAIL_COLOR)
	_refresh_summary()


func _stop_run() -> void:
	_queue.clear()
	if is_running():
		_kill_current()
		_set_status(_current, "Stopped", UiTheme.MUTED)
	_current = ""
	_refresh_summary()


func _kill_current() -> void:
	if _pid != -1:
		OS.kill(_pid)
		_pid = -1


func _set_status(path: String, text: String, color: Color) -> void:
	if not _rows.has(path):
		return
	var status: Label = _rows[path]["status"]
	status.text = text
	status.add_theme_color_override("font_color", color)


func _refresh_summary() -> void:
	if _total == 0:
		_summary.text = "%d test scripts found" % _rows.size()
	elif is_running() or not _queue.is_empty():
		_summary.text = "Running %d of %d · %d passed · %d failed" % [_done + 1, _total, _passed, _failed]
	else:
		_summary.text = "%d of %d done · %d passed · %d failed" % [_done, _total, _passed, _failed]
	_stop.disabled = not is_running() and _queue.is_empty()
	_run_all.disabled = is_running()
	_run_selected.disabled = is_running()

