extends SceneTree
## Headless Autowork entry: GDScript + Luau Hub suites.


func _initialize() -> void:
	if not ClassDB.class_exists("Autowork"):
		push_error("Autowork module is required (use a Blazium editor build with module_autowork_enabled=yes)")
		quit(1)
		return

	var autowork = ClassDB.instantiate("Autowork")
	root.add_child(autowork)

	# Apply .autoworkconfig.json before extra dirs so include_subdirs is set first.
	# Config suffix is .gd only; Luau is added below with its own suffix.
	if ClassDB.class_exists("AutoworkConfig"):
		var cfg = ClassDB.instantiate("AutoworkConfig")
		cfg.load_options("res://.autoworkconfig.json")
		cfg.apply_options(autowork)

	# Luau AutoworkTest scripts (pure logic + require) when Luau is available.
	if ClassDB.class_exists("LuauScript") or ClassDB.class_exists("LuauScriptLanguage"):
		autowork.add_directory("res://tests/luau", "test_", ".luau")

	autowork.run_tests()
	var fails: int = autowork.get_fail_count()
	print("Autowork done: pass=%d fail=%d pending=%d" % [
		autowork.get_pass_count(), fails, autowork.get_pending_count()
	])
	quit(fails)