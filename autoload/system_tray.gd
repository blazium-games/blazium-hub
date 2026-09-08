extends Node
## Windows system tray via StatusIndicator. Disabled on unsupported platforms.

var _indicator: StatusIndicator
var _menu: PopupMenu


func _ready() -> void:
	if HubSelfTest != null and HubSelfTest.active:
		return
	if OS.get_name() != "Windows":
		return
	get_tree().set_auto_accept_quit(false)
	_menu = PopupMenu.new()
	_menu.name = "TrayMenu"
	add_child(_menu)
	_menu.id_pressed.connect(_on_menu_id)
	_rebuild_menu()

	_indicator = StatusIndicator.new()
	_indicator.tooltip = "Blazium Hub"
	var icon := load("res://assets/icons/icon.svg")
	if icon:
		_indicator.icon = icon
	_indicator.menu = _menu.get_path()
	add_child(_indicator)
	_indicator.pressed.connect(_on_indicator_pressed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_on_close_requested()


func _rebuild_menu() -> void:
	_menu.clear()
	_menu.add_item("Show Blazium Hub", 1)
	_menu.add_separator()
	var recent: Array = []
	if HubState:
		recent = HubState.recent_projects(6)
	if recent.is_empty():
		_menu.add_item("(no recent projects)", 90)
		_menu.set_item_disabled(0, false)
		var idx := _menu.get_item_index(90)
		if idx >= 0:
			_menu.set_item_disabled(idx, true)
	else:
		var id := 100
		for p in recent:
			var label := str(p)
			var path := str(p)
			if typeof(p) == TYPE_DICTIONARY:
				label = str(p.get("name", p.get("path", path)))
				path = str(p.get("path", path))
			_menu.add_item(label, id)
			_menu.set_item_metadata(_menu.get_item_index(id), path)
			id += 1
	_menu.add_separator()
	_menu.add_item("Quit", 2)


func _on_menu_id(id: int) -> void:
	match id:
		1:
			_show()
		2:
			get_tree().quit()
		_:
			if id >= 100:
				var idx := _menu.get_item_index(id)
				var path: String = str(_menu.get_item_metadata(idx))
				if not path.is_empty() and HubCli:
					HubCli.open_project(path)


func _on_indicator_pressed(_mouse_button: int) -> void:
	_show()


func _show() -> void:
	var win := get_window()
	if win:
		win.show()
		win.mode = Window.MODE_WINDOWED
		win.grab_focus()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_rebuild_menu()


func _on_close_requested() -> void:
	if OS.get_name() != "Windows":
		get_tree().quit()
		return
	if HubSettings and HubSettings.close_to_tray:
		var win := get_window()
		if win:
			var was_visible := win.visible
			win.hide()
			if was_visible and win.visible:
				get_tree().quit()
		else:
			get_tree().quit()
	else:
		get_tree().quit()


func refresh_menu() -> void:
	if _menu:
		_rebuild_menu()
