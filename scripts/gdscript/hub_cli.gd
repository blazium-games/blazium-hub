extends Node
## Runs blazium-cli with --json and parses stdout.

signal command_finished(ok: bool, data: Variant, error: String)

var cli_path: String = ""
var _last_error: String = ""
var _async_busy: bool = false
var _async_mutex := Mutex.new()
var _async_done: bool = false
var _async_exec: Dictionary = {}
var _async_thread: Thread


func get_last_error() -> String:
	return _last_error


func is_busy() -> bool:
	return _async_busy


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
	if HubLog:
		HubLog.append("ERROR: %s" % _last_error)
	return ""


## Find the last top-level JSON object/array in mixed stdout+stderr text.
func extract_last_json_text(text: String) -> String:
	var s := text.strip_edges()
	if s.is_empty():
		return ""
	var end := -1
	for i in range(s.length() - 1, -1, -1):
		var ch := s[i]
		if ch == "}" or ch == "]":
			end = i
			break
	if end < 0:
		return ""
	var open_ch := "{" if s[end] == "}" else "["
	var close_ch := s[end]
	var depth := 0
	var in_str := false
	var escape := false
	for i in range(end, -1, -1):
		var ch := s[i]
		if in_str:
			if escape:
				escape = false
			elif ch == "\\":
				escape = true
			elif ch == "\"":
				in_str = false
			continue
		if ch == "\"":
			in_str = true
			continue
		if ch == close_ch:
			depth += 1
		elif ch == open_ch:
			depth -= 1
			if depth == 0:
				return s.substr(i, end - i + 1)
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
		if not lines.is_empty():
			data = JSON.parse_string(lines[lines.size() - 1])
	if data == null:
		var extracted := extract_last_json_text(text)
		if not extracted.is_empty():
			data = JSON.parse_string(extracted)
	if data == null:
		_last_error = "failed to parse JSON (see Logs): %s" % text.substr(0, 200)
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


## Pure OS.execute — safe to call from a worker thread (no HubLog/UI).
func _execute_json(bin: String, argv: PackedStringArray) -> Dictionary:
	var output: Array = []
	var code := OS.execute(bin, argv, output, true, false)
	var text := ""
	for line in output:
		if text.is_empty():
			text = str(line)
		else:
			text += "\n" + str(line)
	return {"code": code, "text": text, "bin": bin, "argv": argv}


func _finish_execute(exec: Dictionary) -> Variant:
	var code: int = int(exec.get("code", 1))
	var text: String = str(exec.get("text", ""))
	var bin: String = str(exec.get("bin", ""))
	var argv_var: Variant = exec.get("argv", PackedStringArray())
	var argv: PackedStringArray = argv_var if typeof(argv_var) == TYPE_PACKED_STRING_ARRAY else PackedStringArray()
	var joined_args := " ".join(argv)
	if HubLog:
		HubLog.append_block("CLI %s %s (exit %d)" % [bin, joined_args, code], text)
	var data: Variant = parse_json_output(text, code)
	if data == null and HubLog and not _last_error.is_empty():
		HubLog.append("ERROR: %s" % _last_error)
	var ok := data != null
	command_finished.emit(ok, data, _last_error)
	return data


func run_json(args: PackedStringArray) -> Variant:
	_last_error = ""
	var bin := resolve_cli()
	if bin.is_empty():
		return null
	var argv: PackedStringArray = ["--json"]
	argv.append_array(args)
	return _finish_execute(_execute_json(bin, argv))


func _async_worker(bin: String, argv: PackedStringArray) -> void:
	var exec: Dictionary = _execute_json(bin, argv)
	_async_mutex.lock()
	_async_exec = exec
	_async_done = true
	_async_mutex.unlock()


## Run blazium-cli off the main thread so the Hub UI stays responsive.
func run_json_async(args: PackedStringArray) -> Variant:
	if _async_busy:
		_last_error = "Another CLI operation is already running"
		if HubLog:
			HubLog.append("ERROR: %s" % _last_error)
		return null
	_last_error = ""
	var bin := resolve_cli()
	if bin.is_empty():
		return null
	var argv: PackedStringArray = ["--json"]
	argv.append_array(args)
	_async_busy = true
	_async_mutex.lock()
	_async_done = false
	_async_exec = {}
	_async_mutex.unlock()
	_async_thread = Thread.new()
	_async_thread.start(_async_worker.bind(bin, argv))
	while true:
		_async_mutex.lock()
		var done := _async_done
		_async_mutex.unlock()
		if done:
			break
		await get_tree().process_frame
	_async_thread.wait_to_finish()
	_async_thread = null
	_async_mutex.lock()
	var exec: Dictionary = _async_exec.duplicate(true)
	_async_mutex.unlock()
	_async_busy = false
	return _finish_execute(exec)


func editors() -> Variant:
	return run_json(PackedStringArray(["editors"]))


func install(version: String = "", channel: String = "") -> Variant:
	var args := PackedStringArray(["install"])
	if not version.is_empty():
		args.append(version)
	if not channel.strip_edges().is_empty():
		args.append("--channel")
		args.append(channel.strip_edges())
	return run_json(args)


func install_async(version: String = "", channel: String = "") -> Variant:
	var args := PackedStringArray(["install"])
	if not version.is_empty():
		args.append(version)
	if not channel.strip_edges().is_empty():
		args.append("--channel")
		args.append(channel.strip_edges())
	return await run_json_async(args)


func uninstall(version: String, channel: String = "") -> Variant:
	var args := PackedStringArray(["uninstall", version])
	if not channel.strip_edges().is_empty():
		args.append("--channel")
		args.append(channel.strip_edges())
	return run_json(args)


func uninstall_async(version: String, channel: String = "") -> Variant:
	var args := PackedStringArray(["uninstall", version])
	if not channel.strip_edges().is_empty():
		args.append("--channel")
		args.append(channel.strip_edges())
	return await run_json_async(args)


func install_path(path: String = "") -> Variant:
	if path.is_empty():
		return run_json(PackedStringArray(["install-path"]))
	return run_json(PackedStringArray(["install-path", path]))


func projects() -> Variant:
	return run_json(PackedStringArray(["projects"]))


func projects_add(path: String) -> Variant:
	return run_json(PackedStringArray(["projects", "add", path]))


func projects_add_async(path: String) -> Variant:
	return await run_json_async(PackedStringArray(["projects", "add", path]))


func projects_remove(path: String) -> Variant:
	return run_json(PackedStringArray(["projects", "remove", path]))


func projects_remove_async(path: String) -> Variant:
	return await run_json_async(PackedStringArray(["projects", "remove", path]))


func open_project(path: String) -> Variant:
	return run_json(PackedStringArray(["open", path]))


func open_project_async(path: String) -> Variant:
	return await run_json_async(PackedStringArray(["open", path]))


func load_project(path: String) -> Variant:
	return run_json(PackedStringArray(["load", path]))


func upgrade_dry_run() -> Variant:
	return run_json(PackedStringArray(["upgrade", "--dry-run"]))


func update_check(product: String = "all", hub_current: String = "", install_root: String = "") -> Variant:
	var args := PackedStringArray(["update", "check", "--product", product])
	if not hub_current.is_empty():
		args.append("--current")
		args.append(hub_current)
	if not install_root.is_empty():
		args.append("--install-root")
		args.append(install_root)
	return run_json(args)


func update_apply_cli() -> Variant:
	return run_json(PackedStringArray(["update", "apply", "--product", "cli"]))


func update_apply_cli_async() -> Variant:
	return await run_json_async(PackedStringArray(["update", "apply", "--product", "cli"]))


func update_apply_hub(current_version: String = "", install_root: String = "", launch: bool = false) -> Variant:
	var args := PackedStringArray(["update", "apply", "--product", "hub"])
	if not current_version.is_empty():
		args.append("--current")
		args.append(current_version)
	if not install_root.is_empty():
		args.append("--install-root")
		args.append(install_root)
	if launch:
		args.append("--launch")
	return run_json(args)


func update_apply_hub_async(current_version: String = "", install_root: String = "", launch: bool = false) -> Variant:
	var args := PackedStringArray(["update", "apply", "--product", "hub"])
	if not current_version.is_empty():
		args.append("--current")
		args.append(current_version)
	if not install_root.is_empty():
		args.append("--install-root")
		args.append(install_root)
	if launch:
		args.append("--launch")
	return await run_json_async(args)


func templates_download(version: String) -> Variant:
	var args := PackedStringArray(["templates", "download", version, "--tpz"])
	return run_json(args)


func templates_download_async(version: String) -> Variant:
	return await run_json_async(PackedStringArray(["templates", "download", version, "--tpz"]))


func handle_uri(uri: String) -> Variant:
	return run_json(PackedStringArray(["handle-uri", uri]))
