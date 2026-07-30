extends Control

@onready var nav_projects: Button = %NavProjects
@onready var nav_editors: Button = %NavEditors
@onready var nav_settings: Button = %NavSettings
@onready var pages: TabContainer = %Pages
@onready var status_label: Label = %StatusLabel
@onready var projects_view: Control = %ProjectsView
@onready var editors_view: Control = %EditorsView
@onready var settings_view: Control = %SettingsView


func _ready() -> void:
	nav_projects.pressed.connect(func(): pages.current_tab = 0)
	nav_editors.pressed.connect(func(): pages.current_tab = 1)
	nav_settings.pressed.connect(func(): pages.current_tab = 2)
	if HubState:
		HubState.error_message.connect(_on_error)
		HubState.refreshed.connect(_on_refreshed)
	if UriRouter:
		UriRouter.toast.connect(_on_error)
	call_deferred("_initial_refresh")


func _initial_refresh() -> void:
	status_label.text = "Refreshing…"
	HubState.refresh_all()
	if SystemTray and SystemTray.has_method("refresh_menu"):
		SystemTray.refresh_menu()
	status_label.text = "Ready"


func _on_error(msg: String) -> void:
	status_label.text = msg


func _on_refreshed() -> void:
	if projects_view.has_method("reload"):
		projects_view.reload()
	if editors_view.has_method("reload_installed"):
		editors_view.reload_installed()
	if SystemTray and SystemTray.has_method("refresh_menu"):
		SystemTray.refresh_menu()
	status_label.text = "Ready"
