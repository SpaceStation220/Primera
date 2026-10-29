// AI EDIT START - Integrate event jobs and ID permissions
/datum/job/ussp_botanist
	display_order = 59
	parent_type = /datum/job/botanist
	config_tag = "USSP_BOTANIST"
	outfit = /datum/outfit/job/ussp_botanist
// AI EDIT END
	title = "Агроном"
	description = "Работайте в теплице. Снабжайте продуктами посёлок, наслаждайтесь запахом цветов и укусами пчёл."

// AI EDIT START - Integrate event jobs and ID permissions
/datum/outfit/job/ussp_botanist
	parent_type = /datum/outfit/job/botanist
// AI EDIT END
	name = "Агроном"
	// AI EDIT START - Integrate event jobs and ID permissions
	jobtype = /datum/job/ussp_botanist
	// AI EDIT END

	id = /obj/item/card/id/advanced
	// AI EDIT START - Integrate event jobs and ID permissions
	id_trim = /datum/id_trim/job/ussp_botanist
	// AI EDIT END
	uniform = /obj/item/clothing/under/costume/buttondown/slacks
	suit = /obj/item/clothing/suit/apron/overalls
	backpack_contents = list()
	belt = null
	head = null
	// AI EDIT START - Preserve event outfits with the dual ear inventory API
	ear_right = null
	// AI EDIT END
	shoes = /obj/item/clothing/shoes/workboots
	gloves = null
	l_pocket = null
	l_hand = null
	pda_slot = null

	backpack = /obj/item/storage/backpack
	satchel = /obj/item/storage/backpack/satchel
	duffelbag = /obj/item/storage/backpack/duffelbag
	messenger = /obj/item/storage/backpack/messenger

// AI EDIT START - Integrate event jobs and ID permissions
/datum/id_trim/job/ussp_botanist
	parent_type = /datum/id_trim/job/botanist
	job = /datum/job/ussp_botanist
// AI EDIT END
	assignment = "Агроном"


// AI EDIT START - Integrate event jobs and ID permissions
/// Keep the standard role's Russian aliases bound to the standard job.
/datum/job/ussp_botanist/New()
	. = ..()
	alternate_titles = null
// AI EDIT END
