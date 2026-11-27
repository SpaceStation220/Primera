/// Wash a mixed sample, scan it with and without UV, then sterilize it.
/datum/unit_test/forensic_blood_residue/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/detective_scanner/scanner = allocate(/obj/item/detective_scanner)
	user.put_in_active_hand(scanner)
	var/obj/item/knife/knife = allocate(/obj/item/knife)
	var/obj/item/flashlight/forensic_uv/uv = allocate(/obj/item/flashlight/forensic_uv)
	var/obj/item/reagent_containers/cup/beaker/cleaner = allocate(/obj/item/reagent_containers/cup/beaker)
	cleaner.reagents.add_reagent(/datum/reagent/space_cleaner, 5)
	var/list/first = list("0123456789abcdef0123456789abcdef" = get_blood_type(/datum/blood_type/human/a_plus))
	var/list/second = list("fedcba9876543210fedcba9876543210" = get_blood_type(/datum/blood_type/lizard))
	knife.add_blood_DNA(first)
	cleaner.reagents.expose(knife, TOUCH)
	knife.add_blood_DNA(second)
	cleaner.reagents.expose(knife, TOUCH)
	TEST_ASSERT_NULL(GET_ATOM_BLOOD_DNA(knife), "A washed knife still carries transferable blood.")
	scanner.scan(user, knife)
	var/datum/detective_scanner_log/result = scanner.log_data[1]
	TEST_ASSERT_NULL(result.data_entries[DETSCAN_CATEGORY_BLOOD], "A normal scan disclosed washed DNA without UV.")
	uv.attack_self(user)
	scanner.scan(user, knife)
	result = scanner.log_data[2]
	TEST_ASSERT_NULL(result.data_entries[DETSCAN_CATEGORY_BLOOD], "UV alone disclosed an untreated residue.")
	var/obj/item/reagent_containers/spray/fluorescein/spray = allocate(/obj/item/reagent_containers/spray/fluorescein)
	user.put_in_inactive_hand(spray)
	TEST_ASSERT(spray.try_spray(knife, user), "The detective could not apply the spray to the washed knife.")
	user.dropItemToGround(spray)
	scanner.scan(user, knife)
	result = scanner.log_data[3]
	var/datum/detective_scanner_data_entry/blood = result.data_entries[DETSCAN_CATEGORY_BLOOD]
	TEST_ASSERT_NOTNULL(blood, "The scanner missed the UV-revealed stain.")
	TEST_ASSERT_EQUAL(length(blood.data), 2, "The scanner lost a donor in the mixed stain.")
	var/list/donors_by_type = list("A+" = first[1], "L" = second[1])
	for(var/profile, blood_type in blood.data)
		var/original = donors_by_type[blood_type]
		TEST_ASSERT_NOTNULL(original, "The scanner lost the donor's blood type.")
		var/missing = stringpercent(profile, "?")
		TEST_ASSERT(missing > 0 && missing < length(original), "A washed profile must contain both missing and readable characters.")
		TEST_ASSERT_EQUAL(stringmerge(profile, original, "?"), original, "Readable characters did not match the donor at their original positions.")
		TEST_ASSERT_EQUAL(length(profile), length(original), "The scanner changed the profile length.")
	var/list/first_readings = blood.data.Copy()

	var/list/lit_overlays = knife.overlays.Copy()
	uv.attack_self(user)
	TEST_ASSERT(length(lit_overlays - knife.overlays), "A treated knife still glowed without UV.")
	scanner.scan(user, knife)
	result = scanner.log_data[4]
	TEST_ASSERT_NULL(result.data_entries[DETSCAN_CATEGORY_BLOOD], "The dye alone disclosed washed DNA.")
	uv.attack_self(user)
	TEST_ASSERT_EQUAL(length(lit_overlays - knife.overlays), 0, "The treated trace did not return under UV.")
	var/obj/item/storage/backpack/bag = allocate(/obj/item/storage/backpack)
	knife.forceMove(bag)
	TEST_ASSERT(length(lit_overlays - knife.overlays), "A washed item still glowed inside a bag.")
	user.put_in_inactive_hand(knife)
	TEST_ASSERT_EQUAL(length(lit_overlays - knife.overlays), 0, "A held item did not reappear under the stationary lamp.")
	scanner.scan(user, knife)
	result = scanner.log_data[5]
	blood = result.data_entries[DETSCAN_CATEGORY_BLOOD]
	TEST_ASSERT_NOTNULL(blood, "A second scan missed the same revealed stain.")
	TEST_ASSERT_EQUAL(length(blood.data), length(first_readings), "Rescanning changed the number of readings.")
	for(var/profile, blood_type in first_readings)
		TEST_ASSERT_EQUAL(blood.data[profile], blood_type, "Rescanning the same stain changed its partial profile.")

	cleaner.reagents.clear_reagents()
	cleaner.reagents.add_reagent(/datum/reagent/space_cleaner/sterilizine, 5)
	cleaner.reagents.expose(knife, TOUCH)
	scanner.scan(user, knife)
	result = scanner.log_data[6]
	TEST_ASSERT_NULL(result.data_entries[DETSCAN_CATEGORY_BLOOD], "Sterilized DNA reappeared on the scanner.")
	knife.add_blood_DNA(second)
	scanner.scan(user, knife)
	result = scanner.log_data[7]
	blood = result.data_entries[DETSCAN_CATEGORY_BLOOD]
	TEST_ASSERT_NOTNULL(blood, "The scanner missed fresh blood.")
	TEST_ASSERT(second[1] in blood.data, "The scanner masked the DNA of fresh blood.")
	knife.wash(CLEAN_WASH)
	spray.reagents.expose(knife, VAPOR)
	scanner.scan(user, knife)
	result = scanner.log_data[8]
	blood = result.data_entries[DETSCAN_CATEGORY_BLOOD]
	TEST_ASSERT_NOTNULL(blood, "Fresh blood could not leave a new trace after sterilization.")
	TEST_ASSERT_EQUAL(length(blood.data), 1, "Sterilization preserved an older sample.")
	TEST_ASSERT_EQUAL(blood.data[blood.data[1]], "L", "The new residue's blood type changed.")

/// The rendered UV stain changes only pixels where the weapon and blood pattern overlap.
/datum/unit_test/forensic_uv_item_mask/Run()
	var/obj/item/knife/knife = allocate(/obj/item/knife)
	knife.add_blood_DNA(list("sample" = get_blood_type(/datum/blood_type/human/a_plus)))
	knife.wash(CLEAN_WASH)
	var/icon/clean = getFlatIcon(knife)
	var/obj/item/reagent_containers/spray/fluorescein/spray = allocate(/obj/item/reagent_containers/spray/fluorescein)
	spray.reagents.expose(knife, VAPOR)
	var/obj/item/flashlight/forensic_uv/uv = allocate(/obj/item/flashlight/forensic_uv)
	uv.attack_self()
	var/icon/lit = getFlatIcon(knife)
	var/icon/pattern = icon('icons/effects/blood.dmi', "itemblood")
	var/changed = 0
	for(var/x in 1 to clean.Width())
		for(var/y in 1 to clean.Height())
			var/pixel = clean.GetPixel(x, y)
			if(lit.GetPixel(x, y) == pixel)
				continue
			TEST_ASSERT(pixel && pattern.GetPixel(x, y), "UV changed a pixel outside the intersection at [x],[y].")
			changed++
	TEST_ASSERT(changed, "UV did not reveal any pixels of the washed blade.")

/// Check the layers drawn on a character after spraying the wearer, including light from a pocket.
/datum/unit_test/forensic_uv_equipment/Run()
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/clothing/under/color/grey/uniform = allocate(__IMPLIED_TYPE__)
	var/obj/item/knife/knife = allocate(__IMPLIED_TYPE__)
	var/list/sample = list("sample" = get_blood_type(/datum/blood_type/human/a_plus))
	for(var/obj/item/item as anything in list(uniform, knife))
		item.add_blood_DNA(sample)
		item.wash(CLEAN_WASH)
	TEST_ASSERT(wearer.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING), "Could not equip the washed uniform.")
	TEST_ASSERT(wearer.put_in_active_hand(knife), "Could not hold the washed knife.")
	var/obj/item/flashlight/forensic_uv/lamp = allocate(__IMPLIED_TYPE__)
	lamp.attack_self()
	TEST_ASSERT(wearer.equip_to_slot_if_possible(lamp, ITEM_SLOT_LPOCKET), "Could not pocket the lit lamp.")

	var/clean_hand = icon2base64(getFlatIcon(wearer.overlays_standing[HANDS_LAYER][1], defdir = SOUTH, no_anim = TRUE))
	var/clean_uniform = icon2base64(getFlatIcon(wearer.overlays_standing[UNIFORM_LAYER], defdir = SOUTH, no_anim = TRUE))
	var/obj/item/reagent_containers/spray/fluorescein/spray = allocate(__IMPLIED_TYPE__)
	spray.reagents.expose(wearer, VAPOR)
	var/lit_hand = icon2base64(getFlatIcon(wearer.overlays_standing[HANDS_LAYER][1], defdir = SOUTH, no_anim = TRUE))
	var/lit_uniform = icon2base64(getFlatIcon(wearer.overlays_standing[UNIFORM_LAYER], defdir = SOUTH, no_anim = TRUE))
	TEST_ASSERT_NOTEQUAL(lit_hand, clean_hand, "The in-hand knife sprite did not reveal blood under the pocket lamp.")
	TEST_ASSERT_NOTEQUAL(lit_uniform, clean_uniform, "The worn uniform did not reveal blood under the pocket lamp.")

	var/obj/item/storage/backpack/bag = allocate(__IMPLIED_TYPE__)
	wearer.transferItemToLoc(lamp, bag)
	TEST_ASSERT_EQUAL(icon2base64(getFlatIcon(wearer.overlays_standing[HANDS_LAYER][1], defdir = SOUTH, no_anim = TRUE)), clean_hand, "A lamp in a bag still illuminated the knife.")
	TEST_ASSERT_EQUAL(icon2base64(getFlatIcon(wearer.overlays_standing[UNIFORM_LAYER], defdir = SOUTH, no_anim = TRUE)), clean_uniform, "The uniform kept its UV overlay after losing the light.")

/// Two walking directions washed separately on the same tile must both be visible under UV.
/datum/unit_test/forensic_uv_footprint_directions/Run()
	var/mob/living/carbon/human/walker = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/clothing/shoes/shoes = allocate(__IMPLIED_TYPE__)
	walker.equip_to_slot_if_possible(shoes, ITEM_SLOT_FEET)
	var/turf/pool_tile = get_step(run_loc_floor_bottom_left, NORTH)
	var/turf/target = get_step(pool_tile, EAST)
	var/obj/effect/decal/cleanable/blood/pool = allocate(/obj/effect/decal/cleanable/blood, pool_tile, null, walker.get_blood_dna_list())
	pool.bloodiness = BLOOD_POOL_MAX
	var/list/clean_floor = target.overlays.Copy()
	var/obj/item/reagent_containers/spray/fluorescein/spray = allocate(__IMPLIED_TYPE__)
	var/obj/item/flashlight/forensic_uv/lamp = allocate(__IMPLIED_TYPE__)
	lamp.attack_self()
	for(var/direction in list(EAST, NORTH))
		walker.forceMove(pool_tile)
		sleep(world.tick_lag) // Bloody soles do not deposit a new print on the pickup tick.
		walker.setDir(direction)
		walker.forceMove(target)
		target.wash(CLEAN_WASH)
		spray.reagents.expose(target, VAPOR)
		var/list/revealed = target.overlays - clean_floor
		TEST_ASSERT_EQUAL(length(revealed), 1, "The footprint did not leave a single revealed shape.")
		var/image/shape = revealed[1]
		var/list/directions = list()
		for(var/image/step_image as anything in shape.overlays)
			if(step_image.plane == FLOAT_PLANE && step_image.icon_state == "blood1")
				directions |= step_image.dir
		TEST_ASSERT(direction in directions, "The new walking direction was missing.")
		TEST_ASSERT(EAST in directions, "Washing the second print erased the first walking direction.")
	target.wash(CLEAN_WASH | CLEAN_TYPE_BLOOD_RESIDUE)

/// Compare real light sources against the same stationary evidence in the unlit test room.
/datum/unit_test/forensic_uv_contrast
	/// Restore the test room's fullbright turf if a lighting overlay was needed.
	var/turf/added_lighting_at

/datum/unit_test/forensic_uv_contrast/Destroy()
	added_lighting_at?.lighting_clear_overlay()
	added_lighting_at = null
	return ..()

/datum/unit_test/forensic_uv_contrast/Run()
	var/turf/sample_turf = run_loc_floor_bottom_left
	if(!sample_turf.lighting_object)
		sample_turf.lighting_build_overlay()
		added_lighting_at = sample_turf
	var/obj/item/knife/knife = allocate(/obj/item/knife, sample_turf)
	knife.add_blood_DNA(list("sample" = get_blood_type(/datum/blood_type/human/a_plus)))
	knife.wash(CLEAN_WASH)
	var/turf/near = get_step(sample_turf, EAST)
	var/obj/item/reagent_containers/spray/fluorescein/spray = allocate(/obj/item/reagent_containers/spray/fluorescein)
	spray.reagents.expose(knife, VAPOR)
	var/turf/far = get_step(near, EAST)
	var/obj/item/flashlight/forensic_uv/uv = allocate(/obj/item/flashlight/forensic_uv, far)
	uv.attack_self()
	var/datum/component/blood_residue/residue = knife.GetComponent(/datum/component/blood_residue)
	var/image/stain = residue.displayed[1]
	var/far_alpha = stain.alpha
	uv.forceMove(near)
	stain = residue.displayed[1]
	var/near_alpha = stain.alpha
	uv.forceMove(sample_turf)
	stain = residue.displayed[1]
	var/dark_alpha = stain.alpha
	TEST_ASSERT(0 < far_alpha && far_alpha < near_alpha && near_alpha < dark_alpha, "Approaching an already visible stain did not progressively brighten it.")
	var/turf/third = get_step(far, EAST)
	var/turf/fourth = get_step(third, EAST)
	uv.forceMove(third)
	stain = residue.displayed[1]
	TEST_ASSERT(stain.alpha > dark_alpha / 3, "The trace was already too faint three tiles from the source.")
	uv.forceMove(fourth)
	stain = residue.displayed[1]
	var/fourth_alpha = stain.alpha
	TEST_ASSERT(fourth_alpha < dark_alpha / 10, "Four tiles from the source, the stain was still conspicuous.")
	// The room fits a radius of five along a 3-4-5 triangle.
	uv.forceMove(get_ranged_target_turf(fourth, NORTH, 3))
	stain = residue.displayed[1]
	TEST_ASSERT(stain.alpha > 0 && stain.alpha < fourth_alpha / 2, "The fifth tile should show only a faint trace.")
	uv.forceMove(run_loc_floor_top_right)
	TEST_ASSERT_EQUAL(length(residue.displayed), 0, "The corner outside the circular light still revealed the knife.")
	uv.forceMove(sample_turf)
	var/obj/item/flashlight/forensic_uv/second = allocate(/obj/item/flashlight/forensic_uv, far)
	second.attack_self()
	stain = residue.displayed[1]
	TEST_ASSERT_EQUAL(stain.alpha, dark_alpha, "A weaker UV source washed out the stronger source.")
	uv.attack_self()
	stain = residue.displayed[1]
	TEST_ASSERT_EQUAL(stain.alpha, far_alpha, "Switching off the nearest UV source did not restore the weaker exposure.")
	uv.attack_self()
	var/obj/effect/dummy/lighting_obj/white_light = allocate(/obj/effect/dummy/lighting_obj, sample_turf, 2, 1, COLOR_WHITE)
	var/deadline = world.time + 5 * SSobj.wait
	UNTIL(residue.glow_alpha < dark_alpha || world.time >= deadline)
	stain = residue.displayed[1]
	TEST_ASSERT(stain.alpha > 0 && stain.alpha < dark_alpha, "White light did not reduce the contrast of the stationary UV stain.")
	white_light.set_light_on(FALSE)
	deadline = world.time + 5 * SSobj.wait
	UNTIL(residue.glow_alpha == dark_alpha || world.time >= deadline)
	stain = residue.displayed[1]
	TEST_ASSERT_EQUAL(stain.alpha, dark_alpha, "Turning the room light off did not restore the original contrast.")

/// Cover changes and independent light sources must update an existing stain on a stationary floor.
/datum/unit_test/forensic_uv_field/Run()
	var/turf/origin = run_loc_floor_bottom_left
	var/turf/between = get_step(origin, EAST)
	var/turf/target = get_step(between, EAST)
	var/obj/item/flashlight/forensic_uv/first = allocate(/obj/item/flashlight/forensic_uv, origin)
	var/obj/item/flashlight/forensic_uv/second = allocate(/obj/item/flashlight/forensic_uv, origin)
	first.attack_self()
	second.attack_self()
	var/list/sample = list("sample" = get_blood_type(/datum/blood_type/lizard))
	var/obj/effect/decal/cleanable/blood/pool = allocate(/obj/effect/decal/cleanable/blood, target, null, sample)
	var/list/clean_floor = target.overlays.Copy()
	target.wash(CLEAN_WASH)
	TEST_ASSERT(QDELETED(pool), "Washing left an active blood pool.")
	var/datum/component/blood_residue/residue = target.GetComponent(/datum/component/blood_residue)
	TEST_ASSERT_NOTNULL(residue, "The wet stain left no evidence.")
	allocated += residue
	TEST_ASSERT_EQUAL(length(target.overlays - clean_floor), 0, "Untreated floor evidence glowed under UV.")
	var/obj/item/reagent_containers/spray/fluorescein/spray = allocate(/obj/item/reagent_containers/spray/fluorescein)
	spray.reagents.expose(target, VAPOR)
	TEST_ASSERT(length(target.overlays - clean_floor), "A new trace under a stationary lamp was invisible.")
	TEST_ASSERT_EQUAL(target.wash(CLEAN_SCRUB), NONE, "A second wash awarded another clean.")
	first.attack_self()
	TEST_ASSERT(length(target.overlays - clean_floor), "Switching off one lamp hid the second lamp's stain.")
	var/obj/machinery/door/window/instant/door = allocate(/obj/machinery/door/window/instant, between)
	door.open(BYPASS_DOOR_CHECKS)
	door.close(BYPASS_DOOR_CHECKS)
	TEST_ASSERT_EQUAL(length(target.overlays - clean_floor), 0, "UV passed through an opaque obstruction.")
	door.open(BYPASS_DOOR_CHECKS)
	TEST_ASSERT(length(target.overlays - clean_floor), "The stationary lamp missed the reopened sight line.")

	var/mob/living/carbon/human/carrier = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/detective_scanner/scanner = allocate(/obj/item/detective_scanner)
	carrier.put_in_inactive_hand(scanner)
	scanner.scan(carrier, target)
	var/datum/detective_scanner_log/log_entry = scanner.log_data[1]
	var/datum/detective_scanner_data_entry/blood = log_entry.data_entries[DETSCAN_CATEGORY_BLOOD]
	TEST_ASSERT_NOTNULL(blood, "Scanning the illuminated floor missed the washed pool.")
	var/profile = blood.data[1]
	TEST_ASSERT(findtext(profile, "?"), "The washed floor disclosed the full profile.")
	TEST_ASSERT_EQUAL(stringmerge(profile, "sample", "?"), "sample", "The floor scan reported the wrong donor.")
	TEST_ASSERT_EQUAL(blood.data[profile], "L", "The floor scan reported the wrong blood type.")
	carrier.put_in_active_hand(second)
	var/obj/structure/closet/closet = allocate(/obj/structure/closet, origin)
	carrier.forceMove(closet)
	TEST_ASSERT_EQUAL(length(target.overlays - clean_floor), 0, "A lamp inside a closet still illuminated the floor.")
	carrier.forceMove(origin)
	TEST_ASSERT(length(target.overlays - clean_floor), "Moving a held lamp out of storage did not reveal the stain.")
	qdel(second)
	TEST_ASSERT_EQUAL(length(target.overlays - clean_floor), 0, "Deleting the last lamp left the stain visible.")

	var/obj/item/reagent_containers/cup/beaker/sterilizer = allocate(/obj/item/reagent_containers/cup/beaker)
	sterilizer.reagents.add_reagent(/datum/reagent/space_cleaner/sterilizine, 5)
	sterilizer.reagents.expose(target, TOUCH)
	TEST_ASSERT(QDELETED(residue), "Sterilizine left the floor evidence behind.")
	allocate(/obj/effect/decal/cleanable/blood, target, null, list("Oil" = get_blood_type(/datum/blood_type/oil)))
	target.wash(CLEAN_WASH)
	TEST_ASSERT_NULL(target.GetComponent(/datum/component/blood_residue), "Oil left a forensic blood stain.")
