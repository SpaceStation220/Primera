/// Colonist roles exist in the lobby only while the event map is selected.
/datum/job/lazarus
	faction = FACTION_STATION
	job_flags = STATION_JOB_FLAGS
	exp_granted_type = EXP_TYPE_CREW
	departments_list = list(/datum/job_department/assistant)
	outfit = /datum/outfit/job/assistant
	allow_bureaucratic_error = FALSE
	random_spawns_possible = FALSE

/datum/job/lazarus/map_check()
	return type != /datum/job/lazarus && SSmapping.current_map?.map_name == LAZARUS_MAP_NAME && ..()

/// Late arrivals use the same remote settlement as their roundstart role.
/datum/job/lazarus/get_latejoin_spawn_point()
	return get_default_roundstart_spawn_point() || ..()

/datum/job/lazarus/hermit
	title = "Hermit"
	description = "Выживайте в уединении среди ледяных пустошей."
	supervisors = "собственная совесть"
	config_tag = "LAZARUS_HERMIT"
	total_positions = 6
	spawn_positions = 6

/datum/job/lazarus/crusader
	title = "Crusader"
	description = "Несите веру колонистам и противостойте скверне."
	supervisors = "всевышний"
	config_tag = "LAZARUS_CRUSADER"
	total_positions = 1
	spawn_positions = 1
	outfit = /datum/outfit/job/lazarus/crusader

/datum/job/lazarus/abandoned_miner
	title = "Abandoned Miner"
	description = "Вы забытый шахтёр на окраине колонии."
	supervisors = "руководство комплекса"
	config_tag = "LAZARUS_ABANDONED_MINER"
	total_positions = 1
	spawn_positions = 1
	outfit = /datum/outfit/job/miner

/datum/job/lazarus/cannibal
	title = "Cannibal"
	description = "Служите Великой Плоти и устройте пир."
	supervisors = "голос плоти"
	config_tag = "LAZARUS_CANNIBAL"
	total_positions = 4
	spawn_positions = 4
	outfit = /datum/outfit/job/lazarus/cannibal

/datum/job/lazarus/sectarian
	title = "Sectarian"
	description = "Почитайте Бога-Во-Плоти и ожидайте его пробуждения."
	supervisors = "Бог-Во-Плоти"
	config_tag = "LAZARUS_SECTARIAN"
	total_positions = 4
	spawn_positions = 4
	outfit = /datum/outfit/job/lazarus/sectarian

/datum/job/lazarus/syndicate_agent
	title = "Syndicate Agent"
	description = "Работайте на Синдикат в охваченной карантином колонии."
	supervisors = "Синдикат"
	config_tag = "LAZARUS_SYNDICATE_AGENT"
	total_positions = 3
	spawn_positions = 3
	outfit = /datum/outfit/job/lazarus/syndicate_agent

/// Event factions have no station PDA or survival-box loadout.
/datum/outfit/job/lazarus
	name = "Lazarus colonist"
	id_trim = /datum/id_trim/job/assistant
	pda_slot = null
	box = null
	belt = null
	l_pocket = null
	r_pocket = null
	ear_right = /obj/item/radio/headset

/datum/outfit/job/lazarus/crusader
	name = "Lazarus Crusader"
	jobtype = /datum/job/lazarus/crusader
	uniform = /obj/item/clothing/under/rank/civilian/chaplain
	shoes = /obj/item/clothing/shoes/sneakers/black

/datum/outfit/job/lazarus/cannibal
	name = "Lazarus Cannibal"
	jobtype = /datum/job/lazarus/cannibal
	uniform = /obj/item/clothing/under/color/white
	suit = /obj/item/clothing/suit/hooded/wintercoat
	gloves = /obj/item/clothing/gloves/color/white
	shoes = /obj/item/clothing/shoes/winterboots
	mask = /obj/item/clothing/mask/animal/pig
	belt = /obj/item/storage/belt/fannypack
	id = /obj/item/card/id/advanced/chameleon
	backpack_contents = list(/obj/item/restraints/handcuffs = 1, /obj/item/knife/butcher = 1)

/datum/outfit/job/lazarus/sectarian
	name = "Lazarus Sectarian"
	jobtype = /datum/job/lazarus/sectarian
	uniform = /obj/item/clothing/under/color/black
	suit = /obj/item/clothing/suit/hooded/cultrobes
	gloves = /obj/item/clothing/gloves/color/black
	shoes = /obj/item/clothing/shoes/jackboots
	mask = /obj/item/clothing/mask/gas/plaguedoctor
	backpack_contents = list(/obj/item/knife/ritual = 1)

/datum/outfit/job/lazarus/syndicate_agent
	name = "Lazarus Syndicate Agent"
	jobtype = /datum/job/lazarus/syndicate_agent
	uniform = /obj/item/clothing/under/syndicate
	gloves = /obj/item/clothing/gloves/combat
	shoes = /obj/item/clothing/shoes/jackboots
	belt = /obj/item/storage/belt/military
	id = /obj/item/card/id/advanced/chameleon
