extends AutoworkTest


func test_004_parse_json_success() -> void:
	var data: Variant = HubCli.parse_json_output('{"editors":[],"ok":true}', 0)
	assert_true(typeof(data) == TYPE_DICTIONARY, "parses object")
	assert_true((data as Dictionary).has("editors"))


func test_004_parse_json_trailing_noise() -> void:
	var text := "note\n{\"ok\":true,\"version\":\"1.0\"}\n"
	var data: Variant = HubCli.parse_json_output(text, 0)
	assert_true(typeof(data) == TYPE_DICTIONARY)
	assert_eq(str((data as Dictionary).get("version", "")), "1.0")


func test_004_parse_json_error_exit() -> void:
	var data: Variant = HubCli.parse_json_output('{"error":"boom"}', 1)
	assert_true(data == null, "error + nonzero exit => null")
	assert_eq(HubCli.get_last_error(), "boom")


func test_004_parse_json_empty() -> void:
	var data: Variant = HubCli.parse_json_output("   ", 0)
	assert_true(data == null)
	assert_true(HubCli.get_last_error().contains("empty"))


func test_004_set_cli_path() -> void:
	HubCli.set_cli_path("  C:/tools/blazium-cli.exe  ")
	assert_eq(HubCli.get_cli_path(), "C:/tools/blazium-cli.exe")
