/datum/outfit/job/ussp_barman
	// AI EDIT START - Integrate event jobs and ID permissions
	jobtype = /datum/job/ussp_barman
	// AI EDIT END
	name = "Владелец кабака"
	id = /obj/item/card/id/advanced
	id_trim = /datum/id_trim/job/ussp_barman
	uniform = /obj/item/clothing/under/costume/buttondown/slacks/service
	shoes = /obj/item/clothing/shoes/laceup
	belt = null
	pda_slot = null
	// AI EDIT START - Preserve event outfits with the dual ear inventory API
	ear_right = null
	// AI EDIT END

	backpack = /obj/item/storage/backpack
	satchel = /obj/item/storage/backpack/satchel
	duffelbag = /obj/item/storage/backpack/duffelbag
	messenger = /obj/item/storage/backpack/messenger

/datum/job/ussp_barman
	// AI EDIT START - Integrate event jobs and ID permissions
	parent_type = /datum/job/ussp
	display_order = 57
	config_tag = "USSP_BARMAN"
	// AI EDIT END
	title = "Владелец кабака"
	supervisors = "управдомом"
	description = "Управляйте кабаком под номинальным руководством муниципалитета. Гоните самогон из под полы."
	departments_list = list(
		/datum/job_department/service,
	)
	outfit = /datum/outfit/job/ussp_barman
	faction = FACTION_STATION
	total_positions = 1
	spawn_positions = 1
	paycheck = PAYCHECK_CREW
	bounty_types = CIV_JOB_BASIC
	department_for_prefs = /datum/job_department/service
	family_heirlooms = list(/obj/item/storage/toolbox/mechanical/old/heirloom, /obj/item/clothing/gloves/cut/heirloom)
	job_flags = STATION_JOB_FLAGS

/datum/id_trim/job/ussp_barman
	// AI EDIT START - Integrate event jobs and ID permissions
	template_access = list(
		ACCESS_CAPTAIN,
		ACCESS_CHANGE_IDS,
		ACCESS_HOP,
	)
	// AI EDIT END
	assignment = "Владелец кабака"
	trim_state = "trim_bartender"
	department_color = COLOR_SERVICE_LIME
	subdepartment_color = COLOR_SERVICE_LIME
	sechud_icon_state = SECHUD_BARTENDER
	minimal_access = list(
		ACCESS_KITCHEN,
		ACCESS_MINERAL_STOREROOM,
		ACCESS_MORGUE,
		ACCESS_SERVICE,
		ACCESS_BAR,
		ACCESS_HYDROPONICS,
		)
	job = /datum/job/ussp_barman
