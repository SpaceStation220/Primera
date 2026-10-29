// AI EDIT START - Scope event jobs and spawn hooks to Avangarde
/// Settlement roles join the lobby only on Avangarde; the base itself is not a playable job.
/datum/job/ussp

/datum/job/ussp/map_check()
	return type != /datum/job/ussp && SSmapping.current_map?.map_name == "avangarde" && ..()

/datum/job/ussp_assistant/map_check()
	return SSmapping.current_map?.map_name == "avangarde" && ..()

/datum/job/ussp_botanist/map_check()
	return SSmapping.current_map?.map_name == "avangarde" && ..()

/datum/job/ussp_hop/map_check()
	return SSmapping.current_map?.map_name == "avangarde" && ..()

/datum/job/ussp_research_director/map_check()
	return SSmapping.current_map?.map_name == "avangarde" && ..()

/datum/job/ussp_scientist/map_check()
	return SSmapping.current_map?.map_name == "avangarde" && ..()

/// Listen to completed job spawns without replacing the job subsystem or outfit initialization.
/datum/modpack/events/initialize()
	. = ..()
	RegisterSignal(SSdcs, COMSIG_GLOB_JOB_AFTER_SPAWN, PROC_REF(on_job_after_spawn))
	RegisterSignal(SSticker, COMSIG_TICKER_ROUND_STARTING, PROC_REF(on_round_starting))

/// Everyone living in Zoryka speaks Spinwarder, regardless of their station or event occupation.
/datum/modpack/events/proc/on_job_after_spawn(datum/source, datum/job/job, mob/living/spawned, client/player_client)
	SIGNAL_HANDLER
	if(SSmapping.current_map.map_name != "avangarde" || !ishuman(spawned))
		return
	var/mob/living/carbon/human/translator = spawned
	translator.grant_language(/datum/language/spinwarder)
	translator.remove_blocked_language(/datum/language/spinwarder)
	translator.set_active_language(/datum/language/spinwarder)
// AI EDIT END

