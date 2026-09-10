extends AutoworkTest


func _products_hub_and_cli() -> Array:
	return [
		{"product": "hub", "update_available": true, "current_version": "0.1.0", "latest_version": "0.1.2", "error": ""},
		{"product": "cli", "update_available": true, "current_version": "0.0.40", "latest_version": "0.0.41", "error": ""},
		{"product": "crash_reporter", "update_available": true, "current_version": "0.1.0", "latest_version": "0.1.1", "error": ""},
		{"product": "toolchain", "update_available": true, "current_version": "0.1.0", "latest_version": "0.1.2", "error": ""},
		{"product": "editor", "update_available": false, "error": ""},
		{"product": "templates", "update_available": false, "error": ""},
	]


func _queue_names(queue: Array) -> PackedStringArray:
	var names := PackedStringArray()
	for item in queue:
		names.append(str(item.get("product", "")))
	return names


func test_011_hub_and_cli_queues_hub_only() -> void:
	assert_true(HubUpdates != null, "HubUpdates autoload")
	var queue: Array = HubUpdates.build_update_queue(_products_hub_and_cli(), {})
	var names := _queue_names(queue)
	assert_eq(names.size(), 2, "hub plus unbundled toolchain")
	assert_eq(names[0], "hub", "hub first")
	assert_eq(names[1], "toolchain", "toolchain not suppressed by hub")
	assert_true(HubUpdates.hub_update_outstanding(_products_hub_and_cli()), "hub outstanding")
	assert_true(names.find("cli") < 0, "cli suppressed")
	assert_true(names.find("crash_reporter") < 0, "crash_reporter suppressed")


func test_011_cli_only_when_hub_current() -> void:
	var products: Array = [
		{"product": "hub", "update_available": false, "error": ""},
		{"product": "cli", "update_available": true, "current_version": "0.0.40", "latest_version": "0.0.41", "error": ""},
	]
	var queue: Array = HubUpdates.build_update_queue(products, {})
	var names := _queue_names(queue)
	assert_eq(names.size(), 1, "cli queued")
	assert_eq(names[0], "cli", "cli alone")
	assert_false(HubUpdates.hub_update_outstanding(products), "hub not outstanding")


func test_011_dismissed_hub_still_suppresses_cli() -> void:
	var products := _products_hub_and_cli()
	var dismissed := {"hub": true}
	var queue: Array = HubUpdates.build_update_queue(products, dismissed)
	var names := _queue_names(queue)
	assert_eq(names.size(), 1, "toolchain remains when hub is dismissed")
	assert_eq(names[0], "toolchain", "toolchain not bundled with hub")
	assert_true(names.find("cli") < 0, "cli still suppressed")
	assert_true(names.find("crash_reporter") < 0, "crash_reporter still suppressed")
	assert_true(HubUpdates.hub_update_outstanding(products), "hub still outstanding in catalog")


func test_011_crash_reporter_only_when_hub_current() -> void:
	var products: Array = [
		{"product": "hub", "update_available": false, "error": ""},
		{"product": "crash_reporter", "update_available": true, "current_version": "0.1.0", "latest_version": "0.1.1", "error": ""},
	]
	var names := _queue_names(HubUpdates.build_update_queue(products, {}))
	assert_eq(names.size(), 1, "crash_reporter queued")
	assert_eq(names[0], "crash_reporter", "crash_reporter alone")


func test_011_crash_reporter_prompt_is_not_editor_copy() -> void:
	var body := HubUpdates.prompt_body("crash_reporter", "0.1.1", "0.1.0")
	assert_true(body.contains("Blazium Crash Reporter"), "label")
	assert_true(body.contains("0.1.1"), "latest")
	assert_true(body.contains("0.1.0"), "current")
	assert_true(not body.contains("default editor"), "not editor wording")
	assert_eq(HubUpdates.prompt_title("crash_reporter"), "Blazium Crash Reporter Update Available")
	assert_eq(HubUpdates.prompt_title("hub"), "Blazium Hub Update Available")
	var unknown := HubUpdates.prompt_body("crash_reporter", "0.1.2", "")
	assert_true(unknown.contains("(unknown)"), "empty current stays unknown")


func test_011_editor_still_queued_with_hub() -> void:
	var products: Array = [
		{"product": "hub", "update_available": true, "latest_version": "0.2.0", "error": ""},
		{"product": "cli", "update_available": true, "latest_version": "0.0.41", "error": ""},
		{"product": "crash_reporter", "update_available": true, "latest_version": "0.1.1", "error": ""},
		{"product": "toolchain", "update_available": true, "latest_version": "0.1.2", "error": ""},
		{"product": "editor", "update_available": true, "latest_version": "0.6.725", "error": ""},
	]
	var names := _queue_names(HubUpdates.build_update_queue(products, {}))
	assert_eq(names.size(), 3, "hub + toolchain + editor")
	assert_eq(names[0], "hub")
	assert_eq(names[1], "toolchain")
	assert_eq(names[2], "editor")
	assert_true(names.find("cli") < 0, "cli suppressed")
	assert_true(names.find("crash_reporter") < 0, "crash_reporter suppressed")


func test_011_toolchain_queued_when_hub_outstanding() -> void:
	var products: Array = [
		{"product": "hub", "update_available": true, "latest_version": "0.2.0", "error": ""},
		{"product": "toolchain", "update_available": true, "current_version": "0.1.0", "latest_version": "0.1.2", "error": ""},
	]
	var names := _queue_names(HubUpdates.build_update_queue(products, {}))
	assert_eq(names.size(), 2, "hub and toolchain")
	assert_eq(names[0], "hub")
	assert_eq(names[1], "toolchain")


func test_011_toolchain_prompt_is_not_editor_copy() -> void:
	var body := HubUpdates.prompt_body("toolchain", "0.1.2", "0.1.0")
	assert_true(body.contains("Blazium Toolchain"), "label")
	assert_true(body.contains("0.1.2"), "latest")
	assert_true(not body.contains("default editor"), "not editor wording")


func _products_editor_and_templates(editor_latest: String, templates_latest: String) -> Array:
	return [
		{"product": "hub", "update_available": false, "error": ""},
		{"product": "editor", "update_available": true, "current_version": "0.6.700", "latest_version": editor_latest, "error": ""},
		{"product": "templates", "update_available": true, "current_version": "0.6.700", "latest_version": templates_latest, "error": ""},
	]


func test_011_editor_prompt_is_install_not_update() -> void:
	var body := HubUpdates.prompt_body("editor", "0.6.830", "0.6.700")
	assert_true(body.contains("Blazium editor"), "label")
	assert_true(body.contains("0.6.830"), "latest")
	assert_true(body.contains("0.6.700"), "current")
	assert_true(body.contains("install"), "asks to install")
	assert_true(not body.contains("update"), "does not say update")
	assert_eq(HubUpdates.prompt_title("editor"), "Install Blazium editor")
	assert_eq(HubUpdates.prompt_ok_button("editor"), "Install")
	assert_eq(HubUpdates.prompt_ok_button("hub"), "Update")
	var empty_cur := HubUpdates.prompt_body("editor", "0.6.830", "")
	assert_true(empty_cur.contains("(no default editor)"), "empty current")
	var tpl := HubUpdates.prompt_body("templates", "0.6.830", "0.6.700")
	assert_true(tpl.contains("Install export templates"), "templates install wording")
	assert_true(not tpl.contains("default editor"), "templates not editor-update copy")


func test_011_declined_editor_version_skips_editor_and_templates() -> void:
	var products := _products_editor_and_templates("0.6.830", "0.6.830")
	var names := _queue_names(HubUpdates.build_update_queue(products, {}, ["0.6.830"]))
	assert_eq(names.size(), 0, "declined editor version skips editor and templates")


func test_011_newer_editor_version_still_queued() -> void:
	var products := _products_editor_and_templates("0.6.900", "0.6.900")
	var names := _queue_names(HubUpdates.build_update_queue(products, {}, ["0.6.830"]))
	assert_eq(names.size(), 2, "newer engine still queued")
	assert_eq(names[0], "editor")
	assert_eq(names[1], "templates")


func test_011_session_dismiss_editor_drops_templates() -> void:
	var products := _products_editor_and_templates("0.6.830", "0.6.830")
	var names := _queue_names(HubUpdates.build_update_queue(products, {"editor": true}, []))
	assert_eq(names.size(), 0, "session editor dismiss skips templates")
	assert_true(names.find("templates") < 0, "templates not queued")
