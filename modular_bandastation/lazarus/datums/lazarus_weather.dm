// AI EDIT START - Adapt the Lazarus event to the native Primera APIs and regression harness
GLOBAL_LIST_EMPTY(lazarus_blizzard_sounds)

/** Lazarus's blizzard obscures exposed humans without importing Lavaland's fire damage. */
/datum/weather/lazarus_blizzard
	name = "blizzard"
	desc = "Снежная буря, окутывающая снежный лес."
	telegraph_message = span_boldwarning("Ветер на улице начинает усиливаться. Лучше оставаться в укрытии.")
	telegraph_overlay = "light_snow"
	telegraph_duration = 2 MINUTES
	telegraph_sound = 'sound/ambience/weather/snowstorm/snow_start.ogg'
	weather_message = span_userdanger("На улице началась настоящая метель. Лучше оставаться в укрытии и не рисковать.")
	weather_overlay = "snow_storm"
	weather_duration = 7 MINUTES
	weather_duration_lower = 6 MINUTES
	weather_duration_upper = 8 MINUTES
	end_message = span_boldnotice("Рёв ветра постепенно стихает, а землю укрывает одеяло осевшего снега. Теперь вновь возможно выйти на улицу.")
	end_overlay = "light_snow"
	end_sound = 'sound/ambience/weather/snowstorm/snow_end.ogg'
	area_type = /area/lazarus/outdoors
	target_trait = "lazarus"
	immunity_type = TRAIT_SNOWSTORM_IMMUNE
	weather_flags = WEATHER_MOBS | WEATHER_BAROMETER
	probability = 90
	use_glow = FALSE

/datum/weather/lazarus_blizzard/get_playlist_ref()
	return GLOB.lazarus_blizzard_sounds

/datum/weather/lazarus_blizzard/Destroy()
	GLOB.lazarus_blizzard_sounds -= impacted_areas
	return ..()

/datum/weather/lazarus_blizzard/start()
	for(var/area/impacted_area as anything in impacted_areas)
		GLOB.lazarus_blizzard_sounds[impacted_area] = /datum/looping_sound/snowstorm
	return ..()

/datum/weather/lazarus_blizzard/end()
	GLOB.lazarus_blizzard_sounds -= impacted_areas
	return ..()

/datum/weather/lazarus_blizzard/recursive_weather_protection_check(atom/to_check)
	if(..() || ismecha(to_check))
		return TRUE
	if(!ishuman(to_check))
		return FALSE
	var/mob/living/carbon/human/human = to_check
	return human.get_eye_protection() >= FLASH_PROTECTION_WELDER || human.get_thermal_protection() >= (FIRE_IMMUNITY_MAX_TEMP_PROTECT - 15)

/datum/weather/lazarus_blizzard/weather_act_mob(mob/living/victim)
	if(!ishuman(victim))
		return
	victim.apply_status_effect(/datum/status_effect/lazarus_blizzard)
	victim.set_eye_blur_if_lower(2 SECONDS)
	victim.set_temp_blindness_if_lower(2 SECONDS)

/** Refreshable one-second snow drag, independent of other movement penalties. */
/datum/status_effect/lazarus_blizzard
	id = "lazarus_blizzard"
	duration = 1 SECONDS
	status_type = STATUS_EFFECT_REFRESH
	alert_type = null

/datum/status_effect/lazarus_blizzard/on_apply()
	owner.add_movespeed_modifier(/datum/movespeed_modifier/lazarus_blizzard)
	return TRUE

/datum/status_effect/lazarus_blizzard/on_remove()
	owner.remove_movespeed_modifier(/datum/movespeed_modifier/lazarus_blizzard)

/datum/movespeed_modifier/lazarus_blizzard
	multiplicative_slowdown = 5
// AI EDIT END
