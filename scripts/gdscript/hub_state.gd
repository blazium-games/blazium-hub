extends Node
## Cached installed editors / projects from blazium-cli.

signal refreshed()
signal error_message(msg: String)

var installed_editors: Array = []
var projects_list: Array = []
var status_text: String = ""


static func normalize_list_payload(data: Variant, primary_key: String) -> Array:
	if typeof(data) == TYPE_DICTIONARY:
		if data.has(primary_key) and typeof(data[primary_key]) == TYPE_ARRAY:
			return data[primary_key]
		if data.has("items") and typeof(data["items"]) == TYPE_ARRAY:
			return data["items"]
		return []
	if typeof(data) == TYPE_ARRAY:
		return data
	return []


func refresh_editors() -> void:
	var data: Variant = HubCli.editors()
	if data == null:
		error_message.emit(HubCli.get_last_error())
		return
	installed_editors = normalize_list_payload(data, "editors")
	refreshed.emit()


func refresh_projects() -> void:
	var data: Variant = HubCli.projects()
	if data == null:
		error_message.emit(HubCli.get_last_error())
		return
	projects_list = normalize_list_payload(data, "projects")
	refreshed.emit()


func refresh_all() -> void:
	refresh_editors()
	refresh_projects()


func recent_projects(limit: int = 8) -> Array:
	var out: Array = []
	for p in projects_list:
		out.append(p)
		if out.size() >= limit:
			break
	return out
