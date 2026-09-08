extends AutoworkTest


func test_015_sidecar_filename_for_os() -> void:
	assert_eq(HubCli.sidecar_filename_for("Windows"), "crash_reporter.exe", "windows name")
	assert_eq(HubCli.sidecar_filename_for("Linux"), "crash_reporter", "linux name")
	assert_eq(HubCli.sidecar_filename_for("macOS"), "crash_reporter", "macos name")


func test_015_project_does_not_require_reporter_sha() -> void:
	var sha := String(ProjectSettings.get_setting("crash_reporter/reporter_sha256", ""))
	assert_eq(sha, "", "sha left empty so the sidecar can update independently")


func test_015_sidecar_path_missing_is_empty() -> void:
	assert_eq(HubCli.sidecar_path_in(""), "", "empty dir")
	assert_eq(HubCli.sidecar_path_in("C:/no-such-hub-sidecar-dir-xyz"), "", "missing dir")
	var args := HubCli.crash_reporter_cli_args_for("C:/no-such-hub-sidecar-dir-xyz")
	assert_eq(args.size(), 0, "no flag when file missing")


func test_015_sidecar_path_and_launch_args_when_present() -> void:
	var dir := OS.get_cache_dir().path_join("hub_sidecar_launch_test")
	DirAccess.make_dir_recursive_absolute(dir)
	var dest := dir.path_join(HubCli.sidecar_filename())
	var f := FileAccess.open(dest, FileAccess.WRITE)
	assert_true(f != null, "wrote sidecar stub")
	f.store_string("ok")
	f.close()
	assert_eq(HubCli.sidecar_path_in(dir), dest, "found next to hub dir")
	var args := HubCli.crash_reporter_cli_args_for(dir)
	assert_eq(args.size(), 2, "flag + path")
	assert_eq(args[0], "--crash-reporter")
	assert_eq(args[1], dest)
	DirAccess.remove_absolute(dest)
	DirAccess.remove_absolute(dir)


func test_015_data_collection_cli_args_accepted() -> void:
	var prev_decided: bool = HubSettings.data_collection_decided
	var prev_enabled: bool = HubSettings.data_collection_enabled
	var prev_anonymous: bool = HubSettings.data_collection_anonymous
	HubSettings.data_collection_decided = true
	HubSettings.data_collection_enabled = true
	HubSettings.data_collection_anonymous = true
	var args := HubCli.data_collection_cli_args()
	assert_eq(args.size(), 2, "consent + mode")
	assert_eq(args[0], "--analytics=accepted")
	assert_eq(args[1], "--analytics-mode=anonymous")
	HubSettings.data_collection_decided = prev_decided
	HubSettings.data_collection_enabled = prev_enabled
	HubSettings.data_collection_anonymous = prev_anonymous


func test_015_data_collection_cli_args_declined() -> void:
	var prev_decided: bool = HubSettings.data_collection_decided
	var prev_enabled: bool = HubSettings.data_collection_enabled
	var prev_anonymous: bool = HubSettings.data_collection_anonymous
	HubSettings.data_collection_decided = true
	HubSettings.data_collection_enabled = false
	var args := HubCli.data_collection_cli_args()
	assert_eq(args.size(), 2, "declined + no sidecar")
	assert_eq(args[0], "--analytics=declined")
	assert_eq(args[1], "--no-crash-reporter")
	var launch := HubCli._with_editor_launch_args(PackedStringArray(["open", "/proj"]))
	assert_eq(launch[0], "open")
	assert_eq(launch[1], "/proj")
	assert_eq(launch[2], "--analytics=declined")
	assert_eq(launch[3], "--no-crash-reporter")
	assert_eq(launch.size(), 4, "declined does not append --crash-reporter")
	HubSettings.data_collection_decided = prev_decided
	HubSettings.data_collection_enabled = prev_enabled
	HubSettings.data_collection_anonymous = prev_anonymous
