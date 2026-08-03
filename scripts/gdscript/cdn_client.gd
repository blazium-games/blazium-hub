extends Node
## Public CDN catalog client (cdn.blazium.app). Never calls Cerebro.

const CDN_BASE := "https://cdn.blazium.app"

signal fetch_finished(ok: bool, data: Variant, error: String)

var _last_error: String = ""


func get_last_error() -> String:
	return _last_error


func _request_body(path_or_url: String, cache_bust: bool = false) -> PackedByteArray:
	_last_error = ""
	var url := path_or_url
	if not url.begins_with("http://") and not url.begins_with("https://"):
		url = CDN_BASE + path_or_url
	if cache_bust:
		# Bypass Cloudflare/shared CDN edge caches after article republishes.
		var sep := "&" if url.contains("?") else "?"
		url = "%s%st=%d" % [url, sep, int(Time.get_unix_time_from_system())]
	# One HTTPRequest per call so News/Editors can fetch concurrently.
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
	return body


func fetch_bytes(path_or_url: String, cache_bust: bool = false) -> PackedByteArray:
	return await _request_body(path_or_url, cache_bust)


func fetch_text(path_or_url: String, cache_bust: bool = false) -> String:
	var body := await _request_body(path_or_url, cache_bust)
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
	return "/catalog/versions/%s/latest.json" % channel


static func versions_path(channel: String) -> String:
	return "/catalog/versions/%s.json" % channel


static func editors_path(channel: String, version: String) -> String:
	return "/%s/%s/editors.json" % [channel, version]


static func articles_rss_path() -> String:
	return "/articles/rss.xml"


static func article_bbcode_path(slug: String) -> String:
	return "/articles/%s/content.bbcode" % slug


static func article_meta_path(slug: String) -> String:
	return "/articles/%s/meta.json" % slug


func latest(channel: String) -> Variant:
	return await fetch_json(latest_path(channel))


func versions(channel: String) -> Variant:
	return await fetch_json(versions_path(channel))


func editors_for(channel: String, version: String) -> Variant:
	return await fetch_json(editors_path(channel, version))
