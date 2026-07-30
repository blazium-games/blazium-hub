extends Node
## Routes blazium:// URIs: hub show locally, everything else via blazium-cli handle-uri.

signal uri_handled(result: Dictionary)
signal toast(message: String)


func _ready() -> void:
	call_deferred("_consume_startup_args")


func _consume_startup_args() -> void:
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("blazium:"):
			handle_uri(str(a))
			return
	for a in OS.get_cmdline_args():
		if str(a).begins_with("blazium:"):
			handle_uri(str(a))
			return


static func is_hub_show_uri(uri: String) -> bool:
	var lower := uri.strip_edges().to_lower()
	if lower.is_empty():
		return false
	return (
		lower == "blazium://"
		or lower == "blazium:"
		or lower == "blazium://hub"
		or lower.begins_with("blazium://hub?")
	)


func handle_uri(uri: String) -> void:
	uri = uri.strip_edges()
	if uri.is_empty():
		return
	if is_hub_show_uri(uri):
		uri_handled.emit({"ok": true, "action": "hub", "uri": uri})
		show_hub()
		return
	var data: Variant = HubCli.handle_uri(uri)
	if data == null:
		var err := HubCli.get_last_error()
		toast.emit(err if not err.is_empty() else "Failed to handle URI")
		uri_handled.emit({"ok": false, "uri": uri, "error": err})
		return
	if typeof(data) == TYPE_DICTIONARY:
		var action := str(data.get("action", ""))
		if action == "hub":
			show_hub()
		elif data.get("launched", false) or data.get("already_open", false):
			toast.emit("Project ready via blazium-cli")
		uri_handled.emit(data)
	else:
		uri_handled.emit({"ok": true, "uri": uri, "data": data})


func show_hub() -> void:
	var win := get_window()
	if win:
		win.show()
		win.mode = Window.MODE_WINDOWED
		win.grab_focus()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var tree := get_tree()
	if tree:
		tree.set_auto_accept_quit(false)
