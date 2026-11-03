// AI EDIT START - Cover apartment key and housing behavior
/// Isolated apartment fixtures do not replace a mapped area's global type singleton.
/area/awaymission/avangarde17/inside/living/housing_test
	area_flags_mapping = NONE
	requires_power = FALSE
	static_lighting = FALSE

/area/awaymission/avangarde17/inside/living/housing_test/double

/area/awaymission/avangarde17/inside/living/housing_test/single

/// Three beds in two apartments must house three of four crew members, exactly once.
/datum/unit_test/avangarde_housing
	/// Restore the testing room's areas even if an assertion returns early.
	var/list/original_areas = list()

/datum/unit_test/avangarde_housing/Destroy()
	for(var/turf/room_turf as anything in original_areas)
		room_turf.change_area(get_area(room_turf), original_areas[room_turf])
	original_areas = null
	return ..()

/datum/unit_test/avangarde_housing/Run()
	var/datum/modpack/events/housing = allocate(__IMPLIED_TYPE__)
	// Areas take no creation location, unlike the movable atoms handled by allocate().
	var/area/awaymission/avangarde17/inside/living/housing_test/double/double_apartment = new
	var/area/awaymission/avangarde17/inside/living/housing_test/single/single_apartment = new
	allocated += double_apartment
	allocated += single_apartment
	double_apartment.name = "Test apartment with two beds"
	single_apartment.name = "Test apartment with one bed"
	var/list/double_turfs = list(run_loc_floor_bottom_left, get_step(run_loc_floor_bottom_left, EAST), get_step(run_loc_floor_bottom_left, NORTH))
	var/list/single_turfs = list(locate(run_loc_floor_bottom_left.x + 3, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z), locate(run_loc_floor_bottom_left.x + 3, run_loc_floor_bottom_left.y + 1, run_loc_floor_bottom_left.z))
	for(var/turf/room_turf as anything in double_turfs + single_turfs)
		original_areas[room_turf] = get_area(room_turf)
		room_turf.change_area(get_area(room_turf), (room_turf in double_turfs) ? double_apartment : single_apartment)
	allocate(/obj/structure/bed, double_turfs[1])
	allocate(/obj/structure/bed, double_turfs[2])
	allocate(/obj/structure/bed, single_turfs[1])
	var/obj/machinery/door/airlock/double_door = allocate(__IMPLIED_TYPE__, double_turfs[3])
	var/obj/machinery/door/airlock/single_door = allocate(__IMPLIED_TYPE__, single_turfs[2])
	var/list/bed_turfs = list(double_turfs[1], double_turfs[2], single_turfs[1])
	var/list/crew_minds = list()
	var/list/residents = list()
	for(var/index in 1 to 4)
		var/mob/living/carbon/human/consistent/resident = allocate(__IMPLIED_TYPE__, run_loc_floor_top_right)
		resident.mind_initialize()
		allocated += resident.mind
		resident.mind.key = "housing-test-player-[index]"
		var/datum/job/resident_job = SSjob.get_job_type(/datum/job/assistant)
		if(index == 4)
			resident_job = SSjob.get_job_type(/datum/job/ussp_homeless) || resident_job
		resident.mind.set_assigned_role(resident_job)
		crew_minds += resident.mind
		residents += resident
	var/mob/living/carbon/human/consistent/npc = allocate(__IMPLIED_TYPE__, run_loc_floor_top_right)
	npc.mind_initialize()
	allocated += npc.mind
	npc.mind.set_assigned_role(SSjob.get_job_type(/datum/job/assistant))
	crew_minds += npc.mind

	var/assigned_count = housing.assign_housing(crew_minds, list(double_apartment, single_apartment))
	if(assigned_count != 3)
		return TEST_FAIL("Three beds housed [assigned_count] residents instead of three (double apartment: [length(double_apartment.get_turfs_from_all_zlevels())] turfs; single apartment: [length(single_apartment.get_turfs_from_all_zlevels())] turfs).")
	if(get_turf(npc) != run_loc_floor_top_right || (locate(/obj/item/key/appartment) in npc.get_all_contents()))
		return TEST_FAIL("A station NPC without a player key participated in roundstart housing.")
	var/list/occupied_beds = list()
	var/key_count = 0
	for(var/mob/living/carbon/human/resident as anything in residents)
		var/obj/item/key/appartment/key = locate() in resident.get_all_contents()
		if(!key)
			if(get_turf(resident) != run_loc_floor_top_right)
				return TEST_FAIL("A resident without an available bed was moved away from their original spawn.")
			continue
		key_count++
		var/turf/assigned_bed = get_turf(resident)
		if(!(assigned_bed in bed_turfs) || (assigned_bed in occupied_beds))
			return TEST_FAIL("Housing assigned a bed more than once or moved a resident outside the available beds.")
		occupied_beds += assigned_bed
		if(key.linked_airlock?.resolve() != ((get_area(resident) == double_apartment) ? double_door : single_door))
			return TEST_FAIL("A housed resident received a key for another apartment.")
	if(key_count != 3)
		return TEST_FAIL("Housing did not issue exactly three apartment keys.")

	if(housing.assign_housing(crew_minds, list(double_apartment, single_apartment)) != 0)
		return TEST_FAIL("Housing was allocated again after it had already been assigned.")
	key_count = 0
	for(var/mob/living/carbon/human/resident as anything in residents)
		for(var/obj/item/key/appartment/key in resident.get_all_contents())
			key_count++
	if(key_count != 3)
		return TEST_FAIL("Repeated housing assignment duplicated apartment keys.")
// AI EDIT END
