/datum/outfit/job/ussp_cook
	// AI EDIT START - Integrate event jobs and ID permissions
	jobtype = /datum/job/ussp_cook
	// AI EDIT END
	name = "Повар столовой"
	id = /obj/item/card/id/advanced
	id_trim = /datum/id_trim/job/ussp_cook
	uniform = /obj/item/clothing/under/costume/buttondown/slacks/service
	suit = /obj/item/clothing/suit/apron/chef
	head = /obj/item/clothing/head/utility/chefhat
	shoes = /obj/item/clothing/shoes/laceup
	gloves = /obj/item/clothing/gloves/color/white
	belt = null
	pda_slot = null
	// AI EDIT START - Preserve event outfits with the dual ear inventory API
	ear_right = null
	// AI EDIT END

	backpack = /obj/item/storage/backpack
	satchel = /obj/item/storage/backpack/satchel
	duffelbag = /obj/item/storage/backpack/duffelbag
	messenger = /obj/item/storage/backpack/messenger
	backpack_contents = list(
		// AI EDIT START - Integrate event jobs and ID permissions
		/obj/item/cooking_voucher = 1,
		// AI EDIT END
		/obj/item/sharpener = 1,
	)

/datum/job/ussp_cook
	// AI EDIT START - Integrate event jobs and ID permissions
	parent_type = /datum/job/ussp
	display_order = 56
	config_tag = "USSP_COOK"
	// AI EDIT END
	title = "Повар столовой"
	supervisors = "управдомом"
	description = "Занимайтесь готовкой еды для граждан славного посёлка городского типа"
	departments_list = list(
		/datum/job_department/service,
	)
	outfit = /datum/outfit/job/ussp_cook
	faction = FACTION_STATION
	total_positions = 2
	spawn_positions = 2
	paycheck = PAYCHECK_CREW
	bounty_types = CIV_JOB_BASIC
	department_for_prefs = /datum/job_department/service
	family_heirlooms = list(/obj/item/storage/toolbox/mechanical/old/heirloom, /obj/item/clothing/gloves/cut/heirloom)
	job_flags = STATION_JOB_FLAGS

/datum/id_trim/job/ussp_cook
	// AI EDIT START - Integrate event jobs and ID permissions
	template_access = list(
		ACCESS_CAPTAIN,
		ACCESS_CHANGE_IDS,
		ACCESS_HOP,
	)
	// AI EDIT END
	assignment = "Повар столовой"
	trim_state = "trim_cook"
	department_color = COLOR_SERVICE_LIME
	subdepartment_color = COLOR_SERVICE_LIME
	sechud_icon_state = SECHUD_CHEF
	minimal_access = list(
		ACCESS_KITCHEN,
		ACCESS_MINERAL_STOREROOM,
		ACCESS_MORGUE,
		ACCESS_SERVICE,
		)
	extra_access = list(
		ACCESS_BAR,
		ACCESS_HYDROPONICS,
		)
	job = /datum/job/ussp_cook
