extends AutoworkTest


func test_012_hub_remote_secret_path_and_token() -> void:
	var path := HubRemoteSecret.resolve_config_path()
	assert_true(path.ends_with("hub_remote.json"), "config path ends with hub_remote.json")
	assert_true(path.contains("blazium"), "config path under blazium dir")

	var machine := HubRemoteSecret.resolve_machine_config_path()
	assert_true(machine.ends_with("hub_remote.json"), "machine path ends with hub_remote.json")
	if OS.get_name() == "Windows":
		assert_true(machine.to_lower().contains("programdata") or machine.contains("blazium"), "windows machine under ProgramData")
	else:
		assert_true(machine.begins_with("/etc/blazium"), "linux machine under /etc/blazium")

	var tok := HubRemoteSecret.generate_token()
	assert_eq(tok.length(), 64, "token is 64 hex chars")
	assert_true(tok.is_valid_hex_number(), "token is hex")


func test_012_hub_remote_secret_autoload_ready() -> void:
	assert_true(HubRemoteSecret != null, "HubRemoteSecret autoload present")
	# Autoload deferred bootstrap should already have run before Autowork tests.
	# If token is still empty (timing), force bootstrap once.
	if str(HubRemoteSecret.get_token()).is_empty():
		HubRemoteSecret._bootstrap()
	assert_false(str(HubRemoteSecret.get_token()).is_empty(), "token populated after bootstrap")
	assert_eq(int(HubRemoteSecret.get_port()), 39218, "default hub remote port")
	assert_true(FileAccess.file_exists(HubRemoteSecret.resolve_config_path()), "hub_remote.json written")

	if not ClassDB.class_exists("RemoteControlServer"):
		return
	var server = Engine.get_singleton("RemoteControlServer")
	assert_true(server != null, "RemoteControlServer singleton")
	if server.has_method("is_started"):
		assert_true(bool(server.is_started()), "Hub remote_control started")
	if ClassDB.class_exists("RemoteControlRegistry"):
		var registry = Engine.get_singleton("RemoteControlRegistry")
		assert_true(
			registry.has_command("show_hub") or registry.has_command("focus_window"),
			"hub focus command registered"
		)


func test_012_hub_remote_path_override_does_not_rotate() -> void:
	var dir := OS.get_environment("TEMP")
	if dir.is_empty():
		dir = OS.get_environment("TMPDIR")
	if dir.is_empty():
		dir = OS.get_environment("HOME")
	if dir.is_empty():
		dir = "."
	dir = dir.path_join("blazium_hub_remote_test_%d" % Time.get_ticks_msec())
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("hub_remote.json")
	var token := "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
	var payload := {
		"host": "127.0.0.1",
		"port": 39218,
		"token": token,
		"created_unix": 1,
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	assert_true(f != null, "wrote override secret file")
	f.store_string(JSON.stringify(payload))
	f.close()

	var prev_override := HubRemoteSecret.path_override
	var prev_token := HubRemoteSecret.token
	var prev_path := HubRemoteSecret.config_path

	# Exercise path override + load-or-keep (do not set ensure_only — that quits the process).
	HubRemoteSecret.path_override = path
	HubRemoteSecret.config_path = HubRemoteSecret.resolve_effective_config_path()
	HubRemoteSecret._ensure_secret_file()

	assert_eq(HubRemoteSecret.config_path, path, "effective path uses override")
	assert_eq(HubRemoteSecret.get_token(), token, "ensure does not rotate existing token")

	# Restore runtime state for later tests.
	HubRemoteSecret.path_override = prev_override
	HubRemoteSecret.token = prev_token
	HubRemoteSecret.config_path = prev_path
	if not str(prev_token).is_empty():
		HubRemoteSecret._apply_project_settings()
