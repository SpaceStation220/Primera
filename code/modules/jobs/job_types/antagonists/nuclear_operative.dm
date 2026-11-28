/datum/job/nuclear_operative
	title = ROLE_OPERATIVE

/datum/job/nuclear_operative/get_roundstart_spawn_point()
	if(SSmapping.current_map?.space_overmap?["nukeops_slots"])
		var/list/empty_points = list()
		for(var/turf/spawn_point as anything in GLOB.nukeop_elevator_start)
			if(!(locate(/mob/living) in spawn_point))
				empty_points += spawn_point
		if(length(empty_points))
			return pick(empty_points)
	return pick(GLOB.nukeop_elevator_start)

/datum/job/nuclear_operative/get_latejoin_spawn_point()
	return pick(GLOB.nukeop_base_start)

/datum/job/nuclear_operative/leader

/datum/job/nuclear_operative/leader/get_latejoin_spawn_point()
	return pick(GLOB.nukeop_base_leader_start)

/datum/job/nuclear_operative/clown_operative
	title = ROLE_CLOWN_OPERATIVE

/datum/job/nuclear_operative/clown_operative/leader

/datum/job/nuclear_operative/clown_operative/leader/get_latejoin_spawn_point()
	return pick(GLOB.nukeop_base_leader_start)
