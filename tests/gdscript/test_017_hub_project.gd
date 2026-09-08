extends AutoworkTest

const HubProject = preload("res://scripts/gdscript/hub_project.gd")


func test_017_settings_file_prefers_blazium() -> void:
	var dir := DirAccess.create_temp("hub_project_")
	assert_true(dir != null, "temp dir")
	var path: String = dir.get_current_dir()
	assert_eq(HubProject.settings_file_name(path), "")
	assert_false(HubProject.is_project_dir(path))
	_write(path.path_join("project.godot"), "config/name=\"GodotOnly\"\n")
	assert_eq(HubProject.settings_file_name(path), "project.godot")
	assert_true(HubProject.is_project_dir(path))
	_write(path.path_join("project.blazium"), "config/name=\"BlaziumWins\"\n")
	assert_eq(HubProject.settings_file_name(path), "project.blazium")
	assert_eq(HubProject.dir_from_path(path.path_join("project.blazium")), path)
	assert_eq(HubProject.dir_from_path(path.path_join("project.godot")), path)
	assert_true(HubProject.is_project_settings_file("C:/game/project.blazium"))
	assert_true(HubProject.is_project_settings_file("/tmp/project.godot"))
	assert_false(HubProject.is_project_settings_file("/tmp/my_project.godot"))
	assert_false(HubProject.is_project_settings_file(path.path_join("icon.svg")))
	_cleanup_temp(path)


func test_017_add_dialog_accepts_blazium_and_godot() -> void:
	var scene := FileAccess.get_file_as_string("res://scenes/views/projects.tscn")
	assert_true(scene.contains("project.blazium"), "dialog lists project.blazium")
	assert_true(scene.contains("project.godot"), "dialog lists project.godot")
	assert_true(scene.contains("*.blazium"), "dialog lists *.blazium")
	assert_true(scene.contains("*.godot"), "dialog lists *.godot")
	var view := FileAccess.get_file_as_string("res://scripts/gdscript/projects_view.gd")
	assert_true(view.contains("HubProject.is_project_dir"), "scan uses shared detector")
	assert_true(view.contains("HubProject.dir_from_path"), "add uses shared detector")
	assert_true(FileAccess.file_exists("res://scripts/gdscript/hub_project.gd"), "detector script")
	assert_true(ResourceLoader.load("res://scripts/gdscript/hub_project.gd") != null, "load detector")


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	assert_true(f != null, "write %s" % path)
	f.store_string(text)
	f.close()


func _cleanup_temp(path: String) -> void:
	DirAccess.remove_absolute(path.path_join("project.godot"))
	DirAccess.remove_absolute(path.path_join("project.blazium"))
	DirAccess.remove_absolute(path)
