/datum/xenoartifact_effect/light
	log_name = "Свет"
	type_name = XENO_EFFECT_PARTICLE

/datum/xenoartifact_effect/light/New()
	. = ..()
	release_method = XENO_EFFECT_TOUCH
	trigger = XENO_TRIGGER_TOUCH
	activation_touch_cost = 0

/datum/xenoartifact_effect/light/toggle_artifact_effect(reveal_toggle)
	if(!activated)
		if(log_name == "Тьма")
			holder.set_light(range, -round(maximum_charges/5))
		else
			holder.set_light(range, round(maximum_charges/5))
	else
		holder.set_light(0,0)
	return ..()

/datum/xenoartifact_effect/light/darkness
	log_name = "Тьма"
