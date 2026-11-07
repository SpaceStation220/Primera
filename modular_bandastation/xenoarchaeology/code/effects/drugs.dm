/datum/xenoartifact_effect/drugs
	log_name = "Наркотическое воздействие"

/datum/xenoartifact_effect/drugs/New()
	. = ..()
	type_name = pick(XENO_EFFECT_PSIONIC, XENO_EFFECT_ORGANIC)

/datum/xenoartifact_effect/drugs/do_effect_touch(mob/user)
	. = ..()
	if(!.)
		return
	do_drugs(user, 60)
	to_chat(user, span_hypnophrase("Мне так спокойно."))

/datum/xenoartifact_effect/drugs/do_effect_aura(seconds_per_tick)
	. = ..()
	if(!.)
		return
	var/turf/curr_turf = get_turf(holder)
	for(var/mob/living/living_mob in range(range, curr_turf))
		if(!SPT_PROB(10, seconds_per_tick))
			continue
		do_drugs(living_mob, 10 * seconds_per_tick)
		to_chat(living_mob, span_hypnophrase("Мне хорошо. Очень хорошо."))

/datum/xenoartifact_effect/drugs/do_effect_pulse(seconds_per_tick)
	. = ..()
	if(!.)
		return
	var/turf/curr_turf = get_turf(holder)
	for(var/mob/living/living_mob in range(range, curr_turf))
		if(!SPT_PROB(25, seconds_per_tick))
			continue
		do_drugs(living_mob, 20 * seconds_per_tick)
		to_chat(living_mob, span_hypnophrase("Здесь так приятно. Стоит бывать тут чаще."))

/datum/xenoartifact_effect/drugs/do_effect_destroy()
	var/turf/curr_turf = get_turf(holder)
	for(var/mob/living/living_mob in range(range+3, curr_turf))
		do_drugs(living_mob, 120)
		to_chat(living_mob, span_hypnophrase("Я словно вышел за пределы своего тела."))

/**
 * Applies drugginess to mob
 *
 * Arguments:
 * * receiver - who will we drug
 * * power - drug power
 */
/datum/xenoartifact_effect/drugs/proc/do_drugs(mob/receiver, power)
	var/weakened = get_xenoartifact_susceptibility(receiver)
	if(!weakened)
		return FALSE
	if(!ishuman(receiver))
		return FALSE
	var/mob/living/carbon/carbon_mob = receiver
	carbon_mob.set_drugginess(power SECONDS * weakened)
	return TRUE
