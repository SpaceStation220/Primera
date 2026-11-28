/datum/xenoartifact_effect/celldrain
	log_name = "Разрядка батарей"
	type_name = XENO_EFFECT_ELECTRO

/datum/xenoartifact_effect/celldrain/do_effect_touch(mob/user)
	. = ..()
	if(!.)
		return
	for(var/obj/item/stock_parts/power_store/cell in user.contents)
		cell.use(1e10, TRUE) // uh oh
	if(issilicon(user))
		to_chat(user, span_notice("СИСТЕМНОЕ ОПОВЕЩЕНИЕ: критическая утечка энергии!"))

/datum/xenoartifact_effect/celldrain/do_effect_aura(seconds_per_tick)
	. = ..()
	if(!.)
		return
	discharge_everything_in_range(25000 * seconds_per_tick, range, holder)

/datum/xenoartifact_effect/celldrain/do_effect_pulse(seconds_per_tick)
	. = ..()
	if(!.)
		return
	var/used_power = .
	discharge_everything_in_range(12500 * used_power * seconds_per_tick, range, holder)

/datum/xenoartifact_effect/celldrain/do_effect_destroy()
	discharge_everything_in_range(1000000000, 10, holder) // Massive uh oh

/**
 * Checks receiver_atom type, tries to discharge it
 *
 * Arguments:
 * * receiver_atmon - what to charge
 * * power - how much do we charge
 */
/datum/xenoartifact_effect/celldrain/proc/try_use_charge(atom/movable/receiver_atmon, power)
	if(!ismovable(receiver_atmon))
		return
	if(istype(receiver_atmon, /obj/machinery/power/smes))
		var/obj/machinery/power/smes/smes = receiver_atmon
		smes.adjust_charge(-power)
		return
	var/obj/item/stock_parts/power_store/cell = receiver_atmon.get_cell()
	cell?.use(power, TRUE)

/**
 * Tries to discharge every rechargable item in artifact range
 *
 * Arguments:
 * * range - in what range
 * * power - how much do we charge
 */
/datum/xenoartifact_effect/celldrain/proc/discharge_everything_in_range(power, range, center)
	var/turf/curr_turf = get_turf(holder)
	var/list/captured_atoms = range(range, curr_turf)
	for(var/atom/captured_atom in captured_atoms)
		try_use_charge(captured_atom, power)
