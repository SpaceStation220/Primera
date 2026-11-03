// AI EDIT START - Assign roundstart housing and apartment keys
/datum/modpack/events
	/// Roundstart housing is assigned once, even if the start signal is sent again.
	var/housing_assigned = FALSE

/// Capture the roundstart crew before late joiners can enter the round.
/datum/modpack/events/proc/on_round_starting(datum/source)
	SIGNAL_HANDLER
	if(SSmapping.current_map.map_name != "avangarde")
		return
	INVOKE_ASYNC(src, PROC_REF(assign_housing), SSticker.minds.Copy(), GLOB.areas.Copy())

/**
 * Assign one roundstart resident per apartment bed, without occupation priorities.
 * Living areas with beds and exactly one entrance are apartments; detached cabins are excluded.
 */
/datum/modpack/events/proc/assign_housing(list/crew_minds, list/apartment_areas)
	if(housing_assigned)
		return 0
	housing_assigned = TRUE

	var/list/available_beds = list()
	var/list/doors_by_bed = list()
	for(var/area/awaymission/avangarde17/inside/living/apartment in apartment_areas)
		if(istype(apartment, /area/awaymission/avangarde17/inside/living/cabin))
			continue
		var/list/room_beds = list()
		var/list/room_doors = list()
		for(var/turf/room_turf as anything in apartment.get_turfs_from_all_zlevels())
			for(var/obj/structure/bed/bed in room_turf)
				room_beds += bed
			for(var/obj/machinery/door/airlock/door in room_turf)
				room_doors += door
		if(!length(room_beds))
			continue
		if(length(room_doors) != 1)
			log_mapping("Avangarde housing: [apartment.type] has [length(room_doors)] entrance airlocks; expected one.")
			continue
		for(var/obj/structure/bed/bed as anything in room_beds)
			doors_by_bed[bed] = room_doors[1]
		available_beds += room_beds

	var/list/residents = list()
	for(var/datum/mind/crew_mind in crew_minds)
		if(!crew_mind.key || crew_mind.late_joiner || crew_mind.assigned_role?.faction != FACTION_STATION)
			continue
		if(ishuman(crew_mind.current) && crew_mind.assigned_role.job_flags & JOB_CREW_MEMBER)
			residents |= crew_mind.current

	var/assigned_count = 0
	for(var/mob/living/carbon/human/resident as anything in shuffle(residents))
		if(!length(available_beds))
			to_chat(resident, span_warning("Свободных квартирных спальных мест не осталось. Обратитесь к администрации посёлка."))
			continue
		var/obj/structure/bed/bed = pick_n_take(available_beds)
		var/area/apartment = get_area(bed)
		var/obj/vehicle/ridden/wheelchair/wheelchair = resident.buckled
		resident.forceMove(get_turf(bed))
		// A roundstart wheelchair must follow its owner when forceMove unbuckles them.
		if(istype(wheelchair))
			wheelchair.forceMove(get_turf(bed))
			wheelchair.buckle_mob(resident)
		var/obj/item/key/appartment/key = new(get_turf(resident), doors_by_bed[bed])
		key.name = "Ключ от [apartment.name]"
		var/where = resident.equip_in_one_of_slots(key, list(LOCATION_BACKPACK, LOCATION_LPOCKET, LOCATION_RPOCKET, LOCATION_HANDS), qdel_on_fail = FALSE, indirect_action = TRUE) || "у ваших ног"
		to_chat(resident, span_notice("Вам выделено жильё: <b>[apartment.name]</b>. Квартирный ключ [where]."))
		assigned_count++
	return assigned_count
// AI EDIT END
