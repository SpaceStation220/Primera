// AI EDIT START - Adapt the Lazarus event to the native Primera APIs and regression harness
#ifdef UNIT_TESTS

/** Every escape size must preserve both minds and release the previous host. */
/datum/unit_test/lazarus_flesh_burst_stages/Run()
	var/list/body_types = list(
		/mob/living/basic/flesh_biomorph/lesser/small,
		/mob/living/basic/flesh_biomorph/lesser/small,
		/mob/living/basic/flesh_biomorph/lesser/medium,
		/mob/living/basic/flesh_biomorph/lesser/large,
		/mob/living/basic/flesh_biomorph/lesser/large,
	)
	for(var/stage in 0 to LAZARUS_FLESH_FINAL_STAGE)
		var/mob/living/carbon/human/consistent/host = allocate(/mob/living/carbon/human/consistent)
		var/mob/living/treacherous_flesh/parasite = allocate(/mob/living/treacherous_flesh)
		host.mind_initialize()
		parasite.mind_initialize()
		var/datum/mind/host_mind = host.mind
		var/datum/mind/parasite_mind = parasite.mind
		parasite.evolution_stage = stage
		TEST_ASSERT(parasite.infest(host), "Stage [stage] could not infest a host.")
		if(stage == LAZARUS_FLESH_FINAL_STAGE)
			TEST_ASSERT(parasite.take_control(), "Final-stage escape could not begin while controlling its host.")
		var/mob/living/basic/flesh_biomorph/escaped = parasite.burst_out()
		allocated += escaped
		TEST_ASSERT(istype(escaped, body_types[stage + 1]), "Stage [stage] produced the wrong escape body.")
		escaped.ai_controller?.force_ai_off()
		TEST_ASSERT_EQUAL(parasite_mind.current, escaped, "Escape lost the parasite's mind at stage [stage].")
		TEST_ASSERT_EQUAL(host.mind, host_mind, "Escape displaced the original host at stage [stage].")
		TEST_ASSERT_NULL(host.treacherous_flesh, "Escape left a parasite attached to its previous host.")
		TEST_ASSERT(QDELETED(parasite), "Escape retained its obsolete parasite body.")
		TEST_ASSERT(host.get_brute_loss() > 0, "Escape did not damage its previous host.")
		TEST_ASSERT(parasite_mind.has_antag_datum(/datum/antagonist/treacherous_flesh), "Escape lost the parasite's antagonist identity.")
		qdel(escaped)
		TEST_ASSERT(!(escaped in GLOB.current_living_antags), "A deleted escaped biomorph remained in the global living-antagonist list.")

	var/mob/living/carbon/human/consistent/dead_host = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/treacherous_flesh/survivor = allocate(/mob/living/treacherous_flesh)
	TEST_ASSERT(survivor.infest(dead_host), "The corpse escape fixture could not attach.")
	dead_host.death()
	var/mob/living/basic/flesh_biomorph/from_corpse = survivor.burst_out()
	allocated += from_corpse
	TEST_ASSERT_NOTNULL(from_corpse, "A parasite could not escape from its dead host.")

/** Extraction uses the actual operation and retains the healthy-patient penalty. */
/datum/unit_test/lazarus_flesh_surgery_extraction
	var/area/previous_area
	var/area/lazarus/event_area
	var/area/previous_registered_area

/datum/unit_test/lazarus_flesh_surgery_extraction/Destroy()
	if(event_area)
		if(get_area(run_loc_floor_bottom_left) == event_area)
			set_turf_to_area(run_loc_floor_bottom_left, previous_area)
		QDEL_NULL(event_area)
		GLOB.areas_by_type[/area/lazarus] = previous_registered_area
	previous_area = null
	previous_registered_area = null
	return ..()

/datum/unit_test/lazarus_flesh_surgery_extraction/Run()
	var/mob/living/carbon/human/consistent/patient = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/surgeon = allocate(/mob/living/carbon/human/consistent)
	var/datum/surgery_operation/limb/lazarus_check_anomalies/operation = GLOB.operations.operations_by_typepath[/datum/surgery_operation/limb/lazarus_check_anomalies]
	var/obj/item/hemostat/tool = allocate(/obj/item/hemostat)
	var/obj/item/bodypart/chest/chest = patient.get_bodypart(BODY_ZONE_CHEST)
	patient.set_resting(TRUE, instant = TRUE)
	ADD_TRAIT(patient, TRAIT_READY_TO_OPERATE, TRAIT_SOURCE_UNIT_TESTS)
	ADD_TRAIT(chest, TRAIT_READY_TO_OPERATE, TRAIT_SOURCE_UNIT_TESTS)
	chest.add_surgical_state(SURGERY_SKIN_OPEN|SURGERY_ORGANS_CUT)
	var/list/available_operations = surgeon.get_available_operations(patient, tool, BODY_ZONE_CHEST)
	TEST_ASSERT(!(operation.main_option in available_operations), "Native surgery menus offered Lazarus extraction on a healthy ordinary patient.")
	operation.on_success(chest, surgeon, tool, list())
	TEST_ASSERT_EQUAL(patient.get_brute_loss(), 0, "An ineligible ordinary patient received extraction damage.")
	previous_area = get_area(run_loc_floor_bottom_left)
	previous_registered_area = GLOB.areas_by_type[/area/lazarus]
	event_area = new /area/lazarus
	set_turf_to_area(run_loc_floor_bottom_left, event_area)
	available_operations = surgeon.get_available_operations(patient, tool, BODY_ZONE_CHEST)
	TEST_ASSERT(operation.main_option in available_operations, "Native surgery menus omitted extraction from a prepared colony patient.")
	TEST_ASSERT(!operation.state_check(patient.get_bodypart(BODY_ZONE_L_ARM)), "Extraction was offered on an arm.")
	operation.on_success(chest, surgeon, tool, list())
	TEST_ASSERT(patient.get_brute_loss() >= 50 && patient.get_tox_loss() >= 25, "A mistaken extraction did not injure the healthy patient.")
	patient.fully_heal()
	set_turf_to_area(run_loc_floor_bottom_left, previous_area)
	chest.add_surgical_state(SURGERY_SKIN_OPEN|SURGERY_ORGANS_CUT)
	var/obj/effect/mob_spawn/ghost_role/treacherous_flesh/egg = allocate(/obj/effect/mob_spawn/ghost_role/treacherous_flesh, patient, patient)
	available_operations = surgeon.get_available_operations(patient, tool, BODY_ZONE_CHEST)
	TEST_ASSERT(operation.main_option in available_operations, "An explicitly infested ordinary patient could not have their egg extracted.")
	operation.on_success(chest, surgeon, tool, list())
	TEST_ASSERT(QDELETED(egg), "Extraction did not remove an unclaimed parasite egg.")
	TEST_ASSERT_NOTNULL(locate(/mob/living/basic/flesh_biomorph/lesser/small) in get_turf(patient), "Egg extraction did not release its small biomorph.")
	TEST_ASSERT_NULL(patient.alternate_appearances?["lazarus_infested"], "Egg extraction retained the infection marker.")
	patient.fully_heal()
	chest.add_surgical_state(SURGERY_SKIN_OPEN|SURGERY_ORGANS_CUT)
	var/mob/living/treacherous_flesh/parasite = allocate(/mob/living/treacherous_flesh)
	parasite.mind_initialize()
	var/datum/mind/parasite_mind = parasite.mind
	TEST_ASSERT(parasite.infest(patient), "The active extraction fixture could not attach.")
	available_operations = surgeon.get_available_operations(patient, tool, BODY_ZONE_CHEST)
	TEST_ASSERT(operation.main_option in available_operations, "An explicitly infested ordinary patient could not have their active parasite extracted.")
	operation.on_success(chest, surgeon, tool, list())
	TEST_ASSERT(QDELETED(parasite), "Surgery did not release the active parasite.")
	TEST_ASSERT(istype(parasite_mind.current, /mob/living/basic/flesh_biomorph/lesser/small), "Surgery lost the parasite player instead of releasing a biomorph.")
	TEST_ASSERT_NULL(patient.treacherous_flesh, "Surgery retained the host's active parasite reference.")

/** Host deletion and invalid infections must not strand temporary minds or markers. */
/datum/unit_test/lazarus_flesh_host_deletion/Run()
	var/mob/living/carbon/human/consistent/host = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/treacherous_flesh/parasite = allocate(/mob/living/treacherous_flesh)
	var/mob/living/treacherous_flesh/other = allocate(/mob/living/treacherous_flesh)
	host.mind_initialize()
	parasite.mind_initialize()
	var/datum/mind/host_mind = host.mind
	var/datum/mind/parasite_mind = parasite.mind
	host.mob_biotypes = MOB_ROBOTIC
	TEST_ASSERT(!parasite.infest(host), "A parasite entered a non-organic human.")
	host.mob_biotypes = MOB_ORGANIC
	TEST_ASSERT(parasite.infest(host), "The deletion fixture could not attach.")
	TEST_ASSERT(!other.infest(host), "A second active parasite entered an occupied host.")
	TEST_ASSERT(parasite.take_control(), "The deletion fixture could not take control.")
	var/mob/living/trapped_mind/prisoner = parasite.trapped_mind
	var/datum/action/return_control/return_action = locate() in host.actions
	TEST_ASSERT(return_action.Trigger(host), "The real return-control button failed.")
	TEST_ASSERT(QDELETED(return_action) && QDELETED(prisoner), "Returning control retained temporary actions or a trapped mind.")
	TEST_ASSERT_EQUAL(host.mind, host_mind, "The return-control action lost the host's original mind.")
	TEST_ASSERT(parasite.take_control(), "Repeated legitimate possession could not start.")
	prisoner = parasite.trapped_mind
	qdel(host)
	TEST_ASSERT(!(host in GLOB.current_living_antags), "A deleted possessed host remained in the global living-antagonist list.")
	TEST_ASSERT(QDELETED(parasite) && QDELETED(prisoner), "Deleting a possessed host retained its parasite or trapped-mind body.")
	TEST_ASSERT_NULL(parasite.host, "The deleted parasite retained its host reference.")
	TEST_ASSERT_NULL(parasite.controlling_mind, "Host deletion retained a controlling mind reference.")
	TEST_ASSERT_NULL(parasite.trapped_mind, "Host deletion retained its temporary body reference.")
	TEST_ASSERT(!host_mind.current || !QDELETED(host_mind.current), "Host deletion stranded the original mind in a deleted body.")
	TEST_ASSERT(!parasite_mind.current || !QDELETED(parasite_mind.current), "Host deletion stranded the parasite's mind in a deleted body.")
	var/mob/living/carbon/human/consistent/saved_host = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/treacherous_flesh/removed_parasite = allocate(/mob/living/treacherous_flesh)
	saved_host.mind_initialize()
	removed_parasite.mind_initialize()
	var/datum/mind/saved_host_mind = saved_host.mind
	var/datum/mind/removed_mind = removed_parasite.mind
	TEST_ASSERT(removed_parasite.infest(saved_host) && removed_parasite.take_control(), "The direct removal fixture could not take control.")
	var/mob/living/trapped_mind/removed_prisoner = removed_parasite.trapped_mind
	qdel(removed_parasite)
	TEST_ASSERT_EQUAL(saved_host.mind, saved_host_mind, "Deleting a controlling parasite did not return the living host's original mind.")
	TEST_ASSERT_EQUAL(saved_host_mind.current, saved_host, "Parasite deletion detached the original host from its body.")
	TEST_ASSERT_NULL(removed_mind.current, "Deleting a controlling parasite left its mind attached to another player's body.")
	TEST_ASSERT(QDELETED(removed_prisoner), "Deleting a controlling parasite retained its trapped-mind body.")
	TEST_ASSERT_NULL(saved_host.treacherous_flesh, "Direct parasite deletion left a stale host reference.")
	var/mob/living/carbon/human/consistent/egg_host = allocate(/mob/living/carbon/human/consistent)
	var/obj/effect/mob_spawn/ghost_role/treacherous_flesh/egg = allocate(/obj/effect/mob_spawn/ghost_role/treacherous_flesh, egg_host, egg_host)
	TEST_ASSERT(egg.allow_spawn(null), "An egg rejected its original living organic host.")
	egg.forceMove(get_turf(egg_host))
	TEST_ASSERT(!egg.allow_spawn(null), "An extracted egg remained playable outside its host.")
	qdel(egg_host)
	TEST_ASSERT(QDELETED(egg), "Deleting the original host retained its ghost-role egg.")
	var/obj/effect/mob_spawn/ghost_role/treacherous_flesh/hostless_egg = allocate(/obj/effect/mob_spawn/ghost_role/treacherous_flesh)
	TEST_ASSERT(QDELETED(hostless_egg), "An egg without a host survived initialization.")

/** All threshold crossings grant every stage once, including a multi-stage jump. */
/datum/unit_test/lazarus_flesh_all_stages/Run()
	var/mob/living/treacherous_flesh/parasite = allocate(/mob/living/treacherous_flesh)
	var/list/thresholds = list(300, 900, 2100, 3600)
	var/list/action_counts = list(5, 9, 13, 15, 16)
	TEST_ASSERT_EQUAL(length(parasite.actions), action_counts[1], "The parasite did not begin with its five starting powers.")
	for(var/stage in 1 to LAZARUS_FLESH_FINAL_STAGE)
		parasite.evolution_points = thresholds[stage]
		parasite.handle_evolution(0)
		TEST_ASSERT_EQUAL(parasite.evolution_stage, stage - 1, "Evolution unlocked before exceeding threshold [stage].")
		parasite.evolution_points++
		parasite.handle_evolution(0)
		TEST_ASSERT_EQUAL(parasite.evolution_stage, stage, "Evolution did not cross threshold [stage].")
		TEST_ASSERT_EQUAL(length(parasite.actions), action_counts[stage + 1], "Stage [stage] did not grant the expected cumulative powers.")
		parasite.grant_skills()
		TEST_ASSERT_EQUAL(length(parasite.actions), action_counts[stage + 1], "Granting stage [stage] again duplicated a power.")
	TEST_ASSERT_NOTNULL(locate(/datum/action/treacherous_flesh/ascension) in parasite.actions, "The final stage did not unlock ascension.")
	var/mob/living/treacherous_flesh/rapid = allocate(/mob/living/treacherous_flesh)
	rapid.evolution_points = 3601
	rapid.handle_evolution(0)
	TEST_ASSERT_EQUAL(length(rapid.actions), 16, "Crossing all stages at once skipped intermediate powers.")

/** Unanswered ascension must leave both players and their chemicals intact. */
/datum/unit_test/lazarus_flesh_ascension/Run()
	var/mob/living/carbon/human/consistent/host = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/treacherous_flesh/parasite = allocate(/mob/living/treacherous_flesh)
	host.mind_initialize()
	parasite.mind_initialize()
	var/datum/mind/host_mind = host.mind
	var/datum/mind/parasite_mind = parasite.mind
	parasite.evolution_points = 3601
	parasite.handle_evolution(0)
	TEST_ASSERT(parasite.infest(host), "The ascension fixture could not attach.")
	parasite.chemicals = LAZARUS_FLESH_CHEMICAL_MAX
	var/datum/action/treacherous_flesh/ascension/ascend = locate() in parasite.actions
	TEST_ASSERT_NOTNULL(ascend, "Final evolution did not make ascension available.")
	TEST_ASSERT(!ascend.Trigger(parasite), "Ascension proceeded without affirmative client confirmation.")
	TEST_ASSERT_EQUAL(parasite.chemicals, LAZARUS_FLESH_CHEMICAL_MAX, "Cancelled ascension spent chemicals.")
	TEST_ASSERT_EQUAL(host.mind, host_mind, "Cancelled ascension displaced the host's mind.")
	TEST_ASSERT_EQUAL(parasite.mind, parasite_mind, "Cancelled ascension displaced the parasite's mind.")
	TEST_ASSERT(!QDELETED(host) && !QDELETED(parasite), "Cancelled ascension destroyed its participants.")
	TEST_ASSERT_EQUAL(host.treacherous_flesh, parasite, "Cancelled ascension removed the active infestation.")

/** Real growth observes cooldowns and interruption; unanswered construction never places a structure. */
/datum/unit_test/lazarus_biomorph_construction/Run()
	var/mob/living/basic/flesh_biomorph/high/builder = allocate(/mob/living/basic/flesh_biomorph/high)
	builder.ai_controller.force_ai_off()
	var/datum/action/cooldown/biomorph/plant_weeds/plant = locate() in builder.actions
	TEST_ASSERT(plant.Trigger(builder), "The spreading action could not grow a real flesh node.")
	var/obj/structure/alien/weeds/node/meaty/node = locate() in get_turf(builder)
	TEST_ASSERT_NOTNULL(node, "Successful flesh spreading did not create its node.")
	TEST_ASSERT(!plant.Trigger(builder), "A cooling-down spreading action activated again.")
	plant.ResetCooldown()
	TEST_ASSERT(!plant.Trigger(builder), "A second node grew on the same turf.")
	qdel(node)
	var/turf/first_location = get_turf(builder)
	var/turf/second_location = get_step(first_location, EAST)
	addtimer(CALLBACK(builder, TYPE_PROC_REF(/atom/movable, forceMove), second_location), 0.5 SECONDS)
	TEST_ASSERT(!plant.Trigger(builder), "Moving during flesh growth did not cancel its real delay.")
	TEST_ASSERT_NULL(locate(/obj/structure/alien/weeds/node/meaty) in first_location, "Interrupted spreading still grew its node.")
	TEST_ASSERT(plant.next_use_time <= world.time, "Interrupted growth retained its cooldown.")
	var/datum/action/cooldown/biomorph/build_structure/build = locate() in builder.actions
	TEST_ASSERT(!build.Trigger(builder), "Construction proceeded without selecting a structure.")
	TEST_ASSERT_NULL(locate(/obj/structure/alien/resin/wall/meaty) in second_location, "Cancelled construction placed a wall.")
	TEST_ASSERT_NULL(locate(/obj/structure/alien/resin/door/meaty) in second_location, "Cancelled construction placed a door.")
	TEST_ASSERT(build.next_use_time <= world.time, "Cancelled construction retained its cooldown.")

/** Hiding grants door passage only while unbolted, and removal restores appearance. */
/datum/unit_test/lazarus_biomorph_sneak_split/Run()
	var/mob/living/basic/flesh_biomorph/lesser/small/small = allocate(/mob/living/basic/flesh_biomorph/lesser/small)
	small.ai_controller.force_ai_off()
	var/obj/machinery/door/airlock/airlock = allocate(/obj/machinery/door/airlock, get_step(run_loc_floor_bottom_left, EAST))
	var/datum/action/cooldown/mob_cooldown/sneak/lazarus/hide = locate() in small.actions
	TEST_ASSERT(hide.Trigger(small), "The small biomorph could not hide.")
	TEST_ASSERT(HAS_TRAIT(small, TRAIT_SNEAK), "Hiding did not grant the native sneak trait.")
	TEST_ASSERT_EQUAL(small.layer, ABOVE_OPEN_TURF_LAYER, "Hiding did not move the biomorph below objects.")
	airlock.locked = FALSE
	TEST_ASSERT(small.CanPassThrough(airlock, EAST, FALSE), "A hidden small biomorph could not pass under an unbolted airlock.")
	airlock.locked = TRUE
	TEST_ASSERT(!small.CanPassThrough(airlock, EAST, FALSE), "A hidden biomorph passed through a bolted airlock.")
	qdel(hide)
	TEST_ASSERT(!HAS_TRAIT(small, TRAIT_SNEAK), "Removing the hide action retained its sneak trait.")
	TEST_ASSERT_EQUAL(small.layer, initial(small.layer), "Removing the hide action retained its altered layer.")
	var/mob/living/basic/flesh_biomorph/lesser/large/large = allocate(/mob/living/basic/flesh_biomorph/lesser/large)
	large.ai_controller.force_ai_off()
	large.mind_initialize()
	var/datum/mind/large_mind = large.mind
	var/code_name = large.code_name
	large.death()
	var/mob/living/basic/flesh_biomorph/lesser/medium/child = large_mind.current
	TEST_ASSERT(istype(child), "A dead large biomorph did not move its mind into a medium child.")
	TEST_ASSERT_EQUAL(child.code_name, code_name, "Splitting lost the player's code name.")
	var/mob/living/basic/flesh_biomorph/lesser/medium/gibbed = allocate(/mob/living/basic/flesh_biomorph/lesser/medium)
	gibbed.ai_controller.force_ai_off()
	var/small_before = length(GLOB.lazarus_biomorphs)
	gibbed.death(TRUE)
	TEST_ASSERT_EQUAL(length(GLOB.lazarus_biomorphs), small_before, "A gibbed biomorph still produced splitting offspring.")

/** Native projectile hits must damage, grapple once, respect blocking and clean their beam. */
/datum/unit_test/lazarus_biomorph_tentacle/Run()
	var/mob/living/basic/flesh_biomorph/high/shooter = allocate(/mob/living/basic/flesh_biomorph/high)
	shooter.ai_controller.force_ai_off()
	var/turf/target_location = locate(shooter.x + 3, shooter.y, shooter.z)
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, target_location)
	var/datum/action/cooldown/spell/pointed/projectile/biomorph_tentacle/spell = locate() in shooter.actions
	var/obj/projectile/biomorph_tentacle/visual = allocate(/obj/projectile/biomorph_tentacle)
	spell.ready_projectile(visual, victim, shooter, 1)
	visual.fire()
	var/datum/beam/beam = visual.tentacle_beam
	TEST_ASSERT_NOTNULL(beam, "A fired tentacle did not create its beam.")
	qdel(visual)
	TEST_ASSERT(QDELETED(beam), "Deleting a tentacle retained its beam.")
	var/obj/projectile/biomorph_tentacle/projectile = allocate(/obj/projectile/biomorph_tentacle)
	spell.ready_projectile(projectile, victim, shooter, 1)
	victim.projectile_hit(projectile, BODY_ZONE_CHEST, blocked = 0)
	TEST_ASSERT(victim.get_brute_loss() > 0, "The native tentacle hit did not damage its victim.")
	TEST_ASSERT(victim.IsImmobilized(), "The tentacle did not immobilize its victim.")
	TEST_ASSERT(projectile.has_pulled, "The tentacle did not start its pull.")
	sleep(1 SECONDS)
	TEST_ASSERT(get_dist(shooter, victim) <= 1, "The tentacle did not pull its victim adjacent to the shooter.")
	var/mob/living/carbon/human/consistent/blocked_victim = allocate(/mob/living/carbon/human/consistent, target_location)
	projectile.on_hit(blocked_victim)
	TEST_ASSERT(!blocked_victim.IsImmobilized(), "One projectile started a second grapple.")
	var/obj/projectile/biomorph_tentacle/blocked = allocate(/obj/projectile/biomorph_tentacle)
	spell.ready_projectile(blocked, blocked_victim, shooter, 1)
	blocked_victim.projectile_hit(blocked, BODY_ZONE_CHEST, blocked = 100)
	TEST_ASSERT(!blocked.has_pulled && !blocked_victim.IsImmobilized(), "A fully blocked tentacle still grappled its victim.")
	TEST_ASSERT(blocked_victim.get_brute_loss() < projectile.damage, "Native blocking did not reduce tentacle damage.")
	qdel(victim)
	var/obj/structure/alien/resin/wall/meaty/wall = allocate(/obj/structure/alien/resin/wall/meaty, target_location)
	var/obj/projectile/biomorph_tentacle/grapple = allocate(/obj/projectile/biomorph_tentacle)
	spell.ready_projectile(grapple, wall, shooter, 1)
	wall.projectile_hit(grapple, BODY_ZONE_CHEST, blocked = 0)
	sleep(1 SECONDS)
	TEST_ASSERT(get_dist(shooter, wall) <= 1, "Hitting a dense structure did not pull the shooter toward it.")

/datum/unit_test/lazarus_wildlife_burst/Run()
	var/mob/living/carbon/human/consistent/human = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/basic/lazarus_prey/deer/infested/deer = allocate(/mob/living/basic/lazarus_prey/deer/infested)
	deer.ai_controller.force_ai_off()
	human.add_faction("treacherous_flesh")
	var/datum/bt_node/ai_behavior/acquire_target/update_combat_targets/nearest/find_target = allocate(/datum/bt_node/ai_behavior/acquire_target/update_combat_targets/nearest)
	find_target.target_key = BB_CURRENT_TARGET
	find_target.hiding_location_key = BB_CURRENT_TARGET_HIDING_LOCATION
	human.forceMove(locate(deer.x + 5, deer.y, deer.z))
	find_target.perform(SSMOBS_DT, deer.ai_controller)
	TEST_ASSERT_NULL(deer.ai_controller.blackboard[BB_CURRENT_TARGET], "An infested animal acquired a target beyond its four-tile detection range.")
	human.forceMove(locate(deer.x + 4, deer.y, deer.z))
	find_target.perform(SSMOBS_DT, deer.ai_controller)
	TEST_ASSERT_EQUAL(deer.ai_controller.blackboard[BB_CURRENT_TARGET], human, "An infested animal did not acquire its target at four tiles.")
	TEST_ASSERT(!deer.biomorphing, "An infested animal revealed itself to a pheromone-protected host.")
	human.remove_faction("treacherous_flesh")
	deer.ai_controller.clear_blackboard_key(BB_CURRENT_TARGET)
	find_target.perform(SSMOBS_DT, deer.ai_controller)
	TEST_ASSERT(deer.biomorphing && deer.stat == DEAD, "Native target acquisition did not begin the infested animal's burst.")
	var/original_timer = deer.biomorph_timer
	deer.start_biomorphing()
	TEST_ASSERT_EQUAL(deer.biomorph_timer, original_timer, "Repeated targeting scheduled a second transformation.")
	var/mob/living/basic/lazarus_prey/bunny/infested/cancelled = allocate(/mob/living/basic/lazarus_prey/bunny/infested)
	cancelled.ai_controller.force_ai_off()
	cancelled.ai_controller.set_blackboard_key(BB_CURRENT_TARGET, human)
	TEST_ASSERT(cancelled.biomorph_timer, "The rabbit did not schedule its transformation.")
	qdel(cancelled)
	TEST_ASSERT_NULL(cancelled.biomorph_timer, "Deleting the transforming animal retained its timer.")
	sleep(5 SECONDS + 2 * world.tick_lag)
	TEST_ASSERT(QDELETED(deer), "The infested deer survived its completed burst.")
	var/offspring = 0
	for(var/mob/living/basic/flesh_biomorph/lesser/medium/child in GLOB.lazarus_biomorphs)
		if(get_area(child) == get_area(run_loc_floor_bottom_left))
			offspring++
	TEST_ASSERT_EQUAL(offspring, 1, "A completed burst and a cancelled burst did not produce exactly one medium biomorph.")
	var/meat = 0
	for(var/obj/item/food/meat/slab/slab in run_loc_floor_bottom_left)
		meat++
	var/leather = 0
	for(var/obj/item/stack/sheet/leather/hide in run_loc_floor_bottom_left)
		leather += hide.amount
	TEST_ASSERT_EQUAL(meat, 12, "The native basic-mob gib path lost the source deer's meat yield.")
	TEST_ASSERT_EQUAL(leather, 10, "The native basic-mob gib path lost the source deer's leather yield.")

#endif
// AI EDIT END
