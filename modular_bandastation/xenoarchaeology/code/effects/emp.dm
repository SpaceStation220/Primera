/datum/xenoartifact_effect/emp
	log_name = "Электромагнитный импульс"
	type_name = XENO_EFFECT_ELECTRO

/datum/xenoartifact_effect/emp/New()
	. = ..()
	release_method = XENO_EFFECT_PULSE

/datum/xenoartifact_effect/emp/do_effect_pulse(seconds_per_tick)
	. = ..()
	if(!.)
		return
	empulse(get_turf(holder), range / 2, range)

/datum/xenoartifact_effect/emp/do_effect_destroy()
	empulse(get_turf(holder), range * 2, range)
