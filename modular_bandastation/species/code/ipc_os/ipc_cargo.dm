/datum/ipc_os_program/factory/cargo
	id = "factory_cargo"
	name = "Грузовой отсек"
	description = "Позволяет загрузить один ящик: щёлкните по нему пустой рукой. Выгрузка — из программы."
	icon = "box"
	builtin_department = "cargo"
	var/obj/structure/closet/crate/stored_crate
	var/loading = FALSE

/datum/ipc_os_program/factory/cargo/start()
	if(!..())
		return FALSE
	RegisterSignal(os.host, COMSIG_LIVING_UNARMED_ATTACK, PROC_REF(on_hand))
	return TRUE

/datum/ipc_os_program/factory/cargo/stop()
	if(running && os.host)
		UnregisterSignal(os.host, COMSIG_LIVING_UNARMED_ATTACK)
	if(stored_crate)
		stored_crate.forceMove(os.host ? os.host.drop_location() : get_turf(os.core))
		stored_crate = null
	return ..()

/datum/ipc_os_program/factory/cargo/proc/on_hand(mob/source, atom/target, proximity, list/modifiers)
	SIGNAL_HANDLER
	if(!running || !istype(target, /obj/structure/closet/crate) || !valid_crate(target, activation_id))
		return NONE
	if(!loading)
		loading = TRUE
		INVOKE_ASYNC(src, PROC_REF(load_crate), target, activation_id)
	return COMPONENT_CANCEL_ATTACK_CHAIN

/datum/ipc_os_program/factory/cargo/proc/valid_crate(obj/structure/closet/crate/crate, activation)
	if(!running || activation_id != activation || !os?.can_use(os.host) || stored_crate || QDELETED(crate) || crate.anchored || !isturf(crate.loc) || !os.host.Adjacent(crate))
		return FALSE
	// These are the same cargo constraints used by the MOD hydraulic clamp.
	for(var/mob/living/passenger in crate.get_all_contents())
		if(passenger.mob_size > MOB_SIZE_SMALL)
			return FALSE
	return TRUE

/datum/ipc_os_program/factory/cargo/proc/load_crate(obj/structure/closet/crate/crate, activation)
	playsound(os.host, 'sound/vehicles/mecha/hydraulic.ogg', 25, TRUE)
	if(do_after(os.host, 3 SECONDS, crate, extra_checks = CALLBACK(src, PROC_REF(valid_crate), crate, activation)) && valid_crate(crate, activation))
		stored_crate = crate
		crate.forceMove(os.core)
	loading = FALSE

/datum/ipc_os_program/factory/cargo/command(list/params)
	if(!stored_crate || loading)
		return FALSE
	stored_crate.forceMove(os.host.drop_location())
	stored_crate = null
	playsound(os.host, 'sound/vehicles/mecha/hydraulic.ogg', 25, TRUE)
	return TRUE
