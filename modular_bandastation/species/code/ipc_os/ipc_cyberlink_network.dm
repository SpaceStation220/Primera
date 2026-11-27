/datum/ipc_os_program/cyberlink
	var/datum/weakref/bot_order_target

/datum/ipc_os_program/cyberlink/proc/command_bots(mob/user)
	var/list/bots = list()
	for(var/mob/living/basic/bot/bot as anything in machine_targets())
		if(istype(bot) && can_remote_ui(user, bot))
			bots += list(list("id" = REF(bot), "name" = bot.name, "selected" = bot_order_target?.resolve() == bot))
	return bots

/datum/ipc_os_program/cyberlink/proc/order_bot(mob/user, turf/destination)
	var/mob/living/basic/bot/bot = bot_order_target?.resolve()
	var/turf/origin = get_turf(bot)
	if(!destination || !origin || destination.z != origin.z || !can_remote_ui(user, bot) || !bot.ai_controller || !(bot.bot_mode_flags & BOT_MODE_ON))
		return FALSE
	if(camera_session)
		if(!camera_session.valid(user) || !(destination in camera_session.visible_turfs()) || !spend_charge(0.5))
			return FALSE
	else if(!(destination in view(user)))
		return FALSE
	if(!bot.summon_bot(user, destination))
		return FALSE
	os.host.adjust_coretemperature(25)
	to_chat(user, span_notice("[bot.name]: маршрут принят."))
	return TRUE

/datum/ipc_os_program/cyberlink/proc/active_relay_anchor() as /atom/movable
	var/atom/movable/anchor = relay_anchor?.resolve()
	if(anchor && connection_body?.resolve() == os.host && os.can_use(os.host) && (anchor in machine_targets()) && machine_operational(anchor))
		return anchor

/// The linked node extends command range by four tiles. Nearby endpoints cannot extend it again.
/datum/ipc_os_program/cyberlink/proc/relay_targets()
	var/list/targets = list()
	var/atom/movable/anchor = active_relay_anchor()
	if(!anchor)
		return targets
	for(var/atom/movable/target in range(4, anchor))
		if(target != anchor && machine_kind(target) && machine_operational(target))
			targets += target
	return targets

/datum/ipc_os_program/cyberlink/proc/command_targets()
	return machine_targets() | relay_targets()

/datum/ipc_os_program/cyberlink/proc/is_relayed(atom/movable/target)
	return !(target in machine_targets()) && (target in relay_targets())

/datum/ipc_cyberlink_camera
	var/network_hops = 0

/datum/ipc_cyberlink_camera/proc/transition_targets()
	var/list/targets = list()
	if(!valid(program.os.host) || QDELETED(active_camera) || !active_camera.can_use())
		return targets
	var/list/visible = visible_turfs()
	for(var/obj/machinery/camera/candidate in SScameras.cameras)
		if(candidate != active_camera && candidate.can_use() && length(candidate.network) && length(candidate.network - network) && (get_turf(candidate) in visible))
			targets += candidate
	return targets

/// Match the human security console: hardware X-ray is allowed, malf-only sight is not.
/datum/ipc_cyberlink_camera/proc/visible_turfs()
	var/list/turfs = list()
	if(QDELETED(active_camera) || !active_camera.can_use())
		return turfs
	var/turf/position = get_turf(active_camera)
	if(!position)
		return turfs
	var/list/visible = active_camera.isXRay(ignore_malf_upgrades = TRUE) ? range(active_camera.view_range, position) : view(active_camera.view_range, position)
	for(var/turf/tile in visible)
		turfs += tile
	return turfs

/datum/ipc_cyberlink_camera/proc/switch_network(obj/machinery/camera/camera)
	if(!(camera in transition_targets()))
		return FALSE
	active_camera?.on_stop_watching(src)
	active_camera = camera
	var/list/reachable_networks = camera.network - network
	network = list(reachable_networks[1])
	network_hops++
	active_camera.on_start_watching(src)
	render_camera()
	update_static_data_for_all_viewers()
	return TRUE
/datum/ipc_cyberlink_camera/proc/transition_data()
	var/list/data = list()
	for(var/obj/machinery/camera/candidate as anything in transition_targets())
		data += list(list("name" = candidate.c_tag, "ref" = REF(candidate)))
	return data
/datum/ipc_os_program/cyberlink/proc/relay_data()
	var/list/data = list()
	for(var/atom/movable/target as anything in relay_targets())
		data += list(list("id" = REF(target), "name" = target.name, "authorized" = !!machine_authorized(target)))
	return data
