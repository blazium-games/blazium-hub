extends AutoworkTest


func test_005_cdn_paths_and_base() -> void:
	assert_eq(CdnClient.CDN_BASE, "https://cdn.blazium.app")
	assert_eq(CdnClient.latest_path("release"), "/catalog/versions/release/latest.json")
	assert_eq(CdnClient.versions_path("nightly"), "/catalog/versions/nightly.json")
	assert_eq(CdnClient.editors_path("release", "0.6.725"), "/release/0.6.725/editors.json")
	assert_false(CdnClient.CDN_BASE.contains("cerebro"), "never points at Cerebro")
