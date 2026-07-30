extends Node
## Public CDN catalog client (cdn.blazium.app). Never calls Cerebro.

const CDN_BASE := "https://cdn.blazium.app"

signal fetch_finished(ok: bool, data: Variant, error: String)

var _last_error: String = ""
var _http: HTTPRequest


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 30.0
	add_child(_http)


func get_last_error() -> String:
	return _last_error


func fetch_json(path: String) -> Variant:
	_last_error = ""
	var url := CDN_BASE + path
	var err := _http.request(url)
	if err != OK:
		_last_error = "HTTP request failed to start (%d)" % err
		return null
	var result: Array = await _http.request_completed
	var http_result: int = result[0]
	var code: int = result[1]
	var body: PackedByteArray = result[3]
	if http_result != HTTPRequest.RESULT_SUCCESS:
		_last_error = "HTTP result %d" % http_result
		return null
	if code < 200 or code >= 300:
		_last_error = "HTTP %d for %s" % [code, path]
		return null
	var text := body.get_string_from_utf8()
	var data: Variant = JSON.parse_string(text)
	if data == null:
		_last_error = "invalid JSON from %s" % path
		return null
	return data


static func latest_path(channel: String) -> String:
	return "/catalog/versions/%s/latest.json" % channel


static func versions_path(channel: String) -> String:
	return "/catalog/versions/%s.json" % channel


static func editors_path(channel: String, version: String) -> String:
	return "/%s/%s/editors.json" % [channel, version]


func latest(channel: String) -> Variant:
	return await fetch_json(latest_path(channel))


func versions(channel: String) -> Variant:
	return await fetch_json(versions_path(channel))


func editors_for(channel: String, version: String) -> Variant:
	return await fetch_json(editors_path(channel, version))
