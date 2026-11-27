/mob/living/carbon/human/proc/has_ipc_specialization(department)
	var/datum/ipc_os/os = get_ipc_os()
	var/obj/item/organ/brain/ipc/core = os?.core
	return os?.generation() == "I" && istype(core) && core.ipc_department == department && os.is_operational()

/// Callers provide the operation's meaning; typed target families cover ordinary department devices.
/proc/ipc_work_departments(atom/target)
	if(istype(target, /obj/machinery/atmospherics) || istype(target, /obj/machinery/power) || istype(target, /obj/structure/cable) || istype(target, /obj/structure/frame) || istype(target, /obj/structure/window) || istype(target, /obj/structure/grille))
		return list("engineering")
	if(istype(target, /obj/machinery/door))
		return list("engineering", "security")
	if(istype(target, /obj/machinery/hydroponics) || istype(target, /obj/item/food))
		return list("service")
	if(istype(target, /obj/machinery/rnd) || istype(target, /obj/machinery/computer/rdconsole))
		return list("science")
	if(istype(target, /obj/machinery/chem_dispenser) || istype(target, /obj/machinery/chem_master))
		return list("medical", "science")
	if(istype(target, /obj/structure/closet/crate))
		return list("cargo")
	return null

/proc/ipc_work_multiplier(atom/movable/user, atom/target, work_departments, action_kind)
	var/mob/living/carbon/human/human = user
	if(!istype(human) || !is_species(human, /datum/species/ipc))
		return 1
	var/datum/ipc_manufacturer/manufacturer = human.get_ipc_manufacturer()
	var/multiplier = 1 / (manufacturer?.action_rate || 1)
	var/datum/ipc_os/os = human.get_ipc_os()
	if(os?.generation() != "I")
		return multiplier
	var/obj/item/organ/brain/ipc/core = os.core
	var/list/departments = islist(work_departments) ? work_departments : (work_departments ? list(work_departments) : ipc_work_departments(target))
	if(!core.ipc_department || !(core.ipc_department in departments))
		return multiplier * 1.25
	if(core.ipc_department == "medical" && action_kind == "surgery")
		return multiplier / 1.2
	if(core.ipc_department == "engineering")
		if(action_kind == "engineering_tools")
			return multiplier / 1.2
		if(action_kind == "construction")
			return multiplier / 1.15
	return multiplier
