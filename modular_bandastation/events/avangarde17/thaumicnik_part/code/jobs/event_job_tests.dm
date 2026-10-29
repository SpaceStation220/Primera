// AI EDIT START - Cover event job registration and ID permissions
/// Event templates use the console's existing authentication and access application paths.
/datum/unit_test/ussp_id_templates
	test_flags = UNIT_TEST_MAP_TEST

/datum/unit_test/ussp_id_templates/Run()
	if(SSmapping.current_map.map_name != "avangarde")
		return
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/modular_computer/computer = allocate(/obj/item/modular_computer)
	var/datum/computer_file/program/card_mod/program = allocate(/datum/computer_file/program/card_mod)
	if(!computer.store_file(program))
		return TEST_FAIL("Failed to install the ID console program.")
	var/datum/tgui/ui = allocate(/datum/tgui, user, program, "NtosCard")
	var/obj/item/card/id/advanced/silver/auth_card = allocate(/obj/item/card/id/advanced/silver)
	var/obj/item/card/id/advanced/target_card = allocate(/obj/item/card/id/advanced)
	// Access templates fill a compatible physical trim; painting and access writing are separate operations.
	if(!SSid_access.apply_trim_to_card(target_card, /datum/id_trim/job/ussp_medic, copy_access = FALSE))
		return TEST_FAIL("Failed to prepare the event medic's physical ID trim.")
	var/datum/bank_account/owner_account = allocate(/datum/bank_account, user.real_name, SSjob.get_job_type(/datum/job/unassigned), 1, FALSE)
	target_card.set_account(owner_account)
	computer.insert_id(auth_card)
	user.put_in_hands(target_card)
	if(!computer.insert_secondary_id(target_card, user))
		return TEST_FAIL("Failed to insert the card to modify.")

	if(!SSid_access.apply_trim_to_card(auth_card, /datum/id_trim/job/medical_doctor))
		return TEST_FAIL("Failed to prepare the doctor's ID.")
	if(program.authenticate(user, auth_card))
		return TEST_FAIL("An ordinary doctor must not authenticate as a department head.")
	program.ui_act("PRG_template", list("path" = "[/datum/id_trim/job/ussp_medic]"), ui)
	if(ACCESS_MEDICAL in target_card.access)
		return TEST_FAIL("An unauthenticated console granted medical access.")

	if(!SSid_access.apply_trim_to_card(auth_card, /datum/id_trim/job/ussp_cmo))
		return TEST_FAIL("Failed to prepare the event CMO's ID.")
	if(!program.authenticate(user, auth_card))
		return TEST_FAIL("The event CMO must be able to authenticate.")
	if(!(/datum/id_trim/job/ussp_medic in program.job_templates))
		return TEST_FAIL("The CMO cannot issue the event medic's template.")
	if(/datum/id_trim/job/ussp_militiaman in program.job_templates)
		return TEST_FAIL("The CMO can issue a security template.")
	program.ui_act("PRG_template", list("path" = "[/datum/id_trim/job/ussp_medic]"), ui)
	if(!(ACCESS_MEDICAL in target_card.access) || !(ACCESS_SURGERY in target_card.access))
		return TEST_FAIL("The event medic template did not grant medical and surgery access: physical trim=[target_card.trim?.type], access=[json_encode(target_card.access)], account job=[target_card.registered_account?.account_job?.type].")
	if(target_card.registered_account?.account_job?.type != /datum/job/ussp_medic)
		return TEST_FAIL("The template assigned the wrong bank-account job: [target_card.registered_account?.account_job?.type].")

/// Equipping an event job must apply its own trim and keep the head's existing wildcard usable.
/datum/unit_test/ussp_job_id_equipment
	test_flags = UNIT_TEST_MAP_TEST

/datum/unit_test/ussp_job_id_equipment/Run()
	if(SSmapping.current_map.map_name != "avangarde")
		return
	var/list/jobs = list(
		/datum/job/ussp_cmo,
		/datum/job/ussp_cargonian,
		/datum/job/ussp_militia_chief,
		/datum/job/ussp_quartermaster,
		/datum/job/ussp_assistant,
		/datum/job/ussp_chief_engineer,
		/datum/job/ussp_hop,
		/datum/job/ussp_research_director,
	)
	for(var/job_type in jobs)
		var/datum/job/job = SSjob.get_job_type(job_type)
		var/mob/living/carbon/human/consistent/subject = allocate(/mob/living/carbon/human/consistent)
		subject.dress_up_as_job(job, consistent = TRUE)
		if(length(subject.get_items_by_slots(ITEM_SLOT_EARS)))
			return TEST_FAIL("[job.title] received an earpiece despite its event outfit disabling headsets.")
		var/obj/item/card/id/card = subject.get_idcard()
		if(!card?.trim)
			return TEST_FAIL("[job.title] did not receive its trimmed ID card: outfit=[job.outfit], card=[card?.type], trim=[card?.trim?.type].")
		var/datum/job/id_job = card.trim.find_job()
		if(id_job?.type != job_type)
			return TEST_FAIL("[job.title]'s ID card belongs to another job: physical trim=[card.trim.type], assignment=[card.assignment], trim job=[id_job?.type] ([REF(id_job)]), expected=[job_type] ([REF(job)]), account job=[card.registered_account?.account_job?.type], access=[json_encode(card.access)].")
		if(card.registered_name != subject.real_name)
			return TEST_FAIL("[job.title]'s ID card was not registered to its owner.")

/// Canonical event titles and standard station titles must resolve to independent jobs.
/datum/unit_test/ussp_job_lookup

/datum/unit_test/ussp_job_lookup/Run()
	var/on_event_map = SSmapping.current_map.map_name == "avangarde"
	var/expected_event_jobs = on_event_map ? 28 : 0
	var/event_job_count = 0
	for(var/datum/job/job as anything in SSjob.joinable_occupations)
		if(SSjob.get_job(job.title) != job)
			return TEST_FAIL("The canonical title [job.title] resolves to another job.")
		if(findtext(job.config_tag, "USSP_") == 1)
			event_job_count++
	if(event_job_count != expected_event_jobs)
		return TEST_FAIL("Expected [expected_event_jobs] event jobs on [SSmapping.current_map.map_name], found [event_job_count].")
	if(!on_event_map)
		if(/datum/id_trim/job/ussp_medic in SSid_access.station_job_templates)
			return TEST_FAIL("An event-only job still offers an ID template outside Avangarde.")
		for(var/datum/modpack/events/event in SSmodpacks.loaded_modpacks)
			if(event.housing_assigned)
				return TEST_FAIL("Avangarde housing ran on another map.")

	var/list/standard_jobs = list(
		JOB_ASSISTANT = /datum/job/assistant,
		JOB_BOTANIST = /datum/job/botanist,
		JOB_HEAD_OF_PERSONNEL = /datum/job/head_of_personnel,
		JOB_RESEARCH_DIRECTOR = /datum/job/research_director,
		JOB_SCIENTIST = /datum/job/scientist,
		JOB_CHIEF_ENGINEER = /datum/job/chief_engineer,
		JOB_CHIEF_MEDICAL_OFFICER = /datum/job/chief_medical_officer,
		JOB_BOTANIST_RU = /datum/job/botanist,
		JOB_HEAD_OF_PERSONNEL_RU = /datum/job/head_of_personnel,
		JOB_RESEARCH_DIRECTOR_RU = /datum/job/research_director,
		JOB_SCIENTIST_RU = /datum/job/scientist,
	)
	for(var/title in standard_jobs)
		var/datum/job/standard_job = SSjob.get_job(title)
		var/datum/job/expected_job = SSjob.get_job_type(standard_jobs[title])
		if(standard_job != expected_job)
			return TEST_FAIL("The standard station title [title] resolves to an event job.")
// AI EDIT END
