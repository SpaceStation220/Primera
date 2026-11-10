/datum/ipc_os/ui_state(mob/user)
	return GLOB.conscious_state

/datum/ipc_os/ui_host(mob/user)
	return host

/datum/ipc_os/ui_status(mob/user, datum/ui_state/state)
	return can_use(user) ? UI_INTERACTIVE : UI_CLOSE

/datum/ipc_os/ui_interact(mob/user, datum/tgui/ui)
	if(!can_use(user))
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "IpcOS", "Positronic OS")
		ui.open()

/datum/ipc_os/ui_data(mob/user)
	var/list/catalog = list()
	for(var/id in programs)
		var/datum/ipc_os_program/program = programs[id]
		if(!program.available())
			continue
		catalog += list(list("id" = id, "name" = program.name, "description" = program.description, "icon" = program.icon, "size" = program.size, "illegal" = program.illegal, "installed" = program.installed, "running" = program.running, "passive" = program.passive))
	return list("programs" = catalog, "used" = used_storage(), "capacity" = capacity(), "charge" = round(100 * host.nutrition / NUTRITION_LEVEL_FULL, 0.1), "error" = error_message, "ready" = FALSE)

/datum/ipc_os/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(!can_use(ui.user))
		return FALSE
	error_message = null
	switch(action)
		if("install")
			install(params["id"])
		if("uninstall")
			uninstall(params["id"])
	return TRUE
