// AI EDIT START - Cover apartment key and housing behavior
/// Assigned keys cannot operate another door, but can close and bolt their own glass airlock.
/datum/unit_test/avangarde_apartment_key/Run()
	var/mob/living/carbon/human/consistent/resident = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/obj/machinery/door/airlock/public/glass/apartment = allocate(__IMPLIED_TYPE__, get_step(run_loc_floor_bottom_left, EAST))
	var/obj/machinery/door/airlock/public/glass/other = allocate(__IMPLIED_TYPE__, get_step(run_loc_floor_bottom_left, NORTH))
	var/obj/item/key/appartment/key = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left, apartment)
	resident.put_in_active_hand(key)
	apartment.autoclose = FALSE
	apartment.bolt()
	other.bolt()

	click_wrapper(resident, other)
	if(!apartment.locked || !other.locked)
		return TEST_FAIL("Clicking another door with an apartment key changed a door's bolts.")
	if(key.interact_with_atom(apartment, resident, list()) != ITEM_INTERACT_SUCCESS || apartment.locked)
		return TEST_FAIL("An assigned apartment key did not unbolt its glass door.")

	if(!apartment.open())
		return TEST_FAIL("Could not open the apartment door for the closing check.")
	if(key.interact_with_atom(apartment, resident, list()) != ITEM_INTERACT_SUCCESS || !apartment.density || !apartment.locked)
		return TEST_FAIL("An assigned apartment key did not close and bolt its glass door.")

	resident.dropItemToGround(key)
	var/obj/item/key/appartment/unassigned_key = allocate(__IMPLIED_TYPE__)
	resident.put_in_active_hand(unassigned_key)
	if(unassigned_key.interact_with_atom(apartment, resident, list()) != ITEM_INTERACT_BLOCKING || !apartment.locked)
		return TEST_FAIL("An unassigned apartment key gained control of a door.")

/// Dropping a key while its timed interaction is running must leave the door unlocked.
/datum/unit_test/avangarde_apartment_key_interrupted/Run()
	var/mob/living/carbon/human/consistent/slow/resident = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/obj/machinery/door/airlock/public/glass/apartment = allocate(__IMPLIED_TYPE__, get_step(run_loc_floor_bottom_left, EAST))
	var/obj/item/key/appartment/key = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left, apartment)
	resident.put_in_active_hand(key)
	addtimer(CALLBACK(resident, TYPE_PROC_REF(/mob, dropItemToGround), key), 1)
	if(key.interact_with_atom(apartment, resident, list()) != ITEM_INTERACT_BLOCKING || apartment.locked || resident.is_holding(key))
		return TEST_FAIL("Dropping an apartment key during the timed action did not cancel the interaction.")

/// Closing a real airlock also yields, so losing the key during its animation must not bolt it.
/datum/unit_test/avangarde_apartment_key_closing_interrupted/Run()
	var/mob/living/carbon/human/consistent/resident = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/obj/machinery/door/airlock/public/glass/apartment = allocate(__IMPLIED_TYPE__, get_step(run_loc_floor_bottom_left, EAST))
	var/obj/item/key/appartment/key = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left, apartment)
	resident.put_in_active_hand(key)
	apartment.autoclose = FALSE
	if(!apartment.open())
		return TEST_FAIL("Could not open the apartment door for the interrupted closing check.")
	addtimer(CALLBACK(resident, TYPE_PROC_REF(/mob, dropItemToGround), key), 1)
	if(key.interact_with_atom(apartment, resident, list()) != ITEM_INTERACT_BLOCKING || !apartment.density || apartment.locked || resident.is_holding(key))
		return TEST_FAIL("Dropping an apartment key while its door was closing did not prevent bolting.")
// AI EDIT END
