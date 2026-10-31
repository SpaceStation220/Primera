// AI EDIT START - Integrate event jobs and ID permissions
/datum/job/ussp_scientist
	display_order = 63
	parent_type = /datum/job/scientist
	config_tag = "USSP_SCIENTIST"
	outfit = /datum/outfit/job/ussp_scientist
// AI EDIT END
	title = "Научный сотрудник"
	description = "Развивайте науку в этом славном посёлке! (а ещё неплохо бы съехать из этого НИИ куда-нибудь в столицу)"

// AI EDIT START - Integrate event jobs and ID permissions
/datum/outfit/job/ussp_scientist
	parent_type = /datum/outfit/job/scientist
// AI EDIT END
	name = "Научный сотрудник"
	// AI EDIT START - Integrate event jobs and ID permissions
	jobtype = /datum/job/ussp_scientist
	// AI EDIT END

	id = /obj/item/card/id/advanced
	// AI EDIT START - Integrate event jobs and ID permissions
	id_trim = /datum/id_trim/job/ussp_scientist
	// AI EDIT END
	uniform = /obj/item/clothing/under/carnival/formal
	suit = /obj/item/clothing/suit/toggle/labcoat
	backpack_contents = list()
	belt = null
	head = null
	// AI EDIT START - Preserve event outfits with the dual ear inventory API
	ear_right = null
	// AI EDIT END
	shoes = /obj/item/clothing/shoes/laceup
	gloves = null
	l_pocket = null
	l_hand = /obj/item/clipboard
	pda_slot = null

	backpack = /obj/item/storage/backpack
	satchel = /obj/item/storage/backpack/satchel
	duffelbag = /obj/item/storage/backpack/duffelbag
	messenger = /obj/item/storage/backpack/messenger

// AI EDIT START - Integrate event jobs and ID permissions
/datum/id_trim/job/ussp_scientist
	parent_type = /datum/id_trim/job/scientist
	job = /datum/job/ussp_scientist
// AI EDIT END
	assignment = "Научный сотрудник"


// AI EDIT START - Integrate event jobs and ID permissions
/// Keep the standard role's Russian aliases bound to the standard job.
/datum/job/ussp_scientist/New()
	. = ..()
	alternate_titles = null
// AI EDIT END
