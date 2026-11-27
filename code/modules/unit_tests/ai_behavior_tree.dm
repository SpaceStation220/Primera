#define TEST_BB_BT_GATE "unit_test_bt_gate"

/datum/bt_node/ai_behavior/unit_test_abort_probe
	/// Number of times this leaf performed an action.
	var/perform_count = 0
	/// Number of times this leaf was finished or cancelled.
	var/finish_count = 0

/datum/bt_node/ai_behavior/unit_test_abort_probe/perform(seconds_per_tick, datum/ai_controller/controller)
	perform_count++
	return AI_BEHAVIOR_INSTANT

/datum/bt_node/ai_behavior/unit_test_abort_probe/finish_action(datum/ai_controller/controller, succeeded)
	finish_count++
	return ..()

/datum/bt_node/ai_behavior/unit_test_abort_probe/close_gate_on_setup/setup(datum/ai_controller/controller)
	controller.clear_blackboard_key(TEST_BB_BT_GATE)
	return TRUE

/datum/bt_node/ai_behavior/unit_test_abort_probe/open_gate_on_perform/perform(seconds_per_tick, datum/ai_controller/controller)
	..()
	controller.set_blackboard_key(TEST_BB_BT_GATE, TRUE)
	return AI_BEHAVIOR_SUCCEEDED

/// An abort-self observer must see the leaf that is being set up for the first time.
/datum/unit_test/ai_behavior_tree_abort_setup/Run()
	var/obj/item/pawn = allocate(/obj/item, run_loc_floor_bottom_left)
	var/datum/ai_controller/controller = allocate(/datum/ai_controller, pawn)
	controller.force_ai_off()
	controller.set_blackboard_key(TEST_BB_BT_GATE, TRUE)
	controller.replace_behavior_nodes(list(list(
		BT_DESC_TYPE = /datum/bt_node/decorator/bb_key_set,
		"key" = TEST_BB_BT_GATE,
		"observer_abort" = BT_ABORT_SELF,
		"child_typepath" = /datum/bt_node/ai_behavior/unit_test_abort_probe/close_gate_on_setup,
	)))
	var/datum/bt_node/decorator/bb_key_set/gate = controller.behavior_nodes[1]
	var/datum/bt_node/ai_behavior/unit_test_abort_probe/probe = gate.child

	controller.SelectBehaviors(1)

	TEST_ASSERT_NULL(controller.blackboard[TEST_BB_BT_GATE], "Leaf setup did not close the gate")
	TEST_ASSERT_EQUAL(probe.perform_count, 0, "Leaf performed after its setup invalidated its branch")
	TEST_ASSERT_EQUAL(probe.finish_count, 1, "Cancelled setup did not clean up its leaf exactly once")
	TEST_ASSERT(!probe.has_active_descendants(), "Leaf remained active after its branch was cancelled")

/// A signal from a lower-priority leaf must terminate the tick even if the leaf returns success.
/datum/unit_test/ai_behavior_tree_abort_lower_priority/Run()
	var/obj/item/pawn = allocate(/obj/item, run_loc_floor_bottom_left)
	var/datum/ai_controller/controller = allocate(/datum/ai_controller, pawn)
	controller.force_ai_off()
	controller.replace_behavior_nodes(list(
		list(
			BT_DESC_TYPE = /datum/bt_node/composite/parallel,
			BT_DESC_CHILDREN = list(
				// This running branch sets the previous active index before the selector can tick.
				list(BT_DESC_TYPE = /datum/bt_node/ai_behavior/unit_test_abort_probe),
				list(
					BT_DESC_TYPE = /datum/bt_node/composite/selector,
					BT_DESC_CHILDREN = list(
						list(
							BT_DESC_TYPE = /datum/bt_node/decorator/bb_key_set,
							"key" = TEST_BB_BT_GATE,
							"observer_abort" = BT_ABORT_LOWER_PRIORITY,
							"child_typepath" = /datum/bt_node/ai_behavior/unit_test_abort_probe,
						),
						list(BT_DESC_TYPE = /datum/bt_node/ai_behavior/unit_test_abort_probe/open_gate_on_perform),
					),
				),
			),
		),
		/datum/bt_node/ai_behavior/unit_test_abort_probe,
	))
	var/datum/bt_node/composite/parallel/parallel = controller.behavior_nodes[1]
	var/datum/bt_node/composite/selector/selector = parallel.children[2]
	var/datum/bt_node/decorator/bb_key_set/gate = selector.children[1]
	var/datum/bt_node/ai_behavior/unit_test_abort_probe/high_priority = gate.child
	var/datum/bt_node/ai_behavior/unit_test_abort_probe/low_priority = selector.children[2]
	var/datum/bt_node/ai_behavior/unit_test_abort_probe/next_root = controller.behavior_nodes[2]

	controller.SelectBehaviors(1)

	TEST_ASSERT_EQUAL(low_priority.perform_count, 1, "Lower-priority leaf did not open the gate")
	TEST_ASSERT(controller.cancelled_during_tick, "Observer missed the new priority while another branch was active")
	TEST_ASSERT_EQUAL(low_priority.finish_count, 1, "Cancelled leaf finished more than once")
	TEST_ASSERT_EQUAL(next_root.perform_count, 0, "Controller ticked another root after the abort")
	TEST_ASSERT_EQUAL(high_priority.perform_count, 0, "Controller immediately restarted the tree during the aborted tick")

	controller.SelectBehaviors(1)

	TEST_ASSERT_EQUAL(high_priority.perform_count, 1, "Controller did not switch to the opened branch on the next tick")
	TEST_ASSERT_EQUAL(low_priority.perform_count, 1, "Controller resumed the cancelled branch instead of switching priority")

/// An uncommanded rat must reach its own combat targeting behavior.
/datum/unit_test/ai_behavior_tree_rat_combat/Run()
	var/mob/living/basic/mouse/rat/rat = allocate(/mob/living/basic/mouse/rat, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/consistent/target = allocate(/mob/living/carbon/human/consistent, get_step(run_loc_floor_bottom_left, NORTH))
	var/datum/ai_controller/controller = rat.ai_controller
	controller.force_ai_off()

	controller.SelectBehaviors(0)

	TEST_ASSERT_EQUAL(controller.blackboard[BB_CURRENT_TARGET], target, "Rat did not acquire the visible hostile target on its own")

/// The idle pickup branch should be available only to untamed monkeys.
/datum/unit_test/ai_behavior_tree_monkey_idle_pickup/Run()
	var/mob/living/carbon/human/species/monkey/monkey = allocate(/mob/living/carbon/human/species/monkey, run_loc_floor_bottom_left)
	var/obj/item/weapon = allocate(/obj/item/crowbar, run_loc_floor_top_right)
	var/datum/ai_controller/controller = monkey.ai_controller
	controller.force_ai_off()
	controller.replace_behavior_nodes(list(/datum/bt_node/subtree/monkey_shenanigans))
	controller.set_blackboard_key(BB_MONKEY_PICKUPTARGET, weapon)

	controller.SelectBehaviors(0)

	TEST_ASSERT_EQUAL(controller.ai_movement.moving_controllers[controller], weapon, "Untamed monkey did not approach the item it found")
	controller.cancel_current_plan()
	controller.set_blackboard_key(BB_MONKEY_TAMED, TRUE)
	controller.set_blackboard_key(BB_MONKEY_PICKUPTARGET, weapon)

	controller.SelectBehaviors(0)

	TEST_ASSERT(!controller.ai_movement.moving_controllers[controller], "Tamed monkey pursued a weapon while idle")

/// Base fixture for AI LOD tests so spatial client grid tracking is always cleaned up on teardown.
/datum/unit_test/ai_lod
	abstract_type = /datum/unit_test/ai_lod
	var/mob/living/watcher

/datum/unit_test/ai_lod/Destroy()
	if(watcher)
		watcher.clear_important_client_contents()
		watcher = null
	return ..()

/// Unwatched station AI must drop to low priority without cancelling its active plan, and wake immediately when a living client enters its cells.
/datum/unit_test/ai_lod/station_priority_transitions/Run()
	TEST_ASSERT_EQUAL(SSlow_priority_ai_controllers.wait, 1 SECONDS, "Low priority AI subsystem wait should be 1 SECONDS")
	TEST_ASSERT(SSlow_priority_ai_controllers.wait > SSai_controllers.wait, "Low priority AI subsystem must tick slower than high priority")

	var/turf/station_turf
	for(var/area_type in GLOB.the_station_areas)
		var/turf/candidate = get_first_open_turf_in_area(GLOB.areas_by_type[area_type])
		if(candidate && istype(get_area(candidate), /area/station))
			station_turf = candidate
			break
	TEST_ASSERT_NOTNULL(station_turf, "Failed to find an open station turf for AI LOD test")

	var/mob/living/basic/mouse/station_mouse = allocate(/mob/living/basic/mouse, station_turf)
	var/datum/ai_controller/controller = station_mouse.ai_controller
	TEST_ASSERT_EQUAL(controller.ai_status, AI_STATUS_ON_LOW, "Unwatched station mob did not start in AI_STATUS_ON_LOW")
	TEST_ASSERT(controller in SSai_controllers.ai_controllers_by_status[AI_STATUS_ON_LOW], "Unwatched station mob missing from low priority status list")

	controller.replace_behavior_nodes(list(/datum/bt_node/ai_behavior/unit_test_abort_probe))
	var/datum/bt_node/ai_behavior/unit_test_abort_probe/probe = controller.behavior_nodes[1]
	controller.SelectBehaviors(1)
	TEST_ASSERT(probe.running, "Probe behavior did not start running before priority transition")

	watcher = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	watcher.enable_client_mobs_in_contents()
	TEST_ASSERT_EQUAL(controller.ai_status, AI_STATUS_ON_LOW, "Distant off-z client promoted station mob prematurely")

	watcher.forceMove(station_turf)
	TEST_ASSERT_EQUAL(controller.ai_status, AI_STATUS_ON, "Station mob did not wake to AI_STATUS_ON when client entered its cell")
	TEST_ASSERT(controller in SSai_controllers.ai_controllers_by_status[AI_STATUS_ON], "Woken station mob missing from high priority status list")
	TEST_ASSERT(probe.running, "Promoting AI_STATUS_ON_LOW to AI_STATUS_ON stopped the active behavior")
	TEST_ASSERT_EQUAL(probe.finish_count, 0, "Promoting AI_STATUS_ON_LOW to AI_STATUS_ON cancelled the active plan")

	watcher.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(controller.ai_status, AI_STATUS_ON_LOW, "Station mob did not return to AI_STATUS_ON_LOW after client left its cells")
	TEST_ASSERT(probe.running, "Downgrading AI_STATUS_ON to AI_STATUS_ON_LOW stopped the active behavior")
	TEST_ASSERT_EQUAL(probe.finish_count, 0, "Downgrading AI_STATUS_ON to AI_STATUS_ON_LOW cancelled the active plan")

/// Sleeping off-station AI moving across cells into range of a stationary client must wake to AI_STATUS_ON.
/datum/unit_test/ai_lod/offstation_move_wakes_sleep/Run()
	var/far_x = run_loc_floor_bottom_left.x + SPATIAL_GRID_CELLSIZE * 2
	if(far_x > world.maxx)
		far_x = run_loc_floor_bottom_left.x - SPATIAL_GRID_CELLSIZE * 2
	var/turf/far_turf = locate(far_x, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z)
	TEST_ASSERT_NOTNULL(far_turf, "Failed to find an off-station turf outside the client cell window")

	watcher = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	watcher.enable_client_mobs_in_contents()

	var/mob/living/basic/mouse/wild_mouse = allocate(/mob/living/basic/mouse, far_turf)
	var/datum/ai_controller/controller = wild_mouse.ai_controller
	TEST_ASSERT_EQUAL(controller.ai_status, AI_STATUS_OFF, "Unwatched off-station mob did not sleep at AI_STATUS_OFF")

	wild_mouse.forceMove(run_loc_floor_top_right)
	TEST_ASSERT_EQUAL(controller.ai_status, AI_STATUS_ON, "Off-station mob did not wake when moved into a stationary client's cell")

#undef TEST_BB_BT_GATE
