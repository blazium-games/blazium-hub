extends AutoworkTest


func test_015_sidecar_filename_for_os() -> void:
	assert_eq(HubCli.sidecar_filename_for("Windows"), "crash_reporter.exe", "windows name")
	assert_eq(HubCli.sidecar_filename_for("Linux"), "crash_reporter", "linux name")
	assert_eq(HubCli.sidecar_filename_for("macOS"), "crash_reporter", "macos name")


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
