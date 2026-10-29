// AI EDIT START - Integrate event jobs and ID permissions
/datum/job/ussp_hop
	display_order = 55
	parent_type = /datum/job/head_of_personnel
	config_tag = "USSP_HOP"
	outfit = /datum/outfit/job/ussp_hop
// AI EDIT END
	title = "Управдом"
	description = "Управляйте всем тем, что не касается других глав, а также следите за трудоустройством очередного Васи 25 лет без образования."

// AI EDIT START - Integrate event jobs and ID permissions
/datum/outfit/job/ussp_hop
	parent_type = /datum/outfit/job/hop
// AI EDIT END
	name = "Управдом"
	// AI EDIT START - Integrate event jobs and ID permissions
	jobtype = /datum/job/ussp_hop
	// AI EDIT END

	// AI EDIT START - Integrate event jobs and ID permissions
	id_trim = /datum/id_trim/job/ussp_hop
	// AI EDIT END
	uniform = /obj/item/clothing/under/costume/buttondown/slacks/service
	suit = null
	backpack_contents = list()
	belt = null
	head = /obj/item/clothing/head/fedora
	// AI EDIT START - Preserve event outfits with the dual ear inventory API
	ear_right = null
	// AI EDIT END
	shoes = /obj/item/clothing/shoes/laceup
	gloves = null
	l_pocket = null
	l_hand = null
	pda_slot = null

	backpack = /obj/item/storage/backpack
	satchel = /obj/item/storage/backpack/satchel
	duffelbag = /obj/item/storage/backpack/duffelbag
	messenger = /obj/item/storage/backpack/messenger

// AI EDIT START - Integrate event jobs and ID permissions
/datum/id_trim/job/ussp_hop
	parent_type = /datum/id_trim/job/head_of_personnel
	job = /datum/job/ussp_hop
// AI EDIT END
	assignment = "Управдом"


// AI EDIT START - Integrate event jobs and ID permissions
/// Keep the standard role's Russian aliases bound to the standard job.
/datum/job/ussp_hop/New()
	. = ..()
	alternate_titles = null
// AI EDIT END
