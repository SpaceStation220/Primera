// AI EDIT START - Adapt the Lazarus event to the native Primera APIs and regression harness
/** Restore the test turf even if a cold assertion stops its test early. */
/datum/unit_test/lazarus_frostbite
	var/area/previous_area
	var/area/lazarus/event_area
	var/area/previous_registered_area

/datum/unit_test/lazarus_frostbite/Destroy()
	if(event_area)
		if(get_area(run_loc_floor_bottom_left) == event_area)
			run_loc_floor_bottom_left.change_area(event_area, previous_area)
		QDEL_NULL(event_area)
		GLOB.areas_by_type[/area/lazarus] = previous_registered_area
	previous_area = null
	previous_registered_area = null
	return ..()

/datum/unit_test/lazarus_frostbite/Run()
	previous_area = get_area(run_loc_floor_bottom_left)
	previous_registered_area = GLOB.areas_by_type[/area/lazarus]
	event_area = new /area/lazarus
	event_area.temperature = AREA_TEMPERATURE_OUTSIDE
	run_loc_floor_bottom_left.change_area(previous_area, event_area)
	var/mob/living/carbon/human/consistent/colonist = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	colonist.AddComponent(/datum/component/lazarus_frostbite)
	TEST_ASSERT_EQUAL(colonist.get_frostbite_delta(), -35, "An unclothed colonist should lose 35 warmth per original tick outdoors.")
	SEND_SIGNAL(colonist, COMSIG_LIVING_LIFE, 1)
	SEND_SIGNAL(colonist, COMSIG_LIVING_LIFE, 1)
	TEST_ASSERT_EQUAL(colonist.frostbite, 3965, "Cold must advance through the real life signal independently of its tick rate.")
	var/obj/item/clothing/suit/hooded/wintercoat/coat = allocate(/obj/item/clothing/suit/hooded/wintercoat)
	colonist.equip_to_slot_or_del(coat, ITEM_SLOT_OCLOTHING)
	TEST_ASSERT_EQUAL(colonist.get_frostbite_delta(), -25, "Wearing a winter coat must reduce cooling by its original insulation.")
	event_area.temperature = AREA_TEMPERATURE_COMFORTABLE
	SEND_SIGNAL(colonist, COMSIG_LIVING_LIFE, 2)
	TEST_ASSERT_EQUAL(colonist.frostbite, 3990, "Warm shelter should replenish 25 reserve per original tick.")
	colonist.frostbite = 3999
	SEND_SIGNAL(colonist, COMSIG_LIVING_LIFE, 2)
	TEST_ASSERT_EQUAL(colonist.frostbite, FROSTBITE_WARM, "Warming must stop at the maximum reserve.")
	event_area.temperature = AREA_TEMPERATURE_OUTSIDE
	colonist.frostbite = 0
	var/before_damage = colonist.get_fire_loss()
	SEND_SIGNAL(colonist, COMSIG_LIVING_LIFE, 2)
	TEST_ASSERT(colonist.get_fire_loss() > before_damage, "Exhausted warmth must cause real cold injury.")
	colonist.fully_heal(HEAL_TEMP)
	TEST_ASSERT_EQUAL(colonist.frostbite, FROSTBITE_WARM, "Native temperature healing must restore the event reserve.")
	run_loc_floor_bottom_left.change_area(event_area, previous_area)
	colonist.frostbite = 1234
	SEND_SIGNAL(colonist, COMSIG_LIVING_LIFE, 2)
	TEST_ASSERT_EQUAL(colonist.frostbite, 1234, "Event cold must stop outside Lazarus.")
	TEST_ASSERT(!colonist.has_alert("lazarus_frostbite"), "The event HUD must clear outside Lazarus.")

/** Map availability uses the native job check, without modifying ordinary maps. */
/datum/unit_test/lazarus_jobs/Run()
	var/datum/map_config/colony = new
	colony.map_name = LAZARUS_MAP_NAME
	var/datum/map_config/previous = SSmapping.current_map
	var/datum/job/lazarus/hermit/role = allocate(/datum/job/lazarus/hermit)
	SSmapping.current_map = colony
	var/available_on_event = role.map_check()
	SSmapping.current_map = previous
	qdel(colony)
	TEST_ASSERT(available_on_event, "The Hermit role should be available on Lazarus.")
	if(previous.map_name != LAZARUS_MAP_NAME)
		TEST_ASSERT(!role.map_check(), "Event jobs should not appear in a normal station lobby.")
	// Exercise native post_equip: event outfits must not attempt to imprint a missing PDA.
	for(var/outfit in subtypesof(/datum/outfit/job/lazarus))
		var/mob/living/carbon/human/consistent/colonist = allocate(/mob/living/carbon/human/consistent)
		colonist.equipOutfit(outfit)
		TEST_ASSERT_NOTNULL(colonist.w_uniform, "The event outfit [outfit] did not equip its uniform.")
// AI EDIT END
