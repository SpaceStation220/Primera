/// Makes sure that crayons have their crayon_color in their initial name (to differentiate them in the crafting menu).
/datum/unit_test/crayon_naming

/datum/unit_test/crayon_naming/Run()
	for(var/obj/item/toy/crayon/crayon_path as anything in typesof(/obj/item/toy/crayon))
		if(is_path_in_list(crayon_path, list(/obj/item/toy/crayon/spraycan, /obj/item/toy/crayon)))
			continue
		var/obj/item/toy/crayon/real_crayon = new crayon_path
		if(!findtext(initial(real_crayon.name),real_crayon.crayon_color))
			TEST_FAIL("[real_crayon] does not have its crayon_color ([real_crayon.crayon_color]) in its initial name ([initial(real_crayon.name)]).")
		qdel(real_crayon)

/// Draw a directional sign, read it under UV, then remove it while it is hidden.
/datum/unit_test/forensic_uv_marker
	normal_floor_required = TRUE

/datum/unit_test/forensic_uv_marker/Run()
	var/mob/living/carbon/human/artist = allocate(/mob/living/carbon/human/consistent)
	var/turf/floor = get_step(artist, EAST)
	var/obj/item/toy/stencil_tool/uv_marker/marker = allocate(__IMPLIED_TYPE__)
	marker.attack_hand(artist)
	TEST_ASSERT(artist.is_holding(marker), "Could not pick up the marker.")
	TEST_ASSERT(length(GET_ATOM_FINGERPRINTS(marker)), "Handling the marker left no fingerprints.")
	artist.setDir(EAST)
	click_wrapper(artist, floor)
	var/obj/effect/decal/cleanable/crayon/uv_sign/sign = locate() in floor
	TEST_ASSERT_NOTNULL(sign, "The marker did not leave a UV sign.")
	allocated += sign
	TEST_ASSERT(!(sign in view(1, artist)), "The hidden sign appeared in ordinary view.")
	TEST_ASSERT_EQUAL(sign.icon_state, "arrow", "The selected stencil was lost.")
	var/matrix/east = matrix()
	east.Turn(90)
	TEST_ASSERT_EQUAL(sign.transform.get_angle(), east.get_angle(), "The arrow did not point east.")
	var/obj/item/flashlight/forensic_uv/lamp = allocate(__IMPLIED_TYPE__, floor)
	lamp.attack_self()
	TEST_ASSERT(sign in view(1, artist), "The nearby lamp did not reveal the ink.")
	var/near_alpha = sign.alpha
	lamp.forceMove(get_step(get_step(floor, EAST), EAST))
	TEST_ASSERT(sign.alpha > 0 && sign.alpha < near_alpha, "The sign did not fade with distance.")
	var/obj/item/detective_scanner/scanner = allocate(__IMPLIED_TYPE__)
	artist.put_in_inactive_hand(scanner)
	scanner.scan(artist, sign)
	var/datum/detective_scanner_log/result = scanner.log_data[1]
	TEST_ASSERT_EQUAL(length(result.data_entries), 0, "The ink gave the scanner forensic information.")
	TEST_ASSERT_NULL(GET_ATOM_HIDDENPRINTS(sign), "The sign retained its author's hidden print.")
	lamp.attack_self()
	TEST_ASSERT(!(sign in view(1, artist)), "The arrow stayed visible after switching off UV.")
	floor.wash(CLEAN_WASH)
	TEST_ASSERT(QDELETED(sign), "Ordinary washing left the hidden sign behind.")
	lamp.attack_self()
	TEST_ASSERT(!(locate(/obj/effect/decal/cleanable/crayon/uv_sign) in floor), "The washed sign reappeared.")

/// Observe entry to the ID paint dialog even though a headless player cannot answer it.
/obj/item/card/id/advanced/uv_marker_test
	var/recolor_attempts = 0

/obj/item/card/id/advanced/uv_marker_test/recolor_id(mob/living/user, obj/item/toy/crayon/our_crayon)
	recolor_attempts++
	return ..()

/datum/unit_test/forensic_uv_marker_surfaces/Run()
	var/mob/living/carbon/human/artist = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/toy/stencil_tool/uv_marker/marker = allocate(__IMPLIED_TYPE__)
	artist.put_in_active_hand(marker)
	var/turf/floor = get_step(artist, EAST)
	var/obj/item/clothing/head/helmet/space/plasmaman/helmet = allocate(__IMPLIED_TYPE__, floor)
	var/obj/item/card/id/advanced/uv_marker_test/card = allocate(__IMPLIED_TYPE__, floor)
	click_wrapper(artist, helmet)
	click_wrapper(artist, card)
	TEST_ASSERT_EQUAL(card.recolor_attempts, 0, "The UV marker opened the ID recolor interaction.")
	TEST_ASSERT(!helmet.smile, "The UV marker painted a visible smile on the visor.")

	var/obj/item/storage/backpack/bag = allocate(__IMPLIED_TYPE__, floor)
	click_wrapper(artist, bag)
	TEST_ASSERT_EQUAL(marker.loc, bag, "The backpack did not accept the marker.")
	var/obj/item/toy/crayon/red/crayon = allocate(__IMPLIED_TYPE__)
	artist.put_in_active_hand(crayon)
	click_wrapper(artist, helmet)
	click_wrapper(artist, card)
	TEST_ASSERT(helmet.smile, "An ordinary crayon could no longer draw on the visor.")
	TEST_ASSERT_EQUAL(card.recolor_attempts, 1, "An ordinary crayon could no longer recolor the ID.")
