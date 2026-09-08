extends RefCounted
## Detect Blazium/Godot project roots. Prefer project.blazium, then project.godot.

const FILE_BLAZIUM := "project.blazium"
const FILE_GODOT := "project.godot"

const PROJECT_FILE_FILTERS: PackedStringArray = [
	"project.blazium, project.godot ; Blazium / Godot project",
	"*.blazium, *.godot ; Project settings",
]


static func is_project_settings_file(path: String) -> bool:
	var name: String = path.get_file()
	return name == FILE_BLAZIUM or name == FILE_GODOT


static func settings_file_name(dir: String) -> String:
	if dir.is_empty():
		return ""
	if FileAccess.file_exists(dir.path_join(FILE_BLAZIUM)):
		return FILE_BLAZIUM
	if FileAccess.file_exists(dir.path_join(FILE_GODOT)):
		return FILE_GODOT
	return ""


static func is_project_dir(dir: String) -> bool:
	return not settings_file_name(dir).is_empty()


static func dir_from_path(path: String) -> String:
	var trimmed: String = path.strip_edges()
	if trimmed.is_empty():
		return ""
	if DirAccess.dir_exists_absolute(trimmed) and is_project_dir(trimmed):
		return trimmed
	if is_project_settings_file(trimmed) and is_project_dir(trimmed.get_base_dir()):
		return trimmed.get_base_dir()
	if is_project_dir(trimmed.get_base_dir()):
		return trimmed.get_base_dir()
	return ""
