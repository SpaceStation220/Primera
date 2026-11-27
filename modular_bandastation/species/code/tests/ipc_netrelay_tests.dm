/datum/unit_test/ipc_netrelay
	abstract_type = /datum/unit_test/ipc_netrelay
	var/datum/turf_reservation/arena
	var/turf/origin
	var/area/misc/testroom/powered_area
	var/area/original_area

/datum/unit_test/ipc_netrelay/New()
	. = ..()
	arena = SSmapping.request_turf_block_reservation(28, 12, 1, turf_type_override = /turf/open/floor/iron)
	origin = arena.bottom_left_turfs[1]
	original_area = get_area(origin)
	powered_area = new
	for(var/x in 0 to 27)
		for(var/y in 0 to 11)
			var/turf/tile = locate(origin.x+x, origin.y+y, origin.z)
			tile.change_area(get_area(tile), powered_area)

/datum/unit_test/ipc_netrelay/Destroy()
	. = ..()
	for(var/x in 0 to 27)
		for(var/y in 0 to 11)
			var/turf/tile = locate(origin.x+x, origin.y+y, origin.z)
			tile.change_area(get_area(tile), original_area)
	QDEL_NULL(arena)
	QDEL_NULL(powered_area)
	original_area = null
	origin = null
	return .

/datum/unit_test/ipc_netrelay/proc/tile(x, y = 5)
	return locate(origin.x+x, origin.y+y, origin.z)

/datum/unit_test/ipc_netrelay/camera_hops/Run()
	var/mob/living/carbon/human/body = allocate_cyberlink_operator()
	body.forceMove(tile(1))
	var/datum/ipc_os_program/cyberlink/program = body.get_ipc_os().programs["cyberlink"]
	var/obj/machinery/camera/first = allocate(/obj/machinery/camera, tile(2))
	var/obj/machinery/camera/second = allocate(/obj/machinery/camera, tile(6))
	var/obj/machinery/camera/far = allocate(/obj/machinery/camera, tile(24))
	first.network = list("net-a")
	second.network = list("net-b")
	far.network = list("net-c")
	program.remember(first)
	program.remember(far)
	program.routing_ready_at = world.time + 80 SECONDS
	TEST_ASSERT(program.begin_routing(body, far, FALSE), "Remembered remote camera still required a puzzle or distance.")
	TEST_ASSERT_NULL(program.routing, "Remembered entry allocated a routing board.")
	program.disconnect_link()
	program.routing_ready_at = 0
	TEST_ASSERT(program.start_camera(first), "Camera fixture could not enter its physical camera.")
	var/datum/ipc_cyberlink_camera/session = program.camera_session
	TEST_ASSERT(second in session.transition_targets(), "Visible other-network camera was not eligible.")
	TEST_ASSERT(!(far in session.transition_targets()), "Off-screen camera became a network gateway.")
	TEST_ASSERT(!program.begin_routing(body, far, TRUE), "Forged remote camera bypassed visibility.")
	TEST_ASSERT(program.begin_routing(body, second, FALSE), "Standard network route failed to start.")
	solve_ipc_routing(program.routing)
	TEST_ASSERT(program.submit_routing(body, program.attempt_id, 1), "Standard network completion failed.")
	TEST_ASSERT_EQUAL(session.network_hops, 1, "Completed hop was not counted.")
	TEST_ASSERT_EQUAL(session.active_camera, second, "Hop did not select its actual gateway camera.")
	TEST_ASSERT(program.has_memory(second), "A solved network gateway was not remembered.")
	TEST_ASSERT(program.begin_routing(body, first, FALSE), "Return hop could not start.")
	TEST_ASSERT_NULL(program.routing, "Returning to a learned camera opened another puzzle.")
	TEST_ASSERT_EQUAL(session.network_hops, 2, "A return hop reset or skipped the tariff counter.")
	var/charge = body.nutrition
	session.tick(10)
	TEST_ASSERT_EQUAL(body.nutrition, charge - program.charge_cost(2), "Two hops did not bill two percent per ten seconds.")
	program.disconnect_link()
	TEST_ASSERT(program.start_camera(first), "Fresh camera session failed.")
	TEST_ASSERT_EQUAL(program.camera_session.network_hops, 0, "New session retained old hop charges.")

/obj/machinery/computer/ipc_remote_test
	var/applied = 0
	var/datum/ipc_os_program/cyberlink/tick_during_open

/obj/machinery/computer/ipc_remote_test/ui_interact(mob/user, datum/tgui/ui)
	tick_during_open?.refresh_remote_panels()
	return ..()

/obj/machinery/computer/ipc_remote_test/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if((action == "apply" || action == "apply-close") && allowed(ui.user))
		applied++
		if(action == "apply-close")
			ui_close(ui.user)
			qdel(ui)
		return TRUE
	return FALSE

/datum/unit_test/ipc_netrelay/remote_ui/Run()
	var/mob/living/carbon/human/body = allocate_cyberlink_operator()
	body.forceMove(tile(1))
	var/datum/ipc_os_program/cyberlink/program = body.get_ipc_os().programs["cyberlink"]
	var/obj/machinery/computer/ipc_remote_test/anchor = allocate(/obj/machinery/computer/ipc_remote_test, tile(5))
	var/obj/machinery/computer/ipc_remote_test/target = allocate(/obj/machinery/computer/ipc_remote_test, tile(9))
	var/obj/machinery/computer/ipc_remote_test/too_far = allocate(/obj/machinery/computer/ipc_remote_test, tile(10))
	var/obj/machinery/computer/ipc_remote_test/out_of_range = allocate(/obj/machinery/computer/ipc_remote_test, tile(6))
	TEST_ASSERT(anchor in program.machine_targets(), "Device four tiles away was not listed.")
	TEST_ASSERT(!(out_of_range in program.machine_targets()), "Device five tiles away remained directly reachable.")
	anchor.machine_stat = NONE
	target.machine_stat = NONE
	too_far.machine_stat = NONE
	out_of_range.machine_stat = NONE
	target.req_access = list(ACCESS_CAPTAIN)
	out_of_range.req_access = null
	for(var/wall_y in 1 to 9)
		allocate(/obj/structure/falsewall, tile(8, wall_y))
	TEST_ASSERT(!(target in view(4, anchor)), "The relay fixture did not block line of sight.")
	TEST_ASSERT(!length(program.relay_targets()), "A machine relayed before the routing puzzle was completed.")
	TEST_ASSERT(program.begin_routing(body, anchor, TRUE), "Routing to the entry node failed.")
	for(var/phase in 1 to 2)
		solve_ipc_routing(program.routing)
		TEST_ASSERT(program.submit_routing(body, program.attempt_id, phase), "Relay activation failed in phase [phase].")
	TEST_ASSERT_EQUAL(program.active_relay_anchor(), anchor, "Solved routing did not activate the chosen relay.")
	TEST_ASSERT(target in program.relay_targets(), "Four-tile relay could not reach beyond body range through a wall.")
	TEST_ASSERT(!(too_far in program.relay_targets()), "A target five tiles from the relay was reachable.")
	var/datum/tgui/control_ui = allocate(/datum/tgui, body, program, "ChromieKnight")
	control_ui.status = UI_INTERACTIVE
	control_ui.on_act_message("relay_control", list("target" = REF(out_of_range)), GLOB.conscious_state)
	TEST_ASSERT(out_of_range in program.remote_panels, "An available console required its own puzzle before remote control.")
	TEST_ASSERT(!program.can_remote_ui(body, target), "Relay granted free device access.")
	TEST_ASSERT(program.begin_routing(body, target, TRUE), "Ordinary relay route could not authorize its reachable console.")
	solve_ipc_routing(program.routing)
	TEST_ASSERT(program.submit_routing(body, program.attempt_id, 1), "Relay route phase one failed.")
	solve_ipc_routing(program.routing)
	TEST_ASSERT(program.submit_routing(body, program.attempt_id, 2), "Relay route phase two failed.")
	TEST_ASSERT_EQUAL(program.relay_anchor.resolve(), anchor, "Negotiating a relay target discarded its physical bridge.")
	TEST_ASSERT(!(too_far in program.relay_targets()), "A connected endpoint became a second relay.")
	target.tick_during_open = program
	TEST_ASSERT(program.open_machine_ui(body, target), "A fast-process tick canceled the native console while it was opening.")
	target.tick_during_open = null
	TEST_ASSERT_EQUAL(target.ui_state(body), GLOB.ipc_remote_state, "Native console retained its adjacent-only UI state.")
	TEST_ASSERT_EQUAL(target.ui_status(body, target.ui_state(body)), UI_INTERACTIVE, "Native atom status downgraded the open console to read-only.")
	var/datum/tgui/ui = allocate(/datum/tgui, body, target, "IpcOS")
	ui.status = UI_INTERACTIVE
	var/charge = body.nutrition
	var/temperature = body.coretemperature
	TEST_ASSERT(program.can_remote_ui(body, target), "Native opening lost device authority (check fixture power).")
	ui.on_act_message("apply", list(), GLOB.ipc_remote_state)
	TEST_ASSERT_EQUAL(target.applied, 1, "Native TGUI dispatcher did not execute the remote device action.")
	TEST_ASSERT_EQUAL(body.nutrition, charge - program.charge_cost(0.5), "Relay did not bill one half percent for its command.")
	TEST_ASSERT_EQUAL(body.coretemperature, temperature + 25, "Native remote command did not heat its body once.")
	charge = body.nutrition
	temperature = body.coretemperature
	ui.on_act_message("no-op", list(), GLOB.ipc_remote_state)
	TEST_ASSERT_EQUAL(body.nutrition, charge, "Failed native action consumed relay energy.")
	TEST_ASSERT_EQUAL(body.coretemperature, temperature, "Failed native action generated heat.")
	charge = body.nutrition
	temperature = body.coretemperature
	ui.on_act_message("apply-close", list(), GLOB.ipc_remote_state)
	TEST_ASSERT_EQUAL(target.applied, 2, "A native action closing its own UI failed.")
	TEST_ASSERT_EQUAL(body.nutrition, charge - program.charge_cost(0.5), "Closing the native UI skipped relay billing.")
	TEST_ASSERT_EQUAL(body.coretemperature, temperature + 25, "Closing the native UI skipped its command heat.")
	target.machine_stat |= NOPOWER
	program.process(0.2)
	TEST_ASSERT_EQUAL(program.linked_target?.resolve(), anchor, "Losing an endpoint also lost the working relay.")
	target.machine_stat &= ~NOPOWER
	program.open_machine_ui(body, target)
	ui = allocate(/datum/tgui, body, target, "IpcOS")
	ui.status = UI_INTERACTIVE
	qdel(anchor)
	TEST_ASSERT(!program.can_remote_ui(body, target), "Deleting relay entry retained remote device authority.")
	ui.on_act_message("apply", list(), GLOB.ipc_remote_state)
	TEST_ASSERT_EQUAL(target.applied, 2, "Lost relay still dispatched an action.")

/// Voluntary cancellation is sent by the routing window and resets the cached board itself.
/datum/unit_test/ipc_netrelay/routing_cancel/Run()
	var/mob/living/carbon/human/body = allocate_cyberlink_operator()
	body.forceMove(tile(1))
	var/datum/ipc_os_program/cyberlink/program = body.get_ipc_os().programs["cyberlink"]
	var/obj/machinery/computer/ipc_remote_test/target = allocate(/obj/machinery/computer/ipc_remote_test, tile(3))
	target.machine_stat = NONE
	TEST_ASSERT(program.begin_routing(body, target, TRUE), "Cancellation fixture failed to start routing.")
	var/datum/ipc_routing_board/board = program.routing
	solve_ipc_routing(board)
	TEST_ASSERT(program.submit_routing(body, program.attempt_id, 1), "Cancellation fixture could not reach phase two.")
	var/datum/tgui/ui = allocate(/datum/tgui, body, program.routing_window, "ChromieRouting")
	ui.status = UI_INTERACTIVE
	ui.on_act_message("routing_cancel", list("attempt" = program.attempt_id, "phase" = 1), GLOB.conscious_state)
	TEST_ASSERT_EQUAL(program.routing, board, "A stale phase cancelled the active puzzle.")
	var/heat = body.coretemperature
	var/burn = body.get_fire_loss()
	ui.on_act_message("routing_cancel", list("attempt" = program.attempt_id, "phase" = 2), GLOB.conscious_state)
	TEST_ASSERT_NULL(program.routing, "The cancel button left the puzzle active.")
	TEST_ASSERT_EQUAL(board.phase, 1, "Cancellation retained progress into phase two.")
	TEST_ASSERT_EQUAL(json_encode(board.cell_data()), json_encode(board.initial_cells), "Cancellation retained rotations or phase-two cells.")
	TEST_ASSERT_EQUAL(program.routing_ready_at, world.time + 10 SECONDS, "Cancellation did not use its normal cooldown.")
	TEST_ASSERT_EQUAL(body.coretemperature, heat, "Voluntary cancellation applied failure heat.")
	TEST_ASSERT_EQUAL(body.get_fire_loss(), burn, "Voluntary cancellation applied failure damage.")
	program.routing_ready_at = world.time
	TEST_ASSERT(program.begin_routing(body, target, TRUE), "Could not restart a cancelled puzzle.")
	TEST_ASSERT_EQUAL(program.routing, board, "Cancelling allocated a new puzzle instead of resetting the same one.")

/datum/unit_test/ipc_bot_hotkey_and_cleaning_energy/Run()
	var/mob/living/carbon/human/body = allocate_cyberlink_operator()
	var/datum/ipc_os_program/cyberlink/program = body.get_ipc_os().programs["cyberlink"]
	var/mob/living/basic/bot/medbot/bot = allocate(/mob/living/basic/bot/medbot)
	bot.ai_controller.force_ai_off()
	TEST_ASSERT(!program.begin_routing(body, bot, FALSE), "Standard bot routing bypassed its ID-slot requirement.")
	var/obj/item/card/id/advanced/card = allocate(/obj/item/card/id/advanced)
	card.set_access(list(ACCESS_MEDICAL, ACCESS_ROBOTICS), FORCE_ADD_ALL)
	body.put_in_hands(card)
	TEST_ASSERT(!program.begin_routing(body, bot, FALSE), "A held card authorized standard bot routing.")
	body.dropItemToGround(card)
	var/obj/item/clothing/under/color/grey/uniform = allocate(/obj/item/clothing/under/color/grey)
	TEST_ASSERT(body.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING), "Bot fixture uniform could not be equipped.")
	TEST_ASSERT(body.equip_to_slot_if_possible(card, ITEM_SLOT_ID), "Bot fixture ID could not be slotted.")
	TEST_ASSERT(SEND_SIGNAL(body, COMSIG_MOB_CLICKON, bot, list(ALT_CLICK = TRUE)) & COMSIG_MOB_CANCEL_CLICKON, "Alt-click was not intercepted for an ordinary bot.")
	TEST_ASSERT_NOTNULL(program.routing, "Alt-click on a medbot did not create its minigame with a valid slotted ID.")
	program.cancel_routing(TRUE)
	TEST_ASSERT(program.routing_ready_at > world.time, "Failure lost its server cooldown.")
	TEST_ASSERT(!program.begin_routing(body, bot, FALSE), "Failed route could immediately restart.")
	var/mob/living/carbon/human/service = allocate_ipc_specialist(/datum/job/bartender)
	var/datum/ipc_os_program/factory/cleaning/cleaner = service.get_ipc_os().programs["factory_cleaning"]
	TEST_ASSERT(cleaner.start(), "Cleaning failed to start.")
	var/charge = service.nutrition
	cleaner.tick(14)
	TEST_ASSERT_EQUAL(service.nutrition, charge, "Cleaning debited before its fifteen-second interval.")
	cleaner.tick(1)
	TEST_ASSERT_EQUAL(service.nutrition, charge - service.ipc_charge_capacity()*0.04, "Cleaning did not debit four percent per fifteen seconds.")

/datum/unit_test/ipc_netrelay/bot_settings/Run()
	var/mob/living/carbon/human/body = allocate_cyberlink_operator()
	body.forceMove(tile(1))
	var/datum/ipc_os_program/cyberlink/program = body.get_ipc_os().programs["cyberlink"]
	var/mob/living/basic/bot/medbot/bot = allocate(/mob/living/basic/bot/medbot, tile(3))
	bot.ai_controller.force_ai_off()
	program.accesses += allocate(/datum/ipc_cyberlink_access, bot)
	TEST_ASSERT(program.open_machine_ui(body, bot), "Medical bot native panel did not open remotely.")
	TEST_ASSERT_EQUAL(bot.ui_state(body), GLOB.ipc_remote_state, "Bot native UI did not use scoped remote range.")
	TEST_ASSERT_EQUAL(bot.ui_status(body, bot.ui_state(body)), UI_INTERACTIVE, "Native atom status left a remote bot panel read-only.")
	var/list/data = bot.ui_data(body)
	TEST_ASSERT(!data["locked"], "Remote settings remained hidden behind the physical cover lock.")
	var/datum/tgui/ui = allocate(/datum/tgui, body, bot, "Medbot")
	ui.status = UI_INTERACTIVE
	var/temperature = body.coretemperature
	ui.on_act_message("heal_threshold", list("threshold" = "45"), GLOB.ipc_remote_state)
	TEST_ASSERT_EQUAL(bot.heal_threshold, 45, "Native medical threshold did not change.")
	TEST_ASSERT_EQUAL(body.coretemperature, temperature + 25, "Bot setting did not bill its command heat.")
	var/cover = bot.bot_access_flags
	ui.on_act_message("maintenance", list(), GLOB.ipc_remote_state)
	TEST_ASSERT_EQUAL(bot.bot_access_flags, cover, "Remote UI opened the bot's physical cover.")
	program.close_remote_panels()
	TEST_ASSERT(!bot.ipc_remote_controls(body), "Closing remote bot UI retained authority.")
	program.remember(bot)
	QDEL_LIST(program.accesses)
	TEST_ASSERT(program.begin_routing(body, bot, FALSE), "A learned bot could not reconnect for commands.")
	TEST_ASSERT_EQUAL(program.bot_order_target.resolve(), bot, "Connecting did not select the bot for orders.")
	TEST_ASSERT(!(SEND_SIGNAL(body, COMSIG_MOB_CLICKON, tile(4), list(SHIFT_CLICK = TRUE, RIGHT_CLICK = TRUE)) & COMSIG_MOB_CANCEL_CLICKON), "The previous shift-right-click was still consumed.")
	TEST_ASSERT(SEND_SIGNAL(body, COMSIG_MOB_CLICKON, tile(4), list(SHIFT_CLICK = TRUE, LEFT_CLICK = TRUE)) & COMSIG_MOB_CANCEL_CLICKON, "Shift-left-click on a turf was not intercepted.")
	TEST_ASSERT_EQUAL(bot.ai_controller.blackboard[BB_BOT_SUMMON_TARGET], tile(4), "The connected bot did not receive its hotkey destination without a temporary access lease.")
	var/obj/machinery/camera/remote_camera = allocate(/obj/machinery/camera, tile(15))
	program.remember(remote_camera)
	TEST_ASSERT(program.begin_routing(body, remote_camera, FALSE), "Camera connection failed while controlling a bot.")
	TEST_ASSERT(program.order_bot(body, tile(16)), "Camera could not relay a bot destination outside the body's view.")
	TEST_ASSERT_EQUAL(bot.ai_controller.blackboard[BB_BOT_SUMMON_TARGET], tile(16), "Camera destination did not reach the selected bot.")

/datum/unit_test/ipc_netrelay/neural_multitool/Run()
	var/mob/living/carbon/human/body = allocate_cyberlink_operator()
	body.forceMove(tile(1))
	var/datum/ipc_os_program/cyberlink/program = body.get_ipc_os().programs["cyberlink"]
	var/obj/machinery/telecomms/receiver/target = allocate(/obj/machinery/telecomms/receiver, tile(3))
	target.machine_stat = NONE
	program.multitool_enabled = TRUE
	TEST_ASSERT(!program.use_multitool(body, target), "Neural tool bypassed the actual ID requirement.")
	program.accesses += allocate(/datum/ipc_cyberlink_access, target)
	TEST_ASSERT(program.use_multitool(body, target), "Authorized native neural multitool failed.")
	TEST_ASSERT_EQUAL(target.get_multitool(body), program.neural_multitool, "Native linking did not find the neural buffer.")
	var/datum/tgui/ui = allocate(/datum/tgui, body, target, "Telecomms")
	ui.status = UI_INTERACTIVE
	ui.on_act_message("buffer", list(), GLOB.ipc_remote_state)
	TEST_ASSERT_EQUAL(program.neural_multitool.buffer, target, "Native buffer action did not store the actual machine.")
	var/obj/machinery/telecomms/receiver/other = allocate(/obj/machinery/telecomms/receiver, tile(4))
	other.machine_stat = NONE
	program.accesses += allocate(/datum/ipc_cyberlink_access, other)
	TEST_ASSERT(program.use_multitool(body, other), "Second authorized telecomms machine did not open.")
	ui = allocate(/datum/tgui, body, other, "Telecomms")
	ui.status = UI_INTERACTIVE
	ui.on_act_message("link", list(), GLOB.ipc_remote_state)
	TEST_ASSERT((target in other.links) && (other in target.links), "Native linking failed to connect both machines.")
	program.close_remote_panels()
	TEST_ASSERT(isnull(target.get_multitool(body)), "Native tool buffer remained available after revocation.")

/datum/unit_test/ipc_netrelay/routing_feedback/Run()
	var/mob/living/carbon/human/body = allocate_cyberlink_operator()
	var/datum/ipc_os_program/cyberlink/program = body.get_ipc_os().programs["cyberlink"]
	program.routing_window = allocate(/datum/ipc_cyberlink_panel, program)
	program.routing_feedback(TRUE)
	TEST_ASSERT_EQUAL(program.routing_window.ui_status(body, null), UI_INTERACTIVE, "Success closed its result window immediately.")
	var/list/data = program.routing_window.ui_data(body)
	TEST_ASSERT_EQUAL(data["routing_result"], "success", "Success did not reach the routing UI.")
	program.routing_feedback(FALSE)
	data = program.routing_window.ui_data(body)
	TEST_ASSERT_EQUAL(data["routing_result"], "failure", "Failure did not reach the routing UI.")

/datum/unit_test/ipc_netrelay/multitool_pads/Run()
	var/mob/living/carbon/human/body = allocate_cyberlink_operator()
	body.forceMove(tile(1))
	var/datum/ipc_os_program/cyberlink/program = body.get_ipc_os().programs["cyberlink"]
	program.multitool_enabled = TRUE
	var/obj/machinery/quantumpad/first = allocate(/obj/machinery/quantumpad, tile(3))
	var/obj/machinery/quantumpad/second = allocate(/obj/machinery/quantumpad, tile(4))
	first.machine_stat = NONE
	second.machine_stat = NONE
	program.accesses += allocate(/datum/ipc_cyberlink_access, first)
	program.accesses += allocate(/datum/ipc_cyberlink_access, second)
	TEST_ASSERT(!program.use_multitool(body, first), "Neural tool bypassed the closed physical panel.")
	first.panel_open = TRUE
	TEST_ASSERT(program.use_multitool(body, first), "Native pad buffer could not be saved with an open panel.")
	TEST_ASSERT_EQUAL(program.neural_multitool.buffer, first, "Pad buffer did not retain the real machine.")
	TEST_ASSERT(program.use_multitool(body, second), "Native pad linking failed.")
	TEST_ASSERT_EQUAL(second.linked_pad, first, "Native pad did not receive its buffered destination.")
	QDEL_LIST(program.accesses)
	TEST_ASSERT(!program.use_multitool(body, second), "Expired authorization retained neural tool access.")
