extends VBoxContainer

const NewsFeed := preload("res://scripts/gdscript/news_feed.gd")
const HubSanitize := preload("res://scripts/gdscript/hub_sanitize.gd")
const NEWS_PANEL_SCENE: PackedScene = preload("res://scenes/views/news_panel.tscn")

@onready var refresh_btn: Button = %RefreshNewsBtn
@onready var back_btn: Button = %BackNewsBtn
@onready var list_panel: Control = %NewsListPanel
@onready var detail_panel: Control = %NewsDetailPanel
@onready var news_list: VBoxContainer = %NewsList
@onready var article_title: Label = %ArticleTitle
@onready var article_hosts: RichTextLabel = %ArticleHosts
@onready var article_body: RichTextLabel = %ArticleBody
@onready var status: Label = %NewsStatus

var _items: Array = []
var _loading: bool = false
var _opening: bool = false
var _article_textures: Array[Texture2D] = []


func _ready() -> void:
	refresh_btn.pressed.connect(_on_refresh)
	back_btn.pressed.connect(_show_list)
	article_body.bbcode_enabled = true
	article_body.fit_content = false
	article_body.scroll_active = true
	article_body.meta_clicked.connect(_on_meta_clicked)
	article_hosts.bbcode_enabled = true
	article_hosts.fit_content = true
	article_hosts.scroll_active = false
	article_hosts.meta_clicked.connect(_on_meta_clicked)
	_show_list()


func reload() -> void:
	_on_refresh()


func ensure_loaded() -> void:
	if _items.is_empty() and not _loading:
		_on_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		call_deferred("ensure_loaded")


func _on_meta_clicked(meta: Variant) -> void:
	var url := str(meta).strip_edges()
	if HubSanitize.is_safe_external_url(url) or HubSanitize.is_allowed_cdn_url(url):
		OS.shell_open(url)


func _set_status(msg: String) -> void:
	status.text = msg
	if HubLog and not msg.is_empty():
		HubLog.append(msg)


func _show_list() -> void:
	list_panel.visible = true
	detail_panel.visible = false
	back_btn.visible = false
	refresh_btn.visible = true
	_set_hosts_bbcode("")


func _show_detail() -> void:
	list_panel.visible = false
	detail_panel.visible = true
	back_btn.visible = true
	refresh_btn.visible = false


func _set_hosts_bbcode(bbcode: String) -> void:
	article_hosts.clear()
	if bbcode.is_empty():
		article_hosts.visible = false
		article_hosts.text = ""
		return
	article_hosts.visible = true
	article_hosts.append_text(bbcode)


func _on_refresh() -> void:
	if _loading:
		return
	_loading = true
	_set_status("Loading news…")
	var xml := await CdnClient.fetch_text(CdnClient.articles_rss_path(), true)
	var from_cache := false
	var items: Array = []
	if xml.is_empty():
		items = NewsFeed.read_cache()
		from_cache = not items.is_empty()
		if items.is_empty():
			_set_status(CdnClient.get_last_error() if not CdnClient.get_last_error().is_empty() else "Failed to load news")
			_loading = false
			return
	else:
		items = NewsFeed.parse_rss(xml)
		if items.is_empty():
			items = NewsFeed.read_cache()
			from_cache = not items.is_empty()
			if items.is_empty():
				_set_status("News feed was empty")
				_loading = false
				return
		else:
			NewsFeed.write_cache(items)

	_items = items
	_populate_list()
	if from_cache:
		_set_status("Showing cached news (%d)" % _items.size())
	else:
		_set_status("%d articles" % _items.size())
	_loading = false


func _populate_list() -> void:
	for child in news_list.get_children():
		news_list.remove_child(child)
		child.free()
	for item in _items:
		var title := str(item.get("title", "Untitled"))
		var date: String = NewsFeed.format_pub_date(str(item.get("pubDate", "")))
		if not date.is_empty():
			var arr: PackedStringArray = date.split(" ")
			date = "%s %s %s" % [arr[1], arr[2], arr[3]]
		var desc := str(item.get("description", "")).strip_edges()
		var news_panel: NewsPanel = NEWS_PANEL_SCENE.instantiate()
		news_panel.header = title
		news_panel.date = date
		news_panel.desc = desc
		news_panel.item = item
		news_panel.open_news.connect(_on_item_activated)
		news_list.add_child(news_panel)


func _on_item_activated(_item: Dictionary) -> void:
	if _opening or _loading:
		return
	_opening = true
	await _open_article(_item)
	_opening = false


func _open_article(item: Dictionary) -> void:
	var slug := str(item.get("slug", ""))
	if slug.is_empty():
		slug = NewsFeed.slug_from_link(str(item.get("link", "")))
	if not HubSanitize.is_valid_slug(slug):
		_set_status("Article has no valid slug")
		return

	_set_status("Loading %s…" % slug)
	var meta_path := CdnClient.article_meta_path(slug)
	var bbcode_path := CdnClient.article_bbcode_path(slug)
	if meta_path.is_empty() or bbcode_path.is_empty():
		_set_status("Article path rejected")
		return
	var meta_text := await CdnClient.fetch_text(meta_path, true)
	var hosts_bb := ""
	if not meta_text.is_empty():
		var meta: Variant = JSON.parse_string(meta_text)
		hosts_bb = NewsFeed.format_hosts_bbcode(NewsFeed.hosts_from_meta(meta))

	var bbcode := await CdnClient.fetch_text(bbcode_path, true)
	if bbcode.is_empty():
		_set_status(CdnClient.get_last_error() if not CdnClient.get_last_error().is_empty() else "Failed to load article")
		return

	bbcode = NewsFeed.sanitize_bbcode(bbcode)
	bbcode = await _localize_images(bbcode)
	article_title.text = HubSanitize.clamp_text(str(item.get("title", slug)), HubSanitize.MAX_TITLE_LEN)
	_set_hosts_bbcode(hosts_bb)
	_render_article_bbcode(bbcode)
	_show_detail()
	_set_status(slug)


func _localize_images(bbcode: String) -> String:
	## Download CDN [img] URLs into local files RichTextLabel can display.
	var out := bbcode
	var re := RegEx.new()
	if re.compile("\\[img\\](https?://[^\\[]+)\\[/img\\]") != OK:
		return out
	var matches := re.search_all(bbcode)
	var cache_dir := "user://news_img_cache"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cache_dir))
	var fetched := 0
	for m in matches:
		if fetched >= HubSanitize.MAX_IMAGES_PER_ARTICLE:
			break
		var url := m.get_string(1).strip_edges()
		if not HubSanitize.is_allowed_cdn_url(url):
			continue
		var local_path := await _cache_image(url, cache_dir)
		if local_path.is_empty():
			continue
		out = out.replace("[img]%s[/img]" % url, "[img]%s[/img]" % local_path)
		fetched += 1
	return out


func _cache_image(url: String, cache_dir: String) -> String:
	if not HubSanitize.is_allowed_cdn_url(url):
		return ""
	var hash_name := url.md5_text()
	var ext := ".img"
	var q := url.find("?")
	var path_part := url if q < 0 else url.substr(0, q)
	var dot := path_part.rfind(".")
	if dot >= 0 and dot > path_part.rfind("/"):
		ext = path_part.substr(dot)
		if ext.length() > 8:
			ext = ".img"
	var local := "%s/%s%s" % [cache_dir, hash_name, ext]
	if not FileAccess.file_exists(local):
		var bytes := await CdnClient.fetch_bytes(url, true)
		if bytes.is_empty():
			return ""
		var f := FileAccess.open(local, FileAccess.WRITE)
		if f == null:
			return ""
		f.store_buffer(bytes)
	return ProjectSettings.globalize_path(local).replace("\\", "/")


func _render_article_bbcode(bbcode: String) -> void:
	article_body.clear()
	_article_textures.clear()
	var re := RegEx.new()
	if re.compile("\\[img\\](.*?)\\[/img\\]") != OK:
		article_body.append_text(bbcode)
		return
	var pos := 0
	for m in re.search_all(bbcode):
		var start := m.get_start()
		if start > pos:
			article_body.append_text(bbcode.substr(pos, start - pos))
		var tex := _texture_from_local(m.get_string(1).strip_edges())
		if tex:
			_article_textures.append(tex)
			article_body.add_image(tex)
		pos = m.get_end()
	if pos < bbcode.length():
		article_body.append_text(bbcode.substr(pos))


func _texture_from_local(path: String) -> Texture2D:
	if path.is_empty() or path.begins_with("http"):
		return null
	var img := Image.new()
	if img.load(path) != OK:
		if not FileAccess.file_exists(path):
			return null
		var bytes := FileAccess.get_file_as_bytes(path)
		if bytes.is_empty():
			return null
		if img.load_png_from_buffer(bytes) != OK and img.load_jpg_from_buffer(bytes) != OK and img.load_webp_from_buffer(bytes) != OK:
			return null
	if img.is_empty():
		return null
	return ImageTexture.create_from_image(img)
