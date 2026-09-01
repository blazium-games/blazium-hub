extends Control

const DATA_COLLECTION_PROMPT := preload("res://scenes/views/data_collection_prompt.tscn")

@onready var nav_projects: Button = %NavProjects
@onready var nav_editors: Button = %NavEditors
@onready var nav_news: Button = %NavNews
@onready var nav_settings: Button = %NavSettings
@onready var pages: TabContainer = %Pages
@onready var status_label: Label = %StatusLabel
@onready var projects_view: Control = %ProjectsView
@onready var editors_view: Control = %EditorsView
@onready var news_view: Control = %NewsView
@onready var settings_view: Control = %SettingsView
@onready var discord_button: Button = %DiscordButton


func _ready() -> void:
	nav_projects.pressed.connect(_select_tab.bind(0))
	nav_editors.pressed.connect(_select_tab.bind(1))
	nav_news.pressed.connect(_select_tab.bind(2))
	nav_settings.pressed.connect(_select_tab.bind(3))
	discord_button.pressed.connect(OS.shell_open.bind("https://discord.gg/XHUTvnxhDR"))
	if HubState:
		HubState.error_message.connect(_on_error)
		HubState.refreshed.connect(_on_refreshed)
	if UriRouter:
		UriRouter.toast.connect(_on_error)
	if HubUpdates:
		HubUpdates.status_changed.connect(_on_error)
	_select_tab(0)
	call_deferred("_initial_refresh")
	call_deferred("_maybe_show_data_collection_prompt")
	DisplayServer.window_set_min_size(Vector2i(800, 520))


func _maybe_show_data_collection_prompt() -> void:
	if HubSettings.data_collection_decided:
		return
	var prompt: ConfirmationDialog = DATA_COLLECTION_PROMPT.instantiate()
	add_child(prompt)
	prompt.consent_given.connect(_on_data_collection_consent)
	prompt.set_anonymous(HubSettings.data_collection_anonymous)


func _on_data_collection_consent(enabled: bool, anonymous: bool) -> void:
	HubSettings.set_data_collection_enabled(enabled)
	HubSettings.set_data_collection_anonymous(anonymous)
	if HubLog:
		HubLog.append("Data collection %s" % ("enabled" if enabled else "disabled"))
		if enabled:
			HubLog.append("Data collection %s" % ("anonymous" if anonymous else "identified"))


func _select_tab(idx: int) -> void:
	pages.current_tab = idx
	nav_projects.set_pressed_no_signal(idx == 0)
	nav_editors.set_pressed_no_signal(idx == 1)
	nav_news.set_pressed_no_signal(idx == 2)
	nav_settings.set_pressed_no_signal(idx == 3)
	if idx == 2 and news_view and news_view.has_method("ensure_loaded"):
		news_view.ensure_loaded()


func _initial_refresh() -> void:
	status_label.text = "Refreshing…"
	HubState.refresh_all()
	if SystemTray and SystemTray.has_method("refresh_menu"):
		SystemTray.refresh_menu()
	status_label.text = "Ready"
	call_deferred("_launch_update_check")


func _launch_update_check() -> void:
	if HubUpdates:
		HubUpdates.check_and_prompt(false)


func _on_error(msg: String) -> void:
	status_label.text = msg
	if HubLog and not msg.is_empty():
		HubLog.append(msg)


func _on_refreshed() -> void:
	if projects_view.has_method("reload"):
		projects_view.reload()
	if editors_view.has_method("reload_installed"):
		editors_view.reload_installed()
	if SystemTray and SystemTray.has_method("refresh_menu"):
		SystemTray.refresh_menu()
	status_label.text = "Ready"
