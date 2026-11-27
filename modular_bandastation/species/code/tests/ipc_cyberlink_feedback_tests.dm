/datum/unit_test/ipc_cyberlink_bot_controls/Run()
	var/mob/living/carbon/human/body = allocate_cyberlink_operator()
	var/datum/ipc_os_program/cyberlink/program = body.get_ipc_os().programs["cyberlink"]
	for(var/bot_type in list(/mob/living/basic/bot/cleanbot, /mob/living/basic/bot/medbot))
		var/mob/living/basic/bot/bot = allocate(bot_type)
		bot.ai_controller.force_ai_off()
		TEST_ASSERT(bot in program.connection_targets(), "Non-security bot was absent from neural targets.")
		TEST_ASSERT(program.begin_routing(body, bot, TRUE), "Bot advanced routing could not start.")
		solve_ipc_routing(program.routing)
		TEST_ASSERT(program.submit_routing(body, program.attempt_id, 1), "Bot first phase failed.")
		solve_ipc_routing(program.routing)
		TEST_ASSERT(program.submit_routing(body, program.attempt_id, 2), "Bot second phase failed.")
		var/was_on = !!(bot.bot_mode_flags & BOT_MODE_ON)
		TEST_ASSERT(program.execute_machine(body, bot, "power"), "Scoped bot power command failed.")
		TEST_ASSERT_EQUAL(!!(bot.bot_mode_flags & BOT_MODE_ON), !was_on, "Bot command did not use real native power state.")
		TEST_ASSERT(program.execute_machine(body, bot, "power"), "Immediate second bot command was blocked.")
		program.disconnect_link()

/datum/unit_test/ipc_cyberlink_camera_entry/Run()
	var/mob/living/carbon/human/body = allocate_cyberlink_operator()
	var/datum/ipc_os_program/cyberlink/program = body.get_ipc_os().programs["cyberlink"]
	var/obj/machinery/camera/camera = allocate(/obj/machinery/camera)
	camera.machine_stat = NONE
	TEST_ASSERT(camera in program.connection_targets(), "Nearby camera was absent from routing targets.")
	TEST_ASSERT(!program.begin_routing(body, camera, FALSE), "Unknown camera accepted standard routing.")
	TEST_ASSERT(program.begin_routing(body, camera, TRUE), "First camera advanced routing failed.")
	solve_ipc_routing(program.routing)
	program.submit_routing(body, program.attempt_id, 1)
	solve_ipc_routing(program.routing)
	TEST_ASSERT(program.submit_routing(body, program.attempt_id, 2), "Camera second phase failed.")
	var/datum/ipc_cyberlink_camera/session = program.camera_session
	TEST_ASSERT_NOTNULL(session, "Camera routing did not create a native viewing session.")
	TEST_ASSERT(session.valid(body), "Camera session rejected its actual owner.")
	var/charge = body.nutrition
	session.tick(10)
	TEST_ASSERT_EQUAL(body.nutrition, charge - body.ipc_charge_capacity() * 0.01, "Camera session did not bill its periodic tariff.")
	session.on_camera_disabled(camera)
	TEST_ASSERT_NULL(session.active_camera, "Native camera disconnect left its picture active.")
	body.forceMove(locate(body.x + 4, body.y, body.z))
	session.tick(0.2)
	TEST_ASSERT_EQUAL(program.camera_session, session, "Moving away broke the new distance-independent camera session.")
	program.disconnect_link()
	TEST_ASSERT(program.begin_routing(body, camera, FALSE), "Learned camera could not reconnect from a distance.")
	TEST_ASSERT_NULL(program.routing, "Learned camera created a repeat puzzle.")
	program.disconnect_link()

/datum/unit_test/ipc_feedback_cleaning_and_botany
	var/datum/turf_reservation/scanner_arena

/datum/unit_test/ipc_feedback_cleaning_and_botany/Destroy()
	. = ..()
	QDEL_NULL(scanner_arena)
	return .

/datum/unit_test/ipc_feedback_cleaning_and_botany/Run()
	var/mob/living/carbon/human/body = allocate_ipc_specialist(/datum/job/bartender)
	var/datum/ipc_os/os = body.get_ipc_os()
	// The normal test room is only seven tiles wide and its walls block a nine-tile scan.
	scanner_arena = SSmapping.request_turf_block_reservation(24, 5, 1, turf_type_override = /turf/open/floor/iron)
	TEST_ASSERT_NOTNULL(scanner_arena, "Could not reserve a long scanner test corridor.")
	var/turf/origin = scanner_arena.bottom_left_turfs[1]
	body.forceMove(locate(origin.x + 1, origin.y + 2, origin.z))
	body.lighting_cutoff = LIGHTING_NIGHTVISION_THRESHOLD
	var/datum/ipc_os_program/factory/cleaning/cleaner = os.programs["factory_cleaning"]
	TEST_ASSERT(cleaner.start(), "Cleaning did not start.")
	TEST_ASSERT(body.has_movespeed_modifier(/datum/movespeed_modifier/ipc_cleaning), "Cleaning did not slow the body.")
	var/turf/floor = get_turf(body)
	TEST_ASSERT_NOTNULL(floor.GetComponent(/datum/component/wet_floor), "Cleaning left a dry floor.")
	cleaner.stop()
	TEST_ASSERT(!body.has_movespeed_modifier(/datum/movespeed_modifier/ipc_cleaning), "Stopping cleaning left its slowdown.")
	var/datum/ipc_os_program/factory/botany/scanner = os.programs["factory_botany"]
	TEST_ASSERT(scanner.start(), "Plant scanner did not start.")
	var/obj/machinery/hydroponics/tray = allocate(/obj/machinery/hydroponics)
	tray.forceMove(locate(body.x + 9, body.y, body.z))
	TEST_ASSERT(tray in view(9, body), "Scanner fixture did not provide a visible nine-tile target.")
	TEST_ASSERT(body.can_read(scanner.device), "Scanner fixture could not read its own device.")
	scanner.analyze(tray, scanner.activation_id)
	TEST_ASSERT_EQUAL(scanner.device.last_tray_scanned?.resolve(), tray, "Visible tray at nine tiles could not be scanned.")
	scanner.device.last_tray_scanned = null
	tray.forceMove(locate(body.x + 10, body.y, body.z))
	scanner.analyze(tray, scanner.activation_id)
	TEST_ASSERT_NULL(scanner.device.last_tray_scanned, "Plant scan exceeded nine tiles.")

/datum/unit_test/ipc_feedback_zeng_loading_port/Run()
	var/mob/living/carbon/human/body = allocate_ipc_specialist(/datum/job/assistant)
	var/obj/item/bodypart/chest/robot/ipc/torso = body.get_bodypart(BODY_ZONE_CHEST)
	torso.ipc_manufacturer = /datum/ipc_manufacturer/zeng::name
	var/obj/item/clothing/mask/gas/mask = allocate(/obj/item/clothing/mask/gas)
	TEST_ASSERT(body.equip_to_slot_if_possible(mask, ITEM_SLOT_MASK), "Could not equip a mouth-covering mask.")
	var/obj/item/food/burger/plain/food = allocate(/obj/item/food/burger/plain)
	body.put_in_hands(food)
	var/result = SEND_SIGNAL(body, COMSIG_MOB_CLICKON, body, list(LEFT_CLICK = TRUE))
	TEST_ASSERT(result & COMSIG_MOB_CANCEL_CLICKON, "Loading port did not intercept native eating before mouth checks.")
	var/deadline = world.time + 5 SECONDS
	UNTIL(!torso.loading_food || world.time >= deadline)
	TEST_ASSERT(food in torso.ipc_food_queue, "Progress-bar food loading failed through a covered mouth.")
	TEST_ASSERT_EQUAL(food.loc, torso, "Loading port lost its dish.")

/datum/unit_test/ipc_feedback_cybersun_footsteps/Run()
	var/mob/living/carbon/human/body = allocate_ipc_specialist(/datum/job/assistant)
	var/obj/item/bodypart/chest/robot/ipc/torso = body.get_bodypart(BODY_ZONE_CHEST)
	torso.ipc_manufacturer = /datum/ipc_manufacturer/cybersun::name
	var/datum/species/ipc/species = body.dna.species
	species.on_life(body, 1)
	TEST_ASSERT(HAS_TRAIT(body, TRAIT_SILENT_FOOTSTEPS), "Cybersun did not suppress native footsteps.")
	torso.ipc_manufacturer = /datum/ipc_manufacturer/con::name
	species.on_life(body, 1)
	TEST_ASSERT(!HAS_TRAIT(body, TRAIT_SILENT_FOOTSTEPS), "Footstep suppression survived a torso brand change.")
