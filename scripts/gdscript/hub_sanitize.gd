extends RefCounted
## Shared validation / sanitization for untrusted Hub ingress.
## Use via: const HubSanitize = preload("res://scripts/gdscript/hub_sanitize.gd")

const CDN_HOST := "cdn.blazium.app"
const MAX_SLUG_LEN := 80
const MAX_URI_LEN := 2048
const MAX_IPC_MSG_LEN := 4096
const MAX_CLI_JSON_BYTES := 2 * 1024 * 1024
const MAX_CDN_TEXT_BYTES := 2 * 1024 * 1024
const MAX_CDN_IMAGE_BYTES := 5 * 1024 * 1024
const MAX_RSS_ITEMS := 100
const MAX_TITLE_LEN := 300
const MAX_DESC_LEN := 2000
const MAX_BBCODE_LEN := 500_000
const MAX_IMAGES_PER_ARTICLE := 32

const _ALLOWED_BBCODE_TAGS := {
	"b": true,
	"i": true,
	"u": true,
	"code": true,
	"url": true,
	"img": true,
	"font_size": true,
}


static func clamp_text(s: String, max_chars: int) -> String:
	if max_chars <= 0 or s.length() <= max_chars:
		return s
	return s.substr(0, max_chars)


static func escape_bbcode_text(s: String) -> String:
	return s.replace("[", "").replace("]", "")


static func is_valid_slug(slug: String) -> bool:
	var s := slug.strip_edges()
	if s.is_empty() or s.length() > MAX_SLUG_LEN:
		return false
	var re := RegEx.new()
	if re.compile("^[a-z0-9]+(?:-[a-z0-9]+)*$") != OK:
		return false
	return re.search(s) != null


static func is_valid_version(v: String) -> bool:
	var s := v.strip_edges()
	if s.is_empty():
		return true # empty = CLI default install
	if s.length() > 64:
		return false
	var re := RegEx.new()
	if re.compile("^[0-9A-Za-z][0-9A-Za-z._+-]{0,63}$") != OK:
		return false
	return re.search(s) != null


static func is_valid_channel(ch: String) -> bool:
	match ch.strip_edges().to_lower():
		"release", "nightly", "prerelease":
			return true
		_:
			return false


static func is_blazium_uri(uri: String) -> bool:
	var s := uri.strip_edges()
	if s.is_empty() or s.length() > MAX_URI_LEN:
		return false
	var lower := s.to_lower()
	return lower.begins_with("blazium:") or lower.begins_with("blazium://")


static func is_allowed_single_instance_message(msg: String) -> bool:
	if msg.length() > MAX_IPC_MSG_LEN:
		return false
	var s := msg.strip_edges()
	if s == "SHOW":
		return true
	if s.begins_with("URI "):
		return is_blazium_uri(s.substr(4).strip_edges())
	return false


static func is_safe_cli_path(path: String) -> bool:
	var p := path.strip_edges()
	if p.is_empty():
		return true
	if p.contains(".."):
		return false
	# Bare PATH names
	if p == "blazium-cli" or p == "blazium-cli.exe":
		return true
	var base := p.get_file().to_lower()
	return base == "blazium-cli" or base == "blazium-cli.exe"


static func sanitize_bind_host(host: String) -> String:
	var h := host.strip_edges().to_lower()
	if h == "127.0.0.1" or h == "::1" or h == "localhost":
		return "127.0.0.1"
	return "127.0.0.1"


static func sanitize_bind_port(port: int, default_port: int = 39218) -> int:
	if port < 1024 or port > 65535:
		return default_port
	return port


static func _has_control_or_space(s: String) -> bool:
	for i in s.length():
		var code := s.unicode_at(i)
		if code <= 0x20 or code == 0x7F:
			return true
	return false


static func is_safe_external_url(url: String) -> bool:
	var u := url.strip_edges()
	if u.is_empty() or not u.to_lower().begins_with("https://"):
		return false
	if u.contains("[") or u.contains("]"):
		return false
	if _has_control_or_space(u):
		return false
	# Reject userinfo: https://user:pass@host/...
	var after := u.substr(8) # after https://
	var slash := after.find("/")
	var authority := after if slash < 0 else after.substr(0, slash)
	if authority.is_empty() or authority.contains("@"):
		return false
	var host := authority
	var colon := authority.rfind(":")
	if colon > 0:
		host = authority.substr(0, colon)
	return not host.is_empty()


static func is_allowed_cdn_url(url: String) -> bool:
	var u := url.strip_edges()
	if u.is_empty() or not u.to_lower().begins_with("https://"):
		return false
	if u.contains("[") or u.contains("]") or _has_control_or_space(u):
		return false
	var after := u.substr(8)
	var slash := after.find("/")
	var authority := after if slash < 0 else after.substr(0, slash)
	if authority.contains("@"):
		return false
	var host := authority.to_lower()
	var colon := host.rfind(":")
	if colon > 0:
		host = host.substr(0, colon)
	if host != CDN_HOST:
		return false
	# Relative query cache-bust is fine
	return true


static func _normalize_tag_name(raw: String) -> String:
	var t := raw.strip_edges().to_lower()
	# font_size=22 → font_size; url=https://… → url
	var eq := t.find("=")
	if eq >= 0:
		t = t.substr(0, eq)
	var sp := t.find(" ")
	if sp >= 0:
		t = t.substr(0, sp)
	return t


static func sanitize_bbcode_for_display(bbcode: String) -> String:
	var src := clamp_text(bbcode, MAX_BBCODE_LEN)
	var out := ""
	var i := 0
	var n := src.length()
	while i < n:
		if src[i] != "[":
			out += src[i]
			i += 1
			continue
		var close := src.find("]", i + 1)
		if close < 0:
			# stray '[' — escape by dropping
			i += 1
			continue
		var inner := src.substr(i + 1, close - i - 1)
		var is_close := inner.begins_with("/")
		var tag_raw := inner.substr(1) if is_close else inner
		var tag := _normalize_tag_name(tag_raw)
		if not _ALLOWED_BBCODE_TAGS.has(tag):
			i = close + 1
			continue
		if tag == "url":
			if is_close:
				out += "[/url]"
				i = close + 1
				continue
			var href := ""
			var eq := inner.find("=")
			if eq >= 0:
				href = inner.substr(eq + 1).strip_edges()
			if is_safe_external_url(href) or is_allowed_cdn_url(href):
				out += "[url=%s]" % href
				i = close + 1
				continue
			# Drop poisoned link: skip through matching [/url], keep inner text plain.
			i = close + 1
			var end_url := src.find("[/url]", i)
			if end_url < 0:
				end_url = src.find("[/URL]", i)
			if end_url >= 0:
				out += src.substr(i, end_url - i)
				i = end_url + 6
			continue
		elif tag == "img":
			if is_close:
				out += "[/img]"
			else:
				out += "[img]"
		elif tag == "font_size":
			if is_close:
				out += "[/font_size]"
			else:
				var eq2 := inner.find("=")
				var size := "16"
				if eq2 >= 0:
					size = inner.substr(eq2 + 1).strip_edges()
					var re := RegEx.new()
					if re.compile("^[0-9]{1,3}$") != OK or re.search(size) == null:
						size = "16"
				out += "[font_size=%s]" % size
		else:
			out += "[%s%s]" % ["/" if is_close else "", tag]
		i = close + 1

	# Second pass: drop [img]…[/img] whose URL is not CDN-allowed
	var re_img := RegEx.new()
	if re_img.compile("\\[img\\]([^\\[]*)\\[/img\\]") == OK:
		for m in re_img.search_all(out):
			var img_url := m.get_string(1).strip_edges()
			if not is_allowed_cdn_url(img_url):
				# Also allow absolute local paths written by our image cache (drive:/ or /)
				var local_ok := img_url.begins_with("user://") \
					or (img_url.length() > 3 and img_url.substr(1, 2) == ":/") \
					or img_url.begins_with("/")
				if not local_ok:
					out = out.replace(m.get_string(0), "")
	return out
