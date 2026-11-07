/datum/xenoartifact_effect/radiate
	log_name = "Радиация"
	/// How much radiation are we pulsing
	var/radiation_amount

/datum/xenoartifact_effect/radiate/New()
	. = ..()
	radiation_amount = rand(1, 10)
	type_name = pick(XENO_EFFECT_PARTICLE, XENO_EFFECT_ORGANIC)

/datum/xenoartifact_effect/radiate/do_effect_touch(mob/living/user)
	. = ..()
	if(!.)
		return
	if (!holder)
		return
	var/turf/holder_turf = get_turf(holder)
	if(isnull(holder_turf))
		return FALSE
	radiation_pulse(source = holder_turf, max_range = range + 5, threshold = 0.3, chance = 50)

/datum/xenoartifact_effect/radiate/do_effect_aura(seconds_per_tick)
	. = ..()
	if(!.)
		return
	if (!holder)
		return
	var/turf/holder_turf = get_turf(holder)
	if(isnull(holder_turf))
		return FALSE
	radiation_pulse(source = holder_turf, max_range = range, threshold = 0.3, chance = 10  * radiation_amount)

/datum/xenoartifact_effect/radiate/do_effect_pulse(seconds_per_tick)
	. = ..()
	if(!.)
		return
	if (!holder)
		return
	var/turf/holder_turf = get_turf(holder)
	if(isnull(holder_turf))
		return FALSE
	var/used_power = .
	radiation_pulse(source = holder_turf, max_range = range, threshold = 0.3, chance = used_power)

/datum/xenoartifact_effect/radiate/do_effect_destroy()
	var/turf/holder_turf = get_turf(holder)
	if(isnull(holder_turf))
		return FALSE
	radiation_pulse(source = holder_turf, max_range = range*2, threshold = 0.1, chance = 75) // Really powerful pulse
