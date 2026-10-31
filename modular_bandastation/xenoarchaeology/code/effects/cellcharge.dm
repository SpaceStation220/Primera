/datum/xenoartifact_effect/cellcharge
	log_name = "Зарядка батарей"
	type_name = XENO_EFFECT_ELECTRO

/datum/xenoartifact_effect/cellcharge/do_effect_touch(mob/user)
	. = ..()
	if(!.)
		return
	for(var/obj/item/stock_parts/power_store/cell in user.contents)
		cell.give(1e5)
	if(issilicon(user))
		to_chat(user, span_notice("СИСТЕМНОЕ ОПОВЕЩЕНИЕ: обнаружен приток энергии!"))

/datum/xenoartifact_effect/cellcharge/do_effect_aura(seconds_per_tick)
	. = ..()
	if(!.)
		return
	recharge_everything_in_range(125000 * seconds_per_tick, range, holder)

/datum/xenoartifact_effect/cellcharge/do_effect_pulse(seconds_per_tick)
	. = ..()
	if(!.)
		return
	var/used_power = .
	recharge_everything_in_range(2500 * used_power * seconds_per_tick, range, holder)

/datum/xenoartifact_effect/cellcharge/do_effect_destroy()
	recharge_everything_in_range(1000000000, 10, holder) // One time use giga-charge

/**
 * Checks receiver_atom type, tries to recharge it
 *
 * Arguments:
 * * receiver_atmon - what to charge
 * * power - how much do we charge
 */
/datum/xenoartifact_effect/cellcharge/proc/try_give_charge(atom/movable/receiver_atmon, power)
	if(!ismovable(receiver_atmon))
		return
	if(istype(receiver_atmon, /obj/machinery/power/smes))
		var/obj/machinery/power/smes/smes = receiver_atmon
		smes.adjust_charge(power)
		return
	var/obj/item/stock_parts/power_store/cell = receiver_atmon.get_cell()
	cell?.give(power)

/**
 * Tries to charge every rechargable item in artifact range
 *
 * Arguments:
 * * range - in what range
 * * power - how much do we charge
 */
/datum/xenoartifact_effect/cellcharge/proc/recharge_everything_in_range(power, range)
	var/turf/curr_turf = get_turf(holder)
	var/list/captured_atoms = range(range, curr_turf)
	for(var/atom/captured_atom in captured_atoms)
		try_give_charge(captured_atom, power)
