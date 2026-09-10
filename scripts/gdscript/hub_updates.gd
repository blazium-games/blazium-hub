extends Node
## Launch/settings update prompts. Session dismissals clear on relaunch.
## Declined editor versions persist so that same engine update is not asked again.

const HubSanitize := preload("res://scripts/gdscript/hub_sanitize.gd")

signal status_changed(message: String)

const PRODUCT_ORDER := ["hub", "cli", "crash_reporter", "toolchain", "editor", "templates"]
const PRODUCT_LABELS := {
	"hub": "Blazium Hub",
	"cli": "blazium-cli",
	"crash_reporter": "Blazium Crash Reporter",
	"toolchain": "Blazium Toolchain",
	"editor": "Blazium editor",
	"templates": "Export templates",
}

var _dismissed: Dictionary = {} # product -> true
var _queue: Array = [] # Array of Dictionary product statuses
var _busy: bool = false
var _dialog: ConfirmationDialog
var _pending: Dictionary = {}
var _last_summary: String = ""
var _hub_includes_cli: bool = false
var _hub_includes_crash_reporter: bool = false


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


## True when catalog reports a Hub update (ignores session dismissals).
## While true, standalone CLI and crash reporter updates are suppressed —
## Hub ships the newest CLI and sidecar. Toolchain is not bundled with Hub.
func hub_update_outstanding(products: Array) -> bool:
	return _find_product_status(products, "hub") != null


func _find_product_status(products: Array, name: String) -> Variant:
	for item in products:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if str(item.get("product", "")) != name:
			continue
		if not bool(item.get("update_available", false)):
			continue
		if not str(item.get("error", "")).is_empty():
			continue
		return item
	return null


func _version_declined(latest: String, declined: Array) -> bool:
	var v := latest.strip_edges()
	if v.is_empty():
		return false
	return declined.has(v)


func _should_skip_templates(products: Array, dismissed: Dictionary, declined: Array, templates_item: Variant) -> bool:
	if typeof(templates_item) != TYPE_DICTIONARY:
		return false
	if dismissed.has("editor"):
		return true
	var editor_item: Variant = _find_product_status(products, "editor")
	if editor_item != null and _version_declined(str(editor_item.get("latest_version", "")), declined):
		return true
	return _version_declined(str(templates_item.get("latest_version", "")), declined)


func _declined_editor_versions() -> Array:
	if HubSettings and HubSettings.has_method("get_declined_editor_versions"):
		return HubSettings.get_declined_editor_versions()
	return []


## Build ordered update prompt queue. Skips CLI and crash reporter when a Hub
## update is outstanding — Hub ships the newest CLI and sidecar. Toolchain
## stays queued because Hub does not bundle it. Skips templates when the editor
## was declined this session or its latest version was previously declined.
func build_update_queue(products: Array, dismissed: Dictionary, declined_editor_versions: Array = []) -> Array:
	var hub_outstanding := hub_update_outstanding(products)
	var queue: Array = []
	for name in PRODUCT_ORDER:
		if (name == "cli" or name == "crash_reporter") and hub_outstanding:
			continue
		if dismissed.has(name):
			continue
		var item: Variant = _find_product_status(products, name)
		if item == null:
			continue
		if name == "editor" and _version_declined(str(item.get("latest_version", "")), declined_editor_versions):
			continue
		if name == "templates" and _should_skip_templates(products, dismissed, declined_editor_versions, item):
			continue
		queue.append(item)
	return queue


func prompt_title(product: String) -> String:
	if product == "editor":
		return "Install Blazium editor"
	return "%s Update Available" % str(PRODUCT_LABELS.get(product, product))


func prompt_ok_button(product: String) -> String:
	if product == "editor":
		return "Install"
	return "Update"


func prompt_body(product: String, latest: String, current: String) -> String:
	var label := str(PRODUCT_LABELS.get(product, product))
	var cur_ed := current if not current.is_empty() else "(no default editor)"
	if product == "editor":
		return "%s version %s is now available, want to install it? Current version is %s" % [label, latest, cur_ed]
	if product == "templates":
		return "Install export templates for version %s? Current version is %s" % [latest, cur_ed]
	var cur := current if not current.is_empty() else "(unknown)"
	return "%s %s is available (current %s). Update now?" % [label, latest, cur]


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
	_hub_includes_cli = (
		hub_update_outstanding(products) and _find_product_status(products, "cli") != null
	)
	_hub_includes_crash_reporter = (
		hub_update_outstanding(products) and _find_product_status(products, "crash_reporter") != null
	)
	_queue = build_update_queue(products, _dismissed, _declined_editor_versions())
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
	_dialog.size.x = 600
	_dialog.title = "Update Available"
	_dialog.ok_button_text = "Update"
	_dialog.get_ok_button().theme_type_variation = "FilledButton"
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
	var cur := str(_pending.get("current_version", ""))
	var latest := str(_pending.get("latest_version", ""))
	var body := prompt_body(product, latest, cur)
	if product == "hub" and _hub_includes_cli:
		body += "\nThis Hub update includes the latest blazium-cli."
	if product == "hub" and _hub_includes_crash_reporter:
		body += "\nThis Hub update includes the latest Blazium Crash Reporter."
	_ensure_dialog()
	_dialog.title = prompt_title(product)
	_dialog.ok_button_text = prompt_ok_button(product)
	_dialog.dialog_text = body
	_dialog.dialog_autowrap = true
	_dialog.popup_centered()


func _drop_queued_product(name: String) -> void:
	var kept: Array = []
	for item in _queue:
		if str(item.get("product", "")) != name:
			kept.append(item)
	_queue = kept


func _on_declined() -> void:
	var product := str(_pending.get("product", ""))
	var latest := str(_pending.get("latest_version", ""))
	if not product.is_empty():
		_dismissed[product] = true
		if product == "editor":
			if HubSettings and HubSettings.has_method("add_declined_editor_version"):
				HubSettings.add_declined_editor_version(latest)
			_dismissed["templates"] = true
			_drop_queued_product("templates")
			_last_summary = "Skipped %s %s" % [str(PRODUCT_LABELS.get(product, product)), latest]
		else:
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
			var r: Variant = await HubCli.update_apply_cli_async()
			ok = r != null
			if not ok:
				_last_summary = HubCli.get_last_error()
			else:
				_last_summary = "blazium-cli updated to %s" % latest
		"crash_reporter":
			var r: Variant = await HubCli.update_apply_crash_reporter_async(install_root())
			ok = r != null
			if not ok:
				_last_summary = HubCli.get_last_error()
			else:
				_last_summary = "Blazium Crash Reporter updated to %s" % latest
		"toolchain":
			var r: Variant = await HubCli.update_apply_toolchain_async(install_root())
			ok = r != null
			if not ok:
				_last_summary = HubCli.get_last_error()
			else:
				_last_summary = "Blazium Toolchain updated to %s" % latest
		"hub":
			var r: Variant = await HubCli.update_apply_hub_async(hub_version(), install_root(), true)
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
			if not HubSanitize.is_valid_version(latest) or latest.strip_edges().is_empty():
				_last_summary = "Rejected invalid editor version"
				status_changed.emit(_last_summary)
				_pending = {}
				call_deferred("_show_next")
				return
			var r: Variant = await HubCli.install_async(latest)
			ok = r != null
			if not ok:
				_last_summary = HubCli.get_last_error()
			else:
				_last_summary = "Editor %s install started" % latest
				if HubState and HubState.has_method("refresh_all"):
					HubState.refresh_all()
		"templates":
			if not HubSanitize.is_valid_version(latest) or latest.strip_edges().is_empty():
				_last_summary = "Rejected invalid templates version"
				status_changed.emit(_last_summary)
				_pending = {}
				call_deferred("_show_next")
				return
			var r: Variant = await HubCli.templates_download_async(latest)
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
