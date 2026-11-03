/datum/outfit/job/ussp_homeless
	// AI EDIT START - Integrate event jobs and ID permissions
	jobtype = /datum/job/ussp_homeless
	// AI EDIT END
	name = "Бездомный"
	uniform = /obj/item/clothing/under/pants/slacks
	suit = /obj/item/clothing/suit/toggle/jacket/sweater
	shoes = /obj/item/clothing/shoes/laceup
	head = /obj/item/clothing/head/costume/ushanka
	belt = null
	pda_slot = null
	// AI EDIT START - Preserve event outfits with the dual ear inventory API
	ear_right = null
	// AI EDIT END
	id = null

	backpack = /obj/item/storage/backpack
	satchel = /obj/item/storage/backpack/satchel
	duffelbag = /obj/item/storage/backpack/duffelbag
	messenger = /obj/item/storage/backpack/messenger

/datum/job/ussp_homeless
	// AI EDIT START - Integrate event jobs and ID permissions
	parent_type = /datum/job/ussp
	display_order = 51
	config_tag = "USSP_HOMELESS"
	// AI EDIT END
	title = "Бездомный"
	supervisors = "правительством СССП"
	description = "Ройтесь в помойках, собирайте бутылки и танцуйте диско."
	departments_list = list(
		/datum/job_department/assistant,
	)
	outfit = /datum/outfit/job/ussp_homeless
	faction = FACTION_STATION
	total_positions = 3
	spawn_positions = 3
	paycheck = PAYCHECK_CREW
	bounty_types = CIV_JOB_BASIC
	department_for_prefs = /datum/job_department/assistant
	family_heirlooms = list(/obj/item/storage/toolbox/mechanical/old/heirloom, /obj/item/clothing/gloves/cut/heirloom)
	job_flags = STATION_JOB_FLAGS

/datum/id_trim/job/ussp_homeless
	// AI EDIT START - Integrate event jobs and ID permissions
	template_access = list(
		ACCESS_CAPTAIN,
		ACCESS_CHANGE_IDS,
		ACCESS_HOP,
	)
	// AI EDIT END
	assignment = "Житель ПГТ \"Зорька\""
	trim_state = "trim_mime"
	department_color = COLOR_ASSISTANT_GRAY
	subdepartment_color = COLOR_ASSISTANT_GRAY
	sechud_icon_state = SECHUD_USSP
	job = /datum/job/ussp_homeless
