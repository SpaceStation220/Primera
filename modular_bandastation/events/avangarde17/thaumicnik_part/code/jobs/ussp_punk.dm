/datum/outfit/job/ussp_punk
	// AI EDIT START - Integrate event jobs and ID permissions
	jobtype = /datum/job/ussp_punk
	// AI EDIT END
	name = "Шпана"
	id = /obj/item/card/id/advanced
	id_trim = /datum/id_trim/job/ussp_punk
	uniform = /obj/item/clothing/under/rank/ussp/gopnik
	mask = /obj/item/clothing/mask/bandana/skull
	shoes = /obj/item/clothing/shoes/sneakers/black
	head = /obj/item/clothing/head/soft/ussp/gopnik
	backpack_contents = list(
		/obj/item/food/semki,
	)
	belt = null
	pda_slot = null
	// AI EDIT START - Preserve event outfits with the dual ear inventory API
	ear_right = null
	// AI EDIT END

	backpack = /obj/item/storage/backpack
	satchel = /obj/item/storage/backpack/satchel
	duffelbag = /obj/item/storage/backpack/duffelbag
	messenger = /obj/item/storage/backpack/messenger

/datum/job/ussp_punk
	// AI EDIT START - Integrate event jobs and ID permissions
	parent_type = /datum/job/ussp
	display_order = 52
	config_tag = "USSP_PUNK"
	// AI EDIT END
	title = "Шпана"
	supervisors = "понятиями"
	description = "Бухайте, деритесь, занимайтесь разбоем. В перерывах сидите в обезьяннике."
	departments_list = list(
		/datum/job_department/assistant,
	)
	outfit = /datum/outfit/job/ussp_punk
	faction = FACTION_STATION
	total_positions = 4
	spawn_positions = 4
	paycheck = PAYCHECK_CREW
	bounty_types = CIV_JOB_BASIC
	department_for_prefs = /datum/job_department/assistant
	family_heirlooms = list(/obj/item/storage/toolbox/mechanical/old/heirloom, /obj/item/clothing/gloves/cut/heirloom)
	job_flags = STATION_JOB_FLAGS

/datum/id_trim/job/ussp_punk
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
	job = /datum/job/ussp_punk
