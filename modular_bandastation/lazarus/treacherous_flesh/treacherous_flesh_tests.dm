#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)

/// Real possession and removal must restore both minds and leave no stale host state.
/datum/unit_test/lazarus_flesh_minds/Run()
	var/mob/living/carbon/human/consistent/host = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/mob/living/treacherous_flesh/parasite = allocate(/mob/living/treacherous_flesh, run_loc_floor_bottom_left)
	host.mind_initialize()
	parasite.mind_initialize()
	var/datum/mind/host_mind = host.mind
	var/datum/mind/parasite_mind = parasite.mind
	TEST_ASSERT(parasite.infest(host), "The parasite could not attach to an organic human.")
	TEST_ASSERT_EQUAL(host.treacherous_flesh, parasite, "The host does not own the active parasite.")
	TEST_ASSERT_NOTNULL(host.alternate_appearances?["lazarus_infested"], "Infestation did not add a private host marker.")
	TEST_ASSERT(parasite.take_control(), "The parasite could not take control.")
	TEST_ASSERT_EQUAL(host.mind, parasite_mind, "Possession did not move the parasite's mind.")
	TEST_ASSERT_EQUAL(parasite.trapped_mind.mind, host_mind, "Possession lost the host's mind.")
	TEST_ASSERT(!parasite.take_control(), "Repeated possession displaced a second mind.")
	parasite.restore_control()
	TEST_ASSERT_EQUAL(host.mind, host_mind, "Returning control did not restore the original host.")
	TEST_ASSERT_EQUAL(parasite.mind, parasite_mind, "Returning control did not restore the parasite.")
	TEST_ASSERT_NULL(parasite.trapped_mind, "Returning control retained a temporary body.")
	TEST_ASSERT(parasite.take_control(), "A second legitimate possession failed.")
	parasite.disinfest(delete = FALSE)
	TEST_ASSERT_EQUAL(host.mind, host_mind, "Removing a controlling parasite lost the host's mind.")
	TEST_ASSERT_NULL(host.treacherous_flesh, "Removal left a stale host reference.")
	TEST_ASSERT_NULL(parasite.host, "Removal left a stale parasite reference.")
	TEST_ASSERT_NULL(host.alternate_appearances?["lazarus_infested"], "Removal retained its private infection marker.")
	TEST_ASSERT_EQUAL(length(parasite.host_actions), 0, "Removal retained actions on the host.")

/// Native pickup and exposure must contaminate food and infect a new human exactly once.
/datum/unit_test/lazarus_flesh_infection/Run()
	var/mob/living/carbon/human/consistent/carrier = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/consistent/patient = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/mob/living/treacherous_flesh/parasite = allocate(/mob/living/treacherous_flesh, run_loc_floor_bottom_left)
	var/obj/item/food/meat/slab/food = allocate(/obj/item/food/meat/slab, run_loc_floor_bottom_left)
	TEST_ASSERT(parasite.infest(carrier), "The carrier could not be infested.")
	parasite.infecting = TRUE
	food.attack_hand(carrier)
	TEST_ASSERT(carrier.is_holding(food), "Carrier could not pick up the food through the player interaction.")
	TEST_ASSERT(food.reagents.has_reagent(/datum/reagent/treacherous_flesh), "Real pickup did not contaminate the food.")
	food.reagents.expose(patient, INGEST)
	TEST_ASSERT(locate(/datum/disease/treacherous_flesh) in patient.diseases, "Contaminated food did not infect an exposed human.")
	food.reagents.expose(patient, INGEST)
	var/infections = 0
	for(var/datum/disease/treacherous_flesh/infection in patient.diseases)
		infections++
	TEST_ASSERT_EQUAL(infections, 1, "Repeated exposure created duplicate infections.")
	var/datum/action/treacherous_flesh/emit_pheromones/pheromones = locate() in parasite.actions
	TEST_ASSERT(pheromones.Trigger(parasite), "The carrier's parasite could not activate pheromones.")
	TEST_ASSERT(carrier.has_faction("treacherous_flesh"), "Pheromones did not protect the carrier.")
	TEST_ASSERT(!patient.has_faction("treacherous_flesh"), "Pheromones mutated another human's cached faction list.")
	TEST_ASSERT(pheromones.Trigger(parasite), "The carrier's parasite could not disable pheromones.")
	TEST_ASSERT(!carrier.has_faction("treacherous_flesh"), "Disabling pheromones retained their faction.")

/// Development and regeneration must retain donor timing when life ticks change.
/datum/unit_test/lazarus_flesh_evolution/Run()
	var/mob/living/carbon/human/consistent/host = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/mob/living/treacherous_flesh/parasite = allocate(/mob/living/treacherous_flesh, run_loc_floor_bottom_left)
	TEST_ASSERT(parasite.infest(host), "The parasite could not attach.")
	parasite.Life(1)
	parasite.Life(1)
	TEST_ASSERT_EQUAL(parasite.chemicals, 2, "Chemical regeneration differs from one unit per second.")
	TEST_ASSERT_EQUAL(parasite.evolution_points, 1, "Evolution differs from one point per two seconds.")
	parasite.evolution_points = 301
	parasite.handle_evolution(0)
	TEST_ASSERT_EQUAL(parasite.evolution_stage, 1, "First evolution threshold did not unlock.")
	TEST_ASSERT_NOTNULL(locate(/datum/action/treacherous_flesh/fleshmend) in parasite.actions, "Evolution did not grant its healing power.")
	parasite.grant_skills()
	var/healing_powers = 0
	for(var/datum/action/treacherous_flesh/fleshmend/action in parasite.actions)
		healing_powers++
	TEST_ASSERT_EQUAL(healing_powers, 1, "Repeated skill grants duplicate powers.")
	parasite.chemicals = 20
	parasite.infecting = TRUE
	parasite.Life(2)
	TEST_ASSERT_EQUAL(parasite.chemicals, 16, "Passive infection does not cost four chemicals per original tick.")

/// A dead larger body must transfer its player to a living offspring exactly once.
/datum/unit_test/lazarus_flesh_split/Run()
	var/mob/living/basic/flesh_biomorph/lesser/medium/body = allocate(/mob/living/basic/flesh_biomorph/lesser/medium, run_loc_floor_bottom_left)
	body.mind_initialize()
	var/datum/mind/player = body.mind
	body.death()
	var/mob/living/basic/flesh_biomorph/lesser/small/successor = player.current
	TEST_ASSERT(istype(successor), "A dying medium biomorph did not transfer its mind into a small offspring.")
	TEST_ASSERT_EQUAL(successor.stat, STABLE, "Splitting transferred the player into a dead body.")
	for(var/mob/living/basic/flesh_biomorph/lesser/small/offspring in run_loc_floor_bottom_left)
		qdel(offspring)

/// Reanimation needs a full unit and must not duplicate creature death drops.
/datum/unit_test/lazarus_reanimation/Run()
	var/mob/living/basic/butterfly/animal = allocate(/mob/living/basic/butterfly, run_loc_floor_bottom_left)
	var/datum/reagent/medicine/lazarus_reagent/medicine = allocate(/datum/reagent/medicine/lazarus_reagent)
	animal.AddElement(/datum/element/death_drops, list(/obj/item/stack/sheet/iron = 1))
	animal.death()
	TEST_ASSERT_EQUAL(animal.stat, DEAD, "The animal did not enter the dead state.")
	medicine.expose_mob(animal, TOUCH, 0.5)
	TEST_ASSERT_EQUAL(animal.stat, DEAD, "A fractional dose revived the animal.")
	medicine.expose_mob(animal, TOUCH, 1)
	TEST_ASSERT_EQUAL(animal.stat, STABLE, "A full dose failed to revive an organic creature.")
	TEST_ASSERT_NOTNULL(animal.GetComponent(/datum/component/lazarus_no_repeat_loot), "Revival did not prevent repeated farming.")
	var/drop_count = 0
	for(var/obj/item/stack/sheet/iron/drop in run_loc_floor_bottom_left)
		drop_count++
	TEST_ASSERT_EQUAL(drop_count, 1, "The first death did not produce exactly one drop.")
	animal.death()
	drop_count = 0
	for(var/obj/item/stack/sheet/iron/drop in run_loc_floor_bottom_left)
		drop_count++
	TEST_ASSERT_EQUAL(drop_count, 1, "A reanimated creature produced duplicate death drops.")

/// The shared recipe must produce the event cure only inside the colony.
/datum/unit_test/lazarus_reagent_recipe
	var/area/previous_area
	var/area/misc/testroom/normal_area
	var/area/lazarus/event_area
	var/area/previous_normal_registry
	var/area/previous_event_registry

/datum/unit_test/lazarus_reagent_recipe/Destroy()
	if(previous_area && (get_area(run_loc_floor_bottom_left) in list(normal_area, event_area)))
		set_turf_to_area(run_loc_floor_bottom_left, previous_area)
	if(normal_area)
		QDEL_NULL(normal_area)
		GLOB.areas_by_type[/area/misc/testroom] = previous_normal_registry
	if(event_area)
		QDEL_NULL(event_area)
		GLOB.areas_by_type[/area/lazarus] = previous_event_registry
	previous_area = null
	previous_normal_registry = null
	previous_event_registry = null
	return ..()

/datum/unit_test/lazarus_reagent_recipe/Run()
	previous_area = get_area(run_loc_floor_bottom_left)
	previous_normal_registry = GLOB.areas_by_type[/area/misc/testroom]
	previous_event_registry = GLOB.areas_by_type[/area/lazarus]
	normal_area = new /area/misc/testroom
	set_turf_to_area(run_loc_floor_bottom_left, normal_area)
	var/obj/item/reagent_containers/cup/beaker/beaker = allocate(/obj/item/reagent_containers/cup/beaker, run_loc_floor_bottom_left)
	beaker.reagents.flags |= REAGENT_HOLDER_INSTANT_REACT
	beaker.reagents.add_reagent(/datum/reagent/medicine/omnizine, 1)
	beaker.reagents.add_reagent(/datum/reagent/water/holywater, 1)
	beaker.reagents.add_reagent(/datum/reagent/toxin/mutagen, 1)
	TEST_ASSERT(beaker.reagents.has_reagent(/datum/reagent/medicine/strange_reagent), "The event changed the ordinary station's recipe.")
	TEST_ASSERT(!beaker.reagents.has_reagent(/datum/reagent/medicine/lazarus_reagent), "Ordinary chemistry produced the event-specific cure.")
	beaker.reagents.clear_reagents()
	event_area = new /area/lazarus
	set_turf_to_area(run_loc_floor_bottom_left, event_area)
	beaker.reagents.add_reagent(/datum/reagent/medicine/omnizine, 1)
	beaker.reagents.add_reagent(/datum/reagent/water/holywater, 1)
	beaker.reagents.add_reagent(/datum/reagent/toxin/mutagen, 1)
	TEST_ASSERT(beaker.reagents.has_reagent(/datum/reagent/medicine/lazarus_reagent), "The original recipe did not produce Lazarus Reagent inside the colony.")
	TEST_ASSERT(!beaker.reagents.has_reagent(/datum/reagent/medicine/strange_reagent), "The competing native reaction consumed the event recipe.")

/// Organic doors must initialize without minerals and leave no mined metal.
/datum/unit_test/lazarus_meaty_door_materials/Run()
	var/iron_before = 0
	for(var/obj/item/stack/sheet/iron/sheets in run_loc_floor_bottom_left)
		iron_before += sheets.amount
	for(var/disassembled in list(FALSE, TRUE))
		var/obj/structure/alien/resin/door/meaty/door = allocate(/obj/structure/alien/resin/door/meaty, run_loc_floor_bottom_left)
		TEST_ASSERT(!length(door.custom_materials), "A living door acquired mineral materials.")
		door.deconstruct(disassembled)
		TEST_ASSERT(QDELETED(door), "Deconstruction did not remove the living door.")
	var/iron_after = 0
	for(var/obj/item/stack/sheet/iron/sheets in run_loc_floor_bottom_left)
		iron_after += sheets.amount
	TEST_ASSERT_EQUAL(iron_after, iron_before, "Destroying or disassembling a living door produced free iron.")

/obj/item/ammo_box/magazine/wt550m9/lazarus_test_empty
	start_empty = TRUE

/obj/item/ammo_box/magazine/wt550m9/wtap/lazarus_test_empty
	start_empty = TRUE

/// Removing initially absent ammunition must preserve positive material remainders.
/datum/unit_test/lazarus_empty_magazine_materials/Run()
	var/obj/item/ammo_box/magazine/wt550m9/empty = allocate(/obj/item/ammo_box/magazine/wt550m9/lazarus_test_empty, run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(empty.ammo_count(), 0, "The colony's empty magazine gained ammunition.")
	TEST_ASSERT(!length(empty.custom_materials), "An empty standard magazine retained a zero material entry.")
	var/obj/item/ammo_box/magazine/wt550m9/wtap/armor_piercing = allocate(/obj/item/ammo_box/magazine/wt550m9/wtap/lazarus_test_empty, run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(armor_piercing.ammo_count(), 0, "An empty AP magazine gained ammunition.")
	TEST_ASSERT_EQUAL(armor_piercing.custom_materials[SSmaterials.get_material(/datum/material/iron)], SHEET_MATERIAL_AMOUNT, "An empty AP magazine lost its remaining iron.")
	TEST_ASSERT(abs(armor_piercing.custom_materials[SSmaterials.get_material(/datum/material/silver)] - SHEET_MATERIAL_AMOUNT * 0.6) < 0.001, "An empty AP magazine lost its silver.")
	var/obj/item/ammo_box/magazine/wt550m9/loaded = allocate(/obj/item/ammo_box/magazine/wt550m9, run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(loaded.ammo_count(), 20, "The ordinary loaded magazine lost ammunition.")
	TEST_ASSERT_EQUAL(loaded.custom_materials[SSmaterials.get_material(/datum/material/iron)], SHEET_MATERIAL_AMOUNT * 2, "The ordinary loaded magazine's material amount changed.")

#endif
