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

	sidecar_filename_for = function(_self, os_name)
		if os_name == "Windows" then
			return "crash_reporter.exe"
		end
		return "crash_reporter"
	end,

	sidecar_filename = function(self)
		return self:sidecar_filename_for(OS.get_name())
	end,

	sidecar_path_in = function(self, dir)
		local base = tostring(dir or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if base == "" then
			return ""
		end
		local p = base .. "/" .. self:sidecar_filename()
		if FileAccess.file_exists(p) then
			return p
		end
		return ""
	end,

	sidecar_path = function(self)
		return self:sidecar_path_in(OS.get_executable_path():get_base_dir())
	end,

	crash_reporter_cli_args_for = function(self, dir)
		local p = self:sidecar_path_in(dir)
		if p == "" then
			return {}
		end
		return { "--crash-reporter", p }
	end,

	data_collection_cli_args = function(_self)
		local args = {}
		if HubSettings == nil then
			return args
		end
		local consent = HubSettings:editor_analytics_consent()
		if consent and consent ~= "" then
			table.insert(args, "--analytics=" .. consent)
		end
		local mode = HubSettings:editor_analytics_mode()
		if mode and mode ~= "" then
			table.insert(args, "--analytics-mode=" .. mode)
		end
		if HubSettings.data_collection_decided and not HubSettings.data_collection_enabled then
			table.insert(args, "--no-crash-reporter")
		end
		return args
	end,

	_with_editor_launch_args = function(self, args)
		for _, v in ipairs(self:data_collection_cli_args()) do
			table.insert(args, v)
		end
		if HubSettings == nil or HubSettings:should_attach_editor_crash_reporter() then
			local extra = self:crash_reporter_cli_args_for(OS.get_executable_path():get_base_dir())
			for _, v in ipairs(extra) do
				table.insert(args, v)
			end
		end
		return args
	end,

	_with_crash_reporter = function(self, args)
		return self:_with_editor_launch_args(args)
	end,

	get_last_error = function(self)
		return self._last_error
	end,

	_trim = function(_self, s)
		return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
	end,

	_append_unique_path = function(_self, candidates, path)
		local p = tostring(path or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if p == "" then
			return
		end
		for _, existing in ipairs(candidates) do
			if existing == p then
				return
			end
		end
		table.insert(candidates, p)
	end,

	install_root_from_exe = function(self)
		local exe = self:_trim(OS.get_executable_path())
		if exe == "" then
			return ""
		end
		local base = exe:get_base_dir()
		local leaf = string.lower(base:get_file())
		if leaf == "hub" or leaf == "bin" then
			return base:get_base_dir()
		end
		return base
	end,

	_append_cli_from_root = function(self, candidates, root, is_win)
		local r = self:_trim(root)
		if r == "" then
			return
		end
		if is_win then
			self:_append_unique_path(candidates, r .. "\\blazium-cli.exe")
			self:_append_unique_path(candidates, r .. "\\bin\\blazium-cli.exe")
		else
			self:_append_unique_path(candidates, r .. "/bin/blazium-cli")
			self:_append_unique_path(candidates, r .. "/blazium-cli")
		end
	end,

	list_cli_candidates = function(self)
		local candidates = {}
		local is_win = OS.get_name() == "Windows"
		self:_append_cli_from_root(candidates, OS.get_environment("BLAZIUM"), is_win)
		self:_append_cli_from_root(candidates, self:install_root_from_exe(), is_win)
		local exe_dir = OS.get_executable_path():get_base_dir()
		if is_win then
			self:_append_unique_path(candidates, exe_dir .. "\\blazium-cli.exe")
			self:_append_unique_path(candidates, OS.get_environment("ProgramFiles") .. "\\Blazium\\blazium-cli.exe")
			self:_append_unique_path(candidates, OS.get_environment("LOCALAPPDATA") .. "\\Blazium\\blazium-cli.exe")
			self:_append_unique_path(candidates, "blazium-cli.exe")
			self:_append_unique_path(candidates, "blazium-cli")
		else
			self:_append_unique_path(candidates, exe_dir .. "/blazium-cli")
			self:_append_unique_path(candidates, "/opt/blazium/bin/blazium-cli")
			self:_append_unique_path(candidates, "/usr/local/bin/blazium-cli")
			self:_append_unique_path(candidates, "/usr/bin/blazium-cli")
			self:_append_unique_path(candidates, OS.get_environment("HOME") .. "/.local/bin/blazium-cli")
			self:_append_unique_path(candidates, "blazium-cli")
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
		local extracted = self:extract_last_json_text(text)
		local payload = extracted ~= "" and extracted or text
		local data = nil
		if string.sub(payload, 1, 1) == "{" or string.sub(payload, 1, 1) == "[" then
			data = JSON.parse_string(payload)
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

	install_path = function(self, path, move_editors)
		if path and path ~= "" then
			local args = { "install-path", path }
			if move_editors then
				table.insert(args, "--move")
			end
			return self:run_json(args)
		end
		return self:run_json({ "install-path" })
	end,

	projects = function(self)
		return self:run_json({ "projects" })
	end,

	projects_add = function(self, path)
		return self:run_json({ "projects", "add", path })
	end,

	projects_create = function(self, path, project_name)
		local args = { "projects", "create", path }
		if project_name and project_name ~= "" then
			table.insert(args, "--name")
			table.insert(args, project_name)
		end
		return self:run_json(args)
	end,

	projects_remove = function(self, path)
		return self:run_json({ "projects", "remove", path })
	end,

	open_project = function(self, path)
		return self:run_json(self:_with_crash_reporter({ "open", path }))
	end,

	load_project = function(self, path)
		return self:run_json(self:_with_crash_reporter({ "load", path }))
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

	update_apply_toolchain = function(self, install_root)
		local args = { "update", "apply", "--product", "toolchain" }
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
		return self:run_json(self:_with_crash_reporter({ "handle-uri", uri }))
	end,
}

return gdclass(HubCli)
