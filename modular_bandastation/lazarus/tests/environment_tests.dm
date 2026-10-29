// AI EDIT START - Adapt the Lazarus event to the native Primera APIs and regression harness
/** Tool order, timed repair invalidation, network output and failure cancellation. */
/datum/unit_test/lazarus_generator/Run()
	var/turf/spot = run_loc_floor_bottom_left
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent/slow, spot)
	var/obj/machinery/power/geothermal_generator/generator = allocate(/obj/machinery/power/geothermal_generator, spot)
	var/obj/item/screwdriver/screwdriver = allocate(/obj/item/screwdriver, user)
	var/obj/item/wirecutters/cutters = allocate(/obj/item/wirecutters, user)
	var/obj/item/wrench/wrench = allocate(/obj/item/wrench, user)
	screwdriver.toolspeed = 0
	cutters.toolspeed = 0
	wrench.toolspeed = 0
	user.put_in_hands(wrench)
	generator.wrench_act(user, wrench)
	TEST_ASSERT_EQUAL(generator.icon_state, "geoterm_broken", "The repair cannot skip opening the lid.")
	user.dropItemToGround(wrench)
	user.put_in_hands(screwdriver)
	generator.screwdriver_act(user, screwdriver)
	TEST_ASSERT_EQUAL(generator.icon_state, "geoterm_1", "Opening the lid must expose damaged wiring.")
	user.dropItemToGround(screwdriver)
	user.put_in_hands(cutters)
	generator.wirecutter_act(user, cutters)
	user.dropItemToGround(cutters)
	user.put_in_hands(wrench)
	generator.wrench_act(user, wrench)
	user.dropItemToGround(wrench)
	user.put_in_hands(screwdriver)
	screwdriver.toolspeed = 1
	INVOKE_ASYNC(generator, TYPE_PROC_REF(/atom, screwdriver_act), user, screwdriver)
	TEST_ASSERT(LAZYACCESS(user.do_afters, generator), "The final repair must actually be waiting before its state is invalidated.")
	generator.break_gen()
	UNTIL(!LAZYACCESS(user.do_afters, generator))
	TEST_ASSERT_EQUAL(generator.icon_state, "geoterm_broken", "A failure during the closing action must invalidate that repair.")
	TEST_ASSERT_NULL(generator.break_timer, "The invalidated repair must not schedule a new failure.")
	screwdriver.toolspeed = 0
	generator.screwdriver_act(user, screwdriver)
	user.dropItemToGround(screwdriver)
	user.put_in_hands(cutters)
	generator.wirecutter_act(user, cutters)
	user.dropItemToGround(cutters)
	user.put_in_hands(wrench)
	generator.wrench_act(user, wrench)
	user.dropItemToGround(wrench)
	user.put_in_hands(screwdriver)
	generator.screwdriver_act(user, screwdriver)
	TEST_ASSERT_EQUAL(generator.icon_state, "geoterm_active", "All four tool steps must activate the generator.")
	var/datum/powernet/network = allocate(/datum/powernet)
	network.add_machine(generator)
	var/previous_energy = network.newavail
	generator.process(SSmachines.wait / 10)
	TEST_ASSERT_EQUAL(network.newavail - previous_energy, power_to_energy(300), "An active generator must supply 300 W through the native grid.")
	generator.disconnect_from_network()
	generator.process(SSmachines.wait / 10)
	TEST_ASSERT_EQUAL(generator.icon_state, "geoterm_broken", "Disconnecting an active generator must break it.")
	TEST_ASSERT_NULL(generator.break_timer, "Breaking a generator must cancel its scheduled failure.")

/** Actual ladder travel carries the original pulled object and rejects a deleted exit. */
/datum/unit_test/lazarus_ladders/Run()
	var/turf/start = run_loc_floor_bottom_left
	var/turf/finish = run_loc_floor_top_right
	var/obj/structure/ladder_teleporter/entrance = allocate(/obj/structure/ladder_teleporter, start)
	var/obj/structure/ladder_teleporter/exit = allocate(/obj/structure/ladder_teleporter, finish)
	entrance.target_id = "unit-test-lazarus-exit"
	exit.ladder_id = entrance.target_id
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent/slow, start)
	var/obj/item/crowbar/pulled = allocate(/obj/item/crowbar, start)
	user.start_pulling(pulled)
	entrance.attack_hand(user, list())
	TEST_ASSERT_EQUAL(get_turf(user), finish, "A valid linked ladder must move the climber to its exit.")
	TEST_ASSERT_EQUAL(get_turf(pulled), finish, "A ladder must bring the original pulled object.")
	user.forceMove(start)
	INVOKE_ASYNC(entrance, TYPE_PROC_REF(/atom, attack_hand), user, list())
	TEST_ASSERT(LAZYACCESS(user.do_afters, DOAFTER_SOURCE_CLIMBING_LADDER), "The climb must actually be waiting before its exit is deleted.")
	qdel(exit)
	UNTIL(!LAZYACCESS(user.do_afters, DOAFTER_SOURCE_CLIMBING_LADDER))
	TEST_ASSERT_EQUAL(get_turf(user), start, "Deleting the exit during travel must leave the climber safely at the entrance.")
	TEST_ASSERT_NULL(entrance.find_destination(), "Deleted ladders must leave the lookup registry.")

/** Native flora harvesting must provide a finite yield and reject a second harvest. */
/datum/unit_test/lazarus_wild_crops/Run()
	var/obj/structure/flora/lazarus/berry/bush = allocate(/obj/structure/flora/lazarus/berry)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/list/berries = bush.harvest(user)
	allocated += berries
	TEST_ASSERT_EQUAL(length(berries), 4, "The berry bush must yield four berries.")
	TEST_ASSERT_EQUAL(bush.icon_state, "berry_bush_empty", "Harvesting must leave the empty bush visible.")
	TEST_ASSERT(!bush.harvest(user), "An already harvested bush must not create more food.")

/** Mash the real crop, then treat an injured limb using the resulting native medical stack. */
/datum/unit_test/lazarus_herbal_poultice/Run()
	var/list/random_seeds = get_sane_item_types(/obj/item/seeds)
	TEST_ASSERT(!(/obj/item/seeds/comfrey in random_seeds), "Ordinary random seed generation includes colony comfrey.")
	TEST_ASSERT(!(/obj/item/seeds/aloe/lazarus in random_seeds), "Ordinary random seed generation includes colony aloe.")
	TEST_ASSERT(/obj/item/seeds/aloe in random_seeds, "Excluding colony aloe also removed ordinary station aloe.")
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/food/grown/comfrey/leaf = allocate(/obj/item/food/grown/comfrey)
	leaf.seed.potency = 43
	user.put_in_hands(leaf)
	leaf.attack_self(user)
	TEST_ASSERT(QDELETED(leaf), "Mashing comfrey must consume the leaf.")
	var/obj/item/stack/medical/bruise_pack/lazarus_poultice/poultice = locate() in user
	TEST_ASSERT_NOTNULL(poultice, "Mashing must put a usable poultice in the user's hand.")
	allocated += poultice
	TEST_ASSERT_EQUAL(poultice.heal_brute, 43, "The poultice must retain the plant's potency.")
	var/obj/item/bodypart/chest/chest = user.get_bodypart(BODY_ZONE_CHEST)
	chest.receive_damage(brute = 50)
	poultice.self_delay = 0
	user.zone_selected = BODY_ZONE_CHEST
	var/before = user.get_brute_loss()
	poultice.interact_with_atom(user, user, list())
	TEST_ASSERT(user.get_brute_loss() < before, "A mashed comfrey poultice must heal a real injury.")

/** Repeated scooping must wait for regrowth and cannot duplicate the initial ten units. */
/datum/unit_test/lazarus_fungus_harvest
	var/turf/fungus_wall
	var/original_floor_type

/datum/unit_test/lazarus_fungus_harvest/Destroy()
	if(fungus_wall && original_floor_type)
		fungus_wall.ChangeTurf(original_floor_type)
	fungus_wall = null
	return ..()

/datum/unit_test/lazarus_fungus_harvest/Run()
	var/turf/reserved_floor = get_step(run_loc_floor_bottom_left, EAST)
	original_floor_type = reserved_floor.type
	fungus_wall = reserved_floor.ChangeTurf(/turf/closed/wall)
	var/obj/effect/decal/cleanable/fungus/fungus = allocate(/obj/effect/decal/cleanable/fungus, fungus_wall)
	TEST_ASSERT(!QDELETED(fungus), "Intentional wall fungus must survive the native decal initialization checks.")
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/reagent_containers/cup/beaker/beaker = allocate(/obj/item/reagent_containers/cup/beaker)
	user.put_in_hands(beaker)
	fungus.item_interaction(user, beaker, list())
	TEST_ASSERT_EQUAL(beaker.reagents.get_reagent_amount(/datum/reagent/fungus), 10, "One fungal patch must provide ten units.")
	fungus.item_interaction(user, beaker, list())
	TEST_ASSERT_EQUAL(beaker.reagents.total_volume, 10, "A harvested patch cannot be scooped again.")
	fungus.recreate()
	fungus.item_interaction(user, beaker, list())
	TEST_ASSERT_EQUAL(beaker.reagents.total_volume, 20, "Regrowth must restore exactly one new ten-unit harvest.")

/** Native gel containers keep the source mender's treatment and anti-poison safeguards. */
/datum/unit_test/lazarus_auto_mender/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent/slow)
	var/obj/item/reagent_containers/medigel/lazarus/brute/mender = allocate(/obj/item/reagent_containers/medigel/lazarus/brute)
	user.put_in_hands(mender)
	mender.reagents.remove_all(10)
	mender.reagents.add_reagent(/datum/reagent/toxin, 1)
	TEST_ASSERT(!mender.reagents.has_reagent(/datum/reagent/toxin), "The normal mender must reject harmful reagents.")
	user.adjust_brute_loss(8)
	var/before = user.get_brute_loss()
	var/initial_volume = mender.reagents.total_volume
	mender.interact_with_atom(user, user, list())
	TEST_ASSERT(user.get_brute_loss() < before, "Timed automatic treatment must heal the patient.")
	TEST_ASSERT(mender.reagents.total_volume < initial_volume, "Healing must consume the mender's finite supply.")
	TEST_ASSERT(!mender.applying, "The treatment lock must clear when the procedure ends.")
	user.add_or_update_variable_actionspeed_modifier(/datum/actionspeed_modifier/base, multiplicative_slowdown = 1)
	mender.emag_act(user)
	mender.reagents.add_reagent(/datum/reagent/toxin, 1)
	TEST_ASSERT(mender.reagents.has_reagent(/datum/reagent/toxin), "An emag must actually disable chemical safety.")
	TEST_ASSERT(user.is_holding(mender) && !user.incapacitated && mender.reagents.total_volume, "The interruption fixture must still be able to treat itself.")
	INVOKE_ASYNC(mender, TYPE_PROC_REF(/obj/item/reagent_containers/medigel/lazarus, interact_with_atom), user, user, list())
	TEST_ASSERT(LAZYACCESS(user.do_afters, user), "The treatment must actually be waiting before its reservoir is emptied.")
	mender.reagents.clear_reagents()
	UNTIL(!LAZYACCESS(user.do_afters, user))
	TEST_ASSERT(!mender.applying, "Emptying the reservoir during a treatment must release the treatment lock without a runtime.")

/** Restore temporary area assignments even if an assertion aborts the scenario. */
/datum/unit_test/lazarus_weather
	var/list/original_areas = list()
	var/area/lazarus/outdoors/wilderness
	var/area/lazarus/shelter/shelter
	var/area/previous_outdoors_registry
	var/area/previous_shelter_registry

/datum/unit_test/lazarus_weather/Destroy()
	for(var/turf/changed as anything in original_areas)
		if(!QDELETED(changed))
			set_turf_to_area(changed, original_areas[changed])
	original_areas.Cut()
	if(wilderness)
		QDEL_NULL(wilderness)
		GLOB.areas_by_type[/area/lazarus/outdoors] = previous_outdoors_registry
	if(shelter)
		QDEL_NULL(shelter)
		GLOB.areas_by_type[/area/lazarus/shelter] = previous_shelter_registry
	previous_outdoors_registry = null
	previous_shelter_registry = null
	return ..()

/datum/unit_test/lazarus_weather/Run()
	var/turf/outside = run_loc_floor_bottom_left
	var/turf/inside = get_step(outside, EAST)
	original_areas[outside] = get_area(outside)
	original_areas[inside] = get_area(inside)
	previous_outdoors_registry = GLOB.areas_by_type[/area/lazarus/outdoors]
	previous_shelter_registry = GLOB.areas_by_type[/area/lazarus/shelter]
	wilderness = new /area/lazarus/outdoors
	shelter = new /area/lazarus/shelter
	set_turf_to_area(outside, wilderness)
	set_turf_to_area(inside, shelter)
	var/datum/weather/lazarus_blizzard/weather = allocate(/datum/weather/lazarus_blizzard, list(outside.z))
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent, outside)
	TEST_ASSERT(weather.can_weather_act_mob(human), "An exposed colonist must be affected by the blizzard.")
	human.forceMove(inside)
	TEST_ASSERT(!weather.can_weather_act_mob(human), "A shelter must protect colonists from the blizzard.")
	human.forceMove(run_loc_floor_top_right)
	TEST_ASSERT(!weather.can_weather_act_mob(human), "Unrelated station areas must never be affected by Lazarus weather.")
	human.forceMove(outside)
	var/obj/item/clothing/glasses/welding/goggles = allocate(/obj/item/clothing/glasses/welding)
	human.equip_to_slot_or_del(goggles, ITEM_SLOT_EYES)
	TEST_ASSERT(!weather.can_weather_act_mob(human), "Welding eye protection must block snow blindness.")
	human.dropItemToGround(goggles)
	weather.weather_act_mob(human)
	TEST_ASSERT(human.has_status_effect(/datum/status_effect/lazarus_blizzard), "The blizzard must apply its movement penalty.")
	TEST_ASSERT(human.is_blind(), "An unprotected colonist must be temporarily blinded by the snow.")
// AI EDIT END
