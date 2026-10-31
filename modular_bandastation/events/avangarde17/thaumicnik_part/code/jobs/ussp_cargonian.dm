/datum/outfit/job/ussp_cargonian
	// AI EDIT START - Integrate event jobs and ID permissions
	jobtype = /datum/job/ussp_cargonian
	// AI EDIT END
	name = "Работник склада"
	id = /obj/item/card/id/advanced
	id_trim = /datum/id_trim/job/ussp_cargonian
	uniform = /obj/item/clothing/under/misc/overalls
	shoes = /obj/item/clothing/shoes/workboots
	suit = /obj/item/clothing/suit/apron/overalls
	gloves = /obj/item/clothing/gloves/fingerless
	head = /obj/item/clothing/head/utility/hardhat
	belt = null
	pda_slot = null
	// AI EDIT START - Preserve event outfits with the dual ear inventory API
	ear_right = null
	// AI EDIT END

	backpack = /obj/item/storage/backpack
	satchel = /obj/item/storage/backpack/satchel
	duffelbag = /obj/item/storage/backpack/duffelbag
	messenger = /obj/item/storage/backpack/messenger

/datum/job/ussp_cargonian
	// AI EDIT START - Integrate event jobs and ID permissions
	parent_type = /datum/job/ussp
	display_order = 75
	config_tag = "USSP_CARGONIAN"
	// AI EDIT END
	title = "Работник склада"
	supervisors = "заведующим складом"
	description = "Следите за снабжением магазинов и рабочих. Совершайте 90% краж."
	departments_list = list(
		/datum/job_department/cargo,
	)
	outfit = /datum/outfit/job/ussp_cargonian
	faction = FACTION_STATION
	total_positions = 3
	spawn_positions = 3
	paycheck = PAYCHECK_CREW
	bounty_types = CIV_JOB_BASIC
	department_for_prefs = /datum/job_department/cargo
	family_heirlooms = list(/obj/item/storage/toolbox/mechanical/old/heirloom, /obj/item/clothing/gloves/cut/heirloom)
	job_flags = STATION_JOB_FLAGS

/datum/id_trim/job/ussp_cargonian
	// AI EDIT START - Integrate event jobs and ID permissions
	template_access = list(
		ACCESS_CAPTAIN,
		ACCESS_CHANGE_IDS,
		ACCESS_QM,
	)
	// AI EDIT END
	assignment = "Работник склада"
	trim_state = "trim_cargotechnician"
	department_color = COLOR_CARGO_BROWN
	subdepartment_color = COLOR_CARGO_BROWN
	sechud_icon_state = SECHUD_USSP
	minimal_access = list(
		ACCESS_AUX_BASE,
		ACCESS_CARGO,
		ACCESS_MECH_MINING,
		ACCESS_MINERAL_STOREROOM,
		ACCESS_MINING,
		ACCESS_MINING_STATION,
		)
	// AI EDIT START - Integrate event jobs and ID permissions
	job = /datum/job/ussp_cargonian
	// AI EDIT END
