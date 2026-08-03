extends AutoworkTest

const HubSanitize := preload("res://scripts/gdscript/hub_sanitize.gd")
const NewsFeed := preload("res://scripts/gdscript/news_feed.gd")


func test_014_cdn_and_external_urls() -> void:
	assert_true(HubSanitize.is_allowed_cdn_url("https://cdn.blazium.app/articles/rss.xml"))
	assert_true(HubSanitize.is_allowed_cdn_url("https://cdn.blazium.app/articles/x/content.bbcode?t=1"))
	assert_false(HubSanitize.is_allowed_cdn_url("https://evil.example/articles/rss.xml"))
	assert_false(HubSanitize.is_allowed_cdn_url("http://cdn.blazium.app/articles/rss.xml"))
	assert_false(HubSanitize.is_allowed_cdn_url("https://user:pass@cdn.blazium.app/x"))
	assert_true(HubSanitize.is_safe_external_url("https://www.indiedb.com/engines/blazium-engine/news/steam-module"))
	assert_false(HubSanitize.is_safe_external_url("http://www.indiedb.com/x"))
	assert_false(HubSanitize.is_safe_external_url("javascript:alert(1)"))
	assert_false(HubSanitize.is_safe_external_url("https://evil]breakout"))
	assert_false(HubSanitize.is_safe_external_url("https://user:pw@example.com/"))


func test_014_slug_version_channel() -> void:
	assert_true(HubSanitize.is_valid_slug("steam-module"))
	assert_false(HubSanitize.is_valid_slug("../etc"))
	assert_false(HubSanitize.is_valid_slug("Steam Module"))
	assert_false(HubSanitize.is_valid_slug(""))
	assert_true(HubSanitize.is_valid_version("0.6.725"))
	assert_true(HubSanitize.is_valid_version(""))
	assert_false(HubSanitize.is_valid_version("../x"))
	assert_true(HubSanitize.is_valid_channel("release"))
	assert_true(HubSanitize.is_valid_channel("prerelease"))
	assert_true(HubSanitize.is_valid_channel("nightly"))
	assert_false(HubSanitize.is_valid_channel("staging"))


func test_014_bbcode_allowlist_and_escape() -> void:
	var dirty := "[b]Hi[/b] [script]x[/script] [url=javascript:alert(1)]x[/url] [url=https://blazium.app]ok[/url] [img]https://evil.test/a.png[/img] [img]https://cdn.blazium.app/articles/steam-module/assets/cover.jpg[/img]"
	var clean := HubSanitize.sanitize_bbcode_for_display(dirty)
	assert_true(clean.contains("[b]Hi[/b]"), clean)
	assert_false(clean.contains("[script]"), clean)
	assert_false(clean.contains("javascript:"), clean)
	assert_false(clean.contains("[/url]x"), clean)
	assert_true(clean.contains("[url=https://blazium.app]ok[/url]"), clean)
	assert_false(clean.contains("evil.test"), clean)
	assert_true(clean.contains("cdn.blazium.app/articles/steam-module/assets/cover.jpg"), clean)
	assert_eq(HubSanitize.escape_bbcode_text("Indie[DB]"), "IndieDB")


func test_014_ipc_and_cli_path() -> void:
	assert_true(HubSanitize.is_allowed_single_instance_message("SHOW"))
	assert_true(HubSanitize.is_allowed_single_instance_message("URI blazium://hub"))
	assert_true(HubSanitize.is_allowed_single_instance_message("URI blazium:open?path=C:/game"))
	assert_false(HubSanitize.is_allowed_single_instance_message("URI https://evil.test"))
	assert_false(HubSanitize.is_allowed_single_instance_message("EVAL 1+1"))
	assert_false(HubSanitize.is_allowed_single_instance_message("A".repeat(HubSanitize.MAX_IPC_MSG_LEN + 10)))
	assert_true(HubSanitize.is_safe_cli_path("blazium-cli"))
	assert_true(HubSanitize.is_safe_cli_path("C:/Program Files/Blazium/blazium-cli.exe"))
	assert_false(HubSanitize.is_safe_cli_path("../evil.exe"))
	assert_false(HubSanitize.is_safe_cli_path("C:/tmp/malware.exe"))


func test_014_bind_and_list_payload() -> void:
	assert_eq(HubSanitize.sanitize_bind_host("0.0.0.0"), "127.0.0.1")
	assert_eq(HubSanitize.sanitize_bind_host("evil.com"), "127.0.0.1")
	assert_eq(HubSanitize.sanitize_bind_host("::1"), "127.0.0.1")
	assert_eq(HubSanitize.sanitize_bind_port(80), 39218)
	assert_eq(HubSanitize.sanitize_bind_port(39218), 39218)
	var bad := HubState.normalize_list_payload({"editors": "not-array"}, "editors")
	assert_eq(bad.size(), 0)
	var good := HubState.normalize_list_payload({"editors": [{"version": "1"}]}, "editors")
	assert_eq(good.size(), 1)


func test_014_cdn_paths_reject_bad_slug() -> void:
	assert_eq(CdnClient.article_bbcode_path("steam-module"), "/articles/steam-module/content.bbcode")
	assert_eq(CdnClient.article_bbcode_path("../x"), "")
	assert_eq(CdnClient.latest_path("nightly"), "/catalog/versions/nightly/latest.json")
	assert_eq(CdnClient.latest_path("nope"), "")


func test_014_news_rejects_poisoned_slug_and_hosts() -> void:
	var xml := """<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"><channel>
<item>
  <title>Bad</title>
  <link>https://cdn.blazium.app/articles/../etc/meta.json</link>
</item>
<item>
  <title>Good</title>
  <link>https://cdn.blazium.app/articles/steam-module/meta.json</link>
</item>
</channel></rss>
"""
	var items := NewsFeed.parse_rss(xml)
	assert_eq(items.size(), 1)
	assert_eq(str(items[0].get("slug", "")), "steam-module")
	var hosts := NewsFeed.hosts_from_meta({
		"hosts": [
			{"name": "Indie[b]DB[/b]", "url": "https://www.indiedb.com/engines/blazium-engine/news/steam-module"},
			{"name": "Bad", "url": "http://insecure.example/x"},
		],
	})
	assert_eq(hosts.size(), 1)
	assert_eq(str(hosts[0].get("name", "")), "IndiebDB/b")
	var bb := NewsFeed.format_hosts_bbcode(hosts)
	assert_false(bb.contains("[b]"), bb)
