-- Companion Luau API mirror of UriRouter (autoload uses scripts/gdscript/uri_router.gd).
local function is_hub_show_uri(uri)
	local lower = string.lower(tostring(uri or ""):gsub("^%s+", ""):gsub("%s+$", ""))
	if lower == "" then
		return false
	end
	return lower == "blazium://"
		or lower == "blazium:"
		or lower == "blazium://hub"
		or string.sub(lower, 1, 14) == "blazium://hub?"
end

local UriRouter = {
	extends = "Node",
	class_name = "UriRouterService",

	is_hub_show_uri = function(_self, uri)
		return is_hub_show_uri(uri)
	end,

	handle_uri = function(self, uri)
		if is_hub_show_uri(uri) then
			return { ok = true, action = "hub", uri = uri }
		end
		local cli = Engine.get_main_loop():get_root():get_node("/root/HubCli")
		return cli:handle_uri(uri)
	end,
}

return gdclass(UriRouter)
