// AI EDIT START - Integrate event jobs and ID permissions
/datum/job/ussp_research_director
	display_order = 62
	parent_type = /datum/job/research_director
	config_tag = "USSP_RESEARCH_DIRECTOR"
	outfit = /datum/outfit/job/ussp_research_director
// AI EDIT END
	title = "Научрук"
	description = "Распределяйте своё внимание между научными сотрудниками, стараясь при этом угодить начальству"

// AI EDIT START - Integrate event jobs and ID permissions
/datum/outfit/job/ussp_research_director
	parent_type = /datum/outfit/job/rd
// AI EDIT END
	name = "Научрук"
	// AI EDIT START - Integrate event jobs and ID permissions
	jobtype = /datum/job/ussp_research_director
	// AI EDIT END

	// AI EDIT START - Integrate event jobs and ID permissions
	id_trim = /datum/id_trim/job/ussp_research_director
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
	l_pocket = /obj/item/laser_pointer/purple
	l_hand = /obj/item/clipboard
	pda_slot = null

	backpack = /obj/item/storage/backpack
	satchel = /obj/item/storage/backpack/satchel
	duffelbag = /obj/item/storage/backpack/duffelbag
	messenger = /obj/item/storage/backpack/messenger

// AI EDIT START - Integrate event jobs and ID permissions
/datum/id_trim/job/ussp_research_director
	parent_type = /datum/id_trim/job/research_director
	job = /datum/job/ussp_research_director
// AI EDIT END
	assignment = "Научрук"


// AI EDIT START - Integrate event jobs and ID permissions
/// Keep the standard role's Russian aliases bound to the standard job.
/datum/job/ussp_research_director/New()
	. = ..()
	alternate_titles = null
// AI EDIT END
