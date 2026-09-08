-- Companion Luau API mirror of CdnClient (autoload uses scripts/gdscript/cdn_client.gd).
local CDN_BASE = "https://cdn.blazium.app"

local CdnClient = {
	extends = "Node",
	class_name = "CdnClientService",

	_last_error = "",

	_ready = function(self)
		self._last_error = ""
	end,

	get_last_error = function(self)
		return self._last_error
	end,

	catalog_channel_alias = function(_self, channel)
		if tostring(channel) == "prerelease" then
			return "pre-release"
		end
		return ""
	end,

	latest_path = function(_self, channel)
		return "/catalog/versions/" .. tostring(channel) .. "/latest.json"
	end,

	versions_path = function(_self, channel)
		return "/catalog/versions/" .. tostring(channel) .. ".json"
	end,

	editors_path = function(_self, channel, version)
		return "/" .. tostring(channel) .. "/" .. tostring(version) .. "/editors.json"
	end,

	articles_rss_path = function(_self)
		return "/articles/rss.xml"
	end,

	article_bbcode_path = function(_self, slug)
		return "/articles/" .. tostring(slug) .. "/content.bbcode"
	end,

	article_meta_path = function(_self, slug)
		return "/articles/" .. tostring(slug) .. "/meta.json"
	end,

	-- Network fetch lives in the GDScript autoload; Luau mirror exposes path helpers + CDN base.
	cdn_base = function(_self)
		return CDN_BASE
	end,

	fetch_json = function(self, _path)
		self._last_error = "use GDScript CdnClient autoload for HTTP fetch"
		return nil
	end,

	latest = function(self, channel)
		return self:fetch_json(self:latest_path(channel))
	end,

	versions = function(self, channel)
		return self:fetch_json(self:versions_path(channel))
	end,

	editors_for = function(self, channel, version)
		return self:fetch_json(self:editors_path(channel, version))
	end,
}

return gdclass(CdnClient)
