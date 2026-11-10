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
		catalog += list(list("id" = id, "name" = program.name, "description" = program.description, "icon" = program.icon, "size" = program.size, "illegal" = program.illegal, "installed" = program.installed, "running" = program.running, "passive" = program.passive, "ready" = program.ready))
	var/datum/ipc_os_program/signal_boost/signaler = programs["signal_boost"]
	var/datum/ipc_os_program/id_spoof/spoofer = programs["id_spoof"]
	return list("programs" = catalog, "used" = used_storage(), "capacity" = capacity(), "charge" = round(100 * host.nutrition / NUTRITION_LEVEL_FULL, 0.1), "temperature" = round(host.coretemperature - T0C, 0.1), "error" = error_message, "frequency" = signaler.frequency, "code" = signaler.code, "minFrequency" = MIN_FREE_FREQ, "maxFrequency" = MAX_FREE_FREQ, "spoof_name" = spoofer.spoof_name, "spoof_job" = spoofer.spoof_job, "stunned" = !!host.IsStun())

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
		if("toggle")
			if(!istext(params["id"]))
				return FALSE
			var/datum/ipc_os_program/program = programs[params["id"]]
			if(!program?.installed || program.passive || !program.ready)
				return FALSE
			if(program.running)
				program.stop()
			else if(!program.start())
				error_message = "Программа не может быть запущена."
		if("signal_freq", "signal_code", "signal_send")
			var/datum/ipc_os_program/signal_boost/signaler = programs["signal_boost"]
			signaler.command(action, params)
		if("pda_open")
			var/datum/ipc_os_program/pda/pda = programs["pda"]
			if(pda.running)
				pda.device.ui_interact(ui.user)
		if("spoof_text")
			var/datum/ipc_os_program/id_spoof/spoofer = programs["id_spoof"]
			if(!spoofer.installed || !istext(params["value"]))
				return FALSE
			var/value = strip_html(trim(copytext_char(params["value"], 1, MAX_NAME_LEN + 1)))
			if(params["field"] == "name" && length(value))
				spoofer.spoof_name = value
			else if(params["field"] == "job")
				spoofer.spoof_job = value
			if(spoofer.running)
				host.update_visible_name()
		if("neural_crack")
			neural_crack()
	return TRUE
