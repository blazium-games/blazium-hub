@tool
class_name ProjectPanel
extends PanelContainer

signal open_project(_path: String)
signal remove_project(_path: String)
signal favorite_changed(_path: String, favorite: bool)

@export var project_name: String:
	set(v):
		project_name = v
		if is_node_ready():
			project_name_label.text = v

@export var project_path: String:
	set(v):
		project_path = v
		if is_node_ready():
			project_path_label.text = v
			var icon_path: String = project_path.path_join("icon.svg")
			if FileAccess.file_exists(icon_path):
				var _str: String = FileAccess.get_file_as_string(icon_path)
				var image = Image.new()
				image.load_svg_from_string(_str)
				var tex: ImageTexture = ImageTexture.create_from_image(image)
				project_icon_texture_rect.texture = tex

var focus_style: StyleBoxFlat
var draw_focus_border: bool = false
var busy: bool = false:
	set(v):
		busy = v
		if is_node_ready():
			open_project_button.disabled = busy
			project_settings_button.disabled = busy

@onready var project_icon_texture_rect: TextureRect = %ProjectIconTextureRect
@onready var project_name_label: Label = %ProjectNameLabel
@onready var project_path_label: Label = %ProjectPathLabel
@onready var blazium_version_button: OptionButton = %BlaziumVersionButton
@onready var open_project_button: Button = %OpenProjectButton
@onready var project_settings_button: MenuButton = %ProjectSettingsButton
@onready var favorite_button: TextureButton = %FavoriteButton


func _ready() -> void:
	get_viewport().gui_focus_changed.connect(_on_gui_focus_changed)
	project_name = project_name
	project_path = project_path
	busy = busy
	favorite_button.button_pressed = HubSettings.is_favorite_project(project_path)
	favorite_button.toggled.connect(_on_favorite_toggled)
	open_project_button.pressed.connect(_on_open_project_pressed)
	project_settings_button.get_popup().id_pressed.connect(_on_settings_menu_id_pressed)


func _on_favorite_toggled(pressed: bool):
	favorite_changed.emit(project_path, pressed)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		open_project.emit(project_path)


func _draw() -> void:
	if has_focus() or draw_focus_border:
		focus_style.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))


func _on_open_project_pressed():
	open_project.emit(project_path)


func _on_settings_menu_id_pressed(_id: int):
	if _id == 0:
		remove_project.emit(project_path)


func _on_gui_focus_changed(node: Control):
	if node == self:
		return
	draw_focus_border = is_ancestor_of(node)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER:
		pass
	elif what == NOTIFICATION_FOCUS_EXIT:
		pass
	elif what == NOTIFICATION_THEME_CHANGED:
		focus_style = get_theme_stylebox("focus", "Button").duplicate()
		focus_style.set_corner_radius_all(8)
		#focus_style.corner_radius_bottom_right = 0
		focus_style.set_border_width_all(2)
