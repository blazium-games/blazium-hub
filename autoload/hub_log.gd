extends Node
## In-memory session log for Hub UI (Editors console + Settings Logs).

signal log_changed

const MAX_LINES := 2000

var _lines: PackedStringArray = PackedStringArray()


func _trim() -> void:
	while _lines.size() > MAX_LINES:
		_lines.remove_at(0)


func append(line: String, emit_signal: bool = true) -> void:
	var ts := Time.get_datetime_string_from_system(false, true)
	_lines.append("[%s] %s" % [ts, line])
	_trim()
	if emit_signal:
		log_changed.emit()


func append_block(title: String, body: String) -> void:
	append("--- %s ---" % title, false)
	var text := body.strip_edges()
	if text.is_empty():
		append("(empty)", false)
	else:
		for line in text.split("\n"):
			append(line, false)
	log_changed.emit()


func clear() -> void:
	_lines.clear()
	log_changed.emit()


func get_text() -> String:
	return "\n".join(_lines)


func line_count() -> int:
	return _lines.size()
