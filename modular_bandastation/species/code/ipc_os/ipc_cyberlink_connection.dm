/datum/ipc_os_program/cyberlink
	var/datum/ipc_routing_board/routing
	var/datum/weakref/routing_target
	var/datum/weakref/linked_target
	var/datum/weakref/relay_anchor
	var/datum/weakref/connection_body
	var/list/routing_cache = list()
	var/list/datum/ipc_cyberlink_access/accesses = list()
	var/attempt_id = 0
	var/routing_deadline = 0
	var/routing_network = FALSE
	var/routing_pilot_kind
	var/routing_ready_at = 0
	var/command_ready_at = 0
	var/link_processing = FALSE
	var/link_message

/datum/ipc_os_program/cyberlink/proc/has_memory(atom/target)
	if(QDELETED(target))
		return FALSE
	for(var/datum/ipc_cyberlink_memory/record as anything in memory)
		if(record.target_ref.resolve() == target)
			return TRUE
	return FALSE

/datum/ipc_os_program/cyberlink/proc/ensure_link_processing()
	if(!link_processing)
		link_processing = TRUE
		START_PROCESSING(SSfastprocess, src)

/datum/ipc_os_program/cyberlink/proc/busy()
	return camera_session || pilot || routing || linked_target?.resolve()

/datum/ipc_os_program/cyberlink/proc/connection_targets()
	return command_targets() | pilot_targets() | camera_targets() | (camera_session ? camera_session.transition_targets() : list())

/datum/ipc_os_program/cyberlink/proc/connection_ready(atom/movable/target)
	if(istype(target, /obj/machinery/camera))
		return (target in camera_targets()) || (camera_session && (target in camera_session.transition_targets()))
	if(pilot_ready(target))
		return TRUE
	return machine_operational(target)

/datum/ipc_os_program/cyberlink/proc/begin_routing(mob/user, atom/movable/target, advanced, pilot_bot = FALSE)
	var/is_network = camera_session && (target in camera_session.transition_targets())
	if(!os.can_use(user) || !running || !available() || os.control_session || (camera_session && !is_network) || pilot || routing || !(target in connection_targets()) || !connection_ready(target))
		return FALSE
	var/is_camera = istype(target, /obj/machinery/camera)
	if(is_camera && has_memory(target))
		if(is_network)
			return camera_session.switch_network(target)
		return start_camera(target)
	if(world.time < routing_ready_at)
		return FALSE
	if(is_network)
		advanced = FALSE
	else if(is_camera && !advanced)
		return FALSE
	var/kind = pilot_ready(target) ? pilot_kind(target) : null
	if(pilot_bot && !(kind in list("bot", "secbot")))
		return FALSE
	if(kind == "bot" && !pilot_bot)
		kind = null
	if((kind in list("combat", "secbot")) && !advanced)
		return FALSE
	var/known_bot = istype(target, /mob/living/basic/bot) && has_memory(target)
	if((!kind || kind == "bot") && !is_camera && !advanced && !known_bot && !slot_access(target))
		return FALSE
	var/through_relay = !kind && !is_camera && is_relayed(target)
	if(!is_camera && has_memory(target) && (kind || known_bot || !advanced))
		if(kind)
			disconnect_link()
			return pilot_start(target)
		connect_machine(target)
		ensure_link_processing()
		return TRUE
	if(!spend_charge(advanced ? 8 : 4))
		return FALSE
	if(!is_camera && !through_relay)
		disconnect_link()
	routing_network = is_network
	routing_pilot_kind = kind
	var/key = "[REF(target)]:[!!advanced]"
	var/datum/ipc_routing_board/board = routing_cache[key]
	if(board && board.target_ref.resolve() != target)
		qdel(board)
		board = null
	if(!board)
		board = new(advanced)
		board.target_ref = WEAKREF(target)
		routing_cache[key] = board
	routing = board
	routing_target = WEAKREF(target)
	connection_body = WEAKREF(os.host)
	if(!routing_window)
		routing_window = new(src)
	routing_window.result = null
	routing_deadline = world.time + (advanced ? 65 SECONDS : 40 SECONDS)
	attempt_id++
	link_message = null
	if(user.client)
		routing_window.ui_interact(user)
	start_routing_audio()
	ensure_link_processing()
	return TRUE

/datum/ipc_os_program/cyberlink/proc/routing_valid()
	var/atom/movable/target = routing_target?.resolve()
	return routing && world.time < routing_deadline && connection_body?.resolve() == os.host && os.can_use(os.host) && !os.control_session && (target in connection_targets()) && connection_ready(target) && (!routing_pilot_kind || pilot_ready(target))

/datum/ipc_os_program/cyberlink/proc/cancel_routing(failed = FALSE)
	if(!routing)
		return
	failed = failed || world.time >= routing_deadline
	var/advanced = routing.advanced
	routing.reset_progress()
	stop_routing_audio()
	routing_pilot_kind = null
	routing = null
	routing_network = FALSE
	routing_target = null
	attempt_id++
	routing_ready_at = world.time + (failed ? (advanced ? 80 SECONDS : 40 SECONDS) : 10 SECONDS)
	if(routing_window)
		if(failed)
			routing_feedback(FALSE)
		else
			SStgui.close_uis(routing_window)
	link_message = failed ? "Маршрутизация сорвана." : "Маршрутизация отменена. Поле возвращено в исходное состояние."
	if(failed && os.is_operational())
		os.host.adjust_coretemperature(advanced ? 70 : 35)
		os.host.apply_damage(advanced ? 40 : 20, BURN)

/datum/ipc_os_program/cyberlink/proc/submit_routing(mob/user, attempt, phase)
	if(!os.can_use(user) || !routing_valid() || attempt != attempt_id || phase != routing.phase || !routing.solved())
		return FALSE
	if(routing.advance_phase())
		link_message = "Вторая фаза: вход закреплён, добавлен узел авторизации."
		return TRUE
	var/atom/movable/target = routing_target.resolve()
	var/advanced = routing.advanced
	stop_routing_audio()
	var/datum/ipc_routing_board/completed = routing
	routing = null
	routing_target = null
	routing_cache -= "[REF(target)]:[!!advanced]"
	qdel(completed)
	attempt_id++
	var/starting_pilot = !!routing_pilot_kind
	routing_pilot_kind = null
	if(routing_network)
		routing_network = FALSE
		var/switched = camera_session?.switch_network(target)
		if(switched)
			remember(target)
		routing_feedback(switched)
		return switched
	if(istype(target, /obj/machinery/camera))
		var/started = start_camera(target)
		if(started)
			remember(target)
		routing_feedback(started)
		return started
	if(starting_pilot)
		if(!pilot_start(target, show_routing_result = TRUE))
			routing_feedback(FALSE)
			return FALSE
		remember(target)
		SStgui.close_uis(routing_window)
		return TRUE
	remember(target)
	connect_machine(target)
	routing_feedback(TRUE)
	if(advanced)
		accesses += new /datum/ipc_cyberlink_access(target)
	link_message = "Соединение установлено."
	log_game("[key_name(user)] completed [advanced ? "advanced" : "standard"] ChromieKnight routing for [target] at [AREACOORD(target)].")
	return TRUE

/datum/ipc_os_program/cyberlink/proc/connect_machine(atom/movable/target)
	if(!is_relayed(target))
		relay_anchor = WEAKREF(target)
	linked_target = WEAKREF(target)
	connection_body = WEAKREF(os.host)
	if(istype(target, /mob/living/basic/bot))
		bot_order_target = WEAKREF(target)

/datum/ipc_os_program/cyberlink/proc/disconnect_link()
	QDEL_NULL(camera_session)
	pilot?.end()
	cancel_routing()
	linked_target = null
	bot_order_target = null
	relay_anchor = null
	connection_body = null
	QDEL_LIST(accesses)

/datum/ipc_os_program/cyberlink/process(seconds_per_tick)
	refresh_remote_panels()
	if(routing)
		if(world.time >= routing_deadline)
			cancel_routing(TRUE)
		else if(!routing_valid())
			cancel_routing()
	if(camera_session)
		camera_session.tick(seconds_per_tick)
		return
	if(pilot)
		pilot.tick(seconds_per_tick)
		if(!pilot)
			link_processing = FALSE
			return PROCESS_KILL
		return
	if(!running || !available() || !os.is_operational() || !os.can_use(os.host) || os.control_session)
		disconnect_link()
		link_processing = FALSE
		return PROCESS_KILL
	var/atom/movable/target = linked_target?.resolve()
	if(linked_target && (!target || connection_body?.resolve() != os.host || !(target in command_targets()) || !machine_operational(target)))
		if(active_relay_anchor())
			linked_target = relay_anchor
		else
			disconnect_link()
	for(var/datum/ipc_cyberlink_access/access as anything in accesses.Copy())
		access.restore()
		if(!access.target_ref.resolve() || (world.time >= access.expires_at && !access.owns_bolts && !access.owns_shock))
			accesses -= access
			qdel(access)
	if(!routing && !linked_target && !length(accesses) && !length(remote_panels))
		link_processing = FALSE
		return PROCESS_KILL

/datum/ipc_os_program/cyberlink/proc/connection_data()
	var/list/devices = list()
	var/atom/connected = linked_target?.resolve()
	if(pilot)
		connected = pilot.target
	if(camera_session)
		connected = camera_session.entry.resolve()
	for(var/atom/movable/target as anything in machine_targets())
		var/list/buttons = list()
		var/list/commands = machine_commands(target)
		for(var/command in commands)
			buttons += list(list("id" = command, "name" = commands[command]))
		var/datum/ipc_cyberlink_access/access = access_for(target)
		devices += list(list("id" = REF(target), "name" = target.name, "online" = !!machine_operational(target), "slot_access" = !!slot_access(target), "known" = has_memory(target), "commands" = buttons, "access_left" = access ? ceil((access.expires_at - world.time)/(1 SECONDS)) : 0))
	for(var/atom/movable/target as anything in pilot_targets())
		devices += list(list("id" = REF(target), "name" = target.name, "online" = TRUE, "pilot_kind" = pilot_kind(target), "slot_access" = pilot_kind(target) != "bot" || !!slot_access(target), "known" = has_memory(target), "commands" = list(), "access_left" = 0))
	return list(
		"devices" = devices,
		"relay_name" = active_relay_anchor()?.name,
		"relay_targets" = relay_data(),
		"attempt" = attempt_id,
		"phase" = routing?.phase,
		"advanced" = routing?.advanced,
		"board" = routing?.cell_data(),
		"routing_left" = routing ? ceil(max(0, routing_deadline-world.time)/(1 SECONDS)) : 0,
		"routing_cooldown" = ceil(max(0, routing_ready_at-world.time)/(1 SECONDS)),
		"command_cooldown" = ceil(max(0, command_ready_at-world.time)/(1 SECONDS)),
		"connected" = connected?.name,
		"message" = link_message,
	)
