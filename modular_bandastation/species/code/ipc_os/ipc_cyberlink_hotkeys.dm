/datum/ipc_os_program/cyberlink
	var/datum/ipc_cyberlink_panel/routing_window

/datum/ipc_os_program/cyberlink/start()
	if(world.time < emp_disabled_until || !..())
		return FALSE
	RegisterSignal(os.host, COMSIG_MOB_CLICKON, PROC_REF(hotkey_click))
	RegisterSignal(os.host, COMSIG_MOB_TRIED_ACCESS, PROC_REF(remote_access))
	return TRUE

/datum/ipc_os_program/cyberlink/proc/hotkey_click(mob/user, atom/target, list/modifiers)
	SIGNAL_HANDLER
	if(!os.can_use(user) || pilot || modifiers[RIGHT_CLICK] || modifiers[MIDDLE_CLICK])
		return NONE
	if(isturf(target) && bot_order_target?.resolve() && modifiers[SHIFT_CLICK] && !modifiers[CTRL_CLICK] && !modifiers[ALT_CLICK])
		INVOKE_ASYNC(src, PROC_REF(order_bot_hotkey), user, target)
		return COMSIG_MOB_CANCEL_CLICKON
	if(modifiers[ALT_CLICK] && (target in connection_targets()))
		INVOKE_ASYNC(src, PROC_REF(route_hotkey), user, target, !!modifiers[SHIFT_CLICK])
		return COMSIG_MOB_CANCEL_CLICKON
	if(multitool_enabled && !modifiers[SHIFT_CLICK] && !modifiers[CTRL_CLICK] && !modifiers[ALT_CLICK] && multitool_supported(target))
		INVOKE_ASYNC(src, PROC_REF(use_multitool), user, target)
		return COMSIG_MOB_CANCEL_CLICKON
	if(!machine_kind(target) || !(target in command_targets()))
		return NONE
	if(modifiers[SHIFT_CLICK] && !modifiers[CTRL_CLICK] && machine_kind(target) != "door")
		if(machine_kind(target) in list("machine", "bot", "apc", "alarm"))
			INVOKE_ASYNC(src, PROC_REF(open_machine_ui), user, target)
			return COMSIG_MOB_CANCEL_CLICKON
		if(length(machine_commands(target)))
			INVOKE_ASYNC(src, PROC_REF(control_menu), user, target)
			return COMSIG_MOB_CANCEL_CLICKON
		return NONE
	var/command
	if(modifiers[CTRL_CLICK] && modifiers[SHIFT_CLICK])
		var/obj/machinery/door/airlock/door = target
		if(istype(door))
			command = door.secondsElectrified ? "unshock" : "shock"
	else if(modifiers[CTRL_CLICK])
		command = machine_kind(target) == "bot" ? "power" : machine_kind(target) == "apc" ? "breaker" : "bolts"
	else if(modifiers[SHIFT_CLICK])
		command = machine_kind(target) == "bot" ? "power" : "door_toggle"
	if(command && (command in machine_commands(target)))
		INVOKE_ASYNC(src, PROC_REF(execute_machine), user, target, command)
		return COMSIG_MOB_CANCEL_CLICKON
	return NONE

/datum/ipc_os_program/cyberlink/proc/order_bot_hotkey(mob/user, turf/destination)
	if(!order_bot(user, destination))
		to_chat(user, span_warning("Бот не принял маршрут. Проверьте питание, доступ и видимость точки."))

/datum/ipc_os_program/cyberlink/proc/control_menu(mob/user, atom/movable/target)
	var/list/commands = machine_commands(target)
	var/list/options = list()
	for(var/id in commands)
		options[commands[id]] = id
	var/selection = tgui_input_list(user, "Электронное управление", target.name, options)
	if(selection && !QDELETED(target))
		execute_machine(user, target, options[selection])

/datum/ipc_cyberlink_panel
	var/datum/ipc_os_program/cyberlink/program
	var/result

/datum/ipc_cyberlink_panel/New(datum/ipc_os_program/cyberlink/program)
	. = ..()
	src.program = program

/datum/ipc_cyberlink_panel/ui_host(mob/user)
	return program?.ui_host(user)

/datum/ipc_cyberlink_panel/ui_state(mob/user)
	return GLOB.conscious_state

/datum/ipc_cyberlink_panel/ui_status(mob/user, datum/ui_state/state)
	return program && (result || (program.routing && program.routing_valid())) && program.ui_status(user, null) == UI_INTERACTIVE ? UI_INTERACTIVE : UI_CLOSE

/datum/ipc_cyberlink_panel/ui_interact(mob/user, datum/tgui/ui)
	if(ui_status(user, null) != UI_INTERACTIVE)
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ChromieRouting", "Маршрутизация · ChromieКnight 4.4")
		ui.open()

/datum/ipc_cyberlink_panel/ui_data(mob/user)
	var/list/data = program.connection_data()
	data["routing_result"] = result
	return data

/datum/ipc_cyberlink_panel/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(action == "routing_dismiss" && result && program.ui_status(ui.user, null) == UI_INTERACTIVE)
		result = null
		SStgui.close_uis(src)
		return TRUE
	if(ui_status(ui.user, state) != UI_INTERACTIVE || !(action in list("routing_rotate", "routing_submit", "routing_cancel")))
		return FALSE
	return program.ui_act(action, params, ui, state)

/datum/ipc_cyberlink_panel/Destroy()
	SStgui.close_uis(src)
	program = null
	return ..()
/datum/ipc_os_program/cyberlink
	var/routing_audio_channel
	var/client/routing_audio_listener

/datum/ipc_os_program/cyberlink/proc/start_routing_audio()
	if(!os.host?.client)
		return
	if(!routing_audio_channel)
		routing_audio_channel = SSsounds.reserve_sound_channel_for_datum(src)
	routing_audio_listener = os.host.client
	SEND_SOUND(routing_audio_listener, sound('modular_bandastation/species/sound/ipc/cyberlink_routing.mp3', repeat = TRUE, channel = routing_audio_channel, volume = 60))

/datum/ipc_os_program/cyberlink/proc/stop_routing_audio()
	if(routing_audio_channel)
		if(routing_audio_listener)
			SEND_SOUND(routing_audio_listener, sound(null, channel = routing_audio_channel))
		SSsounds.free_sound_channel(routing_audio_channel)
		routing_audio_channel = null
	routing_audio_listener = null

/datum/ipc_cyberlink_panel/ui_close(mob/user)
	. = ..()
	if(!QDELETED(src) && user.client && program?.routing_valid())
		addtimer(CALLBACK(src, PROC_REF(reopen_active_route), user, program.attempt_id), 0)

/datum/ipc_cyberlink_panel/proc/reopen_active_route(mob/user, attempt)
	if(user.client && program?.attempt_id == attempt && program.routing_valid())
		ui_interact(user)
/datum/ipc_os_program/cyberlink/proc/route_hotkey(mob/user, atom/movable/target, advanced)
	if(!begin_routing(user, target, advanced))
		if(world.time < routing_ready_at)
			to_chat(user, span_warning("Маршрутизация восстанавливается: [ceil((routing_ready_at-world.time)/(1 SECONDS))] с."))
		else
			to_chat(user, span_warning("Подключение отклонено: проверьте дальность, питание, доступ и сложность маршрутизации."))
		open_ui(user)
