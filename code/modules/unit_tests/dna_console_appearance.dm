/// The appearance panel must describe the current scanner occupant, including fork species, and clear on removal.
/datum/unit_test/dna_console_appearance

/datum/unit_test/dna_console_appearance/Run()
	var/mob/living/carbon/human/operator = allocate(/mob/living/carbon/human/consistent)
	var/obj/machinery/dna_scannernew/scanner = allocate(/obj/machinery/dna_scannernew, run_loc_floor_bottom_left)
	var/obj/machinery/computer/dna_console/console = allocate(/obj/machinery/computer/dna_console, run_loc_floor_top_right)
	console.set_connected_scanner(scanner)
	scanner.set_is_operational(TRUE)
	var/mob/living/carbon/human/subject = allocate(/mob/living/carbon/human/consistent)
	subject.set_species(/datum/species/vulpkanin)
	subject.set_hairstyle("Jagged", update = FALSE)
	subject.set_haircolor("#a26324", update = FALSE)
	subject.dna.features[FEATURE_VULPKANIN_HEAD_MARKINGS] = /datum/sprite_accessory/vulpkanin_head_markings/tiger_head::name
	subject.dna.features[FEATURE_VULPKANIN_HEAD_MARKINGS_COLOR] = "#2b2015"
	subject.dna.features[FEATURE_MUTANT_COLOR] = "#d69e67"
	subject.dna.features[FEATURE_VULPKANIN_TAIL] = "Default"
	subject.dna.features[FEATURE_VULPKANIN_TAIL_MARKINGS] = SPRITE_ACCESSORY_NONE
	subject.dna.features[FEATURE_IPC_HEAD] = /datum/ipc_chassis/morpheus::name
	subject.dna.features[FEATURE_IPC_CHASSIS_COLOR] = "#123456"
	subject.update_body(is_creating = TRUE)
	subject.dna.update_dna_identity()
	scanner.open_machine()
	TEST_ASSERT(scanner.close_machine(subject), "The subject must enter the real scanner.")
	console.can_use_scanner = console.scanner_operational()
	console.is_viable_occupant = console.can_modify_occupant()
	var/original_features = json_encode(subject.dna.features)
	var/original_identity = subject.dna.unique_identity
	var/original_unique_features = subject.dna.unique_features
	var/datum/tgui/editor_ui = allocate(/datum/tgui, operator, console, "DnaConsole")
	editor_ui.status = UI_INTERACTIVE
	var/list/data = console.ui_data(operator)
	var/list/appearance_data = data["appearance"]
	TEST_ASSERT_NOTNULL(appearance_data, "A viable vulpkanin must supply appearance data to the real UI.")
	TEST_ASSERT_EQUAL(appearance_data["subject_ref"], REF(subject), "The UI must identify the scanned subject.")
	TEST_ASSERT_EQUAL(appearance_data["features"]["hairstyle_name"], "Jagged", "Hair must come from the subject's head.")
	TEST_ASSERT_EQUAL(appearance_data["features"]["feature_vulpkanin_head_markings"], /datum/sprite_accessory/vulpkanin_head_markings/tiger_head::name, "Species features must come from the subject's DNA.")
	TEST_ASSERT_EQUAL(appearance_data["supplemental_features"]["vulpkanin_head_markings_color"], "#2b2015", "Supplemental colors must remain linked to their feature.")
	TEST_ASSERT_EQUAL(appearance_data["secondary_features"]["feature_mcolor"], "#d69e67", "The secondary list must contain the subject's coat color.")
	TEST_ASSERT_NOTNULL(appearance_data["catalog"]["feature_vulpkanin_head_markings"]["icons"][/datum/sprite_accessory/vulpkanin_head_markings/tiger_head::name], "The feature must reference its existing catalog icon.")
	var/datum/asset/spritesheet_batched/preferences/catalog_asset = get_asset_datum(/datum/asset/spritesheet_batched/preferences)
	TEST_ASSERT(catalog_asset in console.ui_assets(), "The console must send the appearance spritesheet to its viewers.")
	TEST_ASSERT(appearance_data["catalog"]["feature_vulpkanin_head_markings"]["icons"][/datum/sprite_accessory/vulpkanin_head_markings/tiger_head::name] in catalog_asset.sprites, "The returned icon must exist in the generated spritesheet.")
	TEST_ASSERT(length(appearance_data["portrait"]), "The UI must receive a rendered portrait inside its HTML panel.")
	TEST_ASSERT(!("ipc_head" in appearance_data["catalog"]), "A vulpkanin must not expose IPC choices present in generic DNA defaults.")
	TEST_ASSERT(!("ipc_chassis_color" in appearance_data["catalog"]), "A vulpkanin must not expose IPC colors.")
	TEST_ASSERT("feature_vulpkanin_tail_markings" in appearance_data["secondary_features"], "The default tail must support its markings, as in character creation.")
	TEST_ASSERT(!("vulpkanin_tail_markings_color" in appearance_data["catalog"]), "No markings must hide their supplemental color, as in character creation.")
	TEST_ASSERT_EQUAL(json_encode(subject.dna.features), original_features, "Reading the UI must not change the subject's DNA.")
	TEST_ASSERT_EQUAL(data["targetUNI"], original_identity, "The target identity must initially match the occupant byte for byte.")
	TEST_ASSERT_EQUAL(data["targetUF"], original_unique_features, "The target features must initially match the occupant byte for byte.")
	TEST_ASSERT(!("body_type" in appearance_data["catalog"]), "Controls without a DNA block must be omitted.")
	var/original_portrait = appearance_data["portrait"]
	var/list/edit = list("subject_ref" = REF(subject), "target_ref" = appearance_data["target_ref"], "preference" = "hair_color", "value" = "#2244ff")
	var/original_gender = console.appearance_target.gender
	var/original_subject_gender = subject.gender
	var/original_physique = console.appearance_target.physique
	TEST_ASSERT_EQUAL(appearance_data["secondary_features"]["gender"], original_gender, "Genetic gender must be available as a secondary feature.")
	TEST_ASSERT_EQUAL(length(appearance_data["catalog"]["gender"]["choices"]), 2, "The console must offer only male and female genders.")
	edit["preference"] = "gender"
	edit["value"] = original_gender == FEMALE ? MALE : FEMALE
	TEST_ASSERT(console.ui_act("set_target_appearance", edit, editor_ui), "The editor must accept a valid genetic gender.")
	data = console.ui_data(operator)
	TEST_ASSERT_EQUAL(console.appearance_target.gender, edit["value"], "The selected gender must survive DNA decoding.")
	TEST_ASSERT(data["targetUNI"] != original_identity, "Gender must change the target identity DNA.")
	TEST_ASSERT_EQUAL(subject.gender, original_subject_gender, "Editing gender must preserve the subject.")
	TEST_ASSERT_EQUAL(subject.dna.unique_identity, original_identity, "Editing gender must preserve the source DNA.")
	TEST_ASSERT_EQUAL(console.appearance_target.physique, original_physique, "Genetic gender must preserve the independent physique.")
	edit["value"] = "invalid gender"
	TEST_ASSERT(!console.ui_act("set_target_appearance", edit, editor_ui), "Unknown genders must be rejected.")
	edit["value"] = PLURAL
	TEST_ASSERT(!console.ui_act("set_target_appearance", edit, editor_ui), "Nonbinary gender edits must be rejected by the server.")
	edit["value"] = original_gender
	TEST_ASSERT(console.ui_act("set_target_appearance", edit, editor_ui), "Returning to the initial gender must succeed.")
	data = console.ui_data(operator)
	TEST_ASSERT_EQUAL(data["targetUNI"], original_identity, "Reverting gender must restore the exact original DNA.")
	edit["preference"] = "character_height"
	edit["value"] = "Short"
	TEST_ASSERT(console.ui_act("set_target_appearance", edit, editor_ui), "Short height must be editable.")
	data = console.ui_data(operator)
	var/short_portrait = data["appearance"]["portrait"]
	TEST_ASSERT(short_portrait != original_portrait, "Short height must change the flattened portrait.")
	edit["value"] = "Tall"
	TEST_ASSERT(console.ui_act("set_target_appearance", edit, editor_ui), "Tall height must be editable.")
	data = console.ui_data(operator)
	TEST_ASSERT(data["appearance"]["portrait"] != short_portrait, "Short and tall target heights must have different PNGs.")
	edit["value"] = "Average"
	TEST_ASSERT(console.ui_act("set_target_appearance", edit, editor_ui), "The original height must be restorable.")
	data = console.ui_data(operator)
	TEST_ASSERT_EQUAL(data["targetUNI"], original_identity, "Reverting height must restore the exact original DNA.")
	TEST_ASSERT_EQUAL(data["appearance"]["portrait"], original_portrait, "Reverting height must restore the original portrait.")
	edit["preference"] = "hair_color"
	edit["value"] = "#2244ff"
	TEST_ASSERT(console.ui_act("set_target_appearance", edit, editor_ui), "The real editor action must accept a valid target color.")
	data = console.ui_data(operator)
	appearance_data = data["appearance"]
	TEST_ASSERT(appearance_data["portrait"] != original_portrait, "Changing the target DNA must redraw the portrait.")
	TEST_ASSERT_EQUAL(appearance_data["supplemental_features"]["hair_color"], "#2244ff", "The editor must describe the target color.")
	var/datum/dna_block/identity/hair_color/color_block = GLOB.dna_identity_blocks[/datum/dna_block/identity/hair_color]
	TEST_ASSERT_EQUAL(color_block.get_block(data["targetUNI"]), "2244ff", "The target DNA must encode the chosen color.")
	TEST_ASSERT_EQUAL(data["targetUNI"], color_block.modified_hash(original_identity, "2244ff"), "Changing one field must preserve all other identity blocks.")
	TEST_ASSERT_EQUAL(subject.dna.unique_identity, original_identity, "The subject identity must remain unchanged.")
	TEST_ASSERT_EQUAL(subject.hair_color, "#a26324", "The subject's body must remain unchanged.")
	TEST_ASSERT_EQUAL(json_encode(subject.dna.features), original_features, "Editing the target must not mutate source features.")
	edit["value"] = "not a color"
	TEST_ASSERT(!console.ui_act("set_target_appearance", edit, editor_ui), "Invalid colors must be rejected.")
	edit["preference"] = "ipc_head"
	edit["value"] = /datum/ipc_chassis/morpheus::name
	TEST_ASSERT(!console.ui_act("set_target_appearance", edit, editor_ui), "Forged species controls must be rejected.")
	edit["preference"] = "hair_color"
	edit["value"] = "#a26324"
	TEST_ASSERT(console.ui_act("set_target_appearance", edit, editor_ui), "Returning to the initial choice must succeed.")
	data = console.ui_data(operator)
	TEST_ASSERT_EQUAL(data["targetUNI"], original_identity, "Reverting a choice must restore the initial bytes, without random differences.")
	edit["preference"] = "feature_vulpkanin_tail_markings"
	edit["value"] = /datum/sprite_accessory/vulpkanin_tail_markings/default_tip::name
	TEST_ASSERT(console.ui_act("set_target_appearance", edit, editor_ui), "The target tail pattern must be editable.")
	var/obj/item/organ/tail/vulpkanin/pattern_tail = console.appearance_target.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAIL)
	TEST_ASSERT_EQUAL(console.appearance_target.dna.features[FEATURE_VULPKANIN_TAIL_MARKINGS], edit["value"], "The target DNA must retain the selected pattern.")
	TEST_ASSERT_EQUAL(pattern_tail.tail_markings_overlay.sprite_datum.name, edit["value"], "The target tail pattern overlay must follow its DNA.")
	data = console.ui_data(operator)
	edit["preference"] = "feature_vulpkanin_tail"
	var/original_tail_portrait = data["appearance"]["portrait"]
	edit["value"] = /datum/sprite_accessory/tails/vulpkanin/straight::name
	TEST_ASSERT(console.ui_act("set_target_appearance", edit, editor_ui), "A genetic species feature must be editable.")
	data = console.ui_data(operator)
	TEST_ASSERT(data["targetUF"] != original_unique_features, "A species choice must update target feature DNA.")
	var/obj/item/organ/tail/vulpkanin/target_tail = console.appearance_target.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAIL)
	TEST_ASSERT_EQUAL(target_tail.bodypart_overlay.sprite_datum.name, edit["value"], "The target's tail organ must follow its DNA.")
	TEST_ASSERT_EQUAL(target_tail.tail_markings_overlay.tail_markings_key, target_tail.bodypart_overlay.sprite_datum.icon_state, "Tail markings must follow the new tail shape.")
	TEST_ASSERT(data["appearance"]["portrait"] != original_tail_portrait, "Changing the target tail must redraw its portrait.")
	TEST_ASSERT(!("feature_vulpkanin_tail_markings" in data["appearance"]["catalog"]), "Straight target tails must hide unsupported markings, as in character creation.")
	TEST_ASSERT_EQUAL(subject.dna.unique_features, original_unique_features, "The source feature DNA must stay unchanged.")
	scanner.open_machine()
	TEST_ASSERT(scanner.close_machine(subject), "The same subject can be scanned again.")
	data = console.ui_data(operator)
	TEST_ASSERT_EQUAL(data["targetUF"], original_unique_features, "Reinserting a subject must reset its draft.")
	TEST_ASSERT(!console.ui_act("set_target_appearance", edit, editor_ui), "A stale draft reference must not edit a new scan of the same subject.")
	var/list/controls = list("subject_ref" = REF(subject), "target_ref" = data["appearance"]["target_ref"])
	TEST_ASSERT(!console.ui_act("makeup_pulse_differences", controls, editor_ui), "Matching DNA must not start a batch.")
	var/forward_portrait = data["appearance"]["portrait"]
	TEST_ASSERT(console.ui_act("rotate_appearance_target", controls, editor_ui), "The target portrait must rotate through its real UI action.")
	data = console.ui_data(operator)
	TEST_ASSERT(data["appearance"]["portrait"] != forward_portrait, "Rotation must change the rendered PNG.")
	TEST_ASSERT_EQUAL(data["targetUNI"], original_identity, "Rotation must not edit target DNA.")
	for(var/turn in 1 to 3)
		console.ui_act("rotate_appearance_target", controls, editor_ui)
	TEST_ASSERT_EQUAL(console.appearance_direction, SOUTH, "Four turns must restore the viewing direction.")
	var/list/batch_edit = controls.Copy()
	batch_edit["preference"] = "hair_color"
	batch_edit["value"] = "#a26325"
	TEST_ASSERT(console.ui_act("set_target_appearance", batch_edit, editor_ui), "Prepare one differing identity position.")
	batch_edit["preference"] = "feature_mcolor"
	batch_edit["value"] = "#d69e68"
	TEST_ASSERT(console.ui_act("set_target_appearance", batch_edit, editor_ui), "Prepare one differing species position.")
	data = console.ui_data(operator)
	var/desired_identity = data["targetUNI"]
	var/desired_features = data["targetUF"]
	// High precision isolates the requested positions; low strength avoids large wraparound shifts.
	scanner.precision_coeff = 1000
	console.pulse_strength = 1
	console.pulse_duration = 1
	TEST_ASSERT(console.ui_act("makeup_pulse_differences", controls, editor_ui), "One batch must accept differences in both DNA strings.")
	TEST_ASSERT_EQUAL(length(console.genetic_damage_pulse_queue), 2, "Only the two differing symbols must be queued.")
	TEST_ASSERT(!console.ui_act("makeup_pulse_differences", controls, editor_ui), "A repeated request must not replace an active batch.")
	TEST_ASSERT(!console.ui_act("set_target_appearance", batch_edit, editor_ui), "The target must remain frozen during irradiation.")
	console.process()
	TEST_ASSERT_EQUAL(subject.dna.unique_identity, original_identity, "The timer must prevent immediate irradiation.")
	var/pulse_deadline = console.genetic_damage_pulse_timer
	UNTIL(world.time >= pulse_deadline)
	console.process()
	TEST_ASSERT_NULL(console.genetic_damage_pulse_queue, "Completion must release the batch.")
	TEST_ASSERT_EQUAL(console.genetic_damage_pulse_index, 0, "Completion must end irradiation.")
	TEST_ASSERT(subject.dna.unique_identity != original_identity, "The batch must pulse the identity string.")
	TEST_ASSERT(subject.dna.unique_features != original_unique_features, "The same batch must pulse the species string.")
	data = console.ui_data(operator)
	TEST_ASSERT_EQUAL(data["targetUNI"], desired_identity, "Irradiation must not overwrite the desired identity.")
	TEST_ASSERT_EQUAL(data["targetUF"], desired_features, "Irradiation must not overwrite the desired species features.")
	TEST_ASSERT_EQUAL(data["subjectUNI"], subject.dna.unique_identity, "Post-pulse data must expose actual DNA for difference highlighting.")
	batch_edit["preference"] = "hair_color"
	batch_edit["value"] = "#a26324"
	TEST_ASSERT(console.ui_act("set_target_appearance", batch_edit, editor_ui), "Prepare a guaranteed remaining identity difference for cancellation.")
	TEST_ASSERT(console.ui_act("makeup_pulse_differences", controls, editor_ui), "Remaining differences must be available to a later cycle.")
	var/post_pulse_identity = subject.dna.unique_identity
	scanner.open_machine()
	TEST_ASSERT_NULL(console.genetic_damage_pulse_queue, "Opening the scanner must cancel a pending batch.")
	console.process()
	TEST_ASSERT_EQUAL(subject.dna.unique_identity, post_pulse_identity, "A cancelled batch must not mutate an extracted subject.")

	var/mob/living/carbon/human/ipc = allocate(/mob/living/carbon/human/consistent)
	ipc.set_species(/datum/species/ipc)
	ipc.dna.features[FEATURE_IPC_HEAD] = /datum/ipc_chassis/morpheus::name
	ipc.dna.features[FEATURE_IPC_CHASSIS_COLOR] = "#337799"
	ipc.update_body(is_creating = TRUE)
	scanner.open_machine()
	TEST_ASSERT(scanner.close_machine(ipc), "The IPC must enter the scanner.")
	console.is_viable_occupant = console.can_modify_occupant()
	data = console.ui_data(operator)
	TEST_ASSERT_NULL(data["appearance"], "The appearance panel must preserve the scanner's ordinary DNA restrictions.")
	scanner.scan_level = 3
	console.is_viable_occupant = console.can_modify_occupant()
	data = console.ui_data(operator)
	appearance_data = data["appearance"]
	TEST_ASSERT_NOTNULL(appearance_data, "An IPC must supply appearance data.")
	TEST_ASSERT(!("ipc_head" in appearance_data["catalog"]), "IPC controls without DNA blocks must be omitted.")
	TEST_ASSERT(!("ipc_chassis_color" in appearance_data["catalog"]), "IPC colors without DNA blocks must be omitted.")
	TEST_ASSERT(!("feature_vulpkanin_tail" in appearance_data["catalog"]), "An IPC must not expose vulpkanin tails.")

	var/mob/living/carbon/human/replacement = allocate(/mob/living/carbon/human/consistent)
	replacement.name = subject.name
	replacement.physique = FEMALE
	replacement.set_hairstyle("Bald")
	replacement.dna.update_dna_identity()
	scanner.open_machine()
	TEST_ASSERT(scanner.close_machine(replacement), "The replacement must enter the scanner.")
	data = console.ui_data(operator)
	appearance_data = data["appearance"]
	TEST_ASSERT(!console.ui_act("set_target_appearance", edit, editor_ui), "An old subject reference must not edit a replacement draft.")
	TEST_ASSERT_EQUAL(data["targetUNI"], replacement.dna.unique_identity, "A replacement must receive its own initial target.")
	TEST_ASSERT_EQUAL(console.appearance_target.physique, FEMALE, "The preview must preserve the subject's non-genetic body shape.")
	TEST_ASSERT_EQUAL(appearance_data["subject_ref"], REF(replacement), "Same-name occupants must not share a stale appearance.")
	TEST_ASSERT_EQUAL(appearance_data["features"]["hairstyle_name"], "Bald", "The UI must refresh after replacing the subject.")
	TEST_ASSERT(!("feature_vulpkanin_head_markings" in appearance_data["features"]), "The human must not inherit the previous occupant's species features.")
	edit = list("subject_ref" = REF(replacement), "target_ref" = appearance_data["target_ref"], "preference" = "gender", "value" = MALE)
	ADD_TRAIT(replacement, TRAIT_AGENDER, TRAIT_GENERIC)
	data = console.ui_data(operator)
	TEST_ASSERT(!("gender" in data["appearance"]["catalog"]), "Agender subjects must not expose gender editing.")
	TEST_ASSERT(!console.ui_act("set_target_appearance", edit, editor_ui), "Agender subjects must reject forged gender edits.")
	REMOVE_TRAIT(replacement, TRAIT_AGENDER, TRAIT_GENERIC)
	replacement.set_species(/datum/species/plasmaman)
	data = console.ui_data(operator)
	TEST_ASSERT_NOTNULL(data["appearance"], "The advanced scanner must expose the plasmaman appearance.")
	edit["target_ref"] = data["appearance"]["target_ref"]
	TEST_ASSERT(!("gender" in data["appearance"]["catalog"]), "Species without sexes must not expose gender editing.")
	TEST_ASSERT(!console.ui_act("set_target_appearance", edit, editor_ui), "Species without sexes must reject forged gender edits.")
	replacement.dna.features[FEATURE_MUTANT_COLOR] = GLOB.color_list_ethereal["Green"]
	replacement.set_species(/datum/species/ethereal)
	replacement.dna.update_dna_identity()
	data = console.ui_data(operator)
	TEST_ASSERT_EQUAL(data["appearance"]["features"]["feature_ethcolor"], "Green", "Ethereal DNA color must map back to its palette choice.")
	edit["target_ref"] = data["appearance"]["target_ref"]
	edit["preference"] = "feature_ethcolor"
	edit["value"] = "Red"
	TEST_ASSERT(console.ui_act("set_target_appearance", edit, editor_ui), "The ethereal palette must be editable through the real UI action.")
	TEST_ASSERT_EQUAL(console.appearance_target.dna.features[FEATURE_MUTANT_COLOR], GLOB.color_list_ethereal["Red"], "Ethereal target DNA must encode the selected palette color.")
	TEST_ASSERT_EQUAL(replacement.dna.features[FEATURE_MUTANT_COLOR], GLOB.color_list_ethereal["Green"], "Editing ethereal target color must preserve the subject.")
	replacement.set_species(/datum/species/vox)
	replacement.dna.features -= FEATURE_VOX_LIMB_MARKINGS
	replacement.dna.features[FEATURE_VOX_LIMB_MARKINGS_COLOR] = "#8a6036"
	replacement.dna.update_dna_identity()
	data = console.ui_data(operator)
	edit["target_ref"] = data["appearance"]["target_ref"]
	edit["preference"] = "vox_limb_markings_color"
	edit["value"] = "#2468ac"
	TEST_ASSERT(console.ui_act("set_target_appearance", edit, editor_ui), "A fixed Vox marking must remain recolorable when its style key is absent.")
	for(var/obj/item/bodypart/part as anything in console.appearance_target.bodyparts)
		for(var/datum/bodypart_overlay/simple/body_marking/vox_limb/marking in part.bodypart_overlays)
			TEST_ASSERT_EQUAL(marking.draw_color, "#2468ac", "The actual fixed Vox marking overlay must use the selected color.")

	scanner.open_machine()
	console.is_viable_occupant = console.can_modify_occupant()
	data = console.ui_data(operator)
	TEST_ASSERT_NULL(data["appearance"], "An empty scanner must clear the appearance panel.")
	TEST_ASSERT_NULL(console.appearance_target, "Removing the subject must delete the owned preview body.")
	TEST_ASSERT_NULL(console.appearance_portrait, "An empty scanner must clear the previous portrait.")
/// A missing species marking key must still receive its matching genetic feature block.
/datum/unit_test/dna_console_appearance/sharp_points/Run()
	var/mob/living/carbon/human/operator = allocate(/mob/living/carbon/human/consistent)
	var/obj/machinery/dna_scannernew/scanner = allocate(/obj/machinery/dna_scannernew, run_loc_floor_bottom_left)
	var/obj/machinery/computer/dna_console/console = allocate(/obj/machinery/computer/dna_console, run_loc_floor_top_right)
	console.set_connected_scanner(scanner)
	scanner.set_is_operational(TRUE)
	var/mob/living/carbon/human/subject = allocate(/mob/living/carbon/human/consistent)
	subject.set_species(/datum/species/vulpkanin)
	subject.dna.features -= FEATURE_VULPKANIN_LIMB_MARKINGS
	subject.dna.features[FEATURE_MUTANT_COLOR] = "#d69e67"
	subject.dna.features[FEATURE_VULPKANIN_BODY_MARKINGS_COLOR] = "#2b2015"
	subject.dna.features[FEATURE_VULPKANIN_HEAD_MARKINGS_COLOR] = "#2b2015"
	subject.dna.features[FEATURE_VULPKANIN_TAIL_MARKINGS_COLOR] = "#2b2015"
	subject.dna.features[FEATURE_VULPKANIN_FACIAL_HAIR_COLOR] = "#2b2015"
	subject.update_body(is_creating = TRUE)
	subject.dna.update_dna_identity()
	// Legacy DNA may predate the species' marking key, while still carrying a full feature string.
	subject.dna.features -= FEATURE_VULPKANIN_LIMB_MARKINGS
	scanner.open_machine()
	TEST_ASSERT(scanner.close_machine(subject), "The vulpkanin must enter the real scanner.")
	console.can_use_scanner = TRUE
	console.is_viable_occupant = console.can_modify_occupant()
	var/list/data = console.ui_data(operator)
	var/datum/tgui/editor_ui = allocate(/datum/tgui, operator, console, "DnaConsole")
	editor_ui.status = UI_INTERACTIVE
	var/list/edit = list("subject_ref" = REF(subject), "target_ref" = data["appearance"]["target_ref"], "preference" = "feature_vulpkanin_limb_markings", "value" = /datum/sprite_accessory/vulpkanin_limb_markings/points_sharp::name)
	TEST_ASSERT(console.ui_act("set_target_appearance", edit, editor_ui), "Sharp points must be selectable in the target.")
	data = console.ui_data(operator)
	var/source_before = icon2base64(getFlatIcon(subject, no_anim = TRUE, defdir = SOUTH))
	// Isolate the reported all-blue state from the deliberately random irradiation step.
	subject.dna.unique_features = data["targetUF"]
	subject.updateappearance(mutcolor_update = TRUE, mutations_overlay_update = TRUE)
	data = console.ui_data(operator)
	TEST_ASSERT_EQUAL(data["subjectUF"], data["targetUF"], "The reported case has matching source and target feature strings.")
	TEST_ASSERT_EQUAL(subject.dna.features[FEATURE_VULPKANIN_LIMB_MARKINGS], /datum/sprite_accessory/vulpkanin_limb_markings/points_sharp::name, "Matching DNA must apply Sharp points even if its feature key was absent.")
	for(var/zone in list(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG))
		var/obj/item/bodypart/limb = subject.get_bodypart(zone)
		var/datum/bodypart_overlay/simple/body_marking/vulpkanin_limb/marking = locate() in limb.bodypart_overlays
		TEST_ASSERT_NOTNULL(marking, "The actual [zone] must retain its species marking overlay.")
		TEST_ASSERT_EQUAL(marking.icon_state, "sharppoints", "The actual [zone] must render Sharp points.")
		TEST_ASSERT(marking.can_draw_on_bodypart(limb, subject), "The actual [zone] must allow its markings to be drawn.")
		TEST_ASSERT(findtext(limb.get_cache_key(), "sharppoints"), "The rendered [zone] cache must include the new marking.")
	TEST_ASSERT(icon2base64(getFlatIcon(subject, no_anim = TRUE, defdir = SOUTH)) != source_before, "Actual body rendering must change after the matching DNA is applied.")
	var/mob/living/carbon/human/fresh = allocate(/mob/living/carbon/human)
	fresh.set_species(/datum/species/vulpkanin)
	fresh.updateappearance(mutcolor_update = TRUE)
	TEST_ASSERT_EQUAL(fresh.dna.features[FEATURE_VULPKANIN_LIMB_MARKINGS], SPRITE_ACCESSORY_NONE, "A fresh generated genome must encode the default instead of random limb markings.")
	var/mob/living/carbon/human/foreign = allocate(/mob/living/carbon/human/consistent)
	foreign.dna.features -= FEATURE_VULPKANIN_LIMB_MARKINGS
	foreign.dna.unique_features = data["targetUF"]
	foreign.updateappearance(mutcolor_update = TRUE)
	TEST_ASSERT_NULL(foreign.dna.features[FEATURE_VULPKANIN_LIMB_MARKINGS], "A human must not gain an unsupported vulp marking key from feature DNA.")
