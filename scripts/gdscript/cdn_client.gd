extends Node
## Public CDN catalog client (cdn.blazium.app). Never calls Cerebro.

const HubSanitize := preload("res://scripts/gdscript/hub_sanitize.gd")

const CDN_BASE := "https://cdn.blazium.app"

signal fetch_finished(ok: bool, data: Variant, error: String)

var _last_error: String = ""


func get_last_error() -> String:
	return _last_error


func _request_body(path_or_url: String, cache_bust: bool = false, max_bytes: int = -1) -> PackedByteArray:
	_last_error = ""
	var url := path_or_url
	if not url.begins_with("http://") and not url.begins_with("https://"):
		if path_or_url.is_empty() or not path_or_url.begins_with("/"):
			_last_error = "invalid CDN path"
			return PackedByteArray()
		url = CDN_BASE + path_or_url
	elif not HubSanitize.is_allowed_cdn_url(url):
		_last_error = "URL not on allowed CDN host"
		return PackedByteArray()
	if cache_bust:
		var sep := "&" if url.contains("?") else "?"
		url = "%s%st=%d" % [url, sep, int(Time.get_unix_time_from_system())]
	var limit := max_bytes if max_bytes > 0 else HubSanitize.MAX_CDN_TEXT_BYTES
	var http := HTTPRequest.new()
	http.timeout = 30.0
	add_child(http)
	var err := http.request(url)
	if err != OK:
		_last_error = "HTTP request failed to start (%d)" % err
		http.queue_free()
		return PackedByteArray()
	var result: Array = await http.request_completed
	http.queue_free()
	var http_result: int = result[0]
	var code: int = result[1]
	var body: PackedByteArray = result[3]
	if http_result != HTTPRequest.RESULT_SUCCESS:
		_last_error = "HTTP result %d" % http_result
		return PackedByteArray()
	if code < 200 or code >= 300:
		_last_error = "HTTP %d for %s" % [code, path_or_url]
		return PackedByteArray()
	if body.size() > limit:
		_last_error = "response too large (%d > %d)" % [body.size(), limit]
		return PackedByteArray()
	return body


func fetch_bytes(path_or_url: String, cache_bust: bool = false) -> PackedByteArray:
	return await _request_body(path_or_url, cache_bust, HubSanitize.MAX_CDN_IMAGE_BYTES)


func fetch_text(path_or_url: String, cache_bust: bool = false) -> String:
	var body := await _request_body(path_or_url, cache_bust, HubSanitize.MAX_CDN_TEXT_BYTES)
	if body.is_empty() and not _last_error.is_empty():
		return ""
	return body.get_string_from_utf8()


func fetch_json(path: String) -> Variant:
	var text := await fetch_text(path)
	if text.is_empty():
		if _last_error.is_empty():
			_last_error = "empty body from %s" % path
		return null
	var data: Variant = JSON.parse_string(text)
	if data == null:
		_last_error = "invalid JSON from %s" % path
		return null
	return data


static func latest_path(channel: String) -> String:
	if not HubSanitize.is_valid_channel(channel):
		return ""
	return "/catalog/versions/%s/latest.json" % channel.strip_edges().to_lower()


static func versions_path(channel: String) -> String:
	if not HubSanitize.is_valid_channel(channel):
		return ""
	return "/catalog/versions/%s.json" % channel.strip_edges().to_lower()


static func editors_path(channel: String, version: String) -> String:
	if not HubSanitize.is_valid_channel(channel) or not HubSanitize.is_valid_version(version) or version.strip_edges().is_empty():
		return ""
	return "/%s/%s/editors.json" % [channel.strip_edges().to_lower(), version.strip_edges()]


static func articles_rss_path() -> String:
	return "/articles/rss.xml"


static func article_bbcode_path(slug: String) -> String:
	if not HubSanitize.is_valid_slug(slug):
		return ""
	return "/articles/%s/content.bbcode" % slug.strip_edges()


static func article_meta_path(slug: String) -> String:
	if not HubSanitize.is_valid_slug(slug):
		return ""
	return "/articles/%s/meta.json" % slug.strip_edges()


func latest(channel: String) -> Variant:
	var path := latest_path(channel)
	if path.is_empty():
		_last_error = "invalid channel"
		return null
	return await fetch_json(path)


func versions(channel: String) -> Variant:
	var path := versions_path(channel)
	if path.is_empty():
		_last_error = "invalid channel"
		return null
	return await fetch_json(path)


func editors_for(channel: String, version: String) -> Variant:
	var path := editors_path(channel, version)
	if path.is_empty():
		_last_error = "invalid channel or version"
		return null
	return await fetch_json(path)
