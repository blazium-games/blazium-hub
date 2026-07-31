extends Node
## Launch/settings update prompts. Session dismissals clear on relaunch.

signal status_changed(message: String)

const PRODUCT_ORDER := ["hub", "cli", "editor", "templates"]
const PRODUCT_LABELS := {
	"hub": "Blazium Hub",
	"cli": "blazium-cli",
	"editor": "Blazium editor",
	"templates": "Export templates",
}

var _dismissed: Dictionary = {} # product -> true
var _queue: Array = [] # Array of Dictionary product statuses
var _busy: bool = false
var _dialog: ConfirmationDialog
var _pending: Dictionary = {}
var _last_summary: String = ""


func get_last_summary() -> String:
	return _last_summary


func clear_dismissals() -> void:
	_dismissed.clear()


func hub_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))


func install_root() -> String:
	var env := OS.get_environment("BLAZIUM").strip_edges()
	if not env.is_empty():
		return env
	var exe := OS.get_executable_path()
	var base := exe.get_base_dir()
	if base.get_file().to_lower() == "hub":
		return base.get_base_dir()
	# linux: /opt/blazium/bin/blazium-hub
	if base.get_file().to_lower() == "bin":
		return base.get_base_dir()
	return base


func check_and_prompt(clear_session_dismissals: bool = false) -> void:
	if _busy:
		return
	if clear_session_dismissals:
		clear_dismissals()
	_busy = true
	status_changed.emit("Checking for updates…")
	var data: Variant = HubCli.update_check("all", hub_version(), install_root())
	if data == null:
		_last_summary = HubCli.get_last_error()
		if _last_summary.is_empty():
			_last_summary = "Update check skipped"
		status_changed.emit(_last_summary)
		_busy = false
		return
	var products: Array = []
	if typeof(data) == TYPE_DICTIONARY:
		var p = data.get("products", [])
		if typeof(p) == TYPE_ARRAY:
			products = p
	_queue.clear()
	for name in PRODUCT_ORDER:
		for item in products:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			if str(item.get("product", "")) != name:
				continue
			if not bool(item.get("update_available", false)):
				continue
			if _dismissed.has(name):
				continue
			if not str(item.get("error", "")).is_empty():
				continue
			_queue.append(item)
			break
	if _queue.is_empty():
		_last_summary = "All products up to date"
		status_changed.emit(_last_summary)
		_busy = false
		return
	_last_summary = "%d update(s) available" % _queue.size()
	status_changed.emit(_last_summary)
	_show_next()


func _ensure_dialog() -> void:
	if _dialog != null and is_instance_valid(_dialog):
		return
	_dialog = ConfirmationDialog.new()
	_dialog.title = "Update available"
	_dialog.ok_button_text = "Update"
	_dialog.cancel_button_text = "Not now"
	_dialog.confirmed.connect(_on_accepted)
	_dialog.canceled.connect(_on_declined)
	get_tree().root.add_child(_dialog)


func _show_next() -> void:
	if _queue.is_empty():
		_busy = false
		status_changed.emit(_last_summary)
		return
	_pending = _queue.pop_front()
	var product := str(_pending.get("product", ""))
	var label := str(PRODUCT_LABELS.get(product, product))
	var cur := str(_pending.get("current_version", ""))
	var latest := str(_pending.get("latest_version", ""))
	var body := "%s %s → %s is available.\nUpdate now?" % [label, cur if not cur.is_empty() else "(none)", latest]
	_ensure_dialog()
	_dialog.dialog_text = body
	_dialog.popup_centered()


func _on_declined() -> void:
	var product := str(_pending.get("product", ""))
	if not product.is_empty():
		_dismissed[product] = true
		_last_summary = "Skipped %s until next relaunch" % str(PRODUCT_LABELS.get(product, product))
		status_changed.emit(_last_summary)
	_pending = {}
	call_deferred("_show_next")


func _on_accepted() -> void:
	var product := str(_pending.get("product", ""))
	var latest := str(_pending.get("latest_version", ""))
	status_changed.emit("Updating %s…" % str(PRODUCT_LABELS.get(product, product)))
	var ok := false
	match product:
		"cli":
			var r: Variant = HubCli.update_apply_cli()
			ok = r != null
			if not ok:
				_last_summary = HubCli.get_last_error()
			else:
				_last_summary = "blazium-cli updated to %s" % latest
		"hub":
			var r: Variant = HubCli.update_apply_hub(hub_version(), install_root())
			ok = r != null
			if not ok:
				_last_summary = HubCli.get_last_error()
				status_changed.emit(_last_summary)
				_pending = {}
				call_deferred("_show_next")
				return
			_last_summary = "Hub installer launched; quitting…"
			status_changed.emit(_last_summary)
			get_tree().quit()
			return
		"editor":
			var r: Variant = HubCli.install(latest)
			ok = r != null
			if not ok:
				_last_summary = HubCli.get_last_error()
			else:
				_last_summary = "Editor %s install started" % latest
				if HubState and HubState.has_method("refresh_all"):
					HubState.refresh_all()
		"templates":
			var r: Variant = HubCli.templates_download(latest)
			ok = r != null
			if not ok:
				_last_summary = HubCli.get_last_error()
			else:
				_last_summary = "Templates %s download finished" % latest
		_:
			_last_summary = "Unknown product %s" % product
	status_changed.emit(_last_summary)
	_pending = {}
	call_deferred("_show_next")
