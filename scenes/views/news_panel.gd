@tool
class_name NewsPanel
extends PanelContainer

signal open_news(_item: Dictionary)

var focus_style: StyleBoxFlat
var draw_focus_border: bool = false
var item: Dictionary
var mouse_in: bool = false
var press_attempt: bool = false

@export var header: String:
	set(v):
		header = v
		if is_node_ready():
			header_label.text = header

@export var desc: String:
	set(v):
		desc = v
		if is_node_ready():
			desc_label.text = desc

@export var date: String:
	set(v):
		date = v
		if is_node_ready():
			date_label.text = date

@onready var header_label: Label = %HeaderLabel
@onready var desc_label: Label = %DescLabel
@onready var date_label: Label = %DateLabel


func _ready() -> void:
	get_viewport().gui_focus_changed.connect(_on_gui_focus_changed)
	header = header
	desc = desc
	date = date


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			press_attempt = true
		else:
			if press_attempt:
				if mouse_in:
					open_news.emit(item)
				press_attempt = false
		return
	if event.is_action_pressed("ui_accept"):
		open_news.emit(item)
		return


func _draw() -> void:
	if has_focus() or draw_focus_border:
		focus_style.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))


func _on_gui_focus_changed(node: Control):
	if node == self:
		return
	draw_focus_border = is_ancestor_of(node)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		mouse_in = true
	elif what == NOTIFICATION_MOUSE_EXIT:
		mouse_in = false
	elif what == NOTIFICATION_THEME_CHANGED:
		focus_style = get_theme_stylebox("focus", "Button").duplicate()
		focus_style.set_corner_radius_all(8)
		focus_style.set_border_width_all(2)
