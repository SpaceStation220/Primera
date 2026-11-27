/datum/ipc_os_program/cyberlink
	var/multitool_enabled = FALSE
	var/obj/item/multitool/neural_multitool

/datum/ipc_os_program/cyberlink/proc/can_use_neural_tool(mob/user, obj/machinery/target)
	return multitool_enabled && can_remote_ui(user, target) && (access_for(target) || slot_access(target))

/datum/ipc_os_program/cyberlink/proc/use_multitool(mob/user, obj/machinery/target)
	if(!multitool_supported(target) || !can_use_neural_tool(user, target))
		return FALSE
	if(!neural_multitool)
		neural_multitool = new(os.host)
	if(istype(target, /obj/machinery/telecomms))
		return open_machine_ui(user, target)
	if(neural_multitool.buffer && !can_use_neural_tool(user, neural_multitool.buffer))
		return FALSE
	var/cost = is_relayed(target) ? charge_cost(0.5) : 0
	var/obj/item/organ/heart/ipc/battery = os.working_battery()
	if(cost && !spend_charge(0.5))
		return FALSE
	var/success = target.multitool_act(user, neural_multitool) & ITEM_INTERACT_SUCCESS
	if(success)
		os.host.adjust_coretemperature(25)
	else if(cost && !QDELETED(battery))
		battery.adjust_charge(cost)
	return !!success

/// Only native electronic configuration adapters; physical locks/panels remain native checks.
/datum/ipc_os_program/cyberlink/proc/multitool_supported(atom/target)
	return istype(target, /obj/machinery/telecomms) || istype(target, /obj/machinery/air_sensor) || istype(target, /obj/machinery/airalarm) || istype(target, /obj/machinery/portable_atmospherics/gas_receiver) || istype(target, /obj/machinery/portable_atmospherics/scrubber/bluespace) || istype(target, /obj/machinery/quantumpad)

/datum/ipc_os_program/cyberlink/proc/routing_feedback(success)
	if(!routing_window)
		return
	routing_window.result = success ? "success" : "failure"
	if(os.host?.client)
		SEND_SOUND(os.host, sound(success ? 'modular_bandastation/species/sound/ipc/cyberlink_success.mp3' : 'modular_bandastation/species/sound/ipc/cyberlink_failure.mp3', volume = 60))
	SStgui.update_uis(routing_window)

/mob/living/basic/bot/proc/ipc_remote_controls(mob/user)
	if(!ishuman(user))
		return FALSE
	var/mob/living/carbon/human/body = user
	var/datum/ipc_os_program/cyberlink/program = body.get_ipc_os()?.programs["cyberlink"]
	return program && (src in program.remote_panels) && program.can_remote_ui(user, src)

/mob/living/basic/bot/ui_state(mob/user)
	return ipc_remote_controls(user) ? GLOB.ipc_remote_state : ..()

/mob/living/basic/bot/ui_close(mob/user)
	. = ..()
	if(!ishuman(user))
		return
	var/mob/living/carbon/human/body = user
	var/datum/ipc_os_program/cyberlink/program = body.get_ipc_os()?.programs["cyberlink"]
	if(program && (src in program.remote_panels))
		program.remote_panels -= src
		program.UnregisterSignal(src, list(COMSIG_TGUI_ACTION_REQUEST, COMSIG_QDELETING))
