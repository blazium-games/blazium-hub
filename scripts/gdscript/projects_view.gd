extends VBoxContainer

const PROJECT_PANEL_SCENE: PackedScene = preload("res://scenes/views/project_panel.tscn")

@onready var project_list: VBoxContainer = %ProjectList
@onready var add_btn: Button = %AddProjectButton
@onready var scan_btn: Button = %ScanFolderButton
@onready var file_dialog: FileDialog = %ProjectFileDialog
@onready var scan_dialog: FileDialog = %ScanFileDialog
@onready var status: Label = %ProjectsStatus
@onready var filter_projects_line_edit: LineEdit = %FilterProjectsLineEdit


func _ready() -> void:
	add_btn.pressed.connect(_on_add)
	scan_btn.pressed.connect(_on_scan)
	file_dialog.file_selected.connect(_on_project_file_selected)
	scan_dialog.dir_selected.connect(_on_scan_dir_selected)
	filter_projects_line_edit.text_changed.connect(_update_projects_list)
	reload()


func _update_projects_list(_filter_text: String):
	_build_projects_list(_filter_text)


func reload() -> void:
	_build_projects_list(filter_projects_line_edit.text)


func _build_projects_list(filter_text: String) -> void:
	var query: String = filter_text.strip_edges().to_lower()
	var entries: Array[Dictionary] = []
	for p in HubState.projects_list:
		var entry: Dictionary = {}
		if typeof(p) == TYPE_DICTIONARY:
			entry = p.duplicate()
		else:
			entry["name"] = str(p)
			entry["path"] = str(p)
		var label: String = str(entry.get("name", ""))
		if not query.is_empty() and not label.to_lower().contains(query):
			continue
		entries.append(entry)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_fav: bool = HubSettings.is_favorite_project(str(a.get("path", "")))
		var b_fav: bool = HubSettings.is_favorite_project(str(b.get("path", "")))
		if a_fav == b_fav:
			return str(a.get("name", "")).to_lower() < str(b.get("name", "")).to_lower()
		return a_fav and not b_fav)
	for child in project_list.get_children():
		project_list.remove_child(child)
		child.queue_free()
	for entry in entries:
		var label: String = str(entry.get("name", ""))
		var path: String = str(entry.get("path", ""))
		var project_panel: ProjectPanel = PROJECT_PANEL_SCENE.instantiate()
		project_panel.project_path = path
		project_panel.project_name = label
		project_panel.open_project.connect(_on_open)
		project_panel.remove_project.connect(_on_remove)
		project_panel.favorite_changed.connect(_on_favorite_changed)
		project_list.add_child(project_panel)
	if project_list.get_child_count() == 0:
		status.text = "No projects match the filter." if not query.is_empty() else "No projects registered. Add a project folder."
	else:
		status.text = "%d project(s)" % project_list.get_child_count()


func _on_add() -> void:
	file_dialog.popup_centered_ratio(0.6)


func _on_scan() -> void:
	scan_dialog.popup_centered_ratio(0.6)


func _set_action_busy(busy: bool) -> void:
	add_btn.disabled = busy
	scan_btn.disabled = busy
	for child in project_list.get_children():
		child.busy = busy


func _on_dir_selected(dir: String) -> void:
	status.text = "Adding…"
	_set_action_busy(true)
	var data: Variant = await HubCli.projects_add_async(dir)
	_set_action_busy(false)
	if data == null:
		status.text = HubCli.get_last_error()
		return
	HubState.refresh_projects()
	reload()


func _on_scan_dir_selected(_dir: String):
	status.text = "Scanning…"
	_set_action_busy(true)
	var dir: DirAccess = DirAccess.open(_dir)
	if not dir:
		_set_action_busy(false)
		return
	dir.list_dir_begin()
	var next: String = dir.get_next()
	while next:
		if not dir.current_is_dir():
			next = dir.get_next()
			continue
		var _dir_path: String = _dir.path_join(next)
		if FileAccess.file_exists(_dir_path.path_join("project.godot")):
			await HubCli.projects_add_async(_dir_path)
		next = dir.get_next()
	_set_action_busy(false)
	HubState.refresh_projects()
	reload()



func _on_project_file_selected(_file: String):
	status.text = "Adding…"
	_set_action_busy(true)
	var data: Variant = await HubCli.projects_add_async(_file.get_base_dir())
	_set_action_busy(false)
	if data == null:
		status.text = HubCli.get_last_error()
		return
	HubState.refresh_projects()
	reload()


func _on_remove(_path: String) -> void:
	if _path.is_empty():
		status.text = "Select a project first"
		return
	status.text = "Removing…"
	_set_action_busy(true)
	var data: Variant = await HubCli.projects_remove_async(_path)
	_set_action_busy(false)
	if data == null:
		status.text = HubCli.get_last_error()
		return
	HubState.refresh_projects()
	reload()


func _on_favorite_changed(_path: String, _favorite: bool) -> void:
	HubSettings.set_favorite_project(_path, _favorite)
	_build_projects_list(filter_projects_line_edit.text)


func _on_open(_path: String) -> void:
	if _path.is_empty():
		status.text = "Select a project first"
		return
	status.text = "Opening via blazium-cli…"
	_set_action_busy(true)
	var data: Variant = await HubCli.open_project_async(_path)
	_set_action_busy(false)
	if data == null:
		status.text = HubCli.get_last_error()
		return
	status.text = "Launched"
	HubState.refresh_projects()
