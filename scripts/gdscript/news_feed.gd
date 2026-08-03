extends RefCounted
## RSS 2.0 parser + local cache for Blazium Hub News.
## Use via: const NewsFeed = preload("res://scripts/gdscript/news_feed.gd")

const HubSanitize := preload("res://scripts/gdscript/hub_sanitize.gd")

const CACHE_PATH := "user://news-cache.json"


static func slug_from_link(link: String) -> String:
	var trimmed := link.strip_edges()
	if trimmed.is_empty():
		return ""
	# https://cdn.blazium.app/articles/{slug}/meta.json
	var marker := "/articles/"
	var idx := trimmed.find(marker)
	if idx < 0:
		return ""
	var rest := trimmed.substr(idx + marker.length())
	var slash := rest.find("/")
	var slug := ""
	if slash <= 0:
		slug = rest.trim_suffix(".xml").trim_suffix(".json")
	else:
		slug = rest.substr(0, slash)
	if not HubSanitize.is_valid_slug(slug):
		return ""
	return slug


static func _finalize_item(cur: Dictionary) -> Dictionary:
	var link := str(cur.get("link", ""))
	var slug := slug_from_link(link)
	if slug.is_empty():
		return {}
	cur["slug"] = slug
	cur["title"] = HubSanitize.clamp_text(str(cur.get("title", "")).strip_edges(), HubSanitize.MAX_TITLE_LEN)
	cur["description"] = HubSanitize.clamp_text(str(cur.get("description", "")).strip_edges(), HubSanitize.MAX_DESC_LEN)
	if str(cur.get("title", "")).is_empty():
		return {}
	var cover := str(cur.get("cover", "")).strip_edges()
	if not cover.is_empty() and not HubSanitize.is_allowed_cdn_url(cover):
		cur["cover"] = ""
	return cur


static func parse_rss(xml_text: String) -> Array:
	var items: Array = []
	if xml_text.strip_edges().is_empty():
		return items
	var parser := XMLParser.new()
	var buf := xml_text.to_utf8_buffer()
	if parser.open_buffer(buf) != OK:
		return items

	var in_item := false
	var cur: Dictionary = {}
	var current_tag := ""

	while parser.read() == OK:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				var name := parser.get_node_name()
				current_tag = name
				if name == "item":
					in_item = true
					cur = {
						"title": "",
						"link": "",
						"description": "",
						"pubDate": "",
						"guid": "",
						"cover": "",
						"slug": "",
					}
				elif in_item and name == "enclosure":
					var url := parser.get_named_attribute_value_safe("url")
					if not url.is_empty():
						cur["cover"] = url
			XMLParser.NODE_TEXT, XMLParser.NODE_CDATA:
				if not in_item or current_tag.is_empty():
					continue
				var text := parser.get_node_data().strip_edges()
				if text.is_empty():
					continue
				match current_tag:
					"title":
						cur["title"] = str(cur.get("title", "")) + text
					"link":
						cur["link"] = str(cur.get("link", "")) + text
					"description":
						cur["description"] = str(cur.get("description", "")) + text
					"pubDate":
						cur["pubDate"] = str(cur.get("pubDate", "")) + text
					"guid":
						cur["guid"] = str(cur.get("guid", "")) + text
			XMLParser.NODE_ELEMENT_END:
				var end_name := parser.get_node_name()
				if end_name == "item":
					var item := _finalize_item(cur)
					if not item.is_empty() and items.size() < HubSanitize.MAX_RSS_ITEMS:
						items.append(item)
					in_item = false
					cur = {}
				current_tag = ""
	return items


static func read_cache() -> Array:
	if not FileAccess.file_exists(CACHE_PATH):
		return []
	var f := FileAccess.open(CACHE_PATH, FileAccess.READ)
	if f == null:
		return []
	var raw := f.get_as_text()
	if raw.length() > HubSanitize.MAX_CDN_TEXT_BYTES:
		return []
	var data: Variant = JSON.parse_string(raw)
	if typeof(data) != TYPE_DICTIONARY:
		return []
	var items: Variant = data.get("items", [])
	if typeof(items) != TYPE_ARRAY:
		return []
	var out: Array = []
	for entry in items:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var slug := str(entry.get("slug", ""))
		if not HubSanitize.is_valid_slug(slug):
			slug = slug_from_link(str(entry.get("link", "")))
		if not HubSanitize.is_valid_slug(slug):
			continue
		var cleaned := {
			"title": HubSanitize.clamp_text(str(entry.get("title", "")).strip_edges(), HubSanitize.MAX_TITLE_LEN),
			"link": str(entry.get("link", "")).strip_edges(),
			"description": HubSanitize.clamp_text(str(entry.get("description", "")).strip_edges(), HubSanitize.MAX_DESC_LEN),
			"pubDate": str(entry.get("pubDate", "")).strip_edges(),
			"guid": str(entry.get("guid", "")).strip_edges(),
			"cover": "",
			"slug": slug,
		}
		if cleaned["title"].is_empty():
			continue
		var cover := str(entry.get("cover", "")).strip_edges()
		if HubSanitize.is_allowed_cdn_url(cover):
			cleaned["cover"] = cover
		out.append(cleaned)
		if out.size() >= HubSanitize.MAX_RSS_ITEMS:
			break
	return out


static func write_cache(items: Array) -> void:
	var safe: Array = []
	for entry in items:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if not HubSanitize.is_valid_slug(str(entry.get("slug", ""))):
			continue
		safe.append(entry)
		if safe.size() >= HubSanitize.MAX_RSS_ITEMS:
			break
	var payload := {
		"fetched_at": Time.get_unix_time_from_system(),
		"items": safe,
	}
	var f := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(payload))


static func format_pub_date(pub_date: String) -> String:
	var s := pub_date.strip_edges()
	if s.is_empty():
		return ""
	return HubSanitize.clamp_text(s, 80)


static func sanitize_bbcode(bbcode: String) -> String:
	## Repair known CDN converter corruptions, then apply display allowlist.
	var out := bbcode
	out = out.replace("[font[i]size=", "[font_size=")
	out = out.replace("[/font[/i]size]", "[/font_size]")
	out = out.replace("app[i]id", "app_id")
	return HubSanitize.sanitize_bbcode_for_display(out)


static func hosts_from_meta(meta: Variant) -> Array:
	## Extract [{name,url}, ...] from CDN meta.json payload.
	var out: Array = []
	if typeof(meta) != TYPE_DICTIONARY:
		return out
	var raw: Variant = meta.get("hosts", [])
	if typeof(raw) != TYPE_ARRAY:
		return out
	var seen: Dictionary = {}
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var name := HubSanitize.escape_bbcode_text(str(entry.get("name", "")).strip_edges())
		var url := str(entry.get("url", "")).strip_edges()
		if name.is_empty() or url.is_empty():
			continue
		if not HubSanitize.is_safe_external_url(url):
			continue
		var key := url.to_lower()
		if seen.has(key):
			continue
		seen[key] = true
		out.append({"name": name, "url": url})
	return out


static func format_hosts_bbcode(hosts: Array) -> String:
	if hosts.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for entry in hosts:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var name := HubSanitize.escape_bbcode_text(str(entry.get("name", "")).strip_edges())
		var url := str(entry.get("url", "")).strip_edges()
		if name.is_empty() or not HubSanitize.is_safe_external_url(url):
			continue
		parts.append("[url=%s]%s[/url]" % [url, name])
	if parts.is_empty():
		return ""
	return "Hosted on: " + " · ".join(parts)
