// Оружие массового опорожнения
// Dont mind me

/datum/xenoartifact_effect/disgust
	log_name = "Тошнота"

/datum/xenoartifact_effect/disgust/New()
	. = ..()
	type_name = pick(XENO_EFFECT_PSIONIC, XENO_EFFECT_ORGANIC)

/datum/xenoartifact_effect/disgust/do_effect_touch(mob/user)
	. = ..()
	if(!.)
		return
	apply_disgust(user, 200) // Insta-shit

/datum/xenoartifact_effect/disgust/do_effect_aura(seconds_per_tick)
	. = ..()
	if(!.)
		return
	var/turf/curr_turf = get_turf(holder)
	for(var/mob/living/carbon/living_mob in range(range, curr_turf))
		if(prob(50))
			apply_disgust(living_mob, 2.5 * seconds_per_tick)

/datum/xenoartifact_effect/disgust/do_effect_pulse(seconds_per_tick)
	. = ..()
	if(!.)
		return
	var/used_power = .
	var/turf/curr_turf = get_turf(holder)
	for(var/mob/living/carbon/living_mob in range(range, curr_turf))
		apply_disgust(living_mob, used_power/2 * seconds_per_tick)

/datum/xenoartifact_effect/disgust/do_effect_destroy()
	var/turf/curr_turf = get_turf(holder)
	for(var/mob/living/carbon/living_mob in range(7, curr_turf))
		var/weakness = get_xenoartifact_susceptibility(living_mob)
		if(!weakness)
			continue
		living_mob.SetSleeping(weakness * (10 SECONDS)) //0 resistance gives you 10 seconds of sleep

/**
 * Applies disgust to mob
 *
 * Arguments:
 * * receiver - who will be disgusted
 * * power - disgust power
 */
/datum/xenoartifact_effect/disgust/proc/apply_disgust(mob/receiver, power)
	if(ishuman(receiver) && !issilicon(receiver))
		var/mob/living/carbon/human/human_mob = receiver
		var/weakness = get_xenoartifact_susceptibility(human_mob)
		if(!weakness)
			return
		to_chat(human_mob, pick(
			span_notice("Кажется, ваши внутренности меняются местами."),
			span_notice("Вам нехорошо."),
			span_notice("У вас болит живот."),
		))
		human_mob.adjust_disgust(power)
