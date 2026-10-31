/datum/xenoartifact_effect/stun
	log_name = "Оглушение"

/datum/xenoartifact_effect/stun/New()
	. = ..()
	type_name = pick(XENO_EFFECT_PSIONIC, XENO_EFFECT_ORGANIC)

/datum/xenoartifact_effect/stun/do_effect_touch(mob/user)
	. = ..()
	if(!.)
		return
	if(apply_stun(user, 200, 2)) // Instant stun
		to_chat(user, span_warning("Могучая сила подавляет ваше сознание."))

/datum/xenoartifact_effect/stun/do_effect_aura(seconds_per_tick)
	. = ..()
	if(!.)
		return
	var/turf/curr_turf = get_turf(holder)
	for(var/mob/living/living_mob in range(range, curr_turf))
		if(!SPT_PROB(10, seconds_per_tick))
			continue
		if(apply_stun(living_mob, 12.5, seconds_per_tick))
			to_chat(living_mob, span_warning("Ваше тело на мгновение немеет."))

/datum/xenoartifact_effect/stun/do_effect_pulse(seconds_per_tick)
	. = ..()
	if(!.)
		return
	var/turf/curr_turf = get_turf(holder)
	var/used_power = .
	for(var/mob/living/living_mob in range(range, curr_turf))
		if(!SPT_PROB(25, seconds_per_tick))
			continue
		if(apply_stun(living_mob, 5 * used_power, seconds_per_tick))
			to_chat(living_mob, span_warning("Волна энергии подавляет ваши чувства!"))

/datum/xenoartifact_effect/stun/do_effect_destroy()
	var/turf/curr_turf = get_turf(holder)
	for(var/mob/living/living_mob in range(range+3, curr_turf))
		if(apply_stun(living_mob, 200, 2))
			to_chat(living_mob, span_warning("<b>Огромная</b> волна энергии подавляет ваши чувства!"))

/**
 * Tries to stun receiver, obviously
 *
 * Arguments:
 * * receiver - mob to stun to
 * * power - stun amplifier
 */
/datum/xenoartifact_effect/stun/proc/apply_stun(mob/receiver, power, seconds_per_tick)
	var/weakened = get_xenoartifact_susceptibility(receiver)
	if(!weakened)
		return FALSE
	if(!ishuman(receiver))
		return FALSE
	var/mob/living/carbon/carbon_mob = receiver
	carbon_mob.adjust_confusion_up_to(7.5 SECONDS * seconds_per_tick, 30 SECONDS)
	carbon_mob.adjust_stamina_loss(power * weakened * seconds_per_tick, updating_stamina = TRUE, forced = TRUE)
	return TRUE
