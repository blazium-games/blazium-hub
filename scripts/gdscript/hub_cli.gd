extends Node
## Runs blazium-cli with --json and parses stdout.

const HubSanitize := preload("res://scripts/gdscript/hub_sanitize.gd")

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
	var p := path.strip_edges()
	if not HubSanitize.is_safe_cli_path(p):
		_last_error = "rejected unsafe CLI path"
		return
	cli_path = p


func get_cli_path() -> String:
	return cli_path


func sidecar_filename_for(os_name: String) -> String:
	# Filename only: Hub never stamps or verifies a sidecar SHA, so the reporter can update independently.
	if os_name == "Windows":
		return "crash_reporter.exe"
	return "crash_reporter"


func sidecar_filename() -> String:
	return sidecar_filename_for(OS.get_name())


func sidecar_path_in(dir: String) -> String:
	var base := dir.strip_edges()
	if base.is_empty():
		return ""
	var p := base.path_join(sidecar_filename())
	if FileAccess.file_exists(p):
		return p
	return ""


func sidecar_path() -> String:
	return sidecar_path_in(OS.get_executable_path().get_base_dir())


func crash_reporter_cli_args_for(dir: String) -> PackedStringArray:
	var p := sidecar_path_in(dir)
	if p.is_empty():
		return PackedStringArray()
	return PackedStringArray(["--crash-reporter", p])


func crash_reporter_cli_args() -> PackedStringArray:
	return crash_reporter_cli_args_for(OS.get_executable_path().get_base_dir())


func data_collection_cli_args() -> PackedStringArray:
	var args := PackedStringArray()
	if HubSettings == null:
		return args
	var consent := HubSettings.editor_analytics_consent()
	if not consent.is_empty():
		args.append("--analytics=%s" % consent)
	var mode := HubSettings.editor_analytics_mode()
	if not mode.is_empty():
		args.append("--analytics-mode=%s" % mode)
	if HubSettings.data_collection_decided and not HubSettings.data_collection_enabled:
		args.append("--no-crash-reporter")
	return args


func _with_editor_launch_args(args: PackedStringArray) -> PackedStringArray:
	args.append_array(data_collection_cli_args())
	if HubSettings == null or HubSettings.should_attach_editor_crash_reporter():
		args.append_array(crash_reporter_cli_args())
	return args


func _with_crash_reporter(args: PackedStringArray) -> PackedStringArray:
	return _with_editor_launch_args(args)


func install_root_from_exe() -> String:
	## Same walk as HubUpdates.install_root() without requiring BLAZIUM.
	var exe := OS.get_executable_path().strip_edges()
	if exe.is_empty():
		return ""
	var base := exe.get_base_dir()
	var leaf := base.get_file().to_lower()
	if leaf == "hub" or leaf == "bin":
		return base.get_base_dir()
	return base


func _append_unique_path(candidates: PackedStringArray, path: String) -> PackedStringArray:
	var p := path.strip_edges()
	if p.is_empty():
		return candidates
	for existing in candidates:
		if existing == p:
			return candidates
	candidates.append(p)
	return candidates


func _append_cli_from_root(candidates: PackedStringArray, root: String, is_win: bool) -> PackedStringArray:
	var r := root.strip_edges()
	if r.is_empty():
		return candidates
	if is_win:
		candidates = _append_unique_path(candidates, r.path_join("blazium-cli.exe"))
		candidates = _append_unique_path(candidates, r.path_join("bin").path_join("blazium-cli.exe"))
	else:
		candidates = _append_unique_path(candidates, r.path_join("bin").path_join("blazium-cli"))
		candidates = _append_unique_path(candidates, r.path_join("blazium-cli"))
	return candidates


func list_cli_candidates() -> PackedStringArray:
	## BLAZIUM, exe-derived install root, exe dir, common paths, then bare PATH names.
	var candidates: PackedStringArray = []
	var is_win := OS.get_name() == "Windows"
	candidates = _append_cli_from_root(candidates, OS.get_environment("BLAZIUM"), is_win)
	candidates = _append_cli_from_root(candidates, install_root_from_exe(), is_win)
	var exe_dir := OS.get_executable_path().get_base_dir()
	if is_win:
		candidates = _append_unique_path(candidates, exe_dir.path_join("blazium-cli.exe"))
		candidates = _append_unique_path(candidates, OS.get_environment("ProgramFiles").path_join("Blazium").path_join("blazium-cli.exe"))
		candidates = _append_unique_path(candidates, OS.get_environment("LOCALAPPDATA").path_join("Blazium").path_join("blazium-cli.exe"))
		candidates = _append_unique_path(candidates, "blazium-cli.exe")
		candidates = _append_unique_path(candidates, "blazium-cli")
	else:
		candidates = _append_unique_path(candidates, exe_dir.path_join("blazium-cli"))
		candidates = _append_unique_path(candidates, "/opt/blazium/bin/blazium-cli")
		candidates = _append_unique_path(candidates, "/usr/local/bin/blazium-cli")
		candidates = _append_unique_path(candidates, "/usr/bin/blazium-cli")
		candidates = _append_unique_path(candidates, OS.get_environment("HOME").path_join(".local/bin/blazium-cli"))
		candidates = _append_unique_path(candidates, "blazium-cli")
	return candidates


func resolve_cli() -> String:
	if not cli_path.is_empty() and HubSanitize.is_safe_cli_path(cli_path) and FileAccess.file_exists(cli_path):
		return cli_path
	if HubSettings:
		var p: String = HubSettings.get_cli_path()
		if not p.is_empty() and HubSanitize.is_safe_cli_path(p) and FileAccess.file_exists(p):
			cli_path = p
			return p
	for c in list_cli_candidates():
		if not HubSanitize.is_safe_cli_path(c):
			continue
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
	if text.length() > HubSanitize.MAX_CLI_JSON_BYTES:
		_last_error = "CLI output too large"
		return null
	var extracted := extract_last_json_text(text)
	var payload := extracted if not extracted.is_empty() else text
	var data: Variant = null
	if payload.begins_with("{") or payload.begins_with("["):
		data = JSON.parse_string(payload)
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


func install_path(path: String = "", move_editors: bool = false) -> Variant:
	if path.is_empty():
		return run_json(PackedStringArray(["install-path"]))
	var args := PackedStringArray(["install-path", path])
	if move_editors:
		args.append("--move")
	return run_json(args)


func projects() -> Variant:
	return run_json(PackedStringArray(["projects"]))


func projects_add(path: String) -> Variant:
	return run_json(PackedStringArray(["projects", "add", path]))


func projects_add_async(path: String) -> Variant:
	return await run_json_async(PackedStringArray(["projects", "add", path]))


func projects_create_async(path: String, project_name: String = "") -> Variant:
	var args := PackedStringArray(["projects", "create", path])
	if not project_name.strip_edges().is_empty():
		args.append("--name")
		args.append(project_name.strip_edges())
	return await run_json_async(args)


func projects_remove(path: String) -> Variant:
	return run_json(PackedStringArray(["projects", "remove", path]))


func projects_remove_async(path: String) -> Variant:
	return await run_json_async(PackedStringArray(["projects", "remove", path]))


func open_project(path: String) -> Variant:
	return run_json(_with_crash_reporter(PackedStringArray(["open", path])))


func open_project_async(path: String) -> Variant:
	return await run_json_async(_with_crash_reporter(PackedStringArray(["open", path])))


func load_project(path: String) -> Variant:
	return run_json(_with_crash_reporter(PackedStringArray(["load", path])))


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


func update_apply_crash_reporter(install_root: String = "") -> Variant:
	var args := PackedStringArray(["update", "apply", "--product", "crash_reporter"])
	if not install_root.is_empty():
		args.append("--install-root")
		args.append(install_root)
	return run_json(args)


func update_apply_crash_reporter_async(install_root: String = "") -> Variant:
	var args := PackedStringArray(["update", "apply", "--product", "crash_reporter"])
	if not install_root.is_empty():
		args.append("--install-root")
		args.append(install_root)
	return await run_json_async(args)


func update_apply_toolchain(install_root: String = "") -> Variant:
	var args := PackedStringArray(["update", "apply", "--product", "toolchain"])
	if not install_root.is_empty():
		args.append("--install-root")
		args.append(install_root)
	return run_json(args)


func update_apply_toolchain_async(install_root: String = "") -> Variant:
	var args := PackedStringArray(["update", "apply", "--product", "toolchain"])
	if not install_root.is_empty():
		args.append("--install-root")
		args.append(install_root)
	return await run_json_async(args)


func templates_download(version: String) -> Variant:
	var args := PackedStringArray(["templates", "download", version, "--tpz"])
	return run_json(args)


func templates_download_async(version: String) -> Variant:
	return await run_json_async(PackedStringArray(["templates", "download", version, "--tpz"]))


func handle_uri(uri: String) -> Variant:
	return run_json(_with_crash_reporter(PackedStringArray(["handle-uri", uri])))
