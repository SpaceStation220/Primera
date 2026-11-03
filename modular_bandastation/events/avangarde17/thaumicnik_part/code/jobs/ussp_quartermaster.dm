/datum/outfit/job/ussp_quartermaster
	// AI EDIT START - Integrate event jobs and ID permissions
	jobtype = /datum/job/ussp_quartermaster
	// AI EDIT END
	name = "Заведующий складом"
	// AI EDIT START - Integrate event jobs and ID permissions
	id = /obj/item/card/id/advanced/silver
	// AI EDIT END
	id_trim = /datum/id_trim/job/ussp_quartermaster
	uniform = /obj/item/clothing/under/suit/navy
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

/datum/job/ussp_quartermaster
	// AI EDIT START - Integrate event jobs and ID permissions
	parent_type = /datum/job/ussp
	display_order = 73
	config_tag = "USSP_QUARTERMASTER"
	// AI EDIT END
	title = "Заведующий складом"
	supervisors = "правительством СССП"
	description = "Продавайте оборудование и материалы. Являйтесь единственным способным инженером во всём посёлке."
	departments_list = list(
		/datum/job_department/cargo,
	)
	outfit = /datum/outfit/job/ussp_quartermaster
	faction = FACTION_STATION
	total_positions = 1
	spawn_positions = 1
	paycheck = PAYCHECK_CREW
	bounty_types = CIV_JOB_BASIC
	department_for_prefs = /datum/job_department/cargo
	family_heirlooms = list(/obj/item/storage/toolbox/mechanical/old/heirloom, /obj/item/clothing/gloves/cut/heirloom)
	job_flags = STATION_JOB_FLAGS

/datum/id_trim/job/ussp_quartermaster
	// AI EDIT START - Integrate event jobs and ID permissions
	minimal_wildcard_access = list(ACCESS_QM)
	template_access = list(
		ACCESS_CAPTAIN,
		ACCESS_CHANGE_IDS,
	)
	// AI EDIT END
	assignment = "Заведующий складом"
	trim_state = "trim_cargotechnician"
	department_color = COLOR_CARGO_BROWN
	subdepartment_color = COLOR_CARGO_BROWN
	sechud_icon_state = SECHUD_USSP
	minimal_access = list(
		ACCESS_MINERAL_STOREROOM,
		ACCESS_SERVICE,
		)
	job = /datum/job/ussp_quartermaster
