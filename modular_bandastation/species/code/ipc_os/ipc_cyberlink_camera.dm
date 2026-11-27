/datum/ipc_os_program/cyberlink
	var/datum/ipc_cyberlink_camera/camera_session

/datum/ipc_os_program/cyberlink/proc/camera_targets()
	var/list/targets = list()
	if(!running || !available() || !os.can_use(os.host) || camera_session || pilot)
		return targets
	for(var/obj/machinery/camera/camera as anything in SScameras.cameras)
		if(camera.can_use() && length(camera.network))
			targets += camera
	return targets

/datum/ipc_os_program/cyberlink/proc/start_camera(obj/machinery/camera/entry)
	if(!(entry in camera_targets()))
		return FALSE
	camera_session = new(src, entry)
	if(os.host.client)
		camera_session.ui_interact(os.host)
	ensure_link_processing()
	return TRUE

/// A private native camera map prevents a neural viewer from changing another console's display.
/datum/ipc_cyberlink_camera
	var/datum/ipc_os_program/cyberlink/program
	var/datum/weakref/entry
	var/datum/weakref/body
	var/list/network
	var/obj/machinery/camera/active_camera
	var/atom/movable/screen/map_view/camera/screen
	var/elapsed = 0

/datum/ipc_cyberlink_camera/New(datum/ipc_os_program/cyberlink/program, obj/machinery/camera/entry)
	. = ..()
	src.program = program
	src.entry = WEAKREF(entry)
	body = WEAKREF(program.os.host)
	network = list(entry.network[1])
	active_camera = entry
	screen = new
	screen.generate_view("ipc_camera_[REF(src)]_map")
	entry.on_start_watching(src)

/datum/ipc_cyberlink_camera/proc/valid(mob/user)
	var/obj/machinery/camera/source = entry?.resolve()
	var/turf/location = get_turf(user)
	var/turf/source_location = get_turf(source)
	return program?.running && program.available() && program.os.can_use(user) && user == body?.resolve() && source?.can_use() && location && source_location

/datum/ipc_cyberlink_camera/proc/tick(seconds_per_tick)
	if(!valid(program.os.host))
		qdel(src)
		return
	elapsed += seconds_per_tick
	if(elapsed >= 10)
		elapsed -= 10
		if(!program.spend_charge(1 + 0.5 * network_hops))
			qdel(src)
			return
	render_camera()

/datum/ipc_cyberlink_camera/proc/render_camera()
	if(QDELETED(active_camera) || !active_camera.can_use())
		screen.show_camera_static()
		return
	var/list/turfs = visible_turfs()
	if(!length(turfs))
		screen.show_camera_static()
		return
	var/list/bounds = get_bbox_of_atoms(turfs)
	screen.show_camera(turfs, bounds[3]-bounds[1]+1, bounds[4]-bounds[2]+1)

/datum/ipc_cyberlink_camera/proc/on_camera_disabled(obj/machinery/camera/camera)
	if(active_camera != camera)
		return
	active_camera.on_stop_watching(src)
	active_camera = null
	render_camera()
	SStgui.update_uis(src)

/datum/ipc_cyberlink_camera/ui_host(mob/user)
	return body?.resolve()

/datum/ipc_cyberlink_camera/ui_state(mob/user)
	return GLOB.conscious_state

/datum/ipc_cyberlink_camera/ui_status(mob/user, datum/ui_state/state)
	return valid(user) ? UI_INTERACTIVE : UI_CLOSE

/datum/ipc_cyberlink_camera/ui_assets(mob/user)
	return list(get_asset_datum(/datum/asset/simple/nanomaps))

/datum/ipc_cyberlink_camera/ui_interact(mob/user, datum/tgui/ui)
	if(!valid(user) || !user.client)
		return
	render_camera()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "CameraConsole220", "Камеры · ChromieКnight 4.4")
		ui.open()
		screen.display_to(user, ui.window)

/datum/ipc_cyberlink_camera/ui_static_data(mob/user)
	return list("mapRef" = screen.assigned_map, "mapData" = SSmapping.get_map_ui_data())

/datum/ipc_cyberlink_camera/proc/nearby_camera_data()
	var/list/data = list()
	var/list/visible = visible_turfs()
	for(var/obj/machinery/camera/camera as anything in SScameras.cameras)
		if(!camera.c_tag || !length(camera.network & network) || (camera != active_camera && !(get_turf(camera) in visible)))
			continue
		data += list(list("name" = camera.c_tag, "ref" = REF(camera), "x" = camera.x, "y" = camera.y, "z" = camera.z, "status" = camera.camera_enabled))
	return data

/datum/ipc_cyberlink_camera/ui_data(mob/user)
	var/list/destinations = list()
	var/mob/living/basic/bot/bot = program.bot_order_target?.resolve()
	if(bot && program.can_remote_ui(user, bot))
		for(var/turf/tile as anything in visible_turfs())
			destinations += list(list("id" = REF(tile), "x" = tile.x, "y" = tile.y))
	return list("order_bot" = bot?.name, "destinations" = destinations, "network" = network, "cameras" = nearby_camera_data(), "activeCamera" = active_camera ? list("name" = active_camera.c_tag, "ref" = REF(active_camera), "status" = active_camera.camera_enabled) : null, "can_spy" = FALSE, "neural_hops" = network_hops, "neural_cost" = round(program.charge_cost(1 + 0.5 * network_hops) / program.os.host.ipc_charge_capacity() * 100, 0.01), "neural_routes" = transition_data())

/datum/ipc_cyberlink_camera/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(valid(ui.user) && action == "bot_order")
		for(var/turf/tile as anything in visible_turfs())
			if(REF(tile) == params["destination"])
				return program.order_bot(ui.user, tile)
		return FALSE
	if(valid(ui.user) && action == "neural_route")
		for(var/obj/machinery/camera/candidate as anything in transition_targets())
			if(REF(candidate) == params["camera"])
				INVOKE_ASYNC(program, TYPE_PROC_REF(/datum/ipc_os_program/cyberlink, route_hotkey), ui.user, candidate, FALSE)
				return TRUE
		return FALSE
	if(!valid(ui.user) || action != "switch_camera")
		return FALSE
	var/obj/machinery/camera/selected = locate(params["camera"]) in SScameras.cameras
	if(!selected?.can_use() || !length(selected.network & network) || (selected != active_camera && !(get_turf(selected) in visible_turfs())))
		return FALSE
	active_camera?.on_stop_watching(src)
	active_camera = selected
	active_camera.on_start_watching(src)
	render_camera()
	return TRUE

/datum/ipc_cyberlink_camera/ui_close(mob/user)
	. = ..()
	if(!QDELING(src))
		qdel(src)

/datum/ipc_cyberlink_camera/Destroy()
	if(program?.routing_network)
		program.cancel_routing()
	active_camera?.on_stop_watching(src)
	var/mob/user = body?.resolve()
	if(user)
		screen?.hide_from(user)
	SStgui.close_uis(src)
	QDEL_NULL(screen)
	if(program?.camera_session == src)
		program.camera_session = null
	program = null
	entry = null
	body = null
	active_camera = null
	network = null
	return ..()
