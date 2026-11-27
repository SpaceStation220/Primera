/datum/unit_test/ipc_humanity_transplant/Run()
	var/mob/living/carbon/human/donor = allocate(/mob/living/carbon/human/consistent)
	donor.set_species(/datum/species/ipc)
	var/datum/preference/choiced/ipc/generation/generation = GLOB.preference_entries[/datum/preference/choiced/ipc/generation]
	generation.apply_to_human(donor, "III", null)
	var/datum/ipc_os/os = donor.get_ipc_os()
	var/datum/ipc_os_program/humanity/archive = os.programs["humanity"]
	TEST_ASSERT_EQUAL(archive.body, donor, "Creation did not attach the engram.")
	TEST_ASSERT(donor.mob_mood.enabled, "Gen III did not regain mood.")
	TEST_ASSERT(donor.add_quirk(/datum/quirk/jolly, add_unique = FALSE, announce = FALSE), "Compatible quirk rejected.")
	TEST_ASSERT(!donor.add_quirk(/datum/quirk/vegetarian, add_unique = FALSE, announce = FALSE), "Physiological quirk accepted.")
	archive.records["Память"] = "Холодная вода на правой ладони."
	archive.update_stage(SANITY_LEVEL_UNSTABLE)
	TEST_ASSERT_EQUAL(archive.stage, 1, "A moment on the boundary caused a stage change.")
	donor.mob_mood.set_sanity(42, override = TRUE)
	TEST_ASSERT_EQUAL(archive.stage, 4, "The Mask did not appear at the critical sanity level.")
	var/obj/item/organ/brain/ipc/core = os.core
	core.Remove(donor, special = TRUE)
	TEST_ASSERT(!donor.mob_mood.enabled && !donor.has_quirk(/datum/quirk/jolly), "Former owner kept the engram's mood or quirk.")
	TEST_ASSERT_NULL(archive.body, "Detached archive retained a viewer.")
	var/mob/living/carbon/human/recipient = allocate(/mob/living/carbon/human/consistent)
	recipient.set_species(/datum/species/ipc)
	TEST_ASSERT(core.Insert(recipient, movement_flags = DELETE_IF_REPLACED), "Core insertion failed.")
	generation.apply_to_human(recipient, "II", null)
	TEST_ASSERT_EQUAL(os.generation(), "III", "Applying recipient preferences rewrote the transplanted core.")
	TEST_ASSERT_EQUAL(archive.body, recipient, "New owner did not receive their archive.")
	TEST_ASSERT_EQUAL(recipient.mob_mood.sanity, 42, "Sanity was reset on transfer.")
	TEST_ASSERT(recipient.has_quirk(/datum/quirk/jolly), "Compatible quirk did not follow the core.")
	TEST_ASSERT_EQUAL(archive.records["Память"], "Холодная вода на правой ладони.", "An original record changed.")
	TEST_ASSERT(!length(archive.ui_data(donor)), "Old owner could still receive private records.")
	recipient.mob_mood.update_nutrition_moodlets()
	TEST_ASSERT_NULL(recipient.mob_mood.get_mood_event("nutrition"), "Battery charge caused an organic hunger mood.")

/datum/unit_test/ipc_humanity_archive/Run()
	var/obj/item/organ/brain/ipc/core = allocate(/obj/item/organ/brain/ipc)
	var/datum/ipc_os_program/humanity/archive = core.operating_system.programs["humanity"]
	var/original = "Утром 🧤 я открывал дверь <тихо>."
	archive.records["Память"] = original
	for(var/stage in 3 to 4)
		archive.stage = stage
		var/visible = archive.read_record("Память")
		TEST_ASSERT(visible != original && findtext(visible, "Утром"), "A damaged record should retain recognizable fragments.")
		TEST_ASSERT_EQUAL(archive.read_record("Память"), visible, "Record masks flicker between reads.")
	archive.stage = 1
	TEST_ASSERT_EQUAL(archive.read_record("Память"), original, "Recovery did not restore the original Unicode record.")
	var/datum/preference/text/humanity/memory/field = GLOB.preference_entries[/datum/preference/text/humanity/memory]
	TEST_ASSERT_EQUAL(field.deserialize(original), original, "Preference damaged markup or Unicode data.")
	TEST_ASSERT(!field.is_valid(repeat_string(401, "Ж")), "Server accepted a record above the length limit.")
	var/list/states = icon_states('modular_bandastation/species/icons/hud/humanity.dmi')
	for(var/stage in 1 to 4)
		for(var/expression in list("rest", "up", "down"))
			TEST_ASSERT("stage[stage]-[expression]" in states, "Missing native HUD face.")
	var/obj/item/paper/paper = allocate(/obj/item/paper)
	TEST_ASSERT(!archive.suitable_keepsake(paper), "The photo anchor accepted a paper note.")
	TEST_ASSERT(!archive.suitable_keepsake(core), "The archive accepted an unlisted keepsake.")

/datum/unit_test/ipc_humanity_starting_photo/Run()
	var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent)
	body.set_species(/datum/species/ipc)
	body.mock_client = allocate(/datum/client_interface)
	var/datum/preference/choiced/ipc/generation/generation = GLOB.preference_entries[/datum/preference/choiced/ipc/generation]
	generation.apply_to_human(body, "III", null)
	var/datum/ipc_os/os = body.get_ipc_os()
	var/datum/ipc_os_program/humanity/archive = os.programs["humanity"]
	archive.anchor = "keepsake"
	archive.keepsake_description = "Встреча <дома>"
	var/datum/job/job = SSjob.get_job_type(/datum/job/assistant)
	SEND_GLOBAL_SIGNAL(COMSIG_GLOB_JOB_AFTER_SPAWN, job, body, null)
	var/obj/item/photo/photo = archive.keepsake?.resolve()
	TEST_ASSERT_NOTNULL(photo, "Starting equipment did not grant the photo anchor.")
	allocated += photo
	TEST_ASSERT(body.contains(photo), "Starting photo was not in the player's inventory.")
	TEST_ASSERT(archive.suitable_keepsake(photo), "Starting photo had no rendered picture.")
	TEST_ASSERT_EQUAL(photo.desc, html_encode(archive.keepsake_description), "The keepsake description was missing or unsafe.")
	TEST_ASSERT(!photo.show_picture && !photo.scribble, "The keepsake still used the regular photo viewer or back caption.")
	SEND_GLOBAL_SIGNAL(COMSIG_GLOB_JOB_AFTER_SPAWN, job, body, null)
	TEST_ASSERT_EQUAL(archive.keepsake?.resolve(), photo, "A repeated spawn hook replaced the starting photo.")
	TEST_ASSERT(body.add_quirk(/datum/quirk/item_quirk/photographer, add_unique = FALSE, announce = FALSE), "Gen III could not receive Photographer.")
	var/obj/item/photo/old/replacement = allocate(/obj/item/photo/old, get_turf(body), photo.picture)
	body.dropItemToGround(photo)
	TEST_ASSERT(body.put_in_active_hand(replacement), "Fixture could not hold the other photograph.")
	var/datum/tgui/ui = allocate(/datum/tgui, body, archive, "HumanityArchive")
	ui.status = UI_INTERACTIVE
	ui.on_act_message("bind", list(), GLOB.conscious_state)
	TEST_ASSERT_EQUAL(archive.keepsake?.resolve(), replacement, "Binding a different developed photo did not replace the anchor.")

/datum/unit_test/ipc_humanity_habit
	var/logged_emote

/datum/unit_test/ipc_humanity_habit/Run()
	var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent)
	body.set_species(/datum/species/ipc)
	body.mock_client = allocate(/datum/client_interface)
	var/datum/preference/choiced/ipc/generation/generation = GLOB.preference_entries[/datum/preference/choiced/ipc/generation]
	generation.apply_to_human(body, "III", null)
	var/datum/ipc_os/os = body.get_ipc_os()
	var/datum/ipc_os_program/humanity/archive = os.programs["humanity"]
	archive.anchor = "habit"
	archive.habit_emote = "тихо пересчитывает пальцы."
	RegisterSignal(body, COMSIG_MOB_EMOTE, PROC_REF(on_emote))
	archive.use_anchor(body, "habit")
	TEST_ASSERT_EQUAL(logged_emote, archive.habit_emote, "Completing a habit did not emit its authored /me text.")
	TEST_ASSERT(archive.next_anchor > world.time, "Completing a habit did not apply the normal anchor cooldown.")

/datum/unit_test/ipc_humanity_habit/proc/on_emote(datum/source, datum/emote/emote, act, type_override, message, intentional)
	SIGNAL_HANDLER
	if(act == "me" && intentional)
		logged_emote = message

/datum/unit_test/ipc_humanity_conversation/Run()
	var/mob/living/carbon/human/listener = allocate(/mob/living/carbon/human/consistent)
	listener.set_species(/datum/species/ipc)
	listener.mock_client = allocate(/datum/client_interface)
	var/datum/preference/choiced/ipc/generation/pref = GLOB.preference_entries[/datum/preference/choiced/ipc/generation]
	pref.apply_to_human(listener, "III", null)
	var/datum/ipc_os/os = listener.get_ipc_os()
	var/datum/ipc_os_program/humanity/archive = os.programs["humanity"]
	var/mob/living/carbon/human/speaker = allocate(/mob/living/carbon/human/consistent)
	speaker.mock_client = allocate(/datum/client_interface)
	speaker.forceMove(get_turf(listener))
	var/list/heard = list(speaker, null, "Обычная реплика", 1459, null, null, list(), list(), 4)
	SEND_SIGNAL(listener, COMSIG_MOVABLE_HEAR, heard)
	TEST_ASSERT(!length(archive.speakers), "Radio counted as a local conversation.")
	heard[HEARING_RADIO_FREQ] = null
	heard[HEARING_SPEAKER] = listener
	SEND_SIGNAL(listener, COMSIG_MOVABLE_HEAR, heard)
	archive.evaluate_conversation()
	TEST_ASSERT_NULL(listener.mob_mood.get_mood_event("humanity_social"), "A monologue granted a social mood.")
	heard[HEARING_SPEAKER] = speaker
	SEND_SIGNAL(listener, COMSIG_MOVABLE_HEAR, heard)
	var/key = WEAKREF(speaker)
	var/last_heard = archive.speakers[key]
	SEND_SIGNAL(listener, COMSIG_MOVABLE_HEAR, heard)
	TEST_ASSERT_EQUAL(archive.speakers[key], last_heard, "A repeated message advanced the time window.")
	archive.evaluate_conversation()
	var/datum/mood_event/social = listener.mob_mood.get_mood_event("humanity_social")
	TEST_ASSERT_EQUAL(social?.mood_change, 2, "A two-way local conversation did not receive the expected moodlet.")
	archive.speakers[key] = world.time - 26 SECONDS
	archive.evaluate_conversation()
	TEST_ASSERT_NULL(archive.conversation_since, "An elapsed social window retained its accumulated benefit.")
	archive.records["Личное"] = "Секрет энграммы"
	TEST_ASSERT(length(archive.ui_data(listener)), "Owner could not open the native archive.")
	TEST_ASSERT(!length(archive.ui_data(speaker)), "Nearby player could access the private archive.")
	os.infections["core_rot"] = new /datum/ipc_os_malware/core_rot(os)
	TEST_ASSERT(!length(archive.ui_data(listener)), "CoreRot did not lock the archive.")
	TEST_ASSERT_EQUAL(archive.records["Личное"], "Секрет энграммы", "CoreRot erased stored records.")

/// The same native delay caches are used by actual walking, running and timed actions.
/datum/unit_test/ipc_humanity_balance/Run()
	var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent)
	body.set_species(/datum/species/ipc)
	var/datum/preference/choiced/ipc/generation/generation = GLOB.preference_entries[/datum/preference/choiced/ipc/generation]
	generation.apply_to_human(body, "III", null)
	var/datum/mood/mood = body.mob_mood
	TEST_ASSERT_EQUAL(mood.sanity, 110, "A newly installed engram did not start at 110.")
	mood.set_sanity(40, override = TRUE)
	body.set_move_intent(MOVE_INTENT_WALK)
	var/walk = body.cached_multiplicative_slowdown
	body.set_move_intent(MOVE_INTENT_RUN)
	var/run = body.cached_multiplicative_slowdown * 1.02
	var/action = body.cached_multiplicative_actions_slowdown
	TEST_ASSERT(!body.has_actionspeed_modifier(ACTIONSPEED_ID_SANITY), "Humanity retained the native low-sanity action penalty.")
	for(var/value in list(40, 50, 75, 100, 110, 125, 150))
		mood.set_sanity(value, maximum = SANITY_MAXIMUM, override = TRUE)
		var/rate = 1 + 0.1 * clamp((value - 50) / 75, 0, 1)
		body.set_move_intent(MOVE_INTENT_WALK)
		TEST_ASSERT(abs(body.cached_multiplicative_slowdown - walk) < 0.001, "Sanity [value] accelerated walking.")
		body.set_move_intent(MOVE_INTENT_RUN)
		TEST_ASSERT(abs(body.cached_multiplicative_actions_slowdown - action / rate) < 0.001, "Incorrect effective action delay at [value].")
	for(var/stage in 1 to 4)
		mood.humanity.set_stage(stage)
		var/run_rate = 1.1 - 0.02 * stage
		TEST_ASSERT(abs(body.cached_multiplicative_slowdown - run / run_rate) < 0.001, "Incorrect run rate for dissociation stage [stage].")
	var/datum/timed_action/timed = allocate(/datum/timed_action, body, body, 10 SECONDS, FALSE, NONE)
	TEST_ASSERT(abs(timed.end_time - timed.start_time - 10 SECONDS * action / 1.10) < 0.01, "Timed actions did not use the peak rate.")
	var/list/levels = list(MOOD_LEVEL_NEUTRAL, MOOD_LEVEL_SAD1, MOOD_LEVEL_SAD4, MOOD_LEVEL_HAPPY1, MOOD_LEVEL_HAPPY4)
	var/list/rates = list(-1, -2.2, -3.5, 0.25, 0.8)
	for(var/index in 1 to length(levels))
		mood.set_sanity(110, maximum = SANITY_MAXIMUM, override = TRUE)
		mood.mood_level = levels[index]
		for(var/minute in 1 to 60)
			for(var/step in 1 to 6)
				mood.process(10)
			if(minute in list(10, 30, 60))
				var/expected = clamp(110 + rates[index] * minute, 0, 150)
				TEST_ASSERT(abs(mood.sanity - expected) < 0.01, "Sanity after [minute] min at mood [levels[index]] was [mood.sanity], expected [expected].")
	mood.set_sanity(40, override = TRUE)
	mood.set_sanity(51, override = TRUE)
	TEST_ASSERT_EQUAL(mood.humanity.candidate, 4, "Small fluctuations restarted a stage at its threshold.")
	mood.set_sanity(55, override = TRUE)
	TEST_ASSERT_EQUAL(mood.humanity.candidate, 3, "Recovery could not start above the hysteresis threshold.")

/datum/unit_test/ipc_humanity_eye_episode/Run()
	var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent)
	body.set_species(/datum/species/ipc)
	var/datum/preference/choiced/ipc/generation/generation = GLOB.preference_entries[/datum/preference/choiced/ipc/generation]
	generation.apply_to_human(body, "III", null)
	var/datum/ipc_os_program/humanity/archive = body.mob_mood.humanity
	var/list/states = icon_states('modular_bandastation/species/icons/hud/humanity_echo.dmi')
	var/list/faces = icon_states('modular_bandastation/species/icons/hud/humanity.dmi')
	for(var/frame in 1 to 5)
		TEST_ASSERT(("eyes[frame]" in states) && ("display[frame]" in states) && ("stage4-saccade[frame]" in faces), "Missing synchronized eye frame [frame].")
		archive.show_display_eyes(frame)
		TEST_ASSERT_EQUAL(archive.display_eyes?.icon_state, "display[frame]", "The visible IPC head missed frame [frame].")
	archive.clear_visual()
	TEST_ASSERT_NULL(archive.display_eyes, "Cleanup left the eyes on the physical head.")
	body.obscured_slots |= HIDEEYES
	archive.show_display_eyes(1)
	TEST_ASSERT_NULL(archive.display_eyes, "The public cue shone through an opaque visor.")
	body.mob_mood.set_sanity(40, override = TRUE)
	var/list/lines = list()
	for(var/index in 1 to 16)
		var/message = archive.draw_message()
		TEST_ASSERT(!(message in lines), "A line repeated before the stage-IV pool was exhausted.")
		lines += message
	TEST_ASSERT(archive.draw_message() != lines[16], "Refilling the pool immediately repeated its last line.")
	for(var/index in 1 to 10)
		TEST_ASSERT(archive.message_interval() <= 18 SECONDS && archive.effect_interval() >= 25 SECONDS, "Frequent private text accelerated audiovisual episodes.")
