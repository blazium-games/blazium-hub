-- HubCli: run blazium-cli --json and parse stdout.
local HubCli = {
	extends = "Node",
	class_name = "HubCliService",

	cli_path = "",
	_last_error = "",

	_ready = function(self)
		self.cli_path = ""
		self._last_error = ""
	end,

	set_cli_path = function(self, path)
		self.cli_path = tostring(path or "")
	end,

	get_cli_path = function(self)
		return self.cli_path
	end,

	get_last_error = function(self)
		return self._last_error
	end,

	list_cli_candidates = function(_self)
		local candidates = {}
		local root = tostring(OS.get_environment("BLAZIUM") or ""):gsub("^%s+", ""):gsub("%s+$", "")
		local os_name = OS.get_name()
		local is_win = os_name == "Windows"
		if root ~= "" then
			if is_win then
				table.insert(candidates, root .. "\\blazium-cli.exe")
				table.insert(candidates, root .. "\\bin\\blazium-cli.exe")
			else
				table.insert(candidates, root .. "/bin/blazium-cli")
				table.insert(candidates, root .. "/blazium-cli")
			end
		end
		if is_win then
			local localapp = OS.get_environment("LOCALAPPDATA")
			local prog = OS.get_environment("ProgramFiles")
			table.insert(candidates, prog .. "\\Blazium\\blazium-cli.exe")
			table.insert(candidates, localapp .. "\\Blazium\\blazium-cli.exe")
			table.insert(candidates, "blazium-cli.exe")
			table.insert(candidates, "blazium-cli")
		else
			table.insert(candidates, "/opt/blazium/bin/blazium-cli")
			table.insert(candidates, "/usr/local/bin/blazium-cli")
			table.insert(candidates, "/usr/bin/blazium-cli")
			table.insert(candidates, OS.get_environment("HOME") .. "/.local/bin/blazium-cli")
			table.insert(candidates, "blazium-cli")
		end
		return candidates
	end,

	resolve_cli = function(self)
		if self.cli_path ~= "" and FileAccess.file_exists(self.cli_path) then
			return self.cli_path
		end
		local settings = Engine.get_main_loop():get_root():get_node_or_null("/root/HubSettings")
		if settings and settings.has_method("get_cli_path") then
			local p = settings:get_cli_path()
			if p ~= "" and FileAccess.file_exists(p) then
				self.cli_path = p
				return p
			end
		end
		for _, c in ipairs(self:list_cli_candidates()) do
			if c == "blazium-cli" or c == "blazium-cli.exe" then
				self.cli_path = c
				return c
			end
			if FileAccess.file_exists(c) then
				self.cli_path = c
				return c
			end
		end
		self._last_error = "blazium-cli not found"
		return ""
	end,

	extract_last_json_text = function(_self, text)
		local s = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if s == "" then
			return ""
		end
		local end_i = nil
		for i = #s, 1, -1 do
			local ch = string.sub(s, i, i)
			if ch == "}" or ch == "]" then
				end_i = i
				break
			end
		end
		if not end_i then
			return ""
		end
		local close_ch = string.sub(s, end_i, end_i)
		local open_ch = (close_ch == "}") and "{" or "["
		local depth = 0
		local in_str = false
		local escape = false
		for i = end_i, 1, -1 do
			local ch = string.sub(s, i, i)
			if in_str then
				if escape then
					escape = false
				elseif ch == "\\" then
					escape = true
				elseif ch == '"' then
					in_str = false
				end
			elseif ch == '"' then
				in_str = true
			elseif ch == close_ch then
				depth = depth + 1
			elseif ch == open_ch then
				depth = depth - 1
				if depth == 0 then
					return string.sub(s, i, end_i)
				end
			end
		end
		return ""
	end,

	run_json = function(self, args)
		self._last_error = ""
		local bin = self:resolve_cli()
		if bin == "" then
			return nil
		end
		local argv = { "--json" }
		for _, a in ipairs(args) do
			table.insert(argv, tostring(a))
		end
		local output = {}
		local code = OS.execute(bin, argv, output, true, false)
		local text = ""
		if typeof(output) == TYPE_PACKED_STRING_ARRAY or typeof(output) == TYPE_ARRAY then
			local parts = {}
			for i = 0, output.size() - 1 do
				table.insert(parts, output[i])
			end
			text = table.concat(parts, "\n")
		elseif type(output) == "table" then
			text = table.concat(output, "\n")
		else
			text = tostring(output)
		end
		text = string.gsub(text, "^%s+", "")
		text = string.gsub(text, "%s+$", "")
		local joined = table.concat(argv, " ")
		local hub_log = Engine.get_main_loop():get_root():get_node_or_null("/root/HubLog")
		if hub_log and hub_log.has_method("append_block") then
			hub_log:append_block(string.format("CLI %s %s (exit %s)", bin, joined, tostring(code)), text)
		end
		if text == "" then
			self._last_error = "empty CLI output (exit " .. tostring(code) .. ")"
			return nil
		end
		local data = JSON.parse_string(text)
		if data == nil then
			local last = text
			for line in string.gmatch(text, "[^\r\n]+") do
				last = line
			end
			data = JSON.parse_string(last)
		end
		if data == nil then
			local extracted = self:extract_last_json_text(text)
			if extracted ~= "" then
				data = JSON.parse_string(extracted)
			end
		end
		if data == nil then
			self._last_error = "failed to parse JSON (see Logs): " .. string.sub(text, 1, 200)
			return nil
		end
		if type(data) == "table" and data.error then
			self._last_error = tostring(data.error)
			if code ~= 0 then
				return nil
			end
		end
		if code ~= 0 and (type(data) ~= "table" or data.ok ~= true) then
			self._last_error = self._last_error ~= "" and self._last_error or ("CLI exit " .. tostring(code))
			return nil
		end
		return data
	end,

	editors = function(self)
		return self:run_json({ "editors" })
	end,

	install = function(self, version, channel)
		local args = { "install" }
		if version and version ~= "" then
			table.insert(args, version)
		end
		channel = tostring(channel or ""):match("^%s*(.-)%s*$") or ""
		if channel ~= "" then
			table.insert(args, "--channel")
			table.insert(args, channel)
		end
		return self:run_json(args)
	end,

	uninstall = function(self, version, channel)
		local args = { "uninstall", version }
		channel = tostring(channel or ""):match("^%s*(.-)%s*$") or ""
		if channel ~= "" then
			table.insert(args, "--channel")
			table.insert(args, channel)
		end
		return self:run_json(args)
	end,

	install_path = function(self, path)
		if path and path ~= "" then
			return self:run_json({ "install-path", path })
		end
		return self:run_json({ "install-path" })
	end,

	projects = function(self)
		return self:run_json({ "projects" })
	end,

	projects_add = function(self, path)
		return self:run_json({ "projects", "add", path })
	end,

	projects_remove = function(self, path)
		return self:run_json({ "projects", "remove", path })
	end,

	open_project = function(self, path)
		return self:run_json({ "open", path })
	end,

	load_project = function(self, path)
		return self:run_json({ "load", path })
	end,

	upgrade_dry_run = function(self)
		return self:run_json({ "upgrade", "--dry-run" })
	end,

	update_check = function(self, product, hub_current, install_root)
		product = product or "all"
		local args = { "update", "check", "--product", product }
		if hub_current and hub_current ~= "" then
			table.insert(args, "--current")
			table.insert(args, hub_current)
		end
		if install_root and install_root ~= "" then
			table.insert(args, "--install-root")
			table.insert(args, install_root)
		end
		return self:run_json(args)
	end,

	update_apply_cli = function(self)
		return self:run_json({ "update", "apply", "--product", "cli" })
	end,

	update_apply_crash_reporter = function(self, install_root)
		local args = { "update", "apply", "--product", "crash_reporter" }
		if install_root and install_root ~= "" then
			table.insert(args, "--install-root")
			table.insert(args, install_root)
		end
		return self:run_json(args)
	end,

	update_apply_hub = function(self, current_version, install_root, launch)
		local args = { "update", "apply", "--product", "hub" }
		if current_version and current_version ~= "" then
			table.insert(args, "--current")
			table.insert(args, current_version)
		end
		if install_root and install_root ~= "" then
			table.insert(args, "--install-root")
			table.insert(args, install_root)
		end
		if launch then
			table.insert(args, "--launch")
		end
		return self:run_json(args)
	end,

	templates_download = function(self, version)
		return self:run_json({ "templates", "download", version, "--tpz" })
	end,

	handle_uri = function(self, uri)
		return self:run_json({ "handle-uri", uri })
	end,
}

return gdclass(HubCli)
