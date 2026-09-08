extends AutoworkTest


func test_016_required_res_paths_exist() -> void:
	assert_true(HubSelfTest != null, "HubSelfTest autoload present")
	for p in HubSelfTest.REQUIRED_PATHS:
		assert_true(ResourceLoader.exists(p) or FileAccess.file_exists(p), "exists %s" % p)
		var loaded := ResourceLoader.load(p)
		assert_true(loaded != null, "load %s" % p)
	if ClassDB.class_exists("FastNoiseLite"):
		var main := ResourceLoader.load("res://scenes/main.tscn")
		assert_true(main != null, "main.tscn loads when FastNoiseLite exists")


func test_016_parser_recognizes_self_test_flag() -> void:
	assert_true(HubSelfTest.cmdline_has_self_test(PackedStringArray(["--self-test"])), "bare flag")
	assert_true(
		HubSelfTest.cmdline_has_self_test(PackedStringArray(["--headless", "--self-test", "--quit"])),
		"flag among others"
	)
	assert_false(HubSelfTest.cmdline_has_self_test(PackedStringArray(["--headless", "--quit"])), "no flag")
	assert_false(HubSelfTest.cmdline_has_self_test(PackedStringArray(["--self-test-extra"])), "prefix is not the flag")
	assert_false(HubSelfTest.active, "Autowork run is not a self-test")


func test_016_single_instance_skips_when_self_test_active() -> void:
	var prev: bool = HubSelfTest.active
	HubSelfTest.active = true
	assert_true(SingleInstance._skip_for_autowork(), "self-test skips TCP lock")
	HubSelfTest.active = prev
	assert_true(SingleInstance._skip_for_autowork(), "Autowork still skips TCP lock")
