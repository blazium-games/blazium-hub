extends Node
## Persisted Hub preferences (CLI path, tray behavior).

const HubSanitize := preload("res://scripts/gdscript/hub_sanitize.gd")

const CONFIG_PATH := "user://hub_settings.cfg"

var cli_path: String = ""
var minimize_to_tray: bool = true
var close_to_tray: bool = true


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
	if HubCli and not cli_path.is_empty():
		HubCli.set_cli_path(cli_path)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("paths", "cli_path", cli_path)
	cfg.set_value("tray", "minimize_to_tray", minimize_to_tray)
	cfg.set_value("tray", "close_to_tray", close_to_tray)
	cfg.save(CONFIG_PATH)
