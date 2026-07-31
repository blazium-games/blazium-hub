extends AutoworkTest


func test_007_list_cli_candidates_includes_blazium_env() -> void:
	var prev := OS.get_environment("BLAZIUM")
	OS.set_environment("BLAZIUM", "C:/Program Files/Blazium" if OS.get_name() == "Windows" else "/opt/blazium")
	var candidates: PackedStringArray = HubCli.list_cli_candidates()
	assert_true(candidates.size() >= 2, "has candidates")
	var joined := "\n".join(candidates)
	if OS.get_name() == "Windows":
		assert_true(joined.contains("C:/Program Files/Blazium") or joined.contains("C:\\Program Files\\Blazium"), "BLAZIUM root probed")
		assert_true(joined.contains("blazium-cli.exe"), "windows cli name")
	else:
		assert_true(joined.contains("/opt/blazium/bin/blazium-cli"), "linux BLAZIUM bin")
	assert_true(joined.contains("blazium-cli"), "PATH fallback present")
	# Bare names must be last among duplicates of the same basename class.
	var last: String = candidates[candidates.size() - 1]
	assert_true(last == "blazium-cli" or last == "blazium-cli.exe", "bare PATH name last")
	OS.set_environment("BLAZIUM", prev)


func test_007_packaging_shims_exist() -> void:
	assert_true(FileAccess.file_exists("res://packaging/windows/blazium.cmd"), "blazium.cmd")
	assert_true(FileAccess.file_exists("res://packaging/windows/blazium-hub.cmd"), "blazium-hub.cmd")
	assert_true(FileAccess.file_exists("res://packaging/linux/blazium.sh"), "profile.d blazium.sh")
	assert_true(FileAccess.file_exists("res://ci/smoke_install_linux.sh"), "linux smoke")
	assert_true(FileAccess.file_exists("res://ci/smoke_install_windows.ps1"), "windows smoke")
	var cmd := FileAccess.get_file_as_string("res://packaging/windows/blazium.cmd")
	assert_true(cmd.contains("blazium-cli.exe"), "blazium.cmd forwards to CLI")
	var hub_cmd := FileAccess.get_file_as_string("res://packaging/windows/blazium-hub.cmd")
	assert_true(hub_cmd.contains("BlaziumHub.exe"), "blazium-hub.cmd launches Hub")
	var profile := FileAccess.get_file_as_string("res://packaging/linux/blazium.sh")
	assert_true(profile.contains("BLAZIUM=/opt/blazium"), "sets BLAZIUM")
	assert_true(profile.contains("${BLAZIUM}/bin") or profile.contains("$BLAZIUM/bin"), "prepends bin to PATH")
	var iss := FileAccess.get_file_as_string("res://packaging/windows/blazium-hub.iss")
	assert_true(iss.contains('/DIR='), "documents silent /DIR=")
	assert_true(iss.contains("/LAUNCH"), "documents silent /LAUNCH")
	assert_true(iss.contains("ShouldLaunchAfterSilent"), "silent launch Check helper")
	assert_true(iss.contains("skipifnotsilent"), "silent-only Run entry")
	assert_true(iss.contains("CloseApplications=yes"), "closes Hub for self-update")
	assert_true(iss.contains("ValueData: \"{app}\""), "BLAZIUM uses {app}")
	assert_true(iss.contains("UsePreviousAppDir=yes"), "keeps prior custom dir")
