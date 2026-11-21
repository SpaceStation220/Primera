/datum/xenoartifact_effect/noise
	log_name = "Шум"
	var/static/list/possible_noises = list(
		'sound/machines/buzz/buzz-sigh.ogg',
		'sound/machines/buzz/buzz-two.ogg',
		'sound/machines/chime.ogg',
		'sound/items/bikehorn.ogg',
		'sound/machines/ping.ogg',
		'sound/misc/sadtrombone.ogg',
		'sound/machines/warning-buzzer.ogg',
		'sound/machines/slowclap.ogg',
		'sound/mobs/humanoids/moth/scream_moth.ogg',
		'sound/items/toy_squeak/toysqueak1.ogg',
		'sound/items/poster/poster_ripped.ogg',
		'sound/items/coinflip.ogg',
		'sound/items/megaphone.ogg',
		'sound/effects/magic/warpwhistle.ogg',
		'sound/mobs/non-humanoids/hiss/hiss1.ogg',
		'sound/mobs/humanoids/lizard/lizard_scream_1.ogg',
		'sound/items/weapons/flashbang.ogg',
		'sound/items/weapons/flash.ogg',
		'sound/items/weapons/whip.ogg',
		'sound/items/sitcom_laugh/sitcomLaugh1.ogg',
		'sound/items/gavel.ogg',
		'sound/items/haunted/ghostitemattack.ogg',
		'sound/items/ceramic_break.ogg',
		'sound/effects/hallucinations/veryfar_noise.ogg',
		'sound/effects/hallucinations/radio_static.ogg',
		'sound/effects/hallucinations/look_up1.ogg',
		'sound/effects/hallucinations/wail.ogg',
		'sound/effects/hallucinations/growl2.ogg',
		'sound/effects/hallucinations/far_noise.ogg',
		'sound/mobs/non-humanoids/alien/alien_eat.ogg', // vore :3
		'sound/misc/scary_horn.ogg',
		'sound/effects/magic/curse.ogg',
		'sound/machines/airlock/airlock_alien_prying.ogg',
		'sound/mobs/non-humanoids/clown/hohoho.ogg', // hehe
		'sound/mobs/non-humanoids/clown/hehe.ogg', // hohoho
		'sound/effects/wounds/crack1.ogg',
	)

/datum/xenoartifact_effect/noise/New()
	. = ..()
	trigger = XENO_TRIGGER_OXY
	release_method = XENO_EFFECT_PULSE
	type_name = XENO_EFFECT_PSIONIC

/datum/xenoartifact_effect/noise/do_effect_pulse(seconds_per_tick)
	. = ..()
	if(!.)
		return
	var/sound_type = pick(possible_noises)
	playsound(holder, sound_type, 50, ignore_walls = TRUE)

/datum/xenoartifact_effect/noise/do_effect_destroy()
	playsound(holder, 'sound/effects/hallucinations/wail.ogg', 75, ignore_walls = TRUE, extrarange = 25, pressure_affected = FALSE) // Louder than usual scream with extra range
