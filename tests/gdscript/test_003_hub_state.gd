extends AutoworkTest


func test_003_normalize_editors_payload() -> void:
	var from_editors: Array = HubState.normalize_list_payload({"editors": [{"version": "1"}]}, "editors")
	assert_eq(from_editors.size(), 1)
	assert_eq(str(from_editors[0]["version"]), "1")

	var from_items: Array = HubState.normalize_list_payload({"items": [{"version": "2"}]}, "editors")
	assert_eq(from_items.size(), 1)
	assert_eq(str(from_items[0]["version"]), "2")

	var from_array: Array = HubState.normalize_list_payload([{"version": "3"}], "editors")
	assert_eq(from_array.size(), 1)

	assert_eq(HubState.normalize_list_payload({}, "editors").size(), 0)
	assert_eq(HubState.normalize_list_payload(null, "editors").size(), 0)
	assert_eq(HubState.normalize_list_payload("x", "editors").size(), 0)


func test_003_normalize_projects_and_recent() -> void:
	var projects: Array = HubState.normalize_list_payload(
		{"projects": [{"path": "a"}, {"path": "b"}, {"path": "c"}]},
		"projects"
	)
	assert_eq(projects.size(), 3)
	HubState.projects_list = projects
	var recent: Array = HubState.recent_projects(2)
	assert_eq(recent.size(), 2)
	assert_eq(str(recent[0]["path"]), "a")
