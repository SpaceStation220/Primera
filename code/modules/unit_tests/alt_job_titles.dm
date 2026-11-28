/// Keep test preferences away from player save directories while using the real JSON storage.
/datum/preferences/alt_job_titles_test/load_path(ckey, filename = "preferences.json")
	path = "data/alt_job_titles_tests/[ckey]-[filename]"

/datum/preferences/alt_job_titles_test/Destroy(force)
	if(parent?.prefs == src)
		parent.prefs = null
	parent = null
	return ..()

/// Reject hostile titles at the UI boundary and preserve independent character/job choices on disk.
/datum/unit_test/alt_job_titles_preferences
	var/test_save_path

/datum/unit_test/alt_job_titles_preferences/Destroy()
	. = ..()
	if(test_save_path)
		fdel(test_save_path)
		fdel(PREFS_BACKUP_PATH(test_save_path))

/datum/unit_test/alt_job_titles_preferences/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/alt_job_titles_test, mock_client)
	test_save_path = preferences.path
	var/datum/preference_middleware/jobs/middleware = allocate(/datum/preference_middleware/jobs, preferences)
	TEST_ASSERT(middleware.set_alt_job_title(list("job" = JOB_SCIENTIST, "title" = "Ксенобиолог")), "Valid title was refused.")
	TEST_ASSERT(middleware.set_alt_job_title(list("job" = JOB_ASSISTANT, "title" = "Стажёр")), "A second job could not be configured independently.")
	for(var/list/invalid_params as anything in list(
		list("job" = JOB_SCIENTIST, "title" = "Captain"),
		list("job" = JOB_SCIENTIST, "title" = "Стажёр"),
		list("job" = "Missing job", "title" = "Ксенобиолог"),
		list("job" = list(JOB_ASSISTANT), "title" = "Стажёр"),
		list("job" = JOB_ASSISTANT, "title" = list("Стажёр")),
	))
		TEST_ASSERT(!middleware.set_alt_job_title(invalid_params), "Hostile or mismatched title was accepted.")
	TEST_ASSERT_EQUAL(preferences.alt_job_titles[JOB_SCIENTIST], "Ксенобиолог", "Rejected input changed the saved choice.")
	TEST_ASSERT(preferences.save_character(), "Could not save slot one.")
	preferences.switch_to_slot(2)
	TEST_ASSERT_EQUAL(length(preferences.alt_job_titles), 0, "An empty slot inherited another character's titles.")
	TEST_ASSERT(middleware.set_alt_job_title(list("job" = JOB_SCIENTIST, "title" = "Ксеноархеолог")), "Could not configure slot two.")
	TEST_ASSERT(preferences.save_character(), "Could not save slot two.")
	preferences.save_preferences()
	var/datum/preferences/reloaded = allocate(/datum/preferences/alt_job_titles_test, mock_client)
	TEST_ASSERT_EQUAL(reloaded.alt_job_titles[JOB_SCIENTIST], "Ксеноархеолог", "Reopening JSON lost slot two's title.")
	reloaded.switch_to_slot(1)
	TEST_ASSERT_EQUAL(reloaded.alt_job_titles[JOB_SCIENTIST], "Ксенобиолог", "Slot one's title changed after a reload.")
	TEST_ASSERT_EQUAL(reloaded.alt_job_titles[JOB_ASSISTANT], "Стажёр", "Another job's title was lost.")
	// Match the registry state of a job excluded by map_check(), then save while it is absent.
	var/datum/job/disabled_job = SSjob.get_job(JOB_SCIENTIST)
	var/list/original_names = SSjob.name_occupations
	var/list/original_joinable = SSjob.joinable_occupations
	SSjob.name_occupations = original_names.Copy()
	SSjob.name_occupations -= JOB_SCIENTIST
	SSjob.joinable_occupations = original_joinable.Copy()
	SSjob.joinable_occupations -= disabled_job
	var/loaded_disabled = reloaded.load_character(1)
	var/saved_disabled = reloaded.save_character()
	SSjob.name_occupations = original_names
	SSjob.joinable_occupations = original_joinable
	TEST_ASSERT(loaded_disabled && saved_disabled, "Could not load/save while a job was disabled.")
	TEST_ASSERT(reloaded.load_character(1), "Could not reload after the job became available.")
	TEST_ASSERT_EQUAL(reloaded.alt_job_titles[JOB_SCIENTIST], "Ксенобиолог", "A map-disabled job permanently lost its title.")
	var/datum/preference_middleware/jobs/reloaded_middleware = allocate(/datum/preference_middleware/jobs, reloaded)
	TEST_ASSERT(reloaded_middleware.set_alt_job_title(list("job" = JOB_SCIENTIST, "title" = JOB_SCIENTIST)), "Could not restore the standard title.")
	TEST_ASSERT_NULL(reloaded.alt_job_titles[JOB_SCIENTIST], "Reset retained the alternative.")
	TEST_ASSERT_EQUAL(reloaded.alt_job_titles[JOB_ASSISTANT], "Стажёр", "Reset changed another job.")
	var/list/saved_slot = reloaded.savefile.get_entry("character1")
	saved_slot["alt_job_titles"] = list(JOB_ATMOSPHERIC_TECHNICIAN = "Пожарный", JOB_ASSISTANT = "Посетитель", JOB_CAPTAIN = "Командующий", "Deleted job" = "Стажёр")
	TEST_ASSERT(reloaded.load_character(1), "Could not load corrupted title data.")
	TEST_ASSERT_EQUAL(length(reloaded.alt_job_titles), 0, "Invalid saved titles survived loading.")
	saved_slot["alt_job_titles"] = list(1000000)
	TEST_ASSERT(reloaded.load_character(1), "Malformed list keys prevented character loading.")
	TEST_ASSERT_EQUAL(length(reloaded.alt_job_titles), 0, "Malformed list keys survived loading.")
	saved_slot -= "alt_job_titles"
	TEST_ASSERT(reloaded.load_character(1), "A pre-feature save could not be loaded.")
	TEST_ASSERT_EQUAL(length(reloaded.alt_job_titles), 0, "A legacy save inherited titles.")

/// Exercise real job outfits and manifest insertion while keeping access and the underlying job intact.
/datum/unit_test/alt_job_titles_documents
	var/datum/record/crew/test_record
	var/datum/record/locked/test_locked_record

/datum/unit_test/alt_job_titles_documents/Destroy()
	QDEL_NULL(test_record)
	if(test_locked_record)
		QDEL_NULL(test_locked_record.locked_dna)
		QDEL_NULL(test_locked_record)
	return ..()

/datum/unit_test/alt_job_titles_documents/Run()
	var/datum/job/job = SSjob.get_job(JOB_ATMOSPHERIC_TECHNICIAN)
	var/mob/living/carbon/human/standard = allocate(/mob/living/carbon/human/consistent)
	standard.mind_initialize()
	standard.mind.set_assigned_role(job)
	standard.job = job.title
	standard.dress_up_as_job(job, consistent = TRUE)
	var/obj/item/card/id/standard_card = standard.get_idcard(hand_first = FALSE)
	TEST_ASSERT_NOTNULL(standard_card, "Standard outfit has no ID.")
	var/mob/living/carbon/human/alternate = allocate(/mob/living/carbon/human/consistent)
	alternate.real_name = "Alternative Title Tester"
	alternate.mind_initialize()
	alternate.mind.set_assigned_role(job)
	alternate.mind.assigned_job_title = "Техник жизнеобеспечения"
	alternate.job = job.title
	alternate.dress_up_as_job(job, consistent = TRUE)
	var/obj/item/card/id/card = alternate.get_idcard(hand_first = FALSE)
	var/obj/item/modular_computer/pda/pda = alternate.l_store
	TEST_ASSERT_NOTNULL(card, "Alternative outfit has no ID.")
	TEST_ASSERT(istype(pda), "Alternative outfit has no PDA in its configured slot.")
	TEST_ASSERT_EQUAL(card.assignment, "Техник жизнеобеспечения", "ID ignored the alternative title.")
	TEST_ASSERT_EQUAL(pda.saved_job, "Техник жизнеобеспечения", "PDA ignored the alternative title.")
	TEST_ASSERT_EQUAL(pda.saved_job_role, JOB_ATMOSPHERIC_TECHNICIAN, "PDA software lost the canonical role.")
	TEST_ASSERT_EQUAL(alternate.get_assignment(use_trim = TRUE), standard.get_assignment(use_trim = TRUE), "Role-based consumers received a cosmetic title.")
	pda.imprint_id(job_name = "Custom HoP title", job_role = JOB_ATMOSPHERIC_TECHNICIAN)
	TEST_ASSERT_EQUAL(pda.saved_job_role, JOB_ATMOSPHERIC_TECHNICIAN, "A custom display label changed the imprinted role.")
	pda.imprint_id(job_name = "Unknown role")
	TEST_ASSERT_NULL(pda.saved_job_role, "An unknown imprint retained a previous role's privileges.")
	TEST_ASSERT_EQUAL(card.get_trim_assignment(), standard_card.get_trim_assignment(), "The display title changed the ID trim.")
	TEST_ASSERT_EQUAL(length(card.access ^ standard_card.access), 0, "The display title changed access.")
	TEST_ASSERT_EQUAL(alternate.mind.assigned_role, job, "The display title changed the actual role.")
	TEST_ASSERT_EQUAL(alternate.job, JOB_ATMOSPHERIC_TECHNICIAN, "mob.job became a display title.")
	GLOB.manifest.inject(alternate)
	test_record = find_record(alternate.real_name)
	test_locked_record = find_record(alternate.real_name, locked_only = TRUE)
	TEST_ASSERT_NOTNULL(test_record, "No crew record was created.")
	TEST_ASSERT_EQUAL(test_record.rank, "Техник жизнеобеспечения", "Manifest ignored the display title.")
	TEST_ASSERT_EQUAL(SSjob.get_job(test_record.trim), job, "Manifest lost its real job.")
	TEST_ASSERT_EQUAL(test_record.initial_rank, standard_card.get_trim_assignment(), "Manifest stored a display title as its initial job.")
	GLOB.manifest.modify(alternate.real_name, "Custom HoP title", card.get_trim_assignment())
	TEST_ASSERT_EQUAL(test_record.rank, "Custom HoP title", "HoP could not change the display title.")
	alternate.mind.set_assigned_role(SSjob.get_job(JOB_ASSISTANT))
	TEST_ASSERT_EQUAL(alternate.mind.get_job_title(), JOB_ASSISTANT, "A role change retained the old title.")
	var/mob/living/carbon/human/captain = allocate(/mob/living/carbon/human/consistent)
	captain.mind_initialize()
	var/datum/job/captain_job = SSjob.get_job(JOB_CAPTAIN)
	captain.mind.set_assigned_role(captain_job)
	captain.mind.assigned_job_title = "Командующий"
	TEST_ASSERT_EQUAL(captain.mind.get_job_title(), JOB_CAPTAIN, "A removed command title did not fall back to the canonical job.")
	captain.job = captain_job.title
	captain.dress_up_as_job(captain_job, consistent = TRUE)
	var/obj/machinery/porta_turret/turret = allocate(/obj/machinery/porta_turret)
	TEST_ASSERT_EQUAL(turret.assess_perp(captain), 0, "A removed command title changed the turret's head-of-staff exemption.")
	var/mob/living/carbon/human/impostor = allocate(/mob/living/carbon/human/consistent)
	impostor.real_name = "Forged Captain Tester"
	impostor.equip_to_slot_or_del(allocate(/obj/item/clothing/under/color/grey), ITEM_SLOT_ICLOTHING)
	var/obj/item/card/id/advanced/chameleon/agent_card = allocate(/obj/item/card/id/advanced/chameleon)
	TEST_ASSERT(impostor.equip_to_slot_if_possible(agent_card, ITEM_SLOT_ID), "Could not equip the forged ID fixture.")
	agent_card.registered_name = impostor.real_name
	agent_card.assignment = JOB_CAPTAIN
	TEST_ASSERT_EQUAL(turret.assess_perp(impostor), 0, "A forged Captain assignment no longer fools the turret.")
	SSid_access.apply_trim_override(agent_card, /datum/id_trim/job/captain, TRUE)
	agent_card.assignment = "Unrecognized custom title"
	TEST_ASSERT_EQUAL(turret.assess_perp(impostor), 4, "A custom assignment gained a head exemption solely from its trim.")
