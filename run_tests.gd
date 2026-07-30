extends SceneTree
## Headless Autowork entry: GDScript + Luau Hub suites.


func _initialize() -> void:
	if not ClassDB.class_exists("Autowork"):
		push_error("Autowork module is required (use a Blazium editor build with module_autowork_enabled=yes)")
		quit(1)
		return

	var autowork = ClassDB.instantiate("Autowork")
	root.add_child(autowork)

	# .autoworkconfig.json collects res://tests/gdscript (*.gd).
	# Luau AutoworkTest scripts (pure logic + require) when Luau is available.
	if ClassDB.class_exists("LuauScript") or ClassDB.class_exists("LuauScriptLanguage"):
		autowork.add_directory("res://tests/luau", "test_", ".luau")

	autowork.run_tests()
	var fails: int = autowork.get_fail_count()
	print("Autowork done: pass=%d fail=%d pending=%d" % [
		autowork.get_pass_count(), fails, autowork.get_pending_count()
	])
	quit(fails)