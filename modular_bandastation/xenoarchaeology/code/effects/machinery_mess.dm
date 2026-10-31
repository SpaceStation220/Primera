/datum/xenoartifact_effect/machinery_mess
	log_name = "Скрытое управление механизмами"
	type_name = XENO_EFFECT_ELECTRO

/datum/xenoartifact_effect/machinery_mess/New()
	. = ..()
	release_method = XENO_EFFECT_PULSE

/datum/xenoartifact_effect/machinery_mess/do_effect_pulse(seconds_per_tick)
	. = ..()
	if(!.)
		return
	try_animate(seconds_per_tick)
	try_hack_borg(seconds_per_tick)

/datum/xenoartifact_effect/machinery_mess/do_effect_destroy()
	try_animate(2)
	try_hack_borg(2)

/**
 * Tries to animate nearby machinery into angry mobs.
 * Similar to Malf ability
 */
/datum/xenoartifact_effect/machinery_mess/proc/try_animate(seconds_per_tick)
	var/turf/curr_turf = get_turf(holder)
	for(var/obj/machinery/chosen_machine in range(range, curr_turf))
		if(SPT_PROB(5, seconds_per_tick) && !istype(chosen_machine, /obj/machinery/xenoartifact))
			if(istype(chosen_machine, /obj/machinery/porta_turret_cover))
				var/obj/machinery/porta_turret_cover/chosen_turret = chosen_machine
				chosen_machine = chosen_turret.parent_turret

			if((chosen_machine.resistance_flags & INDESTRUCTIBLE) || is_type_in_typecache(chosen_machine, GLOB.blacklisted_malf_machines))
				return FALSE

			playsound(holder, 'sound/misc/interference.ogg', 50, ignore_walls = TRUE)
			chosen_machine.audible_message(span_userdanger("Из [chosen_machine] доносится громкое электрическое гудение!"))
			if(QDELETED(chosen_machine))
				return

			new /mob/living/basic/mimic/copy/machine(get_turf(chosen_machine), chosen_machine, holder, TRUE)

/**
 * Tries to mess with silicon's laws OR emag simple bots
 */
/datum/xenoartifact_effect/machinery_mess/proc/try_hack_borg(seconds_per_tick)
	var/turf/curr_turf = get_turf(holder)
	for(var/mob/living/silicon/silicon_mob in range(range, curr_turf))
		if(SPT_PROB(12.5, seconds_per_tick))
			if(silicon_mob.stat != DEAD && !silicon_mob.incapacitated)
				var/obj/machinery/ai_law_rack/base/rack = silicon_mob.get_law_rack()
				rack?.scramble_ai_rack(
					new_lawset_prob = 7.5,
					remove_law_prob = 10,
					shuffle_prob = 20,
					base_ion_prob = 100,
					sub_ion_prob = 15,
					ion_limit = 1,
				)
				log_silicon("Artifact changed laws of [key_name(silicon_mob)] to [english_list(silicon_mob.laws.get_law_list(TRUE, TRUE))]")

	for(var/mob/living/basic/bot/bot in range(range, curr_turf))
		if(SPT_PROB(12.5, seconds_per_tick))
			bot.emag_act()
