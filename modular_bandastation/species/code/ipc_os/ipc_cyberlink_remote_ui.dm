GLOBAL_DATUM_INIT(ipc_remote_state, /datum/ui_state/ipc_remote, new)

/datum/ipc_os_program/cyberlink
	var/list/remote_panels = list()
	var/list/opening_panels = list()
	var/list/remote_actions = list()

/datum/ipc_os_program/cyberlink/proc/can_remote_ui(mob/user, atom/movable/target)
	return running && available() && os.can_use(user) && (target in command_targets()) && machine_operational(target) && machine_authorized(target)

/// A requested native panel can have a subtype-specific physical ui_state.
/proc/ipc_remote_panel_state(mob/user, datum/target)
	if(ishuman(user))
		var/mob/living/carbon/human/human = user
		var/datum/ipc_os_program/cyberlink/program = human.get_ipc_os()?.programs["cyberlink"]
		if(program && (target in program.remote_panels))
			return GLOB.ipc_remote_state

/obj/machinery/ui_state(mob/user)
	if(ishuman(user))
		var/mob/living/carbon/human/human = user
		var/datum/ipc_os/os = human.get_ipc_os()
		var/datum/ipc_os_program/cyberlink/program = os?.programs["cyberlink"]
		if(program && (src in program.remote_panels))
			return GLOB.ipc_remote_state
	return ..()

/datum/ui_state/ipc_remote/can_use_topic(atom/movable/source, mob/user)
	if(!ishuman(user))
		return UI_CLOSE
	var/mob/living/carbon/human/human = user
	var/datum/ipc_os/os = human.get_ipc_os()
	var/datum/ipc_os_program/cyberlink/program = os?.programs["cyberlink"]
	return program?.can_remote_ui(user, source) ? UI_INTERACTIVE : UI_CLOSE

/obj/machinery/ui_close(mob/user)
	. = ..()
	if(ishuman(user))
		var/mob/living/carbon/human/human = user
		var/datum/ipc_os/os = human.get_ipc_os()
		var/datum/ipc_os_program/cyberlink/program = os?.programs["cyberlink"]
		if(program && (src in program.remote_panels))
			program.remote_panels -= src
			program.UnregisterSignal(src, list(COMSIG_TGUI_ACTION_REQUEST, COMSIG_QDELETING))

/datum/ipc_os_program/cyberlink/proc/open_machine_ui(mob/user, atom/movable/target)
	if(!can_remote_ui(user, target) || (target in opening_panels))
		return FALSE
	opening_panels += target
	if(!(target in remote_panels))
		remote_panels += target
		RegisterSignal(target, COMSIG_TGUI_ACTION_REQUEST, PROC_REF(remote_request))
		RegisterSignal(target, COMSIG_QDELETING, PROC_REF(remote_deleted))
	target.ui_interact(user)
	opening_panels -= target
	if(QDELETED(target) || !(target in remote_panels) || !can_remote_ui(user, target))
		if(!QDELETED(target))
			remote_panels -= target
			UnregisterSignal(target, list(COMSIG_TGUI_ACTION_REQUEST, COMSIG_QDELETING))
			SStgui.close_user_uis(user, target)
		return FALSE
	var/datum/tgui/panel = SStgui.get_open_ui(user, target)
	if(panel)
		panel.set_state(GLOB.ipc_remote_state)
		panel.process_status()
	else if(user.client)
		remote_panels -= target
		UnregisterSignal(target, list(COMSIG_TGUI_ACTION_REQUEST, COMSIG_QDELETING))
		to_chat(user, span_warning("Устройство не открыло электронный интерфейс."))
		return FALSE
	ensure_link_processing()
	return TRUE

/datum/ipc_os_program/cyberlink/proc/close_remote_panels()
	for(var/atom/movable/target as anything in remote_panels.Copy())
		UnregisterSignal(target, list(COMSIG_TGUI_ACTION_REQUEST, COMSIG_QDELETING))
		SStgui.close_user_uis(os.host, target)
	remote_panels.Cut()
	opening_panels.Cut()
	remote_actions.Cut()

/datum/ipc_os_program/cyberlink/proc/remote_deleted(datum/source)
	SIGNAL_HANDLER
	remote_panels -= source
	opening_panels -= source
	remote_actions -= source

/datum/ipc_os_program/cyberlink/proc/remote_access(mob/source, atom/movable/target)
	SIGNAL_HANDLER
	if(target in remote_panels)
		return can_remote_ui(source, target) ? ACCESS_ALLOWED : ACCESS_DISALLOWED
	return NONE

/datum/ipc_os_program/cyberlink/proc/remote_request(datum/source, mob/user, action, list/params, list/context)
	SIGNAL_HANDLER
	if(user != os.host || action == "change_ui_state")
		return NONE
	if(istype(source, /mob/living/basic/bot) && !(action in list("power", "patrol", "airplane", "heal_threshold", "speaker", "crit_alerts", "stationary_mode", "clean_blood", "clean_trash", "clean_graffiti", "pest_control", "extinguish_fires", "extinguish_people", "fix_breaches", "replace_windows", "replace_tiles", "fix_girders", "build_girders")))
		return COMPONENT_CANCEL_TGUI_ACTION
	if(istype(source, /obj/machinery/telecomms) && action == "link" && neural_multitool?.buffer && !can_use_neural_tool(user, neural_multitool.buffer))
		return COMPONENT_CANCEL_TGUI_ACTION
	if(!context["interactive"] || !can_remote_ui(user, source))
		return COMPONENT_CANCEL_TGUI_ACTION
	var/cost = is_relayed(source) ? charge_cost(0.5) : 0
	var/obj/item/organ/heart/ipc/battery = os.working_battery()
	if(cost && !spend_charge(0.5))
		return COMPONENT_CANCEL_TGUI_ACTION
	var/list/transaction = list("cost" = cost, "battery" = battery, "body" = os.host, "target" = source)
	remote_actions[source] = (remote_actions[source] || 0) + 1
	var/list/completions = context["completions"]
	completions += CALLBACK(src, PROC_REF(remote_complete), transaction)
	return NONE

/datum/ipc_os_program/cyberlink/proc/remote_complete(list/transaction, succeeded)
	if(!transaction)
		return
	var/datum/target = transaction["target"]
	if(remote_actions[target] > 1)
		remote_actions[target]--
	else
		remote_actions -= target
	if(succeeded)
		var/mob/living/carbon/human/body = transaction["body"]
		if(!QDELETED(body))
			body.adjust_coretemperature(25)
	else
		var/obj/item/organ/heart/ipc/battery = transaction["battery"]
		if(!QDELETED(battery) && transaction["cost"])
			battery.adjust_charge(transaction["cost"])
/// Native checks after dialog input can use the same scoped electronic reach.
/proc/ipc_remote_action_reach(mob/living/carbon/human/user, atom/movable/target)
	if(!istype(user))
		return FALSE
	var/datum/ipc_os_program/cyberlink/program = user.get_ipc_os()?.programs["cyberlink"]
	return program && program.remote_actions[target] && (target in program.remote_panels) && program.can_remote_ui(user, target)

/datum/ipc_os_program/cyberlink/proc/refresh_remote_panels()
	for(var/atom/movable/target as anything in remote_panels.Copy())
		// Native TGUI can yield while sending assets before registering its new window.
		if(target in opening_panels)
			continue
		if(!can_remote_ui(os.host, target) || !SStgui.get_open_ui(os.host, target))
			UnregisterSignal(target, list(COMSIG_TGUI_ACTION_REQUEST, COMSIG_QDELETING))
			remote_panels -= target
			SStgui.close_user_uis(os.host, target)
