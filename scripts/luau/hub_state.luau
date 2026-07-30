-- Companion Luau API mirror of HubState (autoload uses scripts/gdscript/hub_state.gd).
local HubState = {
	extends = "Node",
	class_name = "HubStateService",
	installed_editors = {},
	projects_list = {},

	refresh_all = function(self)
		local cli = Engine.get_main_loop():get_root():get_node("/root/HubCli")
		local eds = cli:editors()
		if eds then
			self.installed_editors = eds.editors or eds.items or eds
		end
		local projs = cli:projects()
		if projs then
			self.projects_list = projs.projects or projs.items or projs
		end
	end,
}

return gdclass(HubState)
