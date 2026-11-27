/// A core-owned record remembers one physical instance without keeping a destroyed machine alive.
/datum/ipc_cyberlink_memory
	var/datum/weakref/target_ref
	var/label
	var/category = "machine"

/datum/ipc_cyberlink_memory/New(atom/target)
	. = ..()
	target_ref = WEAKREF(target)
	label = target.name
	if(istype(target, /mob/living/basic/bot))
		category = "bot"
	else if(istype(target, /obj/vehicle/sealed/mecha))
		category = "mech"
	else if(istype(target, /obj/machinery/camera))
		category = "camera"

/datum/ipc_cyberlink_memory/Destroy()
	target_ref = null
	return ..()

/datum/ipc_os_program/cyberlink
	id = "cyberlink"
	name = "ChromieКnight 4.4"
	description = "Системный нейронный интерфейс IV поколения «Киберлинк»."
	icon = "network-wired"
	builtin = TRUE
	installed = TRUE
	passive = TRUE
	ready = TRUE
	/// Persists with this core, independently of stopping or transplanting the program.
	var/remote_enabled = TRUE
	var/list/datum/ipc_cyberlink_memory/memory = list()
	var/list/last_scan
	/// Effective EMPs keep this core's copy of ChromieKnight offline until this time.
	var/emp_disabled_until = 0

/datum/ipc_os_program/cyberlink/available()
	return os.generation() == "IV"

/datum/ipc_os_program/cyberlink/proc/emp_seconds_left()
	return ceil(max(0, emp_disabled_until - world.time) / (1 SECONDS))

/datum/ipc_os_program/cyberlink/proc/disable_by_emp(severity)
	if(!available() || (severity != EMP_LIGHT && severity != EMP_HEAVY))
		return
	var/until = world.time + (severity == EMP_HEAVY ? 90 SECONDS : 60 SECONDS)
	if(until <= emp_disabled_until)
		return
	emp_disabled_until = until
	stop()
	if(os.host)
		to_chat(os.host, span_warning("ChromieКnight 4.4 отключена ЭМИ. Восстановление через [emp_seconds_left()] с."))

/datum/ipc_os_program/cyberlink/stop()
	if(os.host)
		UnregisterSignal(os.host, list(COMSIG_MOB_CLICKON, COMSIG_MOB_TRIED_ACCESS))
	close_remote_panels()
	QDEL_NULL(neural_multitool)
	multitool_enabled = FALSE
	QDEL_NULL(routing_window)
	disconnect_link()
	if(link_processing)
		STOP_PROCESSING(SSfastprocess, src)
		link_processing = FALSE
	last_scan = null
	SStgui.close_uis(src)
	return ..()

/datum/ipc_os_program/cyberlink/Destroy()
	stop()
	QDEL_LIST_ASSOC_VAL(routing_cache)
	routing_cache = null
	QDEL_LIST(memory)
	memory = null
	return ..()

/// Only a completed server-side routing operation may call this; knowledge is not authorization.
/datum/ipc_os_program/cyberlink/proc/remember(atom/target)
	if(QDELETED(target))
		return null
	for(var/datum/ipc_cyberlink_memory/record as anything in memory)
		if(record.target_ref.resolve() == target)
			return record
	var/datum/ipc_cyberlink_memory/new_record = new(target)
	memory += new_record
	return new_record

/// Dedicated debits deliberately exclude ordinary OS drain multipliers and apply PowerSave once.
/datum/ipc_os_program/cyberlink/proc/charge_cost(percent)
	if(!isnum(percent) || percent <= 0 || percent > 100 || !available() || !os.is_operational())
		return null
	var/datum/ipc_os_program/power_save/power_save = os.programs["power_save"]
	return os.host.ipc_charge_capacity() * percent / 100 * (power_save.installed && power_save.running ? 0.85 : 1)

/datum/ipc_os_program/cyberlink/proc/spend_charge(percent)
	var/cost = charge_cost(percent)
	var/obj/item/organ/heart/ipc/battery = os.working_battery()
	if(isnull(cost) || !running || !battery || os.host.nutrition < cost)
		return FALSE
	return battery.adjust_charge(-cost) == -cost

/// Diagnostics enumerate only supported electronics currently visible to the physical chassis.
/datum/ipc_os_program/cyberlink/proc/scanner_targets()
	var/list/targets = list()
	if(!running || !available() || !os.is_operational() || pilot)
		return targets
	for(var/atom/target in view(4, os.host))
		if(istype(target, /obj/machinery/door/airlock) || istype(target, /obj/machinery/power/apc) || istype(target, /obj/machinery/airalarm) || istype(target, /obj/machinery/camera) || istype(target, /obj/vehicle/sealed/mecha) || istype(target, /mob/living/basic/bot))
			targets += target
	return targets

/datum/ipc_os_program/cyberlink/proc/scan_machine(mob/user, atom/target)
	if(!os.can_use(user) || !running || !available() || QDELETED(target) || !(target in scanner_targets()))
		return FALSE
	var/list/result = list("name" = target.name)
	if(ismachinery(target))
		var/obj/machinery/machine = target
		result["powered"] = !(machine.machine_stat & NOPOWER)
	if(target.uses_integrity)
		result["integrity"] = round(100 * target.get_integrity_percentage(), 0.1)
	else if(istype(target, /mob/living/basic/bot))
		var/mob/living/basic/bot/bot = target
		result["integrity"] = round(100 * bot.health / bot.maxHealth, 0.1)
	if(!spend_charge(1))
		return FALSE
	last_scan = result
	return TRUE

/datum/ipc_os_program/cyberlink/ui_host(mob/user)
	return pilot ? pilot.controlled : os.host

/datum/ipc_os_program/cyberlink/ui_state(mob/user)
	return GLOB.conscious_state

/datum/ipc_os_program/cyberlink/ui_status(mob/user, datum/ui_state/state)
	return available() && running && (os.can_use(user) || (pilot && pilot.controlled == user && pilot.valid())) ? UI_INTERACTIVE : UI_CLOSE

/datum/ipc_os_program/cyberlink/proc/open_ui(mob/user)
	if(ui_status(user, null) != UI_INTERACTIVE)
		return FALSE
	ui_interact(user)
	return TRUE

/datum/ipc_os_program/cyberlink/ui_interact(mob/user, datum/tgui/ui)
	if(ui_status(user, null) != UI_INTERACTIVE)
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ChromieKnight", name)
		ui.open()

/datum/ipc_os_program/cyberlink/ui_data(mob/user)
	var/list/records = list()
	var/list/targets = list()
	var/list/cameras = list()
	for(var/obj/machinery/camera/camera as anything in camera_targets())
		cameras += list(list("id" = REF(camera), "name" = camera.c_tag || camera.name, "known" = has_memory(camera)))
	for(var/atom/target as anything in scanner_targets())
		targets += list(list("id" = REF(target), "name" = target.name))
	var/list/nearby = connection_targets()
	var/list/active_devices = remote_panels.Copy()
	for(var/atom/movable/device as anything in list(linked_target?.resolve(), pilot?.target, camera_session?.entry?.resolve(), camera_session?.active_camera))
		if(device)
			active_devices |= device
	for(var/datum/ipc_cyberlink_memory/record as anything in memory)
		var/atom/movable/device = record.target_ref.resolve()
		var/reachable = device && (device in nearby) && connection_ready(device)
		records += list(list("id" = REF(record), "name" = record.label, "category" = record.category, "available" = !!device, "reachable" = !!reachable, "target" = reachable ? REF(device) : null, "pilot_kind" = pilot_kind(device), "active" = device && (device in active_devices)))

	var/list/data = list(
		"command_bots" = command_bots(user),
		"camera_targets" = cameras,
		"active_devices" = length(active_devices),
		"remote_enabled" = remote_enabled,
		"buffer_name" = neural_multitool?.buffer ? "[neural_multitool.buffer]" : null,
		"camera_network" = camera_session?.network,
		"pilot_kind" = pilot_kind(pilot?.target),
		"machine_link" = !!linked_target?.resolve(),
		"multitool_enabled" = multitool_enabled,
		"charge" = round(100 * os.host.nutrition / os.host.ipc_charge_capacity(), 0.1),
		"temperature" = round(os.host.coretemperature - T0C, 0.1),
		"memory" = records,
		"scanner_targets" = targets,
		"scan_cost" = charge_cost(1) / os.host.ipc_charge_capacity() * 100,
		"last_scan" = last_scan,
	)
	var/mob/living/basic/bot/linked_bot = linked_target?.resolve()
	if(istype(linked_bot) && !camera_session && pilot_ready(linked_bot))
		data["linked_bot_pilot"] = REF(linked_bot)
	if(pilot?.target)
		data["pilot_instructions"] = pilot.bot_instructions()
		data["pilot_distance"] = get_dist(get_turf(os.host), get_turf(pilot.target))
		data["pilot_cost"] = round(charge_cost(pilot.periodic_cost()) * 100 / os.host.ipc_charge_capacity(), 0.01)
		if(istype(pilot.target, /obj/vehicle/sealed/mecha))
			data["pilot_integrity"] = round(100 * pilot.target.get_integrity_percentage())
	data += connection_data()
	return data

/datum/ipc_os_program/cyberlink/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(ui_status(ui.user, state) != UI_INTERACTIVE)
		return FALSE
	if(action == "pilot_bot")
		return request_bot_pilot(ui.user, params["target"])
	if(action == "bot_panel" || action == "bot_order_select")
		for(var/mob/living/basic/bot/bot as anything in GLOB.bots_list)
			if(REF(bot) != params["target"] || !can_remote_ui(ui.user, bot))
				continue
			if(action == "bot_panel")
				return open_machine_ui(ui.user, bot)
			bot_order_target = WEAKREF(bot)
			if(camera_session)
				SStgui.update_uis(camera_session)
			return TRUE
		return FALSE
	if(action == "connected_control")
		var/atom/movable/target = linked_target?.resolve()
		if(!target || !(target in command_targets()))
			return FALSE
		if(machine_kind(target) in list("machine", "bot", "apc", "alarm"))
			return open_machine_ui(ui.user, target)
		INVOKE_ASYNC(src, PROC_REF(control_menu), ui.user, target)
		return TRUE
	if(action == "multitool_clear")
		neural_multitool?.set_buffer(null)
		return TRUE
	if(action == "multitool_toggle")
		multitool_enabled = !multitool_enabled
		return TRUE
	if(action == "relay_control")
		for(var/atom/movable/target as anything in relay_targets())
			if(REF(target) == params["target"])
				if(machine_kind(target) in list("machine", "bot", "apc", "alarm"))
					return open_machine_ui(ui.user, target)
				else
					INVOKE_ASYNC(src, PROC_REF(control_menu), ui.user, target)
				return TRUE
		return FALSE
	if(action == "remote_toggle")
		remote_enabled = !remote_enabled
		return TRUE
	if(action == "disconnect")
		if(routing)
			return FALSE
		disconnect_link()
		return TRUE
	if(action == "routing_rotate")
		return routing_valid() && params["attempt"] == attempt_id && params["phase"] == routing.phase && routing.rotate_cell(params["index"])
	if(action == "routing_submit")
		return submit_routing(ui.user, params["attempt"], params["phase"])
	if(action == "routing_cancel")
		if(!routing_valid() || params["attempt"] != attempt_id || params["phase"] != routing.phase)
			return FALSE
		cancel_routing()
		return TRUE
	if(action == "route" || action == "command")
		for(var/atom/movable/target as anything in connection_targets())
			if(REF(target) == params["target"])
				if(action == "route")
					return begin_routing(ui.user, target, !!params["advanced"])
				return execute_machine(ui.user, target, params["command"])
	if(action == "scan" && istext(params["target"]))
		for(var/atom/target as anything in scanner_targets())
			if(REF(target) == params["target"])
				return scan_machine(ui.user, target)
	return FALSE
