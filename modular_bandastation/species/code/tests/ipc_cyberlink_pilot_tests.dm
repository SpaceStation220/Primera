/// Mocks only client presence; mind transfer, occupancy, weapons and damage remain native.
/datum/unit_test/proc/start_ipc_pilot(mob/living/carbon/human/body, atom/movable/target)
	body.mind_initialize()
	var/datum/ipc_os_program/cyberlink/program = body.get_ipc_os().programs["cyberlink"]
	var/datum/ipc_cyberlink_pilot/session = allocate(/datum/ipc_cyberlink_pilot, program, target)
	session.controlled.mock_client = body.mock_client
	TEST_ASSERT(session.start(), "Native pilot session could not start on [target.type].")
	TEST_ASSERT(session.valid(), "New pilot session failed ownership validation on [target.type].")
	return session

/datum/unit_test/ipc_cyberlink_pilot_ownership/Run()
	var/mob/living/carbon/human/body = allocate_cyberlink_operator()
	body.mind_initialize()
	body.mind.set_original_character(body)
	var/datum/mind/mind = body.mind
	var/datum/weakref/original = mind.original_character
	var/obj/vehicle/sealed/mecha/ripley/mech = allocate(/obj/vehicle/sealed/mecha/ripley)
	var/datum/ipc_cyberlink_pilot/session = start_ipc_pilot(body, mech)
	var/datum/ipc_os_program/cyberlink/program = session.program
	TEST_ASSERT_NULL(body.mind, "Source body retained a second copy of the pilot mind.")
	TEST_ASSERT_EQUAL(mind.current, session.controlled, "Mind did not transfer to the native occupant.")
	TEST_ASSERT(session.controlled in mech.return_drivers(), "Proxy did not receive the native driver seat.")
	TEST_ASSERT(mech.occupants[session.controlled] & VEHICLE_CONTROL_MELEE, "Native mech melee controls were absent.")
	TEST_ASSERT_EQUAL(session.controlled.remote_control, mech, "Movement was not routed to the real mech.")
	TEST_ASSERT(HAS_TRAIT(body, TRAIT_IMMOBILIZED) && HAS_TRAIT(body, TRAIT_HANDS_BLOCKED), "Physical body was not immobilized.")
	TEST_ASSERT(!HAS_TRAIT(body, TRAIT_GODMODE), "Pilot protection leaked to the physical body.")
	TEST_ASSERT_EQUAL(program.ui_status(session.controlled, null), UI_INTERACTIVE, "Pilot could not open the return interface.")
	var/mob/living/carbon/human/other = allocate_cyberlink_operator()
	var/datum/ipc_os_program/cyberlink/other_program = other.get_ipc_os().programs["cyberlink"]
	TEST_ASSERT(!other_program.pilot_ready(mech), "Another core could claim the occupied mech.")
	TEST_ASSERT_EQUAL(length(program.scanner_targets()), 0, "Body scanner remained available during piloting.")
	var/datum/client_interface/client = body.mock_client
	body.mock_client = null
	body.get_ipc_os().on_life(body, 1)
	body.player_logged = FALSE
	body.handle_ssd(1)
	TEST_ASSERT(!body.IsSleeping(), "SSD put the source body to sleep during a deliberate transfer.")
	TEST_ASSERT(session.valid(), "The deliberate departure from the source disconnected the pilot.")
	TEST_ASSERT(program.running && program.pilot == session, "Uncliented physical body stopped its own pilot program.")
	body.mock_client = client
	program.disconnect_link()
	TEST_ASSERT_EQUAL(mind.current, body, "Disconnect did not return the mind to its body.")
	TEST_ASSERT(!HAS_TRAIT(body, TRAIT_IPC_REMOTE_PILOT_BODY), "Ending the pilot session left SSD suppression on the body.")
	TEST_ASSERT_EQUAL(mind.original_character, original, "Pilot round trip changed original_character.")
	TEST_ASSERT_EQUAL(length(mech.occupants), 0, "Disconnect left a phantom occupant.")
	TEST_ASSERT_NULL(mech.ipc_neural_pilot, "Disconnect left an exclusive target reservation.")
	TEST_ASSERT(!HAS_TRAIT(body, TRAIT_IMMOBILIZED) && !HAS_TRAIT(body, TRAIT_HANDS_BLOCKED), "Disconnect left the physical body locked.")

/datum/unit_test/ipc_cyberlink_pilot_routing/Run()
	var/mob/living/carbon/human/body = allocate_cyberlink_operator()
	body.mind_initialize()
	var/datum/ipc_os_program/cyberlink/program = body.get_ipc_os().programs["cyberlink"]
	var/obj/vehicle/sealed/mecha/ripley/mech = allocate(/obj/vehicle/sealed/mecha/ripley)
	TEST_ASSERT(program.begin_routing(body, mech, FALSE), "Civilian mech incorrectly required an ID or advanced routing.")
	TEST_ASSERT_EQUAL(body.nutrition, 478, "Civilian routing did not cost four percent.")
	solve_ipc_routing(program.routing)
	TEST_ASSERT(program.submit_routing(body, program.attempt_id, 1), "Completed civilian routing did not enter the mech.")
	TEST_ASSERT_NOTNULL(program.pilot, "Successful routing created no pilot session.")
	program.pilot.controlled.mock_client = body.mock_client
	TEST_ASSERT(program.pilot.valid(), "Routing started an invalid native pilot session.")
	program.disconnect_link()
	var/charge = body.nutrition
	TEST_ASSERT(program.begin_routing(body, mech, FALSE), "Remembered mech could not reconnect.")
	TEST_ASSERT_NULL(program.routing, "Remembered physical mech asked for another puzzle.")
	TEST_ASSERT_EQUAL(body.nutrition, charge, "Remembered reconnect charged for a nonexistent puzzle.")
	program.disconnect_link()
	var/obj/vehicle/sealed/mecha/gygax/combat = allocate(/obj/vehicle/sealed/mecha/gygax)
	TEST_ASSERT(!program.begin_routing(body, combat, FALSE), "Client downgraded a combat mech to standard routing.")
	TEST_ASSERT(program.begin_routing(body, combat, TRUE), "Combat mech could not start advanced routing.")
	solve_ipc_routing(program.routing)
	TEST_ASSERT(program.submit_routing(body, program.attempt_id, 1), "Combat first phase was rejected.")
	TEST_ASSERT_NULL(program.pilot, "First combat phase prematurely granted piloting.")
	solve_ipc_routing(program.routing)
	TEST_ASSERT(program.submit_routing(body, program.attempt_id, 2), "Combat second phase did not grant piloting.")
	program.disconnect_link()

/datum/unit_test/ipc_cyberlink_pilot_interruptions/Run()
	for(var/reason in list("body moved", "EMP", "core extracted", "mech deleted", "mech power", "external transfer", "body death", "occupant extracted", "client lost", "other Z"))
		var/mob/living/carbon/human/body = allocate_cyberlink_operator()
		var/obj/vehicle/sealed/mecha/ripley/mech = allocate(/obj/vehicle/sealed/mecha/ripley)
		var/datum/ipc_cyberlink_pilot/session = start_ipc_pilot(body, mech)
		var/datum/mind/mind = session.source_mind
		var/session_source = REF(session)
		var/datum/ipc_os_program/cyberlink/program = session.program
		var/mob/living/carbon/human/elsewhere
		var/obj/item/organ/brain/core = session.core
		switch(reason)
			if("body moved")
				body.forceMove(get_step(body, NORTH))
			if("EMP")
				SEND_SIGNAL(session.core, COMSIG_ATOM_EMP_ACT, EMP_LIGHT)
			if("core extracted")
				session.core.Remove(body)
			if("mech deleted")
				qdel(mech)
			if("mech power")
				mech.cell.charge = 0
				session.tick(0.2)
			if("external transfer")
				elsewhere = allocate(/mob/living/carbon/human/consistent)
				mind.transfer_to(elsewhere)
			if("body death")
				body.death()
			if("occupant extracted")
				session.controlled.forceMove(get_turf(mech))
				var/deadline = world.time + 2 SECONDS
				UNTIL(!program.pilot || world.time >= deadline)
			if("client lost")
				session.controlled.mock_client = null
				session.tick(0.2)
			if("other Z")
				var/turf/other_level = locate(mech.x, mech.y, mech.z == 1 ? 2 : 1)
				TEST_ASSERT_NOTNULL(other_level, "Other-Z fixture could not find a second level.")
				mech.forceMove(other_level)
				var/deadline = world.time + 2 SECONDS
				UNTIL(!program.pilot || world.time >= deadline)
		TEST_ASSERT_NULL(program.pilot, "Pilot survived interruption: [reason].")
		var/mob/expected = reason == "core extracted" ? core.brainmob : elsewhere ? elsewhere : body
		TEST_ASSERT_EQUAL(mind.current, expected, "Cleanup stole or lost the pilot mind after [reason].")
		TEST_ASSERT(!HAS_TRAIT_FROM(body, TRAIT_HANDS_BLOCKED, session_source) && !HAS_TRAIT_FROM(body, TRAIT_IMMOBILIZED, session_source), "Cleanup left its own body locks after [reason].")
		if(!QDELETED(mech))
			TEST_ASSERT_EQUAL(length(mech.occupants), 0, "Cleanup left an occupant after [reason].")
		TEST_ASSERT_EQUAL(body.get_fire_loss(), 0, "A nondestructive interruption applied destruction burn: [reason].")

/datum/unit_test/ipc_cyberlink_pilot_tariffs_and_damage/Run()
	var/mob/living/carbon/human/body = allocate_cyberlink_operator()
	var/obj/vehicle/sealed/mecha/ripley/mech = allocate(/obj/vehicle/sealed/mecha/ripley)
	var/datum/ipc_cyberlink_pilot/session = start_ipc_pilot(body, mech)
	var/charge = body.nutrition
	session.tick(9)
	TEST_ASSERT_EQUAL(body.nutrition, charge, "Pilot billed before the ten-second period.")
	session.tick(1)
	TEST_ASSERT_EQUAL(body.nutrition, charge - body.ipc_charge_capacity() * 0.01, "Civilian pilot tariff was not one percent.")
	var/datum/ipc_os_program/power_save/save = session.program.os.programs["power_save"]
	save.installed = TRUE
	save.start()
	charge = body.nutrition
	session.tick(10)
	TEST_ASSERT(abs(body.nutrition - (charge - body.ipc_charge_capacity() * 0.0085)) < 0.001, "Pilot did not apply exactly fifteen percent PowerSave once.")
	var/temperature = body.coretemperature
	var/integrity = mech.get_integrity()
	mech.take_damage(30, BRUTE, MELEE, FALSE)
	var/lost = integrity - mech.get_integrity()
	TEST_ASSERT(lost > 0 && lost < 30, "Damage fixture did not exercise real mech armor.")
	TEST_ASSERT_EQUAL(body.coretemperature, temperature + lost * 0.75, "Mech heat used raw damage instead of actual lost integrity.")
	temperature = body.coretemperature
	mech.repair_damage(10)
	mech.take_damage(0, BRUTE, MELEE, FALSE)
	TEST_ASSERT_EQUAL(body.coretemperature, temperature, "Mech repair or zero damage affected pilot heat.")
	session.end()
	var/obj/vehicle/sealed/mecha/gygax/combat = allocate(/obj/vehicle/sealed/mecha/gygax)
	session = start_ipc_pilot(body, combat)
	TEST_ASSERT_EQUAL(session.periodic_cost(), 1.5, "Close combat tariff was incorrect.")
	var/turf/origin = get_turf(body)
	for(var/distance in list(9, 21, 41))
		var/turf/destination = locate(origin.x + distance, origin.y, origin.z)
		TEST_ASSERT_NOTNULL(destination, "Distance fixture ran beyond the native test map.")
		combat.forceMove(destination)
		TEST_ASSERT(session.valid(), "Pilot could not travel beyond its initial eight-tile range.")
		TEST_ASSERT_EQUAL(session.periodic_cost(), distance == 9 ? 2.5 : distance == 21 ? 4 : 6, "Incorrect combat distance tariff at [distance] tiles.")

/datum/unit_test/ipc_cyberlink_pilot_destruction/Run()
	for(var/mech_type in list(/obj/vehicle/sealed/mecha/ripley, /obj/vehicle/sealed/mecha/gygax))
		var/mob/living/carbon/human/body = allocate_cyberlink_operator()
		var/obj/vehicle/sealed/mecha/mech = allocate(mech_type)
		mech.forceMove(get_step(body, EAST))
		var/datum/ipc_cyberlink_pilot/session = start_ipc_pilot(body, mech)
		var/datum/ipc_os_program/cyberlink/program = session.program
		var/combat = program.pilot_kind(mech) == "combat"
		var/temperature = body.coretemperature
		var/integrity = mech.get_integrity()
		mech.take_damage(10000, BRUTE, NONE, FALSE)
		TEST_ASSERT_NULL(program.pilot, "Fatal native mech damage left the pilot connected.")
		TEST_ASSERT_EQUAL(body.coretemperature, temperature + integrity * 0.75 + (combat ? 60 : 35), "Fatal hit heat or once-only destruction penalty was lost.")
		TEST_ASSERT_EQUAL(body.get_fire_loss(), combat ? 40 : 25, "Mech destruction burn was absent or applied more than once.")

/datum/unit_test/ipc_cyberlink_pilot_secbot/Run()
	var/mob/living/carbon/human/body = allocate_cyberlink_operator()
	var/mob/living/basic/bot/secbot/bot = allocate(/mob/living/basic/bot/secbot)
	var/datum/ipc_os_program/cyberlink/program = body.get_ipc_os().programs["cyberlink"]
	TEST_ASSERT_EQUAL(program.pilot_kind(bot), "secbot", "Ordinary helmet-built secbot was excluded in favor of only named Beepsky.")
	TEST_ASSERT(!program.begin_routing(body, bot, FALSE), "Secbot accepted downgraded standard routing.")
	var/obj/item/melee/baton/security/baton = bot.weapon
	var/obj/item/stock_parts/power_store/cell/original_cell = baton.cell
	var/original_active = baton.active
	var/datum/ipc_cyberlink_pilot/session = start_ipc_pilot(body, bot)
	TEST_ASSERT(session.bot_ai.forced_off, "Native secbot AI kept running during manual control.")
	var/turf/source_turf = get_turf(body)
	bot.forceMove(locate(source_turf.x + 21, source_turf.y, source_turf.z))
	TEST_ASSERT_EQUAL(session.periodic_cost(), 1.5, "Secbot tariff increased with distance.")
	bot.forceMove(source_turf)
	TEST_ASSERT_NULL(bot.GetComponent(/datum/component/stun_n_cuff), "Automatic secbot stun/cuff component remained active.")
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/charge = body.nutrition
	TEST_ASSERT(session.stun_target(victim), "Manual native baton attack could not start.")
	TEST_ASSERT_EQUAL(victim.get_stamina_loss(), baton.stamina_damage, "Manual stun bypassed the real security baton effects.")
	TEST_ASSERT_EQUAL(victim.get_brute_loss(), 0, "Manual stun inflicted an extra basic-mob melee attack.")
	TEST_ASSERT_EQUAL(body.nutrition, charge - body.ipc_charge_capacity() * 0.02, "Native successful stun did not cost two percent of the source battery.")
	charge = body.nutrition
	session.stun_target(victim)
	TEST_ASSERT_EQUAL(body.nutrition, charge, "Baton cooldown still charged another stun.")
	COOLDOWN_RESET(baton, cooldown_check)
	bot.next_move = world.time
	var/mob/living/carbon/human/second_victim = allocate(/mob/living/carbon/human/consistent)
	var/datum/ipc_os_program/power_save/save = program.os.programs["power_save"]
	save.installed = TRUE
	save.start()
	TEST_ASSERT(session.stun_target(second_victim), "Second native stun could not start after cooldown.")
	TEST_ASSERT(abs(body.nutrition - (charge - body.ipc_charge_capacity() * 0.017)) < 0.001, "Manual stun applied an incorrect PowerSave discount.")
	COOLDOWN_RESET(baton, cooldown_check)
	bot.next_move = world.time
	body.set_nutrition(1, forced = TRUE)
	var/mob/living/carbon/human/unharmed = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(!session.stun_target(unharmed), "Manual stun succeeded without enough battery.")
	TEST_ASSERT_EQUAL(unharmed.get_brute_loss() + unharmed.get_stamina_loss(), 0, "Insufficient-charge stun turned into a harmful basic attack.")
	body.set_nutrition(400, forced = TRUE)
	session.end()
	TEST_ASSERT_EQUAL(body.mind.current, body, "Secbot disconnect failed to return its pilot.")
	TEST_ASSERT_EQUAL(baton.cell, original_cell, "Temporary baton cell leaked into the world.")
	TEST_ASSERT_EQUAL(baton.active, original_active, "Disconnect changed the original baton state.")
	TEST_ASSERT_NOTNULL(bot.GetComponent(/datum/component/stun_n_cuff), "Native arrest component was not restored.")
	TEST_ASSERT(!bot.ai_controller.forced_off, "Native secbot AI was not restored.")
	session = start_ipc_pilot(body, bot)
	bot.ai_controller.force_ai_off()
	session.end()
	TEST_ASSERT(bot.ai_controller.forced_off, "Teardown undid a newer external AI-disable request.")

/datum/unit_test/ipc_cyberlink_pilot_bot_menu/Run()
	var/mob/living/carbon/human/body = allocate_cyberlink_operator()
	body.mind_initialize()
	var/datum/mind/player = body.mind
	var/datum/ipc_os_program/cyberlink/program = body.get_ipc_os().programs["cyberlink"]
	var/datum/tgui/ui = allocate(/datum/tgui, body, program, "ChromieKnight")
	ui.status = UI_INTERACTIVE
	var/mob/living/basic/bot/cleanbot/bot = allocate(/mob/living/basic/bot/cleanbot)
	ui.on_act_message("pilot_bot", list("target" = REF(bot)), GLOB.conscious_state)
	TEST_ASSERT(program.routing?.advanced, "The actual menu action did not open the first route without a slotted ID.")
	TEST_ASSERT_EQUAL(program.routing_pilot_kind, "bot", "The menu selected electronic commands instead of direct control.")
	ui.on_act_message("disconnect", list(), GLOB.conscious_state)
	TEST_ASSERT_NOTNULL(program.routing, "The program menu disconnected an active routing game.")
	var/datum/tgui/route_ui = allocate(/datum/tgui, body, program.routing_window, "ChromieRouting")
	route_ui.status = UI_INTERACTIVE
	route_ui.on_act_message("disconnect", list(), GLOB.conscious_state)
	TEST_ASSERT_NOTNULL(program.routing, "The routing window accepted an obsolete close action.")
	program.routing_window.ui_close(body)
	TEST_ASSERT_NOTNULL(program.routing, "Closing the routing UI cancelled the running board.")
	bot.mock_client = body.mock_client
	for(var/phase in 1 to 2)
		solve_ipc_routing(program.routing)
		TEST_ASSERT(program.submit_routing(body, program.attempt_id, phase), "Cleanbot pilot routing could not complete phase [phase].")
	TEST_ASSERT_EQUAL(player.current, bot, "Completing the route did not transfer the mind into the native cleanbot.")
	TEST_ASSERT(program.pilot?.valid(), "The cleanbot pilot session did not survive handoff.")
	TEST_ASSERT_EQUAL(program.routing_window.result, "success", "The new pilot did not receive the routing result.")
	var/turf/spot = get_step(bot, EAST)
	var/obj/effect/decal/cleanable/dirt/mess = allocate(/obj/effect/decal/cleanable/dirt, spot)
	bot.ClickOn(mess, "left=1")
	var/deadline = world.time + 4 SECONDS
	UNTIL(QDELETED(mess) || world.time >= deadline)
	TEST_ASSERT(QDELETED(mess), "A left click during direct control did not perform native cleaning.")
	bot.Logout()
	TEST_ASSERT_EQUAL(player.current, body, "Ending cleanbot control left the pilot outside their body.")
	bot.mock_client = null
	bot.handle_ssd(1)
	TEST_ASSERT(bot.player_logged && !bot.IsSleeping(), "Leaving a borrowed bot sent it into player SSD.")
	TEST_ASSERT(program.pilot_ready(bot) && !bot.ai_controller.forced_off, "The released bot could not resume autonomy or be piloted again.")

/datum/unit_test/ipc_cyberlink_pilot_ed209/Run()
	var/mob/living/carbon/human/body = allocate_cyberlink_operator()
	var/mob/living/basic/bot/secbot/ed209/bot = allocate(/mob/living/basic/bot/secbot/ed209)
	var/datum/ipc_os_program/cyberlink/program = body.get_ipc_os().programs["cyberlink"]
	TEST_ASSERT(program.pilot_ready(bot), "Powered ED-209 was excluded from the pilot list.")
	TEST_ASSERT(!program.begin_routing(body, bot, FALSE), "ED-209 accepted downgraded routing.")
	var/datum/component/arrest = bot.GetComponent(/datum/component/stun_n_cuff)
	var/datum/ipc_cyberlink_pilot/session = start_ipc_pilot(body, bot)
	var/datum/component/ranged_attacks/weapon = bot.GetComponent(/datum/component/ranged_attacks)
	var/turf/destination = get_step(bot, EAST)
	TEST_ASSERT_NOTNULL(weapon, "Manual ED-209 lost its native ranged component.")
	TEST_ASSERT_EQUAL(weapon.projectile_type, /obj/projectile/beam/disabler, "Station ED-209 lost its standard disabler.")
	TEST_ASSERT(SEND_SIGNAL(bot, COMSIG_MOB_CLICKON, destination, list(LEFT_CLICK = TRUE)) & COMSIG_MOB_CANCEL_CLICKON, "Manual ED-209 did not take over the primary click.")
	TEST_ASSERT(!COOLDOWN_FINISHED(weapon, fire_cooldown), "Manual ED-209 did not fire through its native component.")
	session.end()
	TEST_ASSERT_EQUAL(bot.GetComponent(/datum/component/stun_n_cuff), arrest, "Manual ED-209 changed the native arrest configuration.")

/datum/unit_test/ipc_cyberlink_emp_shutdown/Run()
	var/mob/living/carbon/human/body = allocate_cyberlink_operator()
	var/datum/ipc_os/os = body.get_ipc_os()
	var/datum/ipc_os_program/cyberlink/program = os.programs["cyberlink"]
	body.emp_protection = EMP_PROTECTION_HIGH
	body.emp_act(EMP_HEAVY)
	TEST_ASSERT(program.running, "An EMP absorbed by chassis protection shut down the program.")
	body.emp_protection = 0
	var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock)
	TEST_ASSERT(program.begin_routing(body, door, TRUE), "The EMP fixture could not start routing.")
	body.emp_act(EMP_LIGHT)
	TEST_ASSERT_EQUAL(program.emp_seconds_left(), 60, "Light EMP used the wrong recovery time.")
	TEST_ASSERT_NULL(program.routing, "Light EMP left a routing attempt active.")
	TEST_ASSERT(!program.running, "Light EMP did not stop ChromieKnight.")
	os.resume_passives()
	TEST_ASSERT(!program.running, "The normal passive boot bypassed EMP recovery.")
	TEST_ASSERT_EQUAL(os.ui_data(body)["cyberlink_emp_left"], 60, "The desktop did not show the EMP recovery time.")
	program.emp_disabled_until = world.time
	os.resume_passives()
	TEST_ASSERT(program.running, "ChromieKnight did not resume after EMP recovery.")

	var/mob/living/carbon/human/pilot_body = allocate_cyberlink_operator()
	var/obj/vehicle/sealed/mecha/ripley/mech = allocate(/obj/vehicle/sealed/mecha/ripley)
	var/datum/ipc_cyberlink_pilot/session = start_ipc_pilot(pilot_body, mech)
	var/datum/ipc_os_program/cyberlink/pilot_program = session.program
	mech.cell.charge = mech.cell.maxcharge
	mech.emp_act(EMP_HEAVY)
	TEST_ASSERT(mech.equipment_disabled, "The occupied mech did not take its usual EMP equipment penalty.")
	TEST_ASSERT_EQUAL(pilot_program.emp_seconds_left(), 0, "An EMP on the mech disabled the remote chassis' program.")
	TEST_ASSERT_EQUAL(pilot_program.pilot, session, "An EMP on an operational mech returned the pilot to their chassis.")
	TEST_ASSERT(session.valid(), "An EMP on an operational mech invalidated its pilot link.")
	pilot_body.emp_act(EMP_HEAVY)
	TEST_ASSERT_EQUAL(pilot_program.emp_seconds_left(), 90, "Heavy EMP used the wrong recovery time.")
	TEST_ASSERT_NULL(pilot_program.pilot, "Heavy EMP left the mech under direct control.")
	TEST_ASSERT_EQUAL(pilot_body.mind?.current, pilot_body, "Heavy EMP did not return the pilot to the chassis.")
	pilot_body.emp_act(EMP_LIGHT)
	TEST_ASSERT_EQUAL(pilot_program.emp_seconds_left(), 90, "A weaker EMP shortened the existing recovery.")
	TEST_ASSERT(!pilot_program.running, "Heavy EMP did not stop ChromieKnight.")

/datum/unit_test/ipc_cyberlink_pilot_secbot_destruction/Run()
	var/mob/living/carbon/human/body = allocate_cyberlink_operator()
	var/mob/living/basic/bot/secbot/bot = allocate(/mob/living/basic/bot/secbot)
	var/datum/ipc_cyberlink_pilot/session = start_ipc_pilot(body, bot)
	var/datum/ipc_os_program/cyberlink/program = session.program
	var/obj/item/melee/baton/security/baton = bot.weapon
	var/temperature = body.coretemperature
	bot.apply_damage(1000, BRUTE)
	TEST_ASSERT_NULL(program.pilot, "Destroyed secbot retained its pilot.")
	TEST_ASSERT_EQUAL(body.mind.current, body, "Secbot exploded before returning its mind.")
	TEST_ASSERT_EQUAL(body.coretemperature, temperature + 15, "Secbot destruction heat was lost or duplicated.")
	TEST_ASSERT_EQUAL(body.get_fire_loss(), 10, "Secbot destruction burn was lost or duplicated.")
	TEST_ASSERT_NULL(baton.cell, "Destroyed secbot dropped a free powered baton cell.")
