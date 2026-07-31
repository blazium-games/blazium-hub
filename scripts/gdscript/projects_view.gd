extends VBoxContainer

@onready var list: ItemList = %ProjectList
@onready var add_btn: Button = %AddProjectBtn
@onready var remove_btn: Button = %RemoveProjectBtn
@onready var open_btn: Button = %OpenProjectBtn
@onready var file_dialog: FileDialog = %ProjectFolderDialog
@onready var status: Label = %ProjectsStatus


func _ready() -> void:
	add_btn.pressed.connect(_on_add)
	remove_btn.pressed.connect(_on_remove)
	open_btn.pressed.connect(_on_open)
	list.item_activated.connect(func(_i): _on_open())
	file_dialog.dir_selected.connect(_on_dir_selected)
	reload()


func reload() -> void:
	list.clear()
	for p in HubState.projects_list:
		var label := str(p)
		var path := str(p)
		if typeof(p) == TYPE_DICTIONARY:
			label = "%s  —  %s" % [str(p.get("name", "")), str(p.get("path", ""))]
			path = str(p.get("path", path))
		var idx := list.add_item(label)
		list.set_item_metadata(idx, path)
	if list.item_count == 0:
		status.text = "No projects registered. Add a project folder."
	else:
		status.text = "%d project(s)" % list.item_count


func _selected_path() -> String:
	var sels := list.get_selected_items()
	if sels.is_empty():
		return ""
	return str(list.get_item_metadata(sels[0]))


func _on_add() -> void:
	file_dialog.popup_centered_ratio(0.6)


func _set_action_busy(busy: bool) -> void:
	add_btn.disabled = busy
	remove_btn.disabled = busy
	open_btn.disabled = busy


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


func _on_remove() -> void:
	var path := _selected_path()
	if path.is_empty():
		status.text = "Select a project first"
		return
	status.text = "Removing…"
	_set_action_busy(true)
	var data: Variant = await HubCli.projects_remove_async(path)
	_set_action_busy(false)
	if data == null:
		status.text = HubCli.get_last_error()
		return
	HubState.refresh_projects()
	reload()


func _on_open() -> void:
	var path := _selected_path()
	if path.is_empty():
		status.text = "Select a project first"
		return
	status.text = "Opening via blazium-cli…"
	_set_action_busy(true)
	var data: Variant = await HubCli.open_project_async(path)
	_set_action_busy(false)
	if data == null:
		status.text = HubCli.get_last_error()
		return
	status.text = "Launched"
	HubState.refresh_projects()
