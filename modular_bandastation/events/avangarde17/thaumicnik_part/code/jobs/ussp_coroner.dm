/datum/outfit/job/ussp_coroner
	// AI EDIT START - Integrate event jobs and ID permissions
	jobtype = /datum/job/ussp_coroner
	// AI EDIT END
	name = "Патологоанатом"
	id = /obj/item/card/id/advanced
	id_trim = /datum/id_trim/job/ussp_coroner
	uniform = /obj/item/clothing/under/costume/buttondown/slacks
	suit = /obj/item/clothing/suit/toggle/labcoat
	shoes = /obj/item/clothing/shoes/laceup
	gloves = /obj/item/clothing/gloves/latex
	belt = null
	pda_slot = null
	// AI EDIT START - Preserve event outfits with the dual ear inventory API
	ear_right = null
	// AI EDIT END

	backpack = /obj/item/storage/backpack
	satchel = /obj/item/storage/backpack/satchel
	duffelbag = /obj/item/storage/backpack/duffelbag
	messenger = /obj/item/storage/backpack/messenger

/datum/job/ussp_coroner
	// AI EDIT START - Integrate event jobs and ID permissions
	parent_type = /datum/job/ussp
	display_order = 67
	config_tag = "USSP_CORONER"
	// AI EDIT END
	title = "Патологоанатом"
	supervisors = "правительством СССП"
	description = "Вскрывайте и утилизируйте трупы. Опционально приторговывайте органами."
	departments_list = list(
		/datum/job_department/medical,
	)
	outfit = /datum/outfit/job/ussp_coroner
	faction = FACTION_STATION
	total_positions = 2
	spawn_positions = 2
	paycheck = PAYCHECK_CREW
	bounty_types = CIV_JOB_BASIC
	department_for_prefs = /datum/job_department/medical
	family_heirlooms = list(/obj/item/storage/medkit/ancient/heirloom, /obj/item/scalpel, /obj/item/hemostat, /obj/item/circular_saw, /obj/item/retractor, /obj/item/cautery, /obj/item/statuebust/hippocratic)
	job_flags = STATION_JOB_FLAGS
	liver_traits = list(TRAIT_MEDICAL_METABOLISM)

/datum/id_trim/job/ussp_coroner
	// AI EDIT START - Integrate event jobs and ID permissions
	template_access = list(
		ACCESS_CAPTAIN,
		ACCESS_CHANGE_IDS,
		ACCESS_CMO,
	)
	// AI EDIT END
	assignment = "Патологоанатом"
	trim_state = "trim_medicaldoctor"
	department_color = COLOR_MEDICAL_BLUE
	subdepartment_color = COLOR_MEDICAL_BLUE
	sechud_icon_state = SECHUD_CORONER
	minimal_access = list(
		ACCESS_MECH_MEDICAL,
		ACCESS_MEDICAL,
		ACCESS_MINERAL_STOREROOM,
		ACCESS_MORGUE,
		ACCESS_PHARMACY,
		ACCESS_SURGERY,
		ACCESS_VIROLOGY,
		ACCESS_PARAMEDIC,
		ACCESS_PLUMBING,
		)
	job = /datum/job/ussp_coroner
