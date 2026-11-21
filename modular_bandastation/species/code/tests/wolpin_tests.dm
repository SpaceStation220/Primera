/// The race mutation must choose the species-specific lesser form and restore its original body.
/datum/unit_test/wolpin_transformation/Run()
	var/mob/living/carbon/human/subject = allocate(/mob/living/carbon/human/consistent)
	subject.set_species(/datum/species/vulpkanin)
	var/original_name = subject.real_name
	subject.dna.add_mutation(/datum/mutation/race, MUTATION_SOURCE_ACTIVATED)
	var/deadline = world.time + 10 SECONDS
	UNTIL(!subject.transformation_timer || world.time >= deadline)
	TEST_ASSERT(is_species(subject, /datum/species/monkey/wolpin), "The race mutation turned a vulpkanin into the wrong lesser form.")
	TEST_ASSERT(ismonkey(subject), "The wolpin must remain compatible with lesser-form machinery.")
	TEST_ASSERT(istype(subject.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAIL), /obj/item/organ/tail/monkey/wolpin), "The wolpin has the wrong tail.")
	for(var/obj/item/bodypart/part as anything in subject.get_bodyparts())
		TEST_ASSERT_EQUAL(part.limb_id, "wolpin", "A wolpin retained a greater-form or monkey limb.")
	subject.dna.remove_mutation(/datum/mutation/race, MUTATION_SOURCE_ACTIVATED)
	deadline = world.time + 10 SECONDS
	UNTIL(!subject.transformation_timer || world.time >= deadline)
	TEST_ASSERT(is_species(subject, /datum/species/vulpkanin), "Removing the race mutation did not restore the vulpkanin.")
	TEST_ASSERT_EQUAL(subject.real_name, original_name, "The roundtrip lost the original name.")

/// Cube-born wolpins must count against the population cap and humanize into vulpkanin.
/datum/unit_test/wolpin_cube/Run()
	var/turf/spawn_turf = run_loc_floor_bottom_left
	var/obj/item/food/monkeycube/wolpin/cube = allocate(/obj/item/food/monkeycube/wolpin, spawn_turf)
	cube.Expand()
	var/mob/living/carbon/human/species/monkey/wolpin/subject = locate() in spawn_turf
	TEST_ASSERT_NOTNULL(subject, "Wetting a wolpin cube did not create a wolpin.")
	allocated += subject
	TEST_ASSERT(subject in SSmobs.cubemonkeys, "A cube-born wolpin bypassed population accounting.")
	subject.dna.remove_mutation(/datum/mutation/race, MUTATION_SOURCE_ACTIVATED)
	var/deadline = world.time + 10 SECONDS
	UNTIL(!subject.transformation_timer || world.time >= deadline)
	TEST_ASSERT(is_species(subject, /datum/species/vulpkanin), "A cube-born wolpin humanized into a human.")
/// Mixed fractional batches must not create extra cubes or change their species.
/datum/unit_test/wolpin_recycling/Run()
	var/mob/living/carbon/human/operator = allocate(/mob/living/carbon/human/consistent)
	var/obj/machinery/monkey_recycler/recycler = allocate(/obj/machinery/monkey_recycler, run_loc_floor_bottom_left)
	for(var/index in 1 to 5)
		var/mob/living/carbon/human/monkey = allocate(/mob/living/carbon/human/species/monkey)
		monkey.death()
		recycler.stuff_monkey_in(monkey, operator)
		var/mob/living/carbon/human/wolpin = allocate(/mob/living/carbon/human/species/monkey/wolpin)
		wolpin.death()
		recycler.stuff_monkey_in(wolpin, operator)
		if(index == 3)
			recycler.interact(operator)
			TEST_ASSERT_NULL(locate(/obj/item/food/monkeycube) in get_turf(recycler), "Mixed fractions printed a cube before either species had enough material.")
	recycler.interact(operator)
	var/monkey_cubes = 0
	var/wolpin_cubes = 0
	for(var/obj/item/food/monkeycube/cube in get_turf(recycler))
		allocated += cube
		if(cube.type == /obj/item/food/monkeycube)
			monkey_cubes++
		else if(cube.type == /obj/item/food/monkeycube/wolpin)
			wolpin_cubes++
	TEST_ASSERT_EQUAL(monkey_cubes, 1, "Five monkeys must yield one monkey cube at default efficiency.")
	TEST_ASSERT_EQUAL(wolpin_cubes, 1, "Five wolpins must yield one wolpin cube at default efficiency.")
	recycler.interact(operator)
	var/list/cubes_after_repeat = list()
	for(var/obj/item/food/monkeycube/cube in get_turf(recycler))
		cubes_after_repeat += cube
	TEST_ASSERT_EQUAL(length(cubes_after_repeat), 2, "Repeated printing duplicated cubes.")
/// Pooled organs must not pick up a monkey's tail style from DNA on insertion.
/datum/unit_test/wolpin_tail_appearance/Run()
	var/mob/living/carbon/human/subject = allocate(/mob/living/carbon/human/consistent)
	subject.dna.features[FEATURE_TAIL_MONKEY] = "Monkey"
	subject.set_species(/datum/species/monkey/wolpin)
	var/obj/item/organ/tail/tail = subject.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAIL)
	TEST_ASSERT_EQUAL(tail.bodypart_overlay.sprite_datum.type, /datum/sprite_accessory/tails/monkey/wolpin, "A pooled wolpin tail imprinted the monkey tail style.")
	tail.Remove(subject, special = TRUE)
	tail.exit_wardrobe()
	tail.Insert(subject, special = TRUE)
	TEST_ASSERT_EQUAL(tail.bodypart_overlay.sprite_datum.type, /datum/sprite_accessory/tails/monkey/wolpin, "Reusing a wolpin tail changed its appearance.")
/// Unmasked limb rendering must resolve both the body sprite and the auxiliary hand layer.
/datum/unit_test/wolpin_visible_paws/Run()
	var/mob/living/carbon/human/species/monkey/wolpin/subject = allocate(/mob/living/carbon/human/species/monkey/wolpin)
	for(var/obj/item/bodypart/part as anything in subject.get_bodyparts())
		for(var/image/overlay as anything in part.get_limb_icon(TRUE))
			TEST_ASSERT(icon_exists(overlay.icon, overlay.icon_state), "Wolpin limb [part.body_zone] produced a missing render state: [overlay.icon_state].")
	var/datum/emote/scream_emote = GLOB.emote_list[/datum/emote/living/scream::key][1]
	TEST_ASSERT_EQUAL(scream_emote.get_sound(subject), 'sound/mobs/non-humanoids/wolpin/dog_yelp.ogg', "Wolpin scream did not use the canine sound.")

/// The body layers sent to the client must retain the original wolpin proportions.
/datum/unit_test/wolpin_body_height_filter/Run()
	var/mob/living/carbon/human/subject = allocate(/mob/living/carbon/human/consistent)
	subject.set_species(/datum/species/vulpkanin)
	subject.monkeyize(instant = TRUE)
	var/list/body_overlays = subject.overlays_standing[BODYPARTS_LAYER]
	TEST_ASSERT(length(body_overlays), "The transformed wolpin has no body overlays.")
	for(var/image/overlay as anything in body_overlays)
		TEST_ASSERT_NULL(overlay.get_filter_data("Monkey_Legs"), "An applied wolpin body overlay still has the monkey leg displacement filter.")
		TEST_ASSERT_NULL(overlay.get_filter_data("Monkey_Torso"), "An applied wolpin body overlay still has the monkey torso displacement filter.")
