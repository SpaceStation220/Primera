/mob/living/proc/handle_ssd(seconds_per_tick, times_fired)
	if(player_logged || HAS_TRAIT(src, TRAIT_IPC_REMOTE_PILOT_BODY))
		return
	SetSleeping(7 SECONDS)
