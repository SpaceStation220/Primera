/// Shared setup uses the same preference and real job-spawn event as a roundstart IPC.
/datum/unit_test/proc/allocate_ipc_specialist(job_type)
	var/mob/living/carbon/human/ipc = allocate(/mob/living/carbon/human/consistent)
	ipc.set_species(/datum/species/ipc)
	ipc.mock_client = allocate(/datum/client_interface)
	// The default unit-test dummy makes do_after instantaneous, even when IGNORE_SLOWDOWNS is set.
	// These fixtures exercise real ten/fifteen-second channels and their cancellation boundary.
	ipc.add_or_update_variable_actionspeed_modifier(/datum/actionspeed_modifier/base, multiplicative_slowdown = 1)
	var/datum/preference/choiced/ipc/generation/generation = GLOB.preference_entries[/datum/preference/choiced/ipc/generation]
	generation.apply_to_human(ipc, "I", null)
	var/datum/job/job = SSjob.get_job_type(job_type)
	SEND_GLOBAL_SIGNAL(COMSIG_GLOB_JOB_AFTER_SPAWN, job, ipc, null)
	return ipc

/// Factory HUDs retain other trait sources, remain zero-size and cannot be removed server-side.
/datum/unit_test/ipc_factory_hud_lifecycle/Run()
	var/mob/living/carbon/human/ipc = allocate_ipc_specialist(/datum/job/doctor)
	var/datum/ipc_os/os = ipc.get_ipc_os()
	var/datum/ipc_os_program/program = os.programs["factory_medhud"]
	TEST_ASSERT(program.available() && program.installed, "Medic did not receive its factory HUD.")
	TEST_ASSERT(!os.programs["factory_sechud"].available(), "Medic received another department's HUD.")
	ADD_TRAIT(ipc, TRAIT_MEDICAL_HUD, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(program.start(), "Factory HUD did not start.")
	TEST_ASSERT(HAS_TRAIT_FROM(ipc, TRAIT_REAGENT_SCANNER, REF(program)), "ChemiMed did not provide reagent scanning.")
	TEST_ASSERT(HAS_TRAIT_FROM(ipc, TRAIT_MEDICAL_HUD, REF(program)), "HUD did not own its trait source.")
	TEST_ASSERT(!os.uninstall(program.id), "Server accepted deletion of a factory program.")
	TEST_ASSERT(!os.begin_download(program.id), "Factory program was downloadable.")
	TEST_ASSERT_EQUAL(os.used_storage(), 0, "Factory programs consumed storage.")
	program.stop()
	TEST_ASSERT(HAS_TRAIT(ipc, TRAIT_MEDICAL_HUD), "Disabling factory HUD removed an external HUD source.")
	TEST_ASSERT(!HAS_TRAIT_FROM(ipc, TRAIT_REAGENT_SCANNER, REF(program)), "Stopping ChemiMed leaked reagent scanning.")
	TEST_ASSERT(!HAS_TRAIT_FROM(ipc, TRAIT_MEDICAL_HUD, REF(program)), "Stopped HUD retained its own effect.")
	TEST_ASSERT(program.start(), "Factory HUD could not restart.")
	os.core.Remove(ipc, special = TRUE)
	TEST_ASSERT(!HAS_TRAIT_FROM(ipc, TRAIT_REAGENT_SCANNER, REF(program)), "Stopping ChemiMed leaked reagent scanning.")
	TEST_ASSERT(!HAS_TRAIT_FROM(ipc, TRAIT_MEDICAL_HUD, REF(program)), "Extraction leaked a HUD onto the former body.")

/datum/unit_test/ipc_factory_calibration/Run()
	var/mob/living/carbon/human/scientist = allocate_ipc_specialist(/datum/job/scientist)
	GLOB.mob_living_list -= scientist
	scientist.set_nutrition(400, forced = TRUE)
	var/datum/ipc_os_program/factory/calibration/program = scientist.get_ipc_os().programs["factory_calibration"]
	if(!program.running)
		program.start()
	TEST_ASSERT(program.running, "The science specialization did not receive its calibration program.")
	TEST_ASSERT(program.command(list("operation" = "cable")), "The calibration control did not extend a cable.")
	var/obj/machinery/autolathe/lathe = allocate(/obj/machinery/autolathe, get_step(scientist, EAST))
	lathe.update_use_power(NO_POWER_USE)
	lathe.set_machine_stat(NONE)
	TEST_ASSERT_EQUAL(program.cable.interact_with_atom(lathe, scientist, list()), ITEM_INTERACT_SUCCESS, "The actual connector interaction did not start a calibration.")
	TEST_ASSERT_EQUAL(scientist.nutrition, 400, "The cable charged the battery before finishing.")
	var/end_by = world.time + 12 SECONDS
	UNTIL(!program.calibrating || world.time >= end_by)
	TEST_ASSERT_EQUAL(lathe.ipc_calibration_mode, "economy", "Completing the cable channel did not activate economy mode.")
	TEST_ASSERT_EQUAL(scientist.nutrition, 400 - scientist.ipc_charge_capacity() * 0.10, "Calibration did not charge ten percent exactly once.")
	TEST_ASSERT(lathe.ipc_calibration_until >= world.time + 19 MINUTES, "Calibration duration was shorter than twenty minutes.")
	var/datum/design/design = allocate(/datum/design)
	design.build_path = /obj/item/screwdriver
	TEST_ASSERT_EQUAL(lathe.ipc_calibrated_cost(design, 1), 0.85, "Economy mode did not save fifteen percent of materials.")
	design.build_path = /obj/item/stack/sheet/iron
	TEST_ASSERT_EQUAL(lathe.ipc_calibrated_cost(design, 1), 1, "Economy mode discounted stack costs.")
	for(var/machine_type in list(/obj/machinery/rnd/production/techfab, /obj/machinery/rnd/production/circuit_imprinter, /obj/machinery/mecha_part_fabricator))
		var/obj/machinery/machine = allocate(machine_type)
		machine.set_machine_stat(NONE)
		TEST_ASSERT(machine.ipc_apply_calibration("fast"), "A supported production machine rejected fast calibration: [machine_type].")
		TEST_ASSERT_EQUAL(machine.ipc_calibrated_time(10 SECONDS), 8 SECONDS, "Speed was not divided by 1.25.")
		machine.ipc_calibration_until = world.time
		TEST_ASSERT_EQUAL(machine.ipc_calibrated_time(10 SECONDS), 10 SECONDS, "An expired calibration still sped up production.")

/datum/unit_test/ipc_factory_guardian_jaws/Run()
	var/mob/living/carbon/human/medic = allocate_ipc_specialist(/datum/job/doctor)
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent, get_step(medic, EAST))
	GLOB.mob_living_list -= medic
	GLOB.mob_living_list -= patient
	medic.set_nutrition(400, forced = TRUE)
	var/datum/ipc_os_program/factory/jaws/jaws = medic.get_ipc_os().programs["factory_jaws"]
	TEST_ASSERT(jaws.start(), "The medic could not equip its factory jaws.")
	TEST_ASSERT(jaws.hands_ready(medic), "The program did not occupy both hands.")
	TEST_ASSERT(!medic.dropItemToGround(jaws.left_jaw), "The medic could drop a deployed jaw.")
	patient.take_overall_damage(brute = 20)
	patient.adjust_oxy_loss(95)
	TEST_ASSERT(patient.stat >= SOFT_CRIT && patient.stat < DEAD, "The procedure fixture did not enter critical condition.")
	var/initial_brute = patient.get_brute_loss()
	TEST_ASSERT_EQUAL(jaws.left_jaw.interact_with_atom(patient, medic, list()), ITEM_INTERACT_SUCCESS, "The medical claw click did not start a procedure.")
	TEST_ASSERT_EQUAL(medic.grab_state, GRAB_AGGRESSIVE, "The jaws did not use native aggressive restraint.")
	TEST_ASSERT_EQUAL(patient.get_brute_loss(), initial_brute, "The opening strike applied damage.")
	TEST_ASSERT(HAS_TRAIT(patient, TRAIT_NOCRITDAMAGE) && HAS_TRAIT(patient, TRAIT_IPC_JAWS_HEARTBEAT), "Stabilization did not prevent passive critical deterioration and replace the heartbeat.")
	patient.execute_resist()
	TEST_ASSERT_NULL(jaws.patient, "The patient could not escape the clamp immediately.")
	TEST_ASSERT(!HAS_TRAIT(patient, TRAIT_NOCRITDAMAGE) && !HAS_TRAIT(patient, TRAIT_IPC_JAWS_HEARTBEAT), "An interrupted clamp leaked treatment effects.")
	TEST_ASSERT_EQUAL(medic.nutrition, 400, "The interrupted procedure charged the medic.")
	TEST_ASSERT(jaws.try_treat(medic, patient, jaws.right_jaw), "The medic could not restart stabilization.")
	var/end_by = world.time + 14 SECONDS
	UNTIL(patient.get_brute_loss() <= initial_brute - 12 || world.time >= end_by)
	TEST_ASSERT_EQUAL(jaws.patient, patient, "Stabilization released its grip after leaving critical condition.")
	TEST_ASSERT(patient.stat < SOFT_CRIT, "Stabilization did not repeat until the patient recovered.")
	TEST_ASSERT_EQUAL(patient.get_brute_loss(), initial_brute - 12, "Two stabilization cycles did not heal twelve brute.")
	TEST_ASSERT_EQUAL(patient.get_oxy_loss(), 83, "Two stabilization cycles did not heal twelve oxygen damage.")
	TEST_ASSERT(abs(medic.nutrition - (400 - medic.ipc_charge_capacity() * 0.08)) < 0.001, "Two stabilization cycles did not cost eight percent.")
	TEST_ASSERT(patient.resist_grab(TRUE), "The patient could not end treatment by trying to move.")
	TEST_ASSERT_NULL(jaws.patient, "The patient's movement attempt left the claws attached.")
	patient.adjust_oxy_loss(-20)
	patient.take_overall_damage(brute = 10)
	var/restore_brute = patient.get_brute_loss()
	TEST_ASSERT(jaws.command(list("operation" = "restore")), "The medic could not select restoration.")
	TEST_ASSERT(jaws.try_treat(medic, patient, jaws.left_jaw), "The medic could not start restoration outside critical condition.")
	end_by = world.time + 18 SECONDS
	UNTIL(patient.get_brute_loss() <= restore_brute - 14 || world.time >= end_by)
	TEST_ASSERT_EQUAL(patient.get_brute_loss(), restore_brute - 14, "Restoration did not repeat for a second cycle.")
	TEST_ASSERT(abs(medic.nutrition - (400 - medic.ipc_charge_capacity() * 0.24)) < 0.001, "Two restoration cycles did not each cost eight percent.")
	medic.forceMove(get_step(medic, WEST))
	end_by = world.time + 2 SECONDS
	UNTIL(!jaws.patient || world.time >= end_by)
	TEST_ASSERT_NULL(jaws.patient, "Moving the medic did not interrupt cyclical treatment.")
	var/obj/item/bodypart/arm = medic.get_bodypart(BODY_ZONE_L_ARM)
	allocated += arm
	arm.drop_limb(special = TRUE)
	TEST_ASSERT(!jaws.running && !jaws.left_jaw && !jaws.right_jaw, "Losing a hand left the jaws deployed.")

/// Ordinary surgery availability and forced failures remain outside the medic's chance bonus.
/datum/unit_test/ipc_generation_medical_and_timing/Run()
	var/mob/living/carbon/human/medic = allocate_ipc_specialist(/datum/job/doctor)
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/scalpel/tool = allocate(/obj/item/scalpel)
	var/datum/surgery_operation/limb/mechanical_incision/operation = GLOB.operations.operations_by_typepath[__IMPLIED_TYPE__]
	var/list/operation_args = list(OPERATION_SPEED = 1)
	var/obj/item/organ/brain/ipc/core = medic.get_organ_slot(ORGAN_SLOT_BRAIN)
	core.ipc_generation = "II"
	var/baseline = operation.get_modified_failure_chance(operation.time, patient, medic, tool, operation_args)
	core.ipc_generation = "I"
	TEST_ASSERT_EQUAL(operation.get_modified_failure_chance(operation.time, patient, medic, tool, operation_args), max(0, clamp(baseline, 0, 99) - 15), "Medical success did not increase by fifteen percentage points.")
	operation_args[OPERATION_SPEED] = 10
	core.ipc_generation = "II"
	var/poor_conditions = operation.get_modified_failure_chance(operation.time, patient, medic, tool, operation_args)
	core.ipc_generation = "I"
	TEST_ASSERT_EQUAL(operation.get_modified_failure_chance(operation.time, patient, medic, tool, operation_args), max(0, clamp(poor_conditions, 0, 99) - 15), "Medical bonus was lost to the native failure-chance cap.")
	TEST_ASSERT_EQUAL(ipc_work_multiplier(medic, patient, "medical", "surgery"), 1 / 1.2, "Medical surgical duration was not divided by 1.2.")
	TEST_ASSERT_EQUAL(ipc_work_multiplier(medic, patient, "medical", null), 1, "Routine medical work received a nonprofessional penalty.")
	TEST_ASSERT_EQUAL(ipc_work_multiplier(medic, patient, "engineering", null), 1.25, "Off-department work was not twenty-five percent longer.")
	var/mob/living/carbon/human/engineer = allocate_ipc_specialist(/datum/job/station_engineer)
	TEST_ASSERT_EQUAL(ipc_work_multiplier(engineer, null, "engineering", "construction"), 1 / 1.15, "Construction did not use its single dedicated bonus.")
	TEST_ASSERT_EQUAL(ipc_work_multiplier(engineer, null, "engineering", "engineering_tools"), 1 / 1.2, "Engineering tool speed was not applied.")
	var/mob/living/carbon/human/miner = allocate_ipc_specialist(/datum/job/shaft_miner)
	TEST_ASSERT_EQUAL(ipc_work_multiplier(miner, null, list("cargo", "service"), null), 1, "Cargo butchering received an off-department penalty.")

/// Whole dishes retain individual processing time, capacity is bounded, and drinks cannot charge it.
/datum/unit_test/ipc_zeng_individual_food_cycles/Run()
	var/mob/living/carbon/human/ipc = allocate_ipc_specialist(/datum/job/assistant)
	// Branding occurs before job capture in real character creation; configure this fixture's physical torso.
	var/obj/item/bodypart/chest/robot/ipc/torso = ipc.get_bodypart(BODY_ZONE_CHEST)
	torso.ipc_manufacturer = /datum/ipc_manufacturer/zeng::name
	ipc.set_nutrition(100, forced = TRUE)
	var/obj/item/food/burger/plain/first = allocate(/obj/item/food/burger/plain)
	ipc.put_in_hands(first)
	TEST_ASSERT(torso.load_ipc_food(ipc, first), "First dish was not loaded.")
	torso.process_ipc_food(ipc, 30)
	var/obj/item/food/burger/plain/second = allocate(/obj/item/food/burger/plain)
	ipc.put_in_hands(second)
	TEST_ASSERT(torso.load_ipc_food(ipc, second), "Second dish was not loaded.")
	torso.process_ipc_food(ipc, 30)
	TEST_ASSERT(QDELETED(first) && !QDELETED(second), "Dishes did not receive individual minute cycles.")
	TEST_ASSERT_EQUAL(ipc.nutrition, 105.5, "First dish did not provide one percent of a normal battery.")
	TEST_ASSERT_EQUAL(length(torso.ipc_food_queue), 1, "Completed dish did not free a slot.")
	torso.process_ipc_food(ipc, 30)
	TEST_ASSERT(QDELETED(second), "Second dish did not finish its own minute.")
	TEST_ASSERT_EQUAL(ipc.nutrition, 111, "Second dish produced incorrect charge.")
	for(var/index in 1 to 5)
		var/obj/item/food/burger/plain/dish = allocate(/obj/item/food/burger/plain)
		ipc.put_in_hands(dish)
		TEST_ASSERT(torso.load_ipc_food(ipc, dish), "A valid queue slot was refused.")
	var/obj/item/food/burger/plain/sixth = allocate(/obj/item/food/burger/plain)
	ipc.put_in_hands(sixth)
	torso.load_ipc_food(ipc, sixth)
	TEST_ASSERT(ipc.is_holding(sixth) && length(torso.ipc_food_queue) == 5, "Sixth dish bypassed capacity or was lost.")
	ipc.dropItemToGround(sixth)
	var/obj/item/reagent_containers/cup/glass/coffee/drink = allocate(/obj/item/reagent_containers/cup/glass/coffee)
	ipc.put_in_hands(drink)
	TEST_ASSERT(!torso.load_ipc_food(ipc, drink), "A drink was accepted as food.")
	ipc.death()
	torso.process_ipc_food(ipc, 60)
	TEST_ASSERT_EQUAL(length(torso.ipc_food_queue), 5, "Death destroyed queued dishes.")

/// Disabling a shield removes the effect, resets its timer, and leaves no transferable item.
/datum/unit_test/ipc_factory_shield_lifecycle/Run()
	var/mob/living/carbon/human/ipc = allocate_ipc_specialist(/datum/job/security_officer)
	var/datum/ipc_os/os = ipc.get_ipc_os()
	var/datum/ipc_os_program/factory/shield/shield = os.programs["factory_shield"]
	ipc.set_nutrition(NUTRITION_LEVEL_FULL, forced = TRUE)
	TEST_ASSERT(shield.start(), "Security shield did not activate.")
	TEST_ASSERT_EQUAL(ipc.get_active_held_item(), shield.emitter, "Shield was not placed in the active hand.")
	shield.tick(10)
	TEST_ASSERT_EQUAL(ipc.nutrition, 550, "Shield charged before its twenty-second interval.")
	shield.tick(10)
	TEST_ASSERT_EQUAL(ipc.nutrition, 539, "Shield did not debit two percent at twenty seconds.")
	shield.stop()
	TEST_ASSERT_NULL(shield.emitter, "Stopped shield retained a block adapter.")
	TEST_ASSERT_EQUAL(shield.elapsed, 0, "Stopped shield retained elapsed drain.")
	TEST_ASSERT(shield.start(), "Shield could not restart.")
	os.core.Remove(ipc, special = TRUE)
	TEST_ASSERT(!shield.running && !shield.emitter, "Brain extraction left an active shield.")
	TEST_ASSERT(!(locate(/obj/item/shield/ipc_integrated) in get_turf(ipc)), "An integrated shield dropped as loot.")

/// Cancelling a real asynchronous brewing transaction returns the original vessel without energy loss.
/datum/unit_test/ipc_factory_brewing_cancel/Run()
	var/mob/living/carbon/human/ipc = allocate_ipc_specialist(/datum/job/bartender)
	var/datum/ipc_os/os = ipc.get_ipc_os()
	var/datum/ipc_os_program/factory/drinks/program = os.programs["factory_drinks"]
	TEST_ASSERT(program.start(), "Drink program did not start.")
	var/obj/item/reagent_containers/cup/glass/drinkingglass/cup = allocate(/obj/item/reagent_containers/cup/glass/drinkingglass)
	ipc.put_in_hands(cup)
	TEST_ASSERT(program.command(list()), "Empty vessel did not start brewing.")
	var/deadline = world.time + 2 SECONDS
	while(!program.audio && program.vessel && world.time < deadline)
		sleep(1)
	TEST_ASSERT_NOTNULL(program.audio, "Real brewing never started its audio/animation cycle.")
	var/before_cancel = ipc.nutrition
	program.stop()
	TEST_ASSERT(!QDELETED(cup) && ipc.is_holding(cup), "Stopping brewing lost its original cup.")
	TEST_ASSERT_NULL(program.audio, "Stopping brewing left its sound loop active.")
	TEST_ASSERT_NULL(program.vessel, "Stopping brewing retained its reservation.")
	TEST_ASSERT_EQUAL(ipc.nutrition, before_cancel, "Cancelled brewing charged energy.")
	sleep(2)
	TEST_ASSERT(!QDELETED(cup), "The cancelled asynchronous completion destroyed the returned cup.")
	TEST_ASSERT(!(locate(/obj/item/reagent_containers/cup/glass/coffee) in get_turf(ipc)), "Cancelled brewing produced a free drink.")

/// Each completed cycle replaces exactly one empty vessel with the genuine filled game item.
/datum/unit_test/ipc_factory_brewing_products/Run()
	var/mob/living/carbon/human/ipc = allocate_ipc_specialist(/datum/job/bartender)
	var/datum/ipc_os/os = ipc.get_ipc_os()
	var/datum/ipc_os_program/factory/drinks/program = os.programs["factory_drinks"]
	TEST_ASSERT(program.start(), "Drink program did not start.")
	var/list/products = list("cola" = /obj/item/reagent_containers/cup/soda_cans/cola, "beer" = /obj/item/reagent_containers/cup/glass/bottle/beer, "coffee" = /obj/item/reagent_containers/cup/glass/coffee)
	for(var/drink in products)
		var/obj/item/reagent_containers/cup/glass/drinkingglass/cup = allocate(/obj/item/reagent_containers/cup/glass/drinkingglass)
		ipc.put_in_hands(cup)
		TEST_ASSERT(program.command(list("drink" = drink)), "Valid drink selection failed.")
		var/charge_before = ipc.nutrition
		var/start = world.time
		TEST_ASSERT(program.command(list()), "Valid preparation failed.")
		var/deadline = world.time + 15 SECONDS
		while(program.vessel && world.time < deadline)
			sleep(1)
		TEST_ASSERT_NULL(program.vessel, "Preparation did not finish.")
		TEST_ASSERT(world.time >= start + 10 SECONDS, "A drink finished before its honest ten-second action.")
		TEST_ASSERT(QDELETED(cup), "Preparation duplicated the original vessel.")
		var/obj/item/reagent_containers/cup/product = locate(products[drink]) in ipc.get_held_items()
		TEST_ASSERT_NOTNULL(product, "Preparation did not deliver the genuine requested item.")
		TEST_ASSERT_EQUAL(product.reagents.total_volume, 30, "Preparation did not use the genuine filled product contents.")
		TEST_ASSERT_EQUAL(ipc.nutrition, charge_before - 27.5, "Preparation did not debit exactly five percent on success.")
		ipc.dropItemToGround(product)
		allocated += product

/// Native cable repairs preserve fractional material costs rather than rounding the penalty away.
/datum/unit_test/ipc_brand_repair_materials/Run()
	var/mob/living/carbon/human/ipc = allocate(/mob/living/carbon/human/consistent)
	ipc.set_species(/datum/species/ipc)
	var/obj/item/bodypart/chest/robot/ipc/torso = ipc.get_bodypart(BODY_ZONE_CHEST)
	torso.ipc_manufacturer = /datum/ipc_manufacturer/hephaestus::name
	var/mob/living/carbon/human/repairer = allocate(/mob/living/carbon/human/consistent)
	repairer.zone_selected = BODY_ZONE_L_ARM
	var/obj/item/stack/cable_coil/wires = allocate(/obj/item/stack/cable_coil, null, 30)
	repairer.put_in_hands(wires)
	var/obj/item/bodypart/arm = ipc.get_bodypart(BODY_ZONE_L_ARM)
	for(var/index in 1 to 10)
		arm.receive_damage(burn = 15, wound_bonus = CANT_WOUND)
		TEST_ASSERT_EQUAL(wires.try_heal_loop(ipc, repairer), ITEM_INTERACT_SUCCESS, "Native repair failed.")
	TEST_ASSERT(abs(wires.get_amount() - 19.5) < 0.001, "Ten repairs did not spend 10.5 real cable units.")
	TEST_ASSERT_EQUAL(arm.burn_dam, 0, "Native repairs did not heal the actual damage.")

/// Two real channels on copied items share one station-state commit, without touching global node costs.
/datum/unit_test/ipc_reverse_engineering_shared_discount
	var/list/previous_links
	var/links_changed = FALSE

/datum/unit_test/ipc_reverse_engineering_shared_discount/Destroy()
	if(links_changed)
		if(isnull(previous_links))
			SSresearch.techweb_unlock_items -= /obj/item/flashlight
		else
			SSresearch.techweb_unlock_items[/obj/item/flashlight] = previous_links
	previous_links = null
	return ..()

/datum/unit_test/ipc_reverse_engineering_shared_discount/Run()
	var/list/nodes = list()
	for(var/node_type in SSresearch.techweb_nodes)
		var/datum/techweb_node/node = SSresearch.techweb_nodes[node_type]
		if(!(node.node_flags & TECHWEB_NODE_STARTER) && !length(node.required_experiments) && values_sum(node.research_costs) > 0)
			nodes += node_type
		if(length(nodes) == 2)
			break
	TEST_ASSERT_EQUAL(length(nodes), 2, "No suitable native research nodes for the fixture.")
	var/datum/techweb/web = allocate(/datum/techweb)
	for(var/node_type in nodes)
		web.available_nodes[node_type] = TRUE
		web.hidden_nodes -= node_type
	previous_links = SSresearch.techweb_unlock_items[/obj/item/flashlight]
	links_changed = TRUE
	SSresearch.techweb_unlock_items[/obj/item/flashlight] = nodes.Copy()
	var/mob/living/carbon/human/first_ipc = allocate_ipc_specialist(/datum/job/scientist)
	var/mob/living/carbon/human/second_ipc = allocate_ipc_specialist(/datum/job/scientist)
	first_ipc.set_nutrition(550, forced = TRUE)
	second_ipc.set_nutrition(550, forced = TRUE)
	var/datum/ipc_os/first_os = first_ipc.get_ipc_os()
	var/datum/ipc_os/second_os = second_ipc.get_ipc_os()
	var/datum/ipc_os_program/factory/reverse_engineering/first = first_os.programs["factory_reverse_engineering"]
	var/datum/ipc_os_program/factory/reverse_engineering/second = second_os.programs["factory_reverse_engineering"]
	TEST_ASSERT(first.start() && second.start(), "Scientists could not enable reverse engineering.")
	var/obj/item/flashlight/target = allocate(/obj/item/flashlight)
	var/obj/item/flashlight/copy = allocate(/obj/item/flashlight)
	var/start = world.time
	INVOKE_ASYNC(first, TYPE_PROC_REF(/datum/ipc_os_program/factory/reverse_engineering, scan), target, web, first.activation_id)
	second.scan(copy, web, second.activation_id)
	TEST_ASSERT(world.time >= start + 15 SECONDS, "Research scan finished before its fifteen-second channel.")
	TEST_ASSERT(web.ipc_scanned_types[/obj/item/flashlight], "Successful type was not remembered by the shared research state.")
	TEST_ASSERT_EQUAL(first_ipc.nutrition + second_ipc.nutrition, 1072.5, "Concurrent scans charged both participants or failed to debit the winning scan.")
	for(var/node_type in nodes)
		var/datum/techweb_node/node = SSresearch.techweb_nodes[node_type]
		TEST_ASSERT(web.ipc_reverse_discounts[node_type], "Automatic scan failed to discount every eligible related node.")
		var/list/price = node.get_price(web)
		for(var/point_type in node.research_costs)
			TEST_ASSERT_EQUAL(price[point_type], node.research_costs[point_type] * 0.9, "Research price did not receive exactly one ten-percent discount.")
		TEST_ASSERT(!web.researched_nodes[node_type], "Scan automatically researched a technology.")
	TEST_ASSERT(!second.valid_scan(copy, web, second.activation_id), "A copied item bypassed the station-wide type cap.")
	TEST_ASSERT_EQUAL(first_os.capacity(), 24, "Science incorrectly granted extra software memory.")

/// Neither equipping nor removing gloves may duplicate or delete the built-in tackle component.
/datum/unit_test/ipc_factory_tackle_ownership/Run()
	var/mob/living/carbon/human/ipc = allocate_ipc_specialist(/datum/job/security_officer)
	var/datum/ipc_os/os = ipc.get_ipc_os()
	var/datum/ipc_os_program/factory/tackle/program = os.programs["factory_tackle"]
	TEST_ASSERT(program.start(), "Built-in tackle did not activate.")
	TEST_ASSERT(HAS_TRAIT_FROM(ipc, TRAIT_FAST_CUFFING, REF(program)), "Tackle did not grant the cuffing trait.")
	var/datum/component/tackler/original = ipc.GetComponent(/datum/component/tackler)
	var/obj/item/clothing/gloves/tackler/gloves = allocate(/obj/item/clothing/gloves/tackler)
	TEST_ASSERT(ipc.equip_to_slot_if_possible(gloves, ITEM_SLOT_GLOVES), "Retrieval gloves could not be equipped.")
	TEST_ASSERT_EQUAL(ipc.GetComponent(/datum/component/tackler), original, "Gloves created a second tackle component.")
	ipc.dropItemToGround(gloves)
	TEST_ASSERT_EQUAL(ipc.GetComponent(/datum/component/tackler), original, "Removing gloves deleted the built-in tackle.")
	program.stop()
	TEST_ASSERT_NULL(ipc.GetComponent(/datum/component/tackler), "Stopping the program leaked its component.")
	TEST_ASSERT(ipc.equip_to_slot_if_possible(gloves, ITEM_SLOT_GLOVES), "Retrieval gloves could not be re-equipped.")
	var/datum/component/tackler/native = ipc.GetComponent(/datum/component/tackler)
	TEST_ASSERT_NOTNULL(native, "Native gloves no longer provide tackling.")
	TEST_ASSERT(program.start(), "Built-in tackle could not share the native component.")
	program.stop()
	TEST_ASSERT_EQUAL(ipc.GetComponent(/datum/component/tackler), native, "Stopping the program removed a still-worn glove's component.")
	ipc.dropItemToGround(gloves)
	TEST_ASSERT_NULL(ipc.GetComponent(/datum/component/tackler), "Gloves retained a component after their last owner released it.")

/// Only one real crate is moved; extracting the core returns the same crate and contents.
/datum/unit_test/ipc_factory_cargo_transaction/Run()
	var/mob/living/carbon/human/ipc = allocate_ipc_specialist(/datum/job/cargo_technician)
	var/datum/ipc_os/os = ipc.get_ipc_os()
	var/datum/ipc_os_program/factory/cargo/program = os.programs["factory_cargo"]
	TEST_ASSERT(program.start(), "Cargo hold did not activate.")
	var/obj/structure/closet/crate/first = allocate(/obj/structure/closet/crate)
	var/obj/structure/closet/crate/second = allocate(/obj/structure/closet/crate)
	var/obj/item/wrench/content = allocate(/obj/item/wrench)
	content.forceMove(first)
	SEND_SIGNAL(ipc, COMSIG_LIVING_UNARMED_ATTACK, first, TRUE, list())
	SEND_SIGNAL(ipc, COMSIG_LIVING_UNARMED_ATTACK, second, TRUE, list())
	var/deadline = world.time + 6 SECONDS
	while(program.loading && world.time < deadline)
		sleep(1)
	TEST_ASSERT_EQUAL(program.stored_crate, first, "Concurrent loading replaced or lost the first crate.")
	TEST_ASSERT(isturf(second.loc), "A second crate was loaded.")
	os.core.Remove(ipc, special = TRUE)
	TEST_ASSERT_NULL(program.stored_crate, "Core extraction retained a stored crate reference.")
	TEST_ASSERT_EQUAL(first.loc, get_turf(ipc), "Core extraction did not return the physical crate.")
	TEST_ASSERT_EQUAL(content.loc, first, "Cargo unloading lost or duplicated its contents.")

/// Torso modifiers affect actual damage, heat input and movement, and vanish with that torso.
/datum/unit_test/ipc_brand_physical_handlers/Run()
	var/mob/living/carbon/human/ipc = allocate(/mob/living/carbon/human/consistent)
	ipc.set_species(/datum/species/ipc)
	var/obj/item/bodypart/chest/robot/ipc/torso = ipc.get_bodypart(BODY_ZONE_CHEST)
	var/obj/item/bodypart/arm = ipc.get_bodypart(BODY_ZONE_L_ARM)
	var/obj/item/bodypart/leg = ipc.get_bodypart(BODY_ZONE_L_LEG)
	torso.ipc_manufacturer = /datum/ipc_manufacturer/hephaestus::name
	arm.receive_damage(brute = 10, wound_bonus = CANT_WOUND)
	TEST_ASSERT(abs(arm.brute_dam - 9.6) < 0.00001, "Small physical protection disappeared through damage rounding.")
	arm.heal_damage(brute = 100, burn = 100)
	torso.ipc_manufacturer = /datum/ipc_manufacturer/shellguard::name
	arm.receive_damage(burn = 10, wound_bonus = CANT_WOUND)
	TEST_ASSERT(abs(arm.burn_dam - 9.6) < 0.00001, "Small burn protection disappeared through damage rounding.")
	torso.ipc_manufacturer = /datum/ipc_manufacturer/cybersun::name
	arm.receive_damage(brute = 10, wound_bonus = CANT_WOUND)
	leg.receive_damage(brute = 10, wound_bonus = CANT_WOUND)
	TEST_ASSERT_EQUAL(arm.brute_dam, 10, "Leg vulnerability leaked onto an arm.")
	TEST_ASSERT(abs(leg.brute_dam - 10.3) < 0.00001, "Cybersun leg vulnerability did not affect the struck leg.")
	torso.ipc_manufacturer = /datum/ipc_manufacturer/xion::name
	ipc.set_coretemperature(300)
	ipc.adjust_coretemperature(10)
	TEST_ASSERT_EQUAL(ipc.coretemperature, 309, "Xion did not reduce incoming heat.")
	ipc.adjust_coretemperature(-5)
	TEST_ASSERT_EQUAL(ipc.coretemperature, 304, "Xion changed the cooling rate.")
	torso.ipc_manufacturer = /datum/ipc_manufacturer/con::name
	ipc.update_movespeed()
	var/base_delay = ipc.cached_multiplicative_slowdown
	torso.ipc_manufacturer = /datum/ipc_manufacturer/cybersun::name
	ipc.update_movespeed()
	TEST_ASSERT(abs(ipc.cached_multiplicative_slowdown * 1.05 - base_delay) < 0.00001, "Cybersun did not increase real movement speed by five percent.")
	var/obj/item/bodypart/chest/robot/ipc/neutral = allocate(/obj/item/bodypart/chest/robot/ipc)
	allocated += torso
	TEST_ASSERT(neutral.replace_limb(ipc), "Neutral torso replacement failed.")
	TEST_ASSERT_EQUAL(ipc.cached_multiplicative_slowdown, base_delay, "Movement bonus leaked after replacing the torso.")
