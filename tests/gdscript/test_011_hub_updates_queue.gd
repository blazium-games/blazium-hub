extends AutoworkTest


func _products_hub_and_cli() -> Array:
	return [
		{"product": "hub", "update_available": true, "current_version": "0.1.0", "latest_version": "0.1.2", "error": ""},
		{"product": "cli", "update_available": true, "current_version": "0.0.40", "latest_version": "0.0.41", "error": ""},
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
	assert_eq(names.size(), 1, "only hub queued")
	assert_eq(names[0], "hub", "hub first/only")
	assert_true(HubUpdates.hub_update_outstanding(_products_hub_and_cli()), "hub outstanding")


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
	assert_eq(queue.size(), 0, "no hub (dismissed) and no cli")
	assert_true(HubUpdates.hub_update_outstanding(products), "hub still outstanding in catalog")


func test_011_editor_still_queued_with_hub() -> void:
	var products: Array = [
		{"product": "hub", "update_available": true, "latest_version": "0.2.0", "error": ""},
		{"product": "cli", "update_available": true, "latest_version": "0.0.41", "error": ""},
		{"product": "editor", "update_available": true, "latest_version": "0.6.725", "error": ""},
	]
	var names := _queue_names(HubUpdates.build_update_queue(products, {}))
	assert_eq(names.size(), 2, "hub + editor")
	assert_eq(names[0], "hub")
	assert_eq(names[1], "editor")
	assert_true(names.find("cli") < 0, "cli suppressed")
