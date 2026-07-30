extends Node
## Runs blazium-cli with --json and parses stdout.

signal command_finished(ok: bool, data: Variant, error: String)

var cli_path: String = ""
var _last_error: String = ""


func get_last_error() -> String:
	return _last_error


func set_cli_path(path: String) -> void:
	cli_path = path.strip_edges()


func get_cli_path() -> String:
	return cli_path


func list_cli_candidates() -> PackedStringArray:
	## Ordered probes: BLAZIUM install root, then common paths, then bare PATH names last.
	var candidates: PackedStringArray = []
	var root := OS.get_environment("BLAZIUM").strip_edges()
	var is_win := OS.get_name() == "Windows"
	if not root.is_empty():
		if is_win:
			candidates.append(root.path_join("blazium-cli.exe"))
			candidates.append(root.path_join("bin").path_join("blazium-cli.exe"))
		else:
			candidates.append(root.path_join("bin").path_join("blazium-cli"))
			candidates.append(root.path_join("blazium-cli"))
	if is_win:
		var localapp := OS.get_environment("LOCALAPPDATA")
		var prog := OS.get_environment("ProgramFiles")
		candidates.append(prog.path_join("Blazium").path_join("blazium-cli.exe"))
		candidates.append(localapp.path_join("Blazium").path_join("blazium-cli.exe"))
	else:
		candidates.append("/opt/blazium/bin/blazium-cli")
		candidates.append("/usr/local/bin/blazium-cli")
		candidates.append("/usr/bin/blazium-cli")
		candidates.append(OS.get_environment("HOME").path_join(".local/bin/blazium-cli"))
	if is_win:
		candidates.append("blazium-cli.exe")
		candidates.append("blazium-cli")
	else:
		candidates.append("blazium-cli")
	return candidates


func resolve_cli() -> String:
	if not cli_path.is_empty() and FileAccess.file_exists(cli_path):
		return cli_path
	if HubSettings:
		var p: String = HubSettings.get_cli_path()
		if not p.is_empty() and FileAccess.file_exists(p):
			cli_path = p
			return p
	for c in list_cli_candidates():
		if c == "blazium-cli" or c == "blazium-cli.exe":
			cli_path = c
			return c
		if FileAccess.file_exists(c):
			cli_path = c
			return c
	_last_error = "blazium-cli not found"
	return ""


func parse_json_output(text: String, code: int) -> Variant:
	_last_error = ""
	text = text.strip_edges()
	if text.is_empty():
		_last_error = "empty CLI output (exit %d)" % code
		return null
	var data: Variant = JSON.parse_string(text)
	if data == null:
		var lines := text.split("\n")
		data = JSON.parse_string(lines[lines.size() - 1])
	if data == null:
		_last_error = "failed to parse JSON: %s" % text.substr(0, 200)
		return null
	if typeof(data) == TYPE_DICTIONARY and data.has("error"):
		_last_error = str(data["error"])
		if code != 0:
			return null
	if code != 0 and (typeof(data) != TYPE_DICTIONARY or not data.get("ok", false)):
		if _last_error.is_empty():
			_last_error = "CLI exit %d" % code
		return null
	return data


func run_json(args: PackedStringArray) -> Variant:
	_last_error = ""
	var bin := resolve_cli()
	if bin.is_empty():
		return null
	var argv: PackedStringArray = ["--json"]
	argv.append_array(args)
	var output: Array = []
	var code := OS.execute(bin, argv, output, true, false)
	var text := ""
	for line in output:
		if text.is_empty():
			text = str(line)
		else:
			text += "\n" + str(line)
	return parse_json_output(text, code)


func editors() -> Variant:
	return run_json(PackedStringArray(["editors"]))


func install(version: String = "") -> Variant:
	var args := PackedStringArray(["install"])
	if not version.is_empty():
		args.append(version)
	return run_json(args)


func uninstall(version: String) -> Variant:
	return run_json(PackedStringArray(["uninstall", version]))


func install_path(path: String = "") -> Variant:
	if path.is_empty():
		return run_json(PackedStringArray(["install-path"]))
	return run_json(PackedStringArray(["install-path", path]))


func projects() -> Variant:
	return run_json(PackedStringArray(["projects"]))


func projects_add(path: String) -> Variant:
	return run_json(PackedStringArray(["projects", "add", path]))


func projects_remove(path: String) -> Variant:
	return run_json(PackedStringArray(["projects", "remove", path]))


func open_project(path: String) -> Variant:
	return run_json(PackedStringArray(["open", path]))


func load_project(path: String) -> Variant:
	return run_json(PackedStringArray(["load", path]))


func upgrade_dry_run() -> Variant:
	return run_json(PackedStringArray(["upgrade", "--dry-run"]))


func handle_uri(uri: String) -> Variant:
	return run_json(PackedStringArray(["handle-uri", uri]))
