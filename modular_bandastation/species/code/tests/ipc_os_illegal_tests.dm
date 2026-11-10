/// Upgrades use real item entry points, and do not grant free installation or stacking storage.
/datum/unit_test/ipc_os_upgrade_items/Run()
	var/mob/living/carbon/human/ipc = allocate(/mob/living/carbon/human/consistent)
	ipc.set_species(/datum/species/ipc)
	var/datum/ipc_os/os = ipc.get_ipc_os()
	var/obj/item/ipc_os_upgrade/upgrade = allocate(/obj/item/ipc_os_upgrade)
	TEST_ASSERT_EQUAL(upgrade.interact_with_atom(ipc, ipc), ITEM_INTERACT_SUCCESS, "Software carrier refused an IPC.")
	TEST_ASSERT(QDELETED(upgrade), "Successful software carrier was not consumed.")
	TEST_ASSERT_EQUAL(os.used_storage(), 0, "Upgrade installed programs for free.")
	TEST_ASSERT_EQUAL(os.capacity(), 24, "Market license added storage.")
	var/datum/ipc_os_program/overclock = os.programs["overclock"]
	TEST_ASSERT(!overclock.available(), "Market license unlocked OverClock.")
	var/obj/item/card/emag/emag = allocate(/obj/item/card/emag)
	TEST_ASSERT_EQUAL(emag.interact_with_atom(ipc, ipc), ITEM_INTERACT_SUCCESS, "Native EMAG did not unlock the IPC.")
	TEST_ASSERT_EQUAL(os.capacity(), 32, "Native EMAG did not give 32 GB.")
	emag.interact_with_atom(ipc, ipc)
	TEST_ASSERT_EQUAL(os.capacity(), 32, "Repeated native EMAG stacked memory.")
	var/obj/item/ipc_os_upgrade/redundant = allocate(/obj/item/ipc_os_upgrade)
	redundant.interact_with_atom(ipc, ipc)
	TEST_ASSERT(!QDELETED(redundant), "A redundant limited update was consumed.")
	TEST_ASSERT(overclock.available(), "Limited upgrade downgraded EMAG.")

/// GhostMode uses native digitalcamo without removing a separate equipment source.
/datum/unit_test/ipc_os_ghost_sources/Run()
	var/mob/living/carbon/human/ipc = allocate(/mob/living/carbon/human/consistent)
	ipc.set_species(/datum/species/ipc)
	ipc.set_nutrition(NUTRITION_LEVEL_FULL, forced = TRUE)
	var/datum/ipc_os/os = ipc.get_ipc_os()
	os.unlock()
	os.install("ghost_mode")
	var/datum/ipc_os_program/ghost_mode/ghost = os.programs["ghost_mode"]
	ipc.AddElement(/datum/element/digitalcamo)
	TEST_ASSERT(ghost.start(), "GhostMode refused to start.")
	var/datum/element/digitalcamo/camo = SSdcs.GetElement(list(/datum/element/digitalcamo), FALSE)
	ghost.tick(10)
	TEST_ASSERT_EQUAL(ipc.nutrition, NUTRITION_LEVEL_FULL * 0.96, "GhostMode did not spend 4% full battery in 10 seconds.")
	ghost.stop()
	TEST_ASSERT(ipc in camo.attached_mobs, "Stopping GhostMode removed another camouflage source.")
	ipc.RemoveElement(/datum/element/digitalcamo)
	TEST_ASSERT(!(ipc in camo.attached_mobs), "Final camouflage source left an image.")
	TEST_ASSERT(!(ipc in camo.sources_by_mob), "Camouflage retained a source reference.")

/// NeuralCrack clears stun only and charges the existing core once.
/datum/unit_test/ipc_os_neural_crack/Run()
	var/mob/living/carbon/human/ipc = allocate(/mob/living/carbon/human/consistent)
	ipc.set_species(/datum/species/ipc)
	var/datum/ipc_os/os = ipc.get_ipc_os()
	os.unlock(TRUE)
	os.install("neural_crack")
	var/obj/item/organ/brain/ipc/core = os.core
	var/brain_before = core.damage
	ipc.Stun(10 SECONDS, ignore_canstun = TRUE)
	ipc.Knockdown(10 SECONDS, ignore_canstun = TRUE)
	TEST_ASSERT(os.neural_crack(), "NeuralCrack failed to remove stun.")
	TEST_ASSERT(!ipc.IsStun(), "NeuralCrack retained stun.")
	TEST_ASSERT(ipc.IsKnockdown(), "NeuralCrack also removed knockdown.")
	TEST_ASSERT_EQUAL(core.damage, brain_before + 15, "NeuralCrack did not inflict exactly 15 brain damage.")
	TEST_ASSERT(!os.neural_crack(), "NeuralCrack charged an unstunned IPC.")
	TEST_ASSERT_EQUAL(core.damage, brain_before + 15, "Repeated NeuralCrack charged twice.")

/// Running speed changes by exactly 25%; walking and final cleanup retain the original delays.
/datum/unit_test/ipc_os_overclock_speed_heat/Run()
	var/mob/living/carbon/human/ipc = allocate(/mob/living/carbon/human/consistent)
	ipc.set_species(/datum/species/ipc)
	var/datum/ipc_os/os = ipc.get_ipc_os()
	os.unlock(TRUE)
	os.install("overclock")
	var/datum/ipc_os_program/overclock/overclock = os.programs["overclock"]
	ipc.set_move_intent(MOVE_INTENT_WALK)
	var/walk_delay = ipc.cached_multiplicative_slowdown
	ipc.set_move_intent(MOVE_INTENT_RUN)
	var/run_delay = ipc.cached_multiplicative_slowdown
	TEST_ASSERT(overclock.start(), "OverClock failed to start.")
	TEST_ASSERT(abs(ipc.cached_multiplicative_slowdown - run_delay / 1.25) < 0.001, "OverClock did not increase running speed by 25%.")
	ipc.set_move_intent(MOVE_INTENT_WALK)
	TEST_ASSERT_EQUAL(ipc.cached_multiplicative_slowdown, walk_delay, "OverClock changed walking speed.")
	ipc.set_move_intent(MOVE_INTENT_RUN)
	for(var/step in 1 to 120)
		overclock.tick(2)
		ipc.dna.species.handle_body_temperature(ipc, 2)
		if(ipc.stat == DEAD)
			break
	TEST_ASSERT(ipc.get_fire_loss() > 0, "Natural heat exchange defeated OverClock's physical heating.")
	TEST_ASSERT(ipc.coretemperature > ipc.dna.species.bodytemp_heat_damage_limit, "OverClock never reached damaging core temperature.")
	var/temperature = ipc.coretemperature
	overclock.stop()
	TEST_ASSERT_EQUAL(ipc.coretemperature, temperature, "Stopping OverClock removed accumulated heat.")
	TEST_ASSERT(!ipc.has_movespeed_modifier(/datum/movespeed_modifier/ipc_os_overclock), "OverClock left its movement modifier.")

/// Display text changes through the native signal without changing real identity or door access.
/datum/unit_test/ipc_os_spoof_identity/Run()
	var/mob/living/carbon/human/ipc = allocate(/mob/living/carbon/human/consistent)
	ipc.set_species(/datum/species/ipc)
	var/datum/ipc_os/os = ipc.get_ipc_os()
	os.unlock()
	os.install("id_spoof")
	var/datum/ipc_os_program/id_spoof/spoof = os.programs["id_spoof"]
	var/real_name = ipc.real_name
	var/obj/item/card/id/advanced/id = allocate(/obj/item/card/id/advanced)
	id.registered_name = real_name
	id.access = list(ACCESS_MEDICAL)
	ipc.equip_to_slot_or_del(id, ITEM_SLOT_ID)
	spoof.spoof_name = "Тестовый псевдоним"
	spoof.spoof_job = "Инженер"
	TEST_ASSERT(spoof.start(), "ID_Spoof failed to start.")
	TEST_ASSERT_EQUAL(ipc.get_visible_name(), "Тестовый псевдоним (Инженер)", "Visible alias did not apply.")
	TEST_ASSERT_EQUAL(ipc.real_name, real_name, "Spoof changed real identity.")
	TEST_ASSERT_EQUAL(id.registered_name, real_name, "Spoof rewrote an ID.")
	TEST_ASSERT_EQUAL(length(id.access), 1, "Spoof changed ID permissions.")
	TEST_ASSERT(ACCESS_MEDICAL in id.GetAccess(), "Spoof removed the original ID access.")
	spoof.expires_at = world.time - 1
	spoof.tick(1)
	TEST_ASSERT(!spoof.running, "Expired spoof remained active.")
	TEST_ASSERT_EQUAL(ipc.get_visible_name(), real_name, "Expired spoof retained visible identity.")

/// A real held toolkit cable must retain the five-second channel and native door outcome.
/datum/unit_test/ipc_os_wall_breaker/Run()
	var/mob/living/carbon/human/ipc = allocate(/mob/living/carbon/human/consistent)
	ipc.set_species(/datum/species/ipc)
	ipc.mock_client = new /datum/client_interface()
	// Do_after deliberately uses dummy action speed in UNIT_TESTS; keep this timed contract at real speed.
	ipc.cached_multiplicative_actions_slowdown = 1
	var/datum/ipc_os/os = ipc.get_ipc_os()
	os.unlock(TRUE)
	os.install("wall_breaker")
	var/datum/ipc_os_program/program = os.programs["wall_breaker"]
	TEST_ASSERT(program.start(), "WallBreaker did not start.")
	var/obj/item/organ/cyberimp/arm/power_cord/ipc/adapter = ipc.get_organ_by_type(/obj/item/organ/cyberimp/arm/power_cord/ipc)
	adapter.ui_action_click()
	var/obj/item/ipc_power_cord/cord = adapter.active_item
	var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock)
	TEST_ASSERT(door.hasPower(), "Fixture airlock has no power.")
	var/started_at = world.time
	TEST_ASSERT_EQUAL(cord.interact_with_atom(door, ipc), ITEM_INTERACT_SUCCESS, "Held cable refused WallBreaker.")
	TEST_ASSERT_EQUAL(cord.interact_with_atom(door, ipc), ITEM_INTERACT_BLOCKING, "Parallel WallBreaker was accepted.")
	var/deadline = world.time + 8 SECONDS
	while(!(door.obj_flags & EMAGGED) && world.time < deadline)
		sleep(1)
	TEST_ASSERT(door.obj_flags & EMAGGED, "Native airlock EMAG did not finish.")
	TEST_ASSERT(world.time >= started_at + 5 SECONDS, "WallBreaker bypassed its five-second channel.")
	TEST_ASSERT(!cord.drawing_power, "WallBreaker left the cable reserved.")
	os.uninstall("wall_breaker")
	TEST_ASSERT(!cord.can_use_software(ipc, door, "wall_breaker"), "Uninstalled WallBreaker still controls its cable.")
