// AI EDIT START - Check optional PrimeDream housing compatibility
/// Real job spawning and apartment allocation must preserve IPC and Vox species mechanics.
/datum/unit_test/avangarde_housing/primedream_species
	test_flags = UNIT_TEST_MAP_TEST

/datum/unit_test/avangarde_housing/primedream_species/Run()
	if(SSmapping.current_map.map_name != "avangarde")
		return
	var/datum/modpack/events/housing = allocate(__IMPLIED_TYPE__)
	var/area/awaymission/avangarde17/inside/living/housing_test/double/apartment = new
	allocated += apartment
	var/list/room_turfs = list(run_loc_floor_bottom_left, get_step(run_loc_floor_bottom_left, EAST), get_step(run_loc_floor_bottom_left, NORTH))
	for(var/turf/room_turf as anything in room_turfs)
		original_areas[room_turf] = get_area(room_turf)
		room_turf.change_area(get_area(room_turf), apartment)
	allocate(/obj/structure/bed, room_turfs[1])
	allocate(/obj/structure/bed, room_turfs[2])
	var/obj/machinery/door/airlock/door = allocate(__IMPLIED_TYPE__, room_turfs[3])
	var/datum/job/job = SSjob.get_job_type(/datum/job/ussp_paramedic)
	var/list/residents = list()
	var/list/crew_minds = list()
	for(var/species_type in list(/datum/species/ipc, /datum/species/vox))
		var/mob/living/carbon/human/consistent/resident = allocate(__IMPLIED_TYPE__, run_loc_floor_top_right)
		resident.set_species(species_type)
		resident.mind_initialize()
		allocated += resident.mind
		resident.mind.key = "primedream-housing-[length(residents) + 1]"
		SSjob.equip_rank(resident, job)
		var/datum/bank_account/account = SSeconomy.bank_accounts_by_id["[resident.account_id]"]
		allocated += account
		if(!is_species(resident, species_type))
			return TEST_FAIL("Equipping the event job replaced species [species_type].")
		residents += resident
		crew_minds += resident.mind

	if(housing.assign_housing(crew_minds, list(apartment)) != 2)
		return TEST_FAIL("The two apartment beds did not house both the IPC and the Vox.")
	for(var/mob/living/carbon/human/resident as anything in residents)
		if(get_area(resident) != apartment)
			return TEST_FAIL("[resident.dna.species.name] was not moved into its apartment.")
		var/obj/item/card/id/card = resident.get_idcard()
		var/datum/job/id_job = card?.trim?.find_job()
		if(id_job?.type != /datum/job/ussp_paramedic || card.registered_name != resident.real_name)
			return TEST_FAIL("[resident.dna.species.name] lost its registered event job ID.")
		if(card.registered_account?.account_job?.type != /datum/job/ussp_paramedic)
			return TEST_FAIL("[resident.dna.species.name] lost its event job bank account.")
		if(!resident.can_speak_language(/datum/language/spinwarder) || resident.get_selected_language() != /datum/language/spinwarder)
			return TEST_FAIL("The actual job spawn did not grant active Spinwarder to [resident.dna.species.name].")
		var/obj/item/key/appartment/key = locate() in resident.get_all_contents()
		if(key?.linked_airlock?.resolve() != door)
			return TEST_FAIL("[resident.dna.species.name] did not receive a key for its apartment.")
		if(isvox(resident))
			if(!istype(resident.wear_mask, /obj/item/clothing/mask/breath/vox) || !istype(resident.internal, /obj/item/tank/internals/nitrogen))
				return TEST_FAIL("The event outfit or housing replaced the Vox's nitrogen life support.")
			if(!resident.is_holding(resident.internal) || resident.internal.air_contents.moles[/datum/gas/nitrogen] <= 0 || resident.internal.air_contents.moles[/datum/gas/oxygen])
				return TEST_FAIL("The housed Vox's active nitrogen tank was lost, emptied or contaminated.")
// AI EDIT END
