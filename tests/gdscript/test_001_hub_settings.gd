extends AutoworkTest


func test_001_settings_defaults_and_persist() -> void:
	assert_true(HubSettings != null, "HubSettings autoload")
	HubSettings.cli_path = ""
	HubSettings.minimize_to_tray = true
	HubSettings.close_to_tray = true
	HubSettings.save_settings()

	HubSettings.cli_path = "C:/fake/blazium-cli.exe"
	HubSettings.minimize_to_tray = false
	HubSettings.close_to_tray = false
	HubSettings.save_settings()

	HubSettings.cli_path = ""
	HubSettings.minimize_to_tray = true
	HubSettings.close_to_tray = true
	HubSettings.load_settings()

	assert_eq(HubSettings.get_cli_path(), "C:/fake/blazium-cli.exe", "cli_path round-trips")
	assert_false(HubSettings.minimize_to_tray, "minimize_to_tray round-trips")
	assert_false(HubSettings.close_to_tray, "close_to_tray round-trips")

	HubSettings.set_cli_path_value("")
	assert_eq(HubSettings.get_cli_path(), "", "set_cli_path_value clears")


func test_001_declined_editor_versions_round_trip() -> void:
	var prev: Array = HubSettings.get_declined_editor_versions()
	HubSettings.declined_editor_versions.clear()
	HubSettings.save_settings()
	HubSettings.add_declined_editor_version("0.6.830")
	assert_true(HubSettings.has_declined_editor_version("0.6.830"), "records declined version")
	HubSettings.add_declined_editor_version("0.6.830")
	assert_eq(HubSettings.get_declined_editor_versions().size(), 1, "dedupes same version")
	HubSettings.declined_editor_versions.clear()
	HubSettings.load_settings()
	assert_true(HubSettings.has_declined_editor_version("0.6.830"), "declined versions persist")
	HubSettings.declined_editor_versions.clear()
	for v: Variant in prev:
		HubSettings.declined_editor_versions.append(str(v))
	HubSettings.save_settings()


func test_001_auto_accept_quit_disabled() -> void:
	assert_false(bool(ProjectSettings.get_setting("application/config/auto_accept_quit", true)), "close-to-tray requires auto_accept_quit off")
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		assert_false((loop as SceneTree).auto_accept_quit, "runtime auto_accept_quit stays off")


func test_001_data_collection_editor_args() -> void:
	var prev_decided: bool = HubSettings.data_collection_decided
	var prev_enabled: bool = HubSettings.data_collection_enabled
	var prev_anonymous: bool = HubSettings.data_collection_anonymous

	HubSettings.data_collection_decided = false
	HubSettings.data_collection_enabled = false
	HubSettings.data_collection_anonymous = true
	assert_eq(HubSettings.editor_analytics_consent(), "", "undecided omits analytics")
	assert_eq(HubSettings.editor_analytics_mode(), "", "undecided omits mode")
	assert_true(HubSettings.should_attach_editor_crash_reporter(), "undecided still attaches sidecar")

	HubSettings.set_data_collection_enabled(true)
	HubSettings.set_data_collection_anonymous(true)
	assert_eq(HubSettings.editor_analytics_consent(), "accepted", "accepted consent")
	assert_eq(HubSettings.editor_analytics_mode(), "anonymous", "anonymous mode")
	assert_true(HubSettings.has_data_collection_consent(), "consent granted")
	assert_true(HubSettings.should_attach_editor_crash_reporter(), "accepted attaches sidecar")

	HubSettings.set_data_collection_anonymous(false)
	assert_eq(HubSettings.editor_analytics_mode(), "identified", "identified mode")

	HubSettings.set_data_collection_enabled(false)
	assert_eq(HubSettings.editor_analytics_consent(), "declined", "declined consent")
	assert_eq(HubSettings.editor_analytics_mode(), "", "declined omits mode")
	assert_false(HubSettings.should_attach_editor_crash_reporter(), "declined skips sidecar")
	assert_false(HubSettings.has_data_collection_consent(), "consent revoked")

	HubSettings.data_collection_decided = prev_decided
	HubSettings.data_collection_enabled = prev_enabled
	HubSettings.data_collection_anonymous = prev_anonymous
	HubSettings.save_settings()
