/// Solve by legal cell rotations using the generated path, without replacing the validator.
/datum/unit_test/proc/solve_ipc_routing(datum/ipc_routing_board/board)
	for(var/position in 1 to length(board.path))
		var/index = board.path[position]
		var/forward = position == length(board.path) ? EAST : board.direction_between(index, board.path[position+1])
		var/expected = (position == 1 ? WEST : board.direction_between(index, board.path[position-1])) | forward
		var/datum/ipc_routing_cell/cell = board.cells[index]
		for(var/rotation in 1 to 4)
			if(cell.mask == expected && (!cell.output_dir || cell.output_dir == forward))
				break
			TEST_ASSERT(board.rotate_cell(index), "Canonical solution required rotating a locked or damaged cell.")
		TEST_ASSERT(cell.mask == expected && (!cell.output_dir || cell.output_dir == forward), "Rotation failed to restore canonical ports: cell [index], mask [cell.mask], expected [expected], output [cell.output_dir], forward [forward].")
	TEST_ASSERT(board.solved(), "Generated canonical route did not pass the real server validator: phase [board.phase], path [json_encode(board.path)], cells [json_encode(board.cell_data())].")

/datum/unit_test/ipc_cyberlink_routing_boards/Run()
	var/datum/ipc_routing_cell/segment = allocate(/datum/ipc_routing_cell)
	segment.mask = NORTH|SOUTH
	segment.output_dir = NORTH
	for(var/turn_number in 1 to 4)
		segment.rotate()
	TEST_ASSERT_EQUAL(segment.mask, NORTH|SOUTH, "Four rotations changed a segment's port count or shape.")
	TEST_ASSERT_EQUAL(segment.output_dir, NORTH, "Four rotations changed the diode's original direction.")
	for(var/number in 1 to 200)
		var/advanced = number > 100
		var/datum/ipc_routing_board/board = allocate(/datum/ipc_routing_board, advanced)
		TEST_ASSERT_EQUAL(length(board.cells), advanced ? 64 : 49, "Routing board size did not match its difficulty.")
		TEST_ASSERT(!board.solved(), "Routing board was solved before any input.")
		var/blocked_count = 0
		var/locked_count = 0
		var/diode_count = 0
		for(var/index in 1 to length(board.cells))
			var/datum/ipc_routing_cell/cell = board.cells[index]
			blocked_count += !!cell.blocked
			locked_count += !!cell.locked
			diode_count += !!cell.output_dir
			if(cell.blocked || cell.locked)
				var/before = cell.mask
				TEST_ASSERT(!board.rotate_cell(index), "Damaged/locked segment could be rotated.")
				TEST_ASSERT_EQUAL(before, cell.mask, "Rejected rotation changed the segment.")
		TEST_ASSERT(blocked_count >= (advanced ? 8 : 4) && blocked_count <= (advanced ? 10 : 6), "Wrong damaged-cell count.")
		TEST_ASSERT(locked_count >= (advanced ? 4 : 2) && locked_count <= (advanced ? 6 : 3), "Wrong locked-cell count.")
		TEST_ASSERT(diode_count >= (advanced ? 2 : 1) && diode_count <= (advanced ? 3 : 1), "Wrong diode count.")
		TEST_ASSERT(!board.rotate_cell(0) && !board.rotate_cell(101) && !board.rotate_cell(1.5), "Malformed rotation index was accepted.")
		solve_ipc_routing(board)
		if(advanced)
			TEST_ASSERT(board.advance_phase(), "Advanced route did not enter its second phase.")
			TEST_ASSERT(!board.solved(), "Second phase needed no correction.")
			TEST_ASSERT_EQUAL(length(board.required_nodes), 2, "Second phase did not add an authorization node.")
			solve_ipc_routing(board)
			TEST_ASSERT(!board.advance_phase(), "Advanced route acquired an unapproved third phase.")
			board.reset_progress()
			TEST_ASSERT_EQUAL(board.phase, 1, "Failed advanced attempt did not return to the first phase.")
			TEST_ASSERT_EQUAL(json_encode(board.cell_data()), json_encode(board.initial_cells), "Failed advanced attempt did not restore its original layout.")

/datum/unit_test/proc/allocate_cyberlink_operator()
	var/mob/living/carbon/human/ipc = allocate(/mob/living/carbon/human/consistent)
	ipc.set_species(/datum/species/ipc)
	ipc.mock_client = allocate(/datum/client_interface)
	var/datum/preference/choiced/ipc/generation/preference = GLOB.preference_entries[/datum/preference/choiced/ipc/generation]
	preference.apply_to_human(ipc, "IV", null)
	ipc.set_nutrition(500, forced = TRUE)
	var/datum/ipc_os_program/cyberlink/program = ipc.get_ipc_os().programs["cyberlink"]
	program.start()
	return ipc

/// Real routing success, not a client boolean, creates a scoped expiring authorization.
/datum/unit_test/ipc_cyberlink_routing_authorization/Run()
	var/mob/living/carbon/human/ipc = allocate_cyberlink_operator()
	var/datum/ipc_os_program/cyberlink/program = ipc.get_ipc_os().programs["cyberlink"]
	var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock)
	door.req_access = list(ACCESS_HYDROPONICS)
	var/obj/item/card/id/advanced/card = allocate(/obj/item/card/id/advanced)
	card.set_access(list(ACCESS_HYDROPONICS), FORCE_ADD_ALL)
	ipc.put_in_hands(card)
	TEST_ASSERT(!program.slot_access(door), "A card in a hand counted as ID-slot access.")
	TEST_ASSERT_EQUAL(length(program.machine_commands(door)), 0, "Unprivileged user received electronic commands.")
	TEST_ASSERT(!program.begin_routing(ipc, door, FALSE), "Standard routing bypassed the ID requirement.")
	TEST_ASSERT(program.begin_routing(ipc, door, TRUE), "Advanced routing could not start on a powered generic airlock.")
	TEST_ASSERT_EQUAL(ipc.nutrition, 456, "Advanced launch did not debit eight percent.")
	TEST_ASSERT(!program.submit_routing(ipc, program.attempt_id, 1), "Unsolved client submission obtained access.")
	TEST_ASSERT_EQUAL(length(program.memory), 0, "Opening a puzzle learned the machine.")
	solve_ipc_routing(program.routing)
	TEST_ASSERT(!program.submit_routing(ipc, program.attempt_id - 1, 1), "Stale attempt token was accepted.")
	TEST_ASSERT(program.submit_routing(ipc, program.attempt_id, 1), "Valid first phase was rejected.")
	TEST_ASSERT_NULL(program.access_for(door), "First phase prematurely granted extended access.")
	solve_ipc_routing(program.routing)
	TEST_ASSERT(program.submit_routing(ipc, program.attempt_id, 2), "Valid second phase was rejected.")
	var/datum/ipc_cyberlink_access/access = program.access_for(door)
	TEST_ASSERT_NOTNULL(access, "Completed advanced puzzle did not create a capability.")
	TEST_ASSERT_EQUAL(access.expires_at, world.time + 10 SECONDS, "Airlock capability did not use its ten-second window.")
	TEST_ASSERT_EQUAL(length(program.memory), 1, "Completed routing did not remember its concrete machine.")
	TEST_ASSERT_EQUAL(door.req_access[1], ACCESS_HYDROPONICS, "Routing rewrote the physical door's access requirements.")
	TEST_ASSERT("bolts" in program.machine_commands(door), "Extended door controls were missing.")
	access.expires_at = world.time - 1
	program.process(0.2)
	TEST_ASSERT_NULL(program.access_for(door), "Expired capability remained usable.")
	TEST_ASSERT_EQUAL(length(program.machine_commands(door)), 0, "Memory or held card granted permanent access.")
	TEST_ASSERT(program.begin_routing(ipc, door, TRUE), "A second advanced attempt could not start.")
	var/datum/ipc_routing_board/retained = program.routing
	program.cancel_routing()
	program.routing_ready_at = world.time
	TEST_ASSERT(program.begin_routing(ipc, door, TRUE), "Canceled route could not resume after cooldown.")
	TEST_ASSERT_EQUAL(program.routing, retained, "Canceling granted a free board reroll.")
	var/obj/item/organ/brain/ipc/core = ipc.get_organ_slot(ORGAN_SLOT_BRAIN)
	allocated += core
	core.Remove(ipc, special = TRUE)
	TEST_ASSERT_NULL(program.routing, "Removing the core left a routing attempt active.")
	TEST_ASSERT_NULL(program.linked_target, "Removing the core retained the former body's connection.")

/// A late cancel cannot turn a timed-out attempt into a harmless voluntary cancellation.
/datum/unit_test/ipc_cyberlink_expired_cancel/Run()
	var/mob/living/carbon/human/ipc = allocate_cyberlink_operator()
	var/datum/ipc_os_program/cyberlink/program = ipc.get_ipc_os().programs["cyberlink"]
	var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock)
	TEST_ASSERT(program.begin_routing(ipc, door, TRUE), "Timeout fixture could not start routing.")
	var/datum/ipc_routing_board/board = program.routing
	board.rotate_cell(1)
	program.routing_deadline = world.time
	program.cancel_routing()
	TEST_ASSERT_NULL(program.routing, "Canceling an expired board left it active.")
	TEST_ASSERT_EQUAL(program.routing_cache["[REF(door)]:1"], board, "A failed attempt granted a new board.")
	TEST_ASSERT_EQUAL(json_encode(board.cell_data()), json_encode(board.initial_cells), "A failed attempt retained its rotations.")
	TEST_ASSERT_EQUAL(program.routing_ready_at, world.time + 80 SECONDS, "Late cancellation bypassed the timeout's failure cooldown.")
	TEST_ASSERT(ipc.get_fire_loss() >= 40, "Late cancellation bypassed the advanced failure's burn penalty.")

/// A lease's rollback owns only revisions it created; later player changes survive it.
/datum/unit_test/ipc_cyberlink_door_rollback/Run()
	var/mob/living/carbon/human/ipc = allocate_cyberlink_operator()
	var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock)
	var/datum/ipc_cyberlink_access/access = allocate(/datum/ipc_cyberlink_access, door)
	TEST_ASSERT(access.set_bolts(ipc), "Cyberlink could not drop powered door bolts.")
	TEST_ASSERT(door.locked, "Bolt command had no physical effect.")
	access.expires_at = world.time - 1
	access.bolt_restore_at = world.time + 7 SECONDS
	access.restore()
	TEST_ASSERT(door.locked, "Bolts were removed before the additional eight-second interval.")
	access.bolt_restore_at = world.time - 1
	access.restore()
	TEST_ASSERT(!door.locked, "Temporary bolts did not restore their original state.")
	qdel(access)
	access = allocate(/datum/ipc_cyberlink_access, door)
	TEST_ASSERT(access.set_shock(ipc, TRUE), "Cyberlink could not electrify a supported door.")
	access.expires_at = world.time - 1
	access.restore()
	TEST_ASSERT_EQUAL(door.secondsElectrified, 0, "Electricity survived the access window.")
	qdel(access)
	access = allocate(/datum/ipc_cyberlink_access, door)
	TEST_ASSERT(access.set_bolts(ipc), "Second bolt lease failed.")
	door.unbolt()
	door.bolt()
	qdel(access)
	TEST_ASSERT(door.locked, "Rollback overwrote a newer player's bolt command.")
	door.unbolt()
	access = allocate(/datum/ipc_cyberlink_access, door)
	TEST_ASSERT(access.set_shock(ipc, TRUE), "Second shock lease failed.")
	door.set_electrified(MACHINE_ELECTRIFIED_PERMANENT, ipc)
	qdel(access)
	TEST_ASSERT_EQUAL(door.secondsElectrified, MACHINE_ELECTRIFIED_PERMANENT, "Rollback erased newer permanent electricity.")
	door.set_electrified(MACHINE_NOT_ELECTRIFIED)
	access = allocate(/datum/ipc_cyberlink_access, door)
	TEST_ASSERT(access.set_bolts(ipc), "Bolt lease for wire-race check failed.")
	door.wires.cut(WIRE_BOLTS, ipc)
	qdel(access)
	TEST_ASSERT(door.locked, "Rollback lifted bolts subsequently fixed by a cut wire.")
	door.wires.cut(WIRE_BOLTS, ipc)
	door.unbolt()
	access = allocate(/datum/ipc_cyberlink_access, door)
	TEST_ASSERT(access.set_shock(ipc, TRUE), "Shock lease for wire-race check failed.")
	door.wires.cut(WIRE_SHOCK, ipc)
	qdel(access)
	TEST_ASSERT_EQUAL(door.secondsElectrified, MACHINE_ELECTRIFIED_PERMANENT, "Rollback removed electricity subsequently fixed by a cut wire.")
	door.wires.cut(WIRE_SHOCK, ipc)

/// Supported machines execute actual native state changes with ID-slot checks and successful-action heat.
/datum/unit_test/ipc_cyberlink_machine_commands/Run()
	var/mob/living/carbon/human/ipc = allocate_cyberlink_operator()
	var/datum/ipc_os/os = ipc.get_ipc_os()
	var/datum/ipc_os_program/cyberlink/program = os.programs["cyberlink"]
	var/obj/machinery/power/apc/apc = allocate(/obj/machinery/power/apc)
	apc.machine_stat = NONE
	apc.req_access = list(ACCESS_ENGINE_EQUIP)
	var/obj/item/card/id/advanced/card = allocate(/obj/item/card/id/advanced)
	card.set_access(list(ACCESS_ENGINE_EQUIP, ACCESS_ATMOS_EQUIP), FORCE_ADD_ALL)
	ipc.put_in_hands(card)
	var/original_cover = apc.coverlocked
	var/temperature = ipc.coretemperature
	TEST_ASSERT(!program.execute_machine(ipc, apc, "cover"), "Held engineering ID authorized a remote APC command.")
	TEST_ASSERT_EQUAL(apc.coverlocked, original_cover, "Unauthorized command changed the APC.")
	ipc.dropItemToGround(card)
	var/obj/item/clothing/under/color/grey/uniform = allocate(/obj/item/clothing/under/color/grey)
	TEST_ASSERT(ipc.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING), "Could not equip ID fixture uniform.")
	TEST_ASSERT(ipc.equip_to_slot_if_possible(card, ITEM_SLOT_ID), "Could not equip ID in its actual slot.")
	TEST_ASSERT(program.execute_machine(ipc, apc, "cover"), "Authorized remote APC command failed.")
	TEST_ASSERT(apc.coverlocked != original_cover, "Remote APC command did not change its real cover lock.")
	TEST_ASSERT_EQUAL(ipc.coretemperature, temperature + 25, "Successful command did not heat the physical chassis by twenty-five degrees.")
	TEST_ASSERT(program.execute_machine(ipc, apc, "cover"), "Consecutive command was still blocked by a cooldown.")
	TEST_ASSERT_EQUAL(apc.coverlocked, original_cover, "Immediate second command did not restore the cover.")
	TEST_ASSERT(program.execute_machine(ipc, apc, "cover"), "Third immediate command was blocked.")
	program.command_ready_at = world.time
	program.remote_enabled = FALSE
	TEST_ASSERT(!program.execute_machine(ipc, apc, "cover"), "Disabled remote control still sent ordinary ID commands.")
	var/datum/ipc_cyberlink_access/access = allocate(/datum/ipc_cyberlink_access, apc)
	program.accesses += access
	TEST_ASSERT_EQUAL(access.expires_at, world.time + 50 SECONDS, "Generic machinery access did not use fifty seconds.")
	TEST_ASSERT(program.execute_machine(ipc, apc, "cover"), "Disabling ordinary commands also disabled a separate advanced capability.")
	TEST_ASSERT_EQUAL(apc.coverlocked, original_cover, "Second APC command failed to restore its real lock state.")
	program.disconnect_link()
	program.remote_enabled = TRUE
	program.command_ready_at = world.time
	var/obj/machinery/airalarm/alarm = allocate(/obj/machinery/airalarm)
	alarm.machine_stat = NONE
	TEST_ASSERT(!program.machine_operational(alarm), "An unfinished air-alarm frame accepted electronic commands.")
	alarm.buildstage = AIR_ALARM_BUILD_COMPLETE
	alarm.set_panel_open(FALSE)
	var/datum/air_alarm_mode/original_mode = alarm.selected_mode
	var/mode_path = original_mode.type == /datum/air_alarm_mode/filtering ? /datum/air_alarm_mode/off : /datum/air_alarm_mode/filtering
	var/changed = program.execute_machine(ipc, alarm, "mode:[mode_path]")
	var/actual_mode = alarm.selected_mode.type
	alarm.select_mode(ipc, original_mode.type)
	TEST_ASSERT(changed && actual_mode == mode_path, "Atmospheric command did not run the native mode handler.")
	program.command_ready_at = world.time
	temperature = ipc.coretemperature
	TEST_ASSERT(!program.execute_machine(ipc, alarm, "mode:[original_mode.type]"), "An unchanged alarm mode counted as a significant command.")
	TEST_ASSERT_EQUAL(ipc.coretemperature, temperature, "Rejected/no-op action caused heat.")
