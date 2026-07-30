extends VBoxContainer

@onready var cli_path_edit: LineEdit = %CliPathEdit
@onready var browse_cli_btn: Button = %BrowseCliBtn
@onready var install_path_edit: LineEdit = %InstallPathEdit
@onready var set_install_btn: Button = %SetInstallPathBtn
@onready var close_tray_check: CheckBox = %CloseToTrayCheck
@onready var check_upgrade_btn: Button = %CheckUpgradeBtn
@onready var status: Label = %SettingsStatus
@onready var cli_dialog: FileDialog = %CliFileDialog


func _ready() -> void:
	cli_path_edit.text = HubSettings.get_cli_path()
	close_tray_check.button_pressed = HubSettings.close_to_tray
	close_tray_check.visible = OS.get_name() == "Windows"
	browse_cli_btn.pressed.connect(func(): cli_dialog.popup_centered_ratio(0.6))
	cli_dialog.file_selected.connect(_on_cli_selected)
	cli_path_edit.text_submitted.connect(_on_cli_submitted)
	set_install_btn.pressed.connect(_on_set_install)
	close_tray_check.toggled.connect(_on_tray_toggled)
	check_upgrade_btn.pressed.connect(_on_upgrade)
	_load_install_path()


func _load_install_path() -> void:
	var data: Variant = HubCli.install_path()
	if typeof(data) == TYPE_DICTIONARY:
		install_path_edit.text = str(data.get("path", data.get("install_path", "")))
	elif typeof(data) == TYPE_STRING:
		install_path_edit.text = str(data)


func _on_cli_selected(path: String) -> void:
	cli_path_edit.text = path
	HubSettings.set_cli_path_value(path)
	status.text = "CLI path saved"


func _on_cli_submitted(text: String) -> void:
	HubSettings.set_cli_path_value(text)
	status.text = "CLI path saved"


func _on_set_install() -> void:
	var path := install_path_edit.text.strip_edges()
	if path.is_empty():
		status.text = "Enter an install path"
		return
	var data: Variant = HubCli.install_path(path)
	if data == null:
		status.text = HubCli.get_last_error()
		return
	status.text = "Install path updated"
	_load_install_path()


func _on_tray_toggled(pressed: bool) -> void:
	HubSettings.close_to_tray = pressed
	HubSettings.save_settings()


func _on_upgrade() -> void:
	status.text = "Checking CLI upgrade…"
	var data: Variant = HubCli.upgrade_dry_run()
	if data == null:
		status.text = HubCli.get_last_error()
		return
	status.text = str(data)
