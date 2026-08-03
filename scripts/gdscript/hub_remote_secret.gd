extends Node
## Loads or creates hub_remote.json and starts authenticated remote_control for CLI IPC.

const HubSanitize := preload("res://scripts/gdscript/hub_sanitize.gd")

const DEFAULT_HOST := "127.0.0.1"
const DEFAULT_PORT := 39218

var host: String = DEFAULT_HOST
var port: int = DEFAULT_PORT
var token: String = ""
var config_path: String = ""
var started: bool = false
var ensure_only: bool = false
var path_override: String = ""


func _ready() -> void:
	_parse_cmdline()
	call_deferred("_bootstrap")


func _parse_cmdline() -> void:
	for a in OS.get_cmdline_user_args():
		_consume_arg(str(a))
	for a in OS.get_cmdline_args():
		_consume_arg(str(a))


func _consume_arg(a: String) -> void:
	if a == "--ensure-hub-remote":
		ensure_only = true
		return
	if a.begins_with("--hub-remote-path="):
		path_override = a.substr("--hub-remote-path=".length()).strip_edges()


func _bootstrap() -> void:
	config_path = resolve_effective_config_path()
	_ensure_secret_file()
	_apply_project_settings()
	if ensure_only:
		# Installer / CI path: write secret and exit without keeping a GUI server.
		OS.set_exit_code(0)
		var tree := get_tree()
		if tree:
			tree.quit(0)
		return
	_start_remote_control()
	_register_show_hub_command()


func resolve_effective_config_path() -> String:
	if not path_override.is_empty():
		return path_override
	var user_path := resolve_user_config_path()
	if _file_has_valid_secret(user_path):
		return user_path
	var machine_path := resolve_machine_config_path()
	if _file_has_valid_secret(machine_path):
		return machine_path
	return user_path


static func resolve_user_config_path() -> String:
	if OS.get_name() == "Windows":
		var base := OS.get_environment("APPDATA")
		if base.is_empty():
			base = OS.get_environment("USERPROFILE").path_join("AppData").path_join("Roaming")
		return base.path_join("blazium").path_join("hub_remote.json")
	var home := OS.get_environment("HOME")
	if home.is_empty():
		home = OS.get_environment("USERPROFILE")
	return home.path_join(".config").path_join("blazium").path_join("hub_remote.json")


static func resolve_machine_config_path() -> String:
	if OS.get_name() == "Windows":
		var base := OS.get_environment("PROGRAMDATA")
		if base.is_empty():
			base = "C:/ProgramData"
		return base.path_join("blazium").path_join("hub_remote.json")
	return "/etc/blazium/hub_remote.json"


## Back-compat alias used by tests.
static func resolve_config_path() -> String:
	return resolve_user_config_path()


static func generate_token() -> String:
	var crypto := Crypto.new()
	var bytes: PackedByteArray = crypto.generate_random_bytes(32)
	var hex := ""
	for i in bytes.size():
		hex += "%02x" % bytes[i]
	return hex


static func _file_has_valid_secret(path: String) -> bool:
	if path.is_empty() or not FileAccess.file_exists(path):
		return false
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = parsed
	var loaded_token := str(d.get("token", "")).strip_edges()
	var loaded_port := int(d.get("port", DEFAULT_PORT))
	return loaded_token.length() >= 32 and loaded_port > 0


static func _read_secret_dict(path: String) -> Dictionary:
	if not _file_has_valid_secret(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed


func _ensure_secret_file() -> void:
	# Prefer valid secret already at the effective path.
	if _file_has_valid_secret(config_path):
		_apply_dict(_read_secret_dict(config_path))
		return

	# When writing user path and machine has a valid secret, copy machine → user
	# (unless installer forced an explicit path override that does not exist yet).
	if path_override.is_empty():
		var machine_path := resolve_machine_config_path()
		if config_path != machine_path and _file_has_valid_secret(machine_path):
			_apply_dict(_read_secret_dict(machine_path))
			_write_secret_file()
			return

	token = generate_token()
	host = DEFAULT_HOST
	port = DEFAULT_PORT
	_write_secret_file()


func _apply_dict(d: Dictionary) -> void:
	if d.is_empty():
		return
	token = str(d.get("token", "")).strip_edges()
	# Never bind remote_control off loopback, even if the file is poisoned.
	host = HubSanitize.sanitize_bind_host(str(d.get("host", DEFAULT_HOST)))
	port = HubSanitize.sanitize_bind_port(int(d.get("port", DEFAULT_PORT)), DEFAULT_PORT)


func _write_secret_file() -> void:
	var dir_path := config_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)
	var payload := {
		"host": host,
		"port": port,
		"token": token,
		"created_unix": int(Time.get_unix_time_from_system()),
	}
	var f := FileAccess.open(config_path, FileAccess.WRITE)
	if f == null:
		push_warning("HubRemoteSecret: failed to write %s" % config_path)
		return
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	if OS.get_name() != "Windows":
		OS.execute("chmod", PackedStringArray(["600", config_path]))


func _apply_project_settings() -> void:
	if not ProjectSettings:
		return
	ProjectSettings.set_setting("blazium/remote_control/server_enabled", true)
	ProjectSettings.set_setting("blazium/remote_control/allow_runtime", true)
	ProjectSettings.set_setting("blazium/remote_control/server_port", port)
	ProjectSettings.set_setting("blazium/remote_control/bind_address", host)
	ProjectSettings.set_setting("blazium/remote_control/token", token)


func _start_remote_control() -> void:
	if not ClassDB.class_exists("RemoteControlServer"):
		return
	var server = Engine.get_singleton("RemoteControlServer")
	if server == null:
		return
	if server.has_method("set_token"):
		server.set_token(token)
	if server.has_method("is_started") and bool(server.is_started()):
		started = true
		return
	if server.has_method("start"):
		var err: Variant = server.start()
		started = (int(err) == OK) or (server.has_method("is_started") and bool(server.is_started()))
		if not started:
			push_warning("HubRemoteSecret: RemoteControlServer.start failed: %s" % str(err))


func _register_show_hub_command() -> void:
	if not ClassDB.class_exists("RemoteControlRegistry"):
		return
	var registry = Engine.get_singleton("RemoteControlRegistry")
	if registry == null or not registry.has_method("register_command"):
		return
	if registry.has_method("has_command") and bool(registry.has_command("show_hub")):
		return
	registry.register_command("show_hub", Callable(self, "_cmd_show_hub"), "Focus/show the Hub window")


func _cmd_show_hub(_args: Dictionary) -> Dictionary:
	if UriRouter and UriRouter.has_method("show_hub"):
		UriRouter.show_hub()
	return {"ok": true, "focused": true, "action": "show_hub"}


func get_token() -> String:
	return token


func get_port() -> int:
	return port


func get_host() -> String:
	return host
