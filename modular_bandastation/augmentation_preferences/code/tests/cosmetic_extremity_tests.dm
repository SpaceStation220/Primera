/// Independent cosmetic choices must reach the preview and spawned character.
/datum/unit_test/cosmetic_extremity_preferences/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences, mock_client)
	preferences.value_cache[/datum/preference/choiced/species] = /datum/species/human
	preferences.value_cache[/datum/preference/body_modifications] = list()
	preferences.job_preferences = list(JOB_STATION_ENGINEER = JP_HIGH)
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	var/atom/movable/screen/map_view/char_preview/preview = preferences.create_character_preview_view(human)
	var/list/pref_types = list(
		/datum/preference/choiced/cosmetic_extremity/left_hand,
		/datum/preference/choiced/cosmetic_extremity/right_hand,
		/datum/preference/choiced/cosmetic_extremity/left_foot,
		/datum/preference/choiced/cosmetic_extremity/right_foot,
	)
	var/list/zones = list(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)
	var/list/sprite_zones = list(BODY_ZONE_PRECISE_L_HAND, BODY_ZONE_PRECISE_R_HAND, BODY_ZONE_PRECISE_L_FOOT, BODY_ZONE_PRECISE_R_FOOT)
	var/list/styles = list("Morpheus", "Hephaestus", "Hephaestus", "Bishop")
	var/list/states = list("morpheus_l_hand", "hephaestus_r_hand", "hephaestus_l_foot", "bishop_r_foot")
	var/list/initial_types = list()
	for(var/index in 1 to length(zones))
		var/obj/item/bodypart/limb = human.get_bodypart(zones[index])
		var/datum/preference/choiced/cosmetic_extremity/preference = GLOB.preference_entries[pref_types[index]]
		initial_types += limb.type
		TEST_ASSERT_EQUAL(preferences.read_preference(pref_types[index]), SPRITE_ACCESSORY_NONE, "Existing characters must default to their ordinary appearance.")
		var/list/preference_data = json_decode(json_encode(preference.compile_constant_data()))
		var/list/choices = preference_data["choices"]
		var/list/display_names = preference_data[CHOICED_PREFERENCE_DISPLAY_NAMES]
		TEST_ASSERT_EQUAL(display_names[SPRITE_ACCESSORY_NONE], "По умолчанию", "The editor has the wrong label for the ordinary appearance.")
		for(var/style as anything in preference.get_choices())
			TEST_ASSERT((style in choices) && istext(display_names[style]) && length(display_names[style]), "The editor is missing a choice or a label for [style].")
			if(style == SPRITE_ACCESSORY_NONE)
				continue
			var/sprite_state = "[lowertext(style)]_[sprite_zones[index]]"
			TEST_ASSERT(icon_exists('modular_bandastation/augmentation_preferences/icons/cosmetic_extremities.dmi', sprite_state), "[preference.type] offers a missing sprite: [sprite_state].")
			TEST_ASSERT(preferences.update_preference(preference, style), "The editor rejected [style] for [preference.type].")
			check_rendered_state(preview.body.get_bodypart(zones[index]), sprite_state)
		TEST_ASSERT(preferences.update_preference(preference, styles[index]), "The editor rejected [preference.type].")

	TEST_ASSERT(preferences.save_character(), "The cosmetic character options could not be saved.")
	TEST_ASSERT(preferences.load_character(), "The cosmetic character options could not be loaded.")
	preferences.apply_prefs_to(human)
	for(var/index in 1 to length(zones))
		TEST_ASSERT_EQUAL(preferences.read_preference(pref_types[index]), styles[index], "A cosmetic selection was lost during save/load.")
		var/obj/item/bodypart/limb = human.get_bodypart(zones[index])
		TEST_ASSERT_EQUAL(limb.type, initial_types[index], "A cosmetic selection replaced the actual limb.")
		check_rendered_state(limb, states[index])
		check_rendered_state(limb, states[index], dropped = TRUE)
		check_rendered_state(preview.body.get_bodypart(zones[index]), states[index])
	TEST_ASSERT(human.usable_hands == 2 && human.usable_legs == 2, "Cosmetic selections changed functional limb counts.")
	TEST_ASSERT(preview.body.gloves && preview.body.shoes, "The default preview lost the engineer's gloves or boots.")
	preview.show_cosmetic_extremities = TRUE
	preview.update_body()
	TEST_ASSERT(!preview.body.gloves && !preview.body.shoes && !preview.body.socks, "The cosmetic preview left the selected extremities covered.")
	check_rendered_state(preview.body.get_bodypart(BODY_ZONE_L_LEG), "hephaestus_l_foot")

	TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[/datum/preference/choiced/cosmetic_extremity/left_foot], SPRITE_ACCESSORY_NONE), "The editor could not restore the default left foot.")
	var/obj/item/bodypart/left_leg = preview.body.get_bodypart(BODY_ZONE_L_LEG)
	TEST_ASSERT_NULL(left_leg.cosmetic_extremity_style, "The preview kept a stale cosmetic left foot.")
	check_rendered_state(preview.body.get_bodypart(BODY_ZONE_R_LEG), "bishop_r_foot")

	for(var/datum/species/species_type as anything in list(/datum/species/human/felinid, /datum/species/human/cerulean))
		var/species_id = initial(species_type.id)
		var/available_parts = species_id == SPECIES_CERULEAN ? 2 : length(zones)
		var/list/selected_styles = species_id == SPECIES_FELINE ? list("Bishop", "Morpheus", "Morpheus", "Hephaestus") : styles
		TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[/datum/preference/choiced/species], species_id), "The editor could not select [species_id].")
		TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/choiced/species), species_type, "The editor did not apply [species_id].")
		for(var/index in 1 to length(zones))
			var/datum/preference/preference = GLOB.preference_entries[pref_types[index]]
			if(index > available_parts)
				TEST_ASSERT(!preference.is_accessible(preferences), "The editor offered a foot prosthesis to [species_id].")
				continue
			TEST_ASSERT(preferences.update_preference(preference, selected_styles[index]), "The editor rejected [preference.savefile_key] for [species_id].")

		TEST_ASSERT(preferences.save_character() && preferences.load_character(), "The [species_id] cosmetic profile failed a savefile round trip.")
		TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/choiced/species), species_type, "The savefile round trip lost [species_id].")
		preview.update_body()
		var/mob/living/carbon/human/subspecies_character = allocate(/mob/living/carbon/human/consistent)
		preferences.apply_prefs_to(subspecies_character)
		TEST_ASSERT_EQUAL(subspecies_character.dna.species.type, species_type, "The spawned character lost [species_id].")
		if(species_id == SPECIES_CERULEAN)
			TEST_ASSERT(istype(subspecies_character.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAIL), /obj/item/organ/tail/fish/cerulean), "The saved cosmetic profile lost the Cerulean tail.")
			TEST_ASSERT_NULL(preview.body.gloves, "The Cerulean preview left gloves covering the prostheses.")
		for(var/index in 1 to length(zones))
			var/obj/item/bodypart/limb = subspecies_character.get_bodypart(zones[index])
			var/obj/item/bodypart/preview_limb = preview.body.get_bodypart(zones[index])
			if(index > available_parts)
				TEST_ASSERT_NULL(limb, "The saved cosmetic profile gave [species_id] a leg.")
				TEST_ASSERT_NULL(preview_limb, "The [species_id] preview gained a leg.")
				continue
			TEST_ASSERT_EQUAL(preferences.read_preference(pref_types[index]), selected_styles[index], "The [species_id] profile lost a cosmetic choice.")
			var/sprite_state = "[lowertext(selected_styles[index])]_[sprite_zones[index]]"
			check_rendered_state(limb, sprite_state)
			check_rendered_state(preview_limb, sprite_state)

	TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_IPC), "The editor could not select IPC species.")
	TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[/datum/preference/choiced/ipc/chassis], /datum/ipc_chassis/hephaestus::name), "The editor could not select an IPC chassis.")
	TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[/datum/preference/color/ipc/chassis], "#223344"), "The editor could not select an IPC chassis tint.")
	for(var/preference_type as anything in pref_types)
		TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[preference_type], SPRITE_ACCESSORY_NONE), "The IPC editor could not select native extremities.")
	preview.update_body()
	preferences.apply_prefs_to(human)
	var/list/native_ipc_appearances = list()
	var/list/native_ipc_types = list()
	var/ipc_color = native_ipc_hand_color(preview.body.get_bodypart(BODY_ZONE_L_ARM))
	var/ipc_sprites = 'modular_bandastation/augmentation_preferences/icons/ipc_cosmetic_extremities.dmi'
	for(var/index in 1 to length(zones))
		var/obj/item/bodypart/limb = preview.body.get_bodypart(zones[index])
		native_ipc_appearances += limb_appearance(limb)
		native_ipc_types += limb.type
		var/datum/preference/choiced/cosmetic_extremity/preference = GLOB.preference_entries[pref_types[index]]
		TEST_ASSERT(preference.is_accessible(preferences), "The editor hid [preference.type] from an IPC.")
		for(var/style as anything in preference.get_choices())
			if(style == SPRITE_ACCESSORY_NONE)
				continue
			TEST_ASSERT(preferences.update_preference(preference, style), "The IPC editor rejected [style] for [preference.type].")
			check_rendered_state(preview.body.get_bodypart(zones[index]), "[lowertext(style)]_[sprite_zones[index]]", source_file = ipc_sprites, expected_color = ipc_color)
		TEST_ASSERT(preferences.update_preference(preference, styles[index]), "The IPC editor rejected the independent style for [preference.type].")

	TEST_ASSERT(preferences.save_character() && preferences.load_character(), "The IPC cosmetic choices failed a savefile round trip.")
	TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/choiced/species), /datum/species/ipc, "The savefile round trip lost IPC species.")
	preferences.apply_prefs_to(human)
	for(var/index in 1 to length(zones))
		var/obj/item/bodypart/limb = human.get_bodypart(zones[index])
		TEST_ASSERT_EQUAL(limb.type, native_ipc_types[index], "A cosmetic selection replaced an IPC limb.")
		TEST_ASSERT_EQUAL(limb.cosmetic_extremity_style, styles[index], "The IPC lost an independent cosmetic selection.")
		check_rendered_state(limb, states[index], source_file = ipc_sprites, expected_color = ipc_color)
		check_rendered_state(limb, states[index], dropped = TRUE, source_file = ipc_sprites, expected_color = ipc_color)
		TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[pref_types[index]], SPRITE_ACCESSORY_NONE), "The IPC editor could not restore a native hand or foot.")
		TEST_ASSERT_EQUAL(limb_appearance(preview.body.get_bodypart(zones[index])), native_ipc_appearances[index], "Restoring the default did not recover the chosen IPC chassis.")
	TEST_ASSERT(human.usable_hands == 2 && human.usable_legs == 2, "Cosmetic selections changed IPC functional limb counts.")
	TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[/datum/preference/choiced/cosmetic_extremity/right_foot], "Bishop"), "The IPC could not select a right foot before changing chassis.")
	var/obj/item/bodypart/right_leg = preview.body.get_bodypart(BODY_ZONE_R_LEG)
	var/original_chassis_cache_key = right_leg.get_cache_key()
	TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[/datum/preference/choiced/ipc/chassis], /datum/ipc_chassis/shellguard::name), "The IPC editor could not change chassis.")
	right_leg = preview.body.get_bodypart(BODY_ZONE_R_LEG)
	TEST_ASSERT_NOTEQUAL(right_leg.get_cache_key(), original_chassis_cache_key, "The IPC retained a stale leg render key after changing chassis with a selected cosmetic foot.")
	TEST_ASSERT_NOTEQUAL(limb_appearance(preview.body.get_bodypart(BODY_ZONE_L_LEG)), native_ipc_appearances[3], "The default IPC foot did not follow a changed chassis.")
	check_rendered_state(preview.body.get_bodypart(BODY_ZONE_R_LEG), "bishop_r_foot", source_file = ipc_sprites, expected_color = ipc_color)
	TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[/datum/preference/color/ipc/chassis], "#664422"), "The IPC editor could not change chassis tint.")
	check_rendered_state(preview.body.get_bodypart(BODY_ZONE_R_LEG), "bishop_r_foot", source_file = ipc_sprites, expected_color = native_ipc_hand_color(preview.body.get_bodypart(BODY_ZONE_L_ARM)))

	preferences.value_cache[/datum/preference/choiced/species] = /datum/species/lizard
	TEST_ASSERT(!preferences.update_preference(GLOB.preference_entries[/datum/preference/choiced/cosmetic_extremity/left_hand], "Bishop"), "The editor accepted cosmetic extremities for a lizard.")
	preview.update_body()
	var/obj/item/bodypart/left_arm = preview.body.get_bodypart(BODY_ZONE_L_ARM)
	TEST_ASSERT_NULL(left_arm.cosmetic_extremity_style, "A saved cosmetic style was applied to the lizard preview.")

/datum/unit_test/cosmetic_extremity_preferences/proc/limb_appearance(obj/item/bodypart/limb)
	var/image/appearance = image('icons/blanks/32x32.dmi', "nothing")
	appearance.overlays = limb.get_limb_icon(dropped = TRUE)
	return icon2base64(getFlatIcon(appearance, no_anim = TRUE))

/datum/unit_test/cosmetic_extremity_preferences/proc/native_ipc_hand_color(obj/item/bodypart/limb)
	for(var/image/limb_image as anything in limb.get_limb_icon(dropped = TRUE))
		if(limb_image.icon_state == "ipc_[limb.aux_zone]")
			return limb_image.color
	TEST_FAIL("The selected IPC chassis did not render its default hand.")

/datum/unit_test/cosmetic_extremity_preferences/proc/check_rendered_state(obj/item/bodypart/limb, expected_state, dropped = FALSE, source_file = 'modular_bandastation/augmentation_preferences/icons/cosmetic_extremities.dmi', expected_color)
	var/list/limb_images = dropped ? limb.get_limb_icon(dropped = TRUE) : limb.owner.overlays_standing[BODYPARTS_LAYER]
	var/image/source_image = image(source_file, expected_state, dir = SOUTH)
	source_image.color = expected_color
	var/icon/source = getFlatIcon(source_image, no_anim = TRUE)
	var/image/selected_images = image('icons/blanks/32x32.dmi', "nothing", dir = SOUTH)
	for(var/image/limb_image as anything in limb_images)
		if(limb_image.icon_state == expected_state)
			selected_images.overlays += limb_image
	// Leg masking splits the selected foot across two unnamed dynamic icons.
	var/icon/rendered = getFlatIcon(selected_images, no_anim = TRUE)
	for(var/x in 1 to source.Width())
		for(var/y in 1 to source.Height())
			if(rendered.GetPixel(x, y) != source.GetPixel(x, y))
				TEST_FAIL("[limb.body_zone] did not render [expected_state] at [x],[y] with its expected color.")
				return
