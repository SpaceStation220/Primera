// AI EDIT START - Adapt the Lazarus event to the native Primera APIs and regression harness
/datum/outfit/lazarus/corpse/chef
	name = "Chef"

	uniform = /obj/item/clothing/under/costume/buttondown/slacks/service
	suit = /obj/item/clothing/suit/toggle/chef
	belt = /obj/item/storage/belt/utility
	shoes = /obj/item/clothing/shoes/sneakers/black
	head = /obj/item/clothing/head/utility/chefhat
	ear_right = /obj/item/radio/headset/headset_srv
	id = /obj/item/card/id/advanced
	id_trim = /datum/id_trim/job/cook

/datum/outfit/lazarus/corpse/iaa
	name = "Lazarus IAA"

	uniform = /obj/item/clothing/under/rank/civilian/lawyer/black
	suit = /obj/item/clothing/suit/toggle/lawyer/black
	shoes = /obj/item/clothing/shoes/sneakers/brown
	ear_right = /obj/item/radio/headset/headset_srvsec
	id = /obj/item/card/id/advanced
	id_trim = /datum/id_trim/job/lawyer
	l_pocket = /obj/item/laser_pointer
	implants = list(/obj/item/implant/mindshield)
// AI EDIT END
