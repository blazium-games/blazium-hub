extends AutoworkTest

const NewsFeed := preload("res://scripts/gdscript/news_feed.gd")


func test_013_slug_from_link() -> void:
	assert_eq(
		NewsFeed.slug_from_link("https://cdn.blazium.app/articles/steam-module/meta.json"),
		"steam-module"
	)
	assert_eq(NewsFeed.slug_from_link(""), "")
	assert_eq(NewsFeed.slug_from_link("https://example.com/nope"), "")


func test_013_parse_rss_items() -> void:
	var xml := """<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Blazium Engine Articles</title>
    <item>
      <title>Steam Module</title>
      <link>https://cdn.blazium.app/articles/steam-module/meta.json</link>
      <guid isPermaLink="true">https://cdn.blazium.app/articles/steam-module/meta.json</guid>
      <pubDate>Wed, 15 Jan 2025 12:00:00 GMT</pubDate>
      <description>Native Steamworks integration</description>
      <enclosure url="https://cdn.blazium.app/articles/steam-module/assets/cover.jpg" type="image/jpeg" />
    </item>
    <item>
      <title>Missing Link</title>
      <description>Should be skipped</description>
    </item>
  </channel>
</rss>
"""
	var items := NewsFeed.parse_rss(xml)
	assert_eq(items.size(), 1, "one valid item")
	var item: Dictionary = items[0]
	assert_eq(str(item.get("title", "")), "Steam Module")
	assert_eq(str(item.get("slug", "")), "steam-module")
	assert_eq(str(item.get("cover", "")), "https://cdn.blazium.app/articles/steam-module/assets/cover.jpg")
	assert_true(str(item.get("description", "")).contains("Steamworks"))


func test_013_cdn_article_paths() -> void:
	assert_eq(CdnClient.articles_rss_path(), "/articles/rss.xml")
	assert_eq(CdnClient.article_bbcode_path("steam-module"), "/articles/steam-module/content.bbcode")
	assert_eq(CdnClient.article_meta_path("steam-module"), "/articles/steam-module/meta.json")


func test_013_sanitize_bbcode_font_size() -> void:
	var broken := "[b][font[i]size=22]Hello[/font[/i]size][/b]\n[code]Steam.initialize(app[i]id)[/code]\n"
	var fixed := NewsFeed.sanitize_bbcode(broken)
	assert_true(fixed.contains("[font_size=22]Hello[/font_size]"), fixed)
	assert_false(fixed.contains("font[i]size"), fixed)
	assert_true(fixed.contains("app_id"), fixed)
	assert_false(fixed.contains("app[i]id"), fixed)


func test_013_parse_live_shaped_rss() -> void:
	## Shape matches cdn.blazium.app/articles/rss.xml (no CDATA, enclosure covers).
	var xml := """<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Blazium Engine Articles</title>
    <link>https://cdn.blazium.app/articles/rss.xml</link>
    <description>Official Blazium Game Engine articles and release notes.</description>
    <language>en-us</language>
    <lastBuildDate>Mon, 03 Aug 2026 00:22:35 GMT</lastBuildDate>
    <item>
      <title>Steam Module</title>
      <link>https://cdn.blazium.app/articles/steam-module/meta.json</link>
      <guid isPermaLink="true">https://cdn.blazium.app/articles/steam-module/meta.json</guid>
      <pubDate>Sun, 02 Aug 2026 12:00:00 GMT</pubDate>
      <description>Native Steamworks integration for Blazium Game Engine.</description>
      <enclosure url="https://cdn.blazium.app/articles/steam-module/assets/cover.jpg" type="image/jpeg" />
    </item>
    <item>
      <title>Blazium Game Engine: Release 0.6.725</title>
      <link>https://cdn.blazium.app/articles/release-0-6-725/meta.json</link>
      <guid isPermaLink="true">https://cdn.blazium.app/articles/release-0-6-725/meta.json</guid>
      <pubDate>Sun, 02 Aug 2026 12:00:00 GMT</pubDate>
      <description>A major update introducing new modules.</description>
      <enclosure url="https://cdn.blazium.app/articles/release-0-6-725/assets/cover.jpg" type="image/jpeg" />
    </item>
  </channel>
</rss>
"""
	var items := NewsFeed.parse_rss(xml)
	assert_eq(items.size(), 2)
	assert_eq(str(items[0].get("slug", "")), "steam-module")
	assert_eq(str(items[1].get("slug", "")), "release-0-6-725")
	assert_true(str(items[0].get("cover", "")).ends_with("/steam-module/assets/cover.jpg"))
	assert_eq(CdnClient.article_bbcode_path(str(items[0].get("slug", ""))), "/articles/steam-module/content.bbcode")


func test_013_hosts_from_meta_and_bbcode() -> void:
	var meta := {
		"slug": "steam-module",
		"hosts": [
			{"name": "IndieDB", "url": "https://www.indiedb.com/engines/blazium-engine/news/steam-module"},
			{"name": "itch.io", "url": "https://blaziumengine.itch.io"},
			{"name": "Dup", "url": "https://www.indiedb.com/engines/blazium-engine/news/steam-module"},
			{"name": "Bad", "url": "/relative"},
			{"name": "", "url": "https://example.com"},
		],
	}
	var hosts := NewsFeed.hosts_from_meta(meta)
	assert_eq(hosts.size(), 2)
	assert_eq(str(hosts[0].get("name", "")), "IndieDB")
	assert_eq(str(hosts[1].get("name", "")), "itch.io")
	var bb := NewsFeed.format_hosts_bbcode(hosts)
	assert_true(bb.begins_with("Hosted on: "), bb)
	assert_true(bb.contains("[url=https://www.indiedb.com/engines/blazium-engine/news/steam-module]IndieDB[/url]"), bb)
	assert_true(bb.contains("[url=https://blaziumengine.itch.io]itch.io[/url]"), bb)
	assert_eq(NewsFeed.format_hosts_bbcode([]), "")
	assert_eq(NewsFeed.hosts_from_meta(null).size(), 0)
