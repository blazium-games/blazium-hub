extends VBoxContainer

@onready var channel_option: OptionButton = %ChannelOption
@onready var installed_list: ItemList = %InstalledList
@onready var available_list: ItemList = %AvailableList
@onready var refresh_btn: Button = %RefreshEditorsBtn
@onready var install_btn: Button = %InstallBtn
@onready var uninstall_btn: Button = %UninstallBtn
@onready var status: Label = %EditorsStatus
@onready var console: TextEdit = %EditorsConsole

var _available_versions: Array = []


func _ready() -> void:
	channel_option.clear()
	channel_option.add_item("release", 0)
	channel_option.add_item("nightly", 1)
	channel_option.select(0)
	refresh_btn.pressed.connect(_on_refresh)
	install_btn.pressed.connect(_on_install)
	uninstall_btn.pressed.connect(_on_uninstall)
	channel_option.item_selected.connect(func(_i): _load_available())
	if HubLog:
		HubLog.log_changed.connect(_refresh_console)
	reload_installed()
	_refresh_console()
	call_deferred("_load_available")


func _set_status(msg: String) -> void:
	status.text = msg
	if HubLog:
		HubLog.append(msg)


func _refresh_console() -> void:
	if console == null:
		return
	if HubLog:
		console.text = HubLog.get_text()
		console.scroll_vertical = console.get_line_count()


func reload_installed() -> void:
	installed_list.clear()
	for e in HubState.installed_editors:
		var label := str(e)
		var version := str(e)
		if typeof(e) == TYPE_DICTIONARY:
			version = str(e.get("version", e.get("Version", "")))
			label = "%s  (%s)" % [version, str(e.get("path", e.get("Path", "")))]
		var idx := installed_list.add_item(label)
		installed_list.set_item_metadata(idx, version)
	status.text = "%d installed" % installed_list.item_count


func _load_available() -> void:
	_set_status("Loading CDN catalog…")
	var channel := "release"
	if channel_option.selected == 1:
		channel = "nightly"
	var data: Variant = await CdnClient.versions(channel)
	available_list.clear()
	_available_versions.clear()
	if data == null:
		_set_status(CdnClient.get_last_error())
		_refresh_console()
		return
	var versions: Array = []
	if typeof(data) == TYPE_ARRAY:
		versions = data
	elif typeof(data) == TYPE_DICTIONARY:
		if data.has("versions"):
			var v = data["versions"]
			if typeof(v) == TYPE_ARRAY:
				versions = v
			elif typeof(v) == TYPE_DICTIONARY:
				versions = v.keys()
		elif data.has("version"):
			versions = [data]
	for item in versions:
		var ver := ""
		if typeof(item) == TYPE_DICTIONARY:
			ver = str(item.get("version", ""))
		else:
			ver = str(item)
		if ver.is_empty():
			continue
		_available_versions.append(ver)
		available_list.add_item(ver)
	var latest: Variant = await CdnClient.latest(channel)
	if typeof(latest) == TYPE_DICTIONARY and latest.has("version"):
		_set_status("CDN %s latest: %s (%d listed)" % [channel, str(latest["version"]), available_list.item_count])
	else:
		_set_status("%d version(s) from CDN" % available_list.item_count)
	_refresh_console()


func _on_refresh() -> void:
	_set_status("Refreshing editors…")
	HubState.refresh_editors()
	reload_installed()
	await _load_available()


func _on_install() -> void:
	var sels := available_list.get_selected_items()
	var version := ""
	if not sels.is_empty():
		version = available_list.get_item_text(sels[0])
	_set_status("Installing %s via blazium-cli…" % (version if not version.is_empty() else "default"))
	var data: Variant = HubCli.install(version)
	_refresh_console()
	if data == null:
		_set_status(HubCli.get_last_error())
		_refresh_console()
		return
	_set_status("Installed")
	HubState.refresh_editors()
	reload_installed()
	_refresh_console()


func _on_uninstall() -> void:
	var sels := installed_list.get_selected_items()
	if sels.is_empty():
		_set_status("Select an installed editor")
		_refresh_console()
		return
	var version := str(installed_list.get_item_metadata(sels[0]))
	_set_status("Uninstalling %s…" % version)
	var data: Variant = HubCli.uninstall(version)
	_refresh_console()
	if data == null:
		_set_status(HubCli.get_last_error())
		_refresh_console()
		return
	_set_status("Uninstalled")
	HubState.refresh_editors()
	reload_installed()
	_refresh_console()
