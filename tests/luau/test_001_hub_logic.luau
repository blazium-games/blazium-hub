-- AutoworkTest in Luau. Newer engines bind assert_*; keep error()/must() so release-editor CI still runs.
local function is_hub_show_uri(uri)
	if type(uri) ~= "string" then
		return false
	end
	local lower = string.lower((string.gsub(uri, "^%s+", "")))
	lower = (string.gsub(lower, "%s+$", ""))
	if lower == "" then
		return false
	end
	return lower == "blazium://"
		or lower == "blazium:"
		or lower == "blazium://hub"
		or string.sub(lower, 1, 14) == "blazium://hub?"
end

local function normalize_list_payload(data, primary_key)
	if type(data) ~= "table" then
		return {}
	end
	if data[primary_key] ~= nil and type(data[primary_key]) == "table" then
		return data[primary_key]
	end
	if data.items ~= nil and type(data.items) == "table" then
		return data.items
	end
	if data[1] ~= nil then
		return data
	end
	return {}
end

local function latest_path(channel)
	return "/catalog/versions/" .. tostring(channel) .. "/latest.json"
end

local function versions_path(channel)
	return "/catalog/versions/" .. tostring(channel) .. ".json"
end

local function editors_path(channel, version)
	return "/" .. tostring(channel) .. "/" .. tostring(version) .. "/editors.json"
end

local function parse_cli_json(text, code)
	text = string.gsub(tostring(text or ""), "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	if text == "" then
		return nil, "empty CLI output (exit " .. tostring(code) .. ")"
	end
	local ok_marker = string.find(text, '"ok"%s*:%s*true')
	local err_marker = string.match(text, '"error"%s*:%s*"(.-)"')
	if err_marker and code ~= 0 then
		return nil, err_marker
	end
	if ok_marker or string.sub(text, 1, 1) == "{" or string.sub(text, 1, 1) == "[" then
		return { raw = text, ok = ok_marker ~= nil }, nil
	end
	return nil, "failed to parse JSON"
end

local function must(cond, msg)
	if not cond then
		error(msg)
	end
end

local Test = {
	extends = "AutoworkTest",

	test_001_is_hub_show_uri = function(_self)
		must(is_hub_show_uri("blazium://hub"), "hub")
		must(is_hub_show_uri("BLAZIUM://HUB"), "case")
		must(is_hub_show_uri("blazium://hub?x=1"), "query")
		must(is_hub_show_uri("blazium://"), "bare")
		must(not is_hub_show_uri("blazium://open?path=C:/g"), "open")
		must(not is_hub_show_uri(""), "empty")
	end,

	test_001_normalize_list_payload = function(_self)
		local eds = normalize_list_payload({ editors = { { version = "1" } } }, "editors")
		must(#eds == 1, "editors key")
		local items = normalize_list_payload({ items = { { version = "2" } } }, "editors")
		must(#items == 1, "items fallback")
		local empty = normalize_list_payload({}, "editors")
		must(#empty == 0, "empty")
	end,

	test_001_cdn_paths = function(_self)
		must(latest_path("release") == "/catalog/versions/release/latest.json", "latest_path")
		must(versions_path("nightly") == "/catalog/versions/nightly.json", "versions_path")
		must(editors_path("release", "0.6.725") == "/release/0.6.725/editors.json", "editors_path")
	end,

	test_001_parse_cli_json_smoke = function(_self)
		local data, err = parse_cli_json('{"ok":true,"editors":[]}', 0)
		must(data ~= nil, "ok payload")
		must(err == nil, "no err")
		local bad, bad_err = parse_cli_json('{"error":"boom"}', 1)
		must(bad == nil, "error payload null")
		must(bad_err == "boom", "error text")
	end,
}

return Test
