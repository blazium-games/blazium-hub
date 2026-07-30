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
