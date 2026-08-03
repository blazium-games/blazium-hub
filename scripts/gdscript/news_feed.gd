extends RefCounted
## RSS 2.0 parser + local cache for Blazium Hub News.
## Use via: const NewsFeed = preload("res://scripts/gdscript/news_feed.gd")


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
	if slash <= 0:
		return rest.trim_suffix(".xml").trim_suffix(".json")
	return rest.substr(0, slash)


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
					var link := str(cur.get("link", ""))
					cur["slug"] = slug_from_link(link)
					if str(cur.get("title", "")).is_empty() == false and not cur["slug"].is_empty():
						items.append(cur)
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
	var data: Variant = JSON.parse_string(raw)
	if typeof(data) != TYPE_DICTIONARY:
		return []
	var items: Variant = data.get("items", [])
	if typeof(items) != TYPE_ARRAY:
		return []
	return items


static func write_cache(items: Array) -> void:
	var payload := {
		"fetched_at": Time.get_unix_time_from_system(),
		"items": items,
	}
	var f := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(payload))


static func format_pub_date(pub_date: String) -> String:
	var s := pub_date.strip_edges()
	if s.is_empty():
		return ""
	# RSS dates look like: Wed, 15 Jan 2025 12:00:00 GMT — show as-is trimmed
	return s


static func sanitize_bbcode(bbcode: String) -> String:
	## Repair known CDN converter corruptions and normalize for RichTextLabel.
	var out := bbcode
	# Older publishes mangled font_size via underscore-italic: font[i]size → font_size
	out = out.replace("[font[i]size=", "[font_size=")
	out = out.replace("[/font[/i]size]", "[/font_size]")
	# Same bug could split snake_case identifiers inside previously unprotected spans.
	out = out.replace("app[i]id", "app_id")
	return out
