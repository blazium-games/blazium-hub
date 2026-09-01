extends Node
## Persisted Hub preferences (CLI path, tray behavior).

const HubSanitize := preload("res://scripts/gdscript/hub_sanitize.gd")

const CONFIG_PATH := "user://hub_settings.cfg"

var cli_path: String = ""
var minimize_to_tray: bool = true
var close_to_tray: bool = true
var data_collection_decided: bool = false
var data_collection_enabled: bool = false
var data_collection_anonymous: bool = true


func _ready() -> void:
	load_settings()


func get_cli_path() -> String:
	return cli_path


func set_cli_path_value(path: String) -> void:
	var p := path.strip_edges()
	if not HubSanitize.is_safe_cli_path(p):
		return
	cli_path = p
	save_settings()
	if HubCli:
		HubCli.set_cli_path(cli_path)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	var loaded := str(cfg.get_value("paths", "cli_path", ""))
	cli_path = loaded if HubSanitize.is_safe_cli_path(loaded) else ""
	minimize_to_tray = bool(cfg.get_value("tray", "minimize_to_tray", true))
	close_to_tray = bool(cfg.get_value("tray", "close_to_tray", true))
	data_collection_decided = bool(cfg.get_value("privacy", "data_collection_decided", false))
	data_collection_enabled = bool(cfg.get_value("privacy", "data_collection_enabled", false))
	data_collection_anonymous = bool(cfg.get_value("privacy", "data_collection_anonymous", true))
	if HubCli and not cli_path.is_empty():
		HubCli.set_cli_path(cli_path)
	_apply_crash_reporter_enabled()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("paths", "cli_path", cli_path)
	cfg.set_value("tray", "minimize_to_tray", minimize_to_tray)
	cfg.set_value("tray", "close_to_tray", close_to_tray)
	cfg.set_value("privacy", "data_collection_decided", data_collection_decided)
	cfg.set_value("privacy", "data_collection_enabled", data_collection_enabled)
	cfg.set_value("privacy", "data_collection_anonymous", data_collection_anonymous)
	cfg.save(CONFIG_PATH)


func set_data_collection_enabled(enabled: bool) -> void:
	data_collection_enabled = enabled
	data_collection_decided = true
	_apply_crash_reporter_enabled()
	save_settings()


func set_data_collection_anonymous(anonymous: bool) -> void:
	data_collection_anonymous = anonymous
	save_settings()


func has_data_collection_consent() -> bool:
	return data_collection_decided and data_collection_enabled


func _apply_crash_reporter_enabled() -> void:
	ProjectSettings.set_setting("crash_reporter/enabled", data_collection_enabled)
