extends ConfirmationDialog

signal consent_given(enabled: bool, anonymous: bool)

const MAX_WIDTH := 620
const MAX_HEIGHT := 460
const MIN_WIDTH := 480

const INFO_TEXT: String = "We'd like to collect a little bit of data to see what setups people are on and iron out bugs. It's totally optional, and you can switch it off any time in Settings. By default we keep it. Here's what we'd get:"

const COLLECTED_DATA: Array = [
	["Operating system", "The OS you're on, its version, and whether you're on Windows, macOS, or Linux."],
	["Screen & window", "Your screen resolution and the size of the Hub window."],
	["Rendering", "Which graphics driver the Hub is using."],
	["Locale", "The language your OS is set to."],
	["Session events", "How long you had the Hub open. There's a random session id, but it's fresh each time you start the app."],
]

@onready var info_label: Label = %InfoLabel
@onready var scroll: ScrollContainer = %CollectedScroll
@onready var list_box: VBoxContainer = %CollectedList
@onready var anonymous_checkbox: CheckBox = %AnonymousCheckbox


func _ready() -> void:
	confirmed.connect(_on_allow)
	canceled.connect(_on_decline)
	_build_list()
	popup_centered()
	_clamp_size()


func _clamp_size() -> void:
	var target := Vector2i(
		maxi(mini(size.x, MAX_WIDTH), MIN_WIDTH),
		maxi(mini(size.y, MAX_HEIGHT), min_size.y)
	)
	set_size(target)


func set_anonymous(anonymous: bool) -> void:
	if anonymous_checkbox:
		anonymous_checkbox.button_pressed = anonymous


func _build_list() -> void:
	info_label.text = INFO_TEXT
	for item: Array in COLLECTED_DATA:
		var name_text: String = str(item[0])
		var desc_text: String = str(item[1])
		var name_label := Label.new()
		name_label.text = name_text
		name_label.theme_type_variation = &"SmallHeaderLabel"
		list_box.add_child(name_label)
		var desc_label := Label.new()
		desc_label.text = desc_text
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list_box.add_child(desc_label)
	scroll.scroll_vertical = 0


func _on_allow() -> void:
	consent_given.emit(true, anonymous_checkbox.button_pressed)
	queue_free()


func _on_decline() -> void:
	consent_given.emit(false, anonymous_checkbox.button_pressed)
	queue_free()
