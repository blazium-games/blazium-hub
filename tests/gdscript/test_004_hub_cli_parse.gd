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


func test_004_parse_json_stderr_progress_pretty() -> void:
	## Real blazium-cli install: progress on stderr, pretty JSON on stdout (merged by OS.execute).
	var text := """Downloading https://cdn.blazium.app/release/0.6.725/BlaziumEditor_v0.6.725_windows.64bit.zip
Installing to C:/Users/Bioblaze/AppData/Local/Blazium/Editors/0.6.725
{
  "arch": "x86_64",
  "channel": "release",
  "ok": true,
  "version": "0.6.725"
}
"""
	var data: Variant = HubCli.parse_json_output(text, 0)
	assert_true(typeof(data) == TYPE_DICTIONARY, "parses pretty JSON after progress")
	assert_eq(str((data as Dictionary).get("version", "")), "0.6.725")
	assert_true(bool((data as Dictionary).get("ok", false)))


func test_004_extract_last_json_text() -> void:
	var blob := "Downloading x\n{\n  \"ok\": true\n}\n"
	var got := HubCli.extract_last_json_text(blob)
	assert_true(got.contains("\"ok\""), "extracts object")
	assert_true(JSON.parse_string(got) != null)


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
