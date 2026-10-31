// AI EDIT START - Integrate event jobs and ID permissions
/datum/outfit/job/ussp_assistant
	parent_type = /datum/outfit/job/assistant
	jobtype = /datum/job/ussp_assistant
// AI EDIT END
	uniform = /obj/item/clothing/under/costume/buttondown/slacks
	shoes = /obj/item/clothing/shoes/laceup
	id = /obj/item/card/id/advanced
	id_trim = /datum/id_trim/job/ussp_assistant
	pda_slot = null
	belt = null
	// AI EDIT START - Preserve event outfits with the dual ear inventory API
	ear_right = null
	// AI EDIT END

// AI EDIT START - Integrate event jobs and ID permissions
/datum/job/ussp_assistant
	display_order = 50
	parent_type = /datum/job/assistant
	config_tag = "USSP_ASSISTANT"
	outfit = /datum/outfit/job/ussp_assistant
// AI EDIT END
	title = "Житель ПГТ \"Зорька\""
	departments_list = list(
		/datum/job_department/assistant,
	)
	department_for_prefs = /datum/job_department/assistant

/datum/id_trim/job/ussp_assistant
	// AI EDIT START - Integrate event jobs and ID permissions
	parent_type = /datum/id_trim/job/assistant
	// AI EDIT END
	assignment = "Житель ПГТ \"Зорька\""
	trim_state = "trim_mime"
	department_color = COLOR_ASSISTANT_GRAY
	subdepartment_color = COLOR_ASSISTANT_GRAY
	sechud_icon_state = SECHUD_USSP
// AI EDIT START - Integrate event jobs and ID permissions
	job = /datum/job/ussp_assistant

/// Keep the resident outfit in previews and when assistant gimmicks are enabled.
/datum/job/ussp_assistant/get_outfit(consistent)
	return outfit
// AI EDIT END
