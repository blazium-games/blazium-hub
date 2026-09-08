extends Node
## Headless packed-asset check: BlaziumHub --headless --self-test --quit

const REQUIRED_PATHS: PackedStringArray = [
	"res://scenes/main.tscn",
	"res://assets/icons/icon.svg",
	"res://autoload/hub_settings.gd",
	"res://scripts/gdscript/hub_cli.gd",
]

var active: bool = false


func _ready() -> void:
	active = cmdline_has_self_test()
	if not active:
		return
	_run()


static func cmdline_has_self_test(args: PackedStringArray = PackedStringArray()) -> bool:
	if args.is_empty():
		for a in OS.get_cmdline_user_args():
			if str(a) == "--self-test":
				return true
		for a in OS.get_cmdline_args():
			if str(a) == "--self-test":
				return true
		return false
	for a in args:
		if str(a) == "--self-test":
			return true
	return false


func _run() -> void:
	for p in REQUIRED_PATHS:
		if not ResourceLoader.exists(p) and not FileAccess.file_exists(p):
			push_error("hub self-test: missing %s" % p)
			print("hub self-test: missing %s" % p)
			get_tree().quit(1)
			return
		var loaded: Resource = ResourceLoader.load(p)
		if loaded == null:
			push_error("hub self-test: failed to load %s" % p)
			print("hub self-test: failed to load %s" % p)
			get_tree().quit(1)
			return
	print("hub self-test: ok")
	get_tree().quit(0)
