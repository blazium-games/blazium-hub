extends AutoworkTest
## Load and smoke-test companion Luau scripts (scripts/luau/*).


func _luau_ready() -> bool:
	if not ClassDB.class_exists("LuauScript"):
		pending("LuauScript not available (luau_module disabled)")
		return false
	return true


func _instantiate_luau(path: String) -> Node:
	var script: Resource = ResourceLoader.load(path)
	if script == null:
		assert_true(false, "%s loads" % path)
		return null
	assert_true(script != null, "%s loads" % path)
	assert_eq(script.get_class(), "LuauScript", "%s is LuauScript" % path)
	var base: String = str(script.get_instance_base_type())
	if base.is_empty():
		base = "Node"
	var node: Node = null
	if ClassDB.class_exists(base):
		node = ClassDB.instantiate(base) as Node
	if node == null:
		assert_true(false, "%s instantiates base %s" % [path, base])
		return null
	node.set_script(script)
	assert_true(node.get_script() != null, "%s script attached" % path)
	return node


func test_010_hub_cli_luau() -> void:
	if not _luau_ready():
		return
	var node := _instantiate_luau("res://scripts/luau/hub_cli.luau")
	if node == null:
		return
	add_child_autofree(node)
	assert_true(node.has_method("set_cli_path"), "set_cli_path")
	assert_true(node.has_method("resolve_cli"), "resolve_cli")
	assert_true(node.has_method("list_cli_candidates"), "list_cli_candidates")
	assert_true(node.has_method("install_root_from_exe"), "install_root_from_exe")
	assert_true(node.has_method("handle_uri"), "handle_uri")
	assert_true(node.has_method("editors"), "editors")
	assert_true(node.has_method("data_collection_cli_args"), "data_collection_cli_args")
	assert_true(node.has_method("_with_editor_launch_args"), "_with_editor_launch_args")
	node.call("set_cli_path", "C:/fake/blazium-cli.exe")
	assert_eq(str(node.call("get_cli_path")), "C:/fake/blazium-cli.exe")


func test_010_hub_state_luau() -> void:
	if not _luau_ready():
		return
	var node := _instantiate_luau("res://scripts/luau/hub_state.luau")
	if node == null:
		return
	add_child_autofree(node)
	assert_true(node.has_method("refresh_all"), "refresh_all")


func test_010_cdn_client_luau() -> void:
	if not _luau_ready():
		return
	var node := _instantiate_luau("res://scripts/luau/cdn_client.luau")
	if node == null:
		return
	add_child_autofree(node)
	assert_true(node.has_method("latest"), "latest")
	assert_true(node.has_method("versions"), "versions")
	assert_true(node.has_method("editors_for"), "editors_for")
	assert_true(node.has_method("latest_path"), "latest_path")
	assert_eq(str(node.call("latest_path", "release")), "/catalog/versions/release/latest.json")


func test_010_uri_router_luau() -> void:
	if not _luau_ready():
		return
	var node := _instantiate_luau("res://scripts/luau/uri_router.luau")
	if node == null:
		return
	add_child_autofree(node)
	assert_true(node.has_method("handle_uri"), "handle_uri")
	assert_true(node.has_method("is_hub_show_uri"), "is_hub_show_uri")
	assert_true(bool(node.call("is_hub_show_uri", "blazium://hub")), "luau hub uri")
	assert_false(bool(node.call("is_hub_show_uri", "blazium://open?path=x")), "luau open uri")
	assert_false(
		bool(node.call("is_hub_show_uri", "blazium://register?path=x&version=1")),
		"luau register uri"
	)
