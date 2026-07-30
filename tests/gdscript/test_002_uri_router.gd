extends AutoworkTest


func test_002_hub_show_uri_classification() -> void:
	assert_true(UriRouter.is_hub_show_uri("blazium://"), "bare blazium://")
	assert_true(UriRouter.is_hub_show_uri("blazium:"), "bare blazium:")
	assert_true(UriRouter.is_hub_show_uri("blazium://hub"), "hub")
	assert_true(UriRouter.is_hub_show_uri("BLAZIUM://HUB"), "case insensitive")
	assert_true(UriRouter.is_hub_show_uri("blazium://hub?x=1"), "hub with query")
	assert_false(UriRouter.is_hub_show_uri(""), "empty")
	assert_false(UriRouter.is_hub_show_uri("blazium://open?path=C:/game"), "open is not hub-show")
	assert_false(UriRouter.is_hub_show_uri("blazium://install?version=1"), "install is not hub-show")
	assert_false(UriRouter.is_hub_show_uri("https://blazium.app"), "https not hub")


func test_002_handle_hub_uri_emits_ok() -> void:
	# Array wrapper so the lambda can mutate captured state (GDScript closure caveat).
	var seen: Array = [{}]
	var cb := func(result: Dictionary) -> void:
		seen[0] = result
	UriRouter.uri_handled.connect(cb)
	UriRouter.handle_uri("blazium://hub")
	UriRouter.uri_handled.disconnect(cb)
	var payload: Dictionary = seen[0]
	assert_true(payload.get("ok", false), "hub URI ok")
	assert_eq(str(payload.get("action", "")), "hub", "action is hub")
