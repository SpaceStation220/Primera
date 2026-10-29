// AI EDIT START - Adapt the Lazarus event to the native Primera APIs and regression harness
/datum/outfit/lazarus/corpse/security
	name = "Lazarus Security"

	uniform = /obj/item/clothing/under/rank/security/officer
	shoes = /obj/item/clothing/shoes/jackboots
	gloves = /obj/item/clothing/gloves/color/black
	id = /obj/item/card/id/advanced
	id_trim = /datum/id_trim/job/security_officer
	suit = /obj/item/clothing/suit/hooded/wintercoat/security
	head = /obj/item/clothing/head/helmet
	belt = /obj/item/storage/belt/security
	ear_right = /obj/item/radio/headset/headset_sec/alt
	back = /obj/item/storage/backpack/security
	implants = list(/obj/item/implant/mindshield)

	loot = list(
		// Tools
		/obj/item/screwdriver = 10,
		/obj/item/wrench = 10,
		/obj/item/weldingtool = 10,
		/obj/item/crowbar = 10,
		/obj/item/wirecutters = 10,
		/obj/item/multitool = 10,
		/obj/item/stack/cable_coil = 10,
		/obj/item/clothing/head/utility/welding = 3,
		/obj/item/clothing/gloves/color/yellow = 2,
		/obj/item/clothing/gloves/color/fyellow = 5,

		// Food (Lack of food is one of the event ideas)
		/obj/item/food/cakeslice/apple = 1,
		/obj/item/food/cakeslice/cheese = 1,
		/obj/item/food/breadslice/meat = 1,
		/obj/item/food/breadslice/creamcheese = 1,
		/obj/item/food/grown/apple = 1,
		/obj/item/food/grown/berries = 5,
		/obj/item/food/donkpocket = 1,
		/obj/item/food/sandwich = 1,
		/obj/item/food/chips = 1,
		/obj/item/food/breadslice/plain = 1,
		/obj/item/food/meat/slab = 5,
		/obj/item/food/meat/steak/plain = 1,

		// Melee Weapons
		/obj/item/hatchet = 8,
		/obj/item/pickaxe = 5,
		/obj/item/shovel = 12,
		/obj/item/fireaxe = 2,
		/obj/item/pickaxe/diamond = 2,
		/obj/item/claymore = 1,
		/obj/item/spear = 8,
		/obj/item/melee/baton/security/cattleprod/loaded = 6,
		/obj/item/melee/baton/security/loaded = 50,
		/obj/item/knife/kitchen = 5,

		// Ranged Weapons + Ammo
		/obj/item/gun/energy/disabler = 40,
		/obj/item/gun/ballistic/automatic/pistol = 1,
		/obj/item/ammo_box/magazine/m10mm = 4,
		/obj/item/gun/energy/laser = 20,
		/obj/item/gun/ballistic/automatic/pistol/gp9 = 15,
		/obj/item/ammo_box/magazine/c9x25mm_pistol = 45,

		// Medicine
		/obj/item/healthanalyzer = 4,
		/obj/item/healthanalyzer/advanced = 2,
		/obj/item/stack/medical/bruise_pack = 10,
		/obj/item/stack/medical/ointment = 10,
		/obj/item/stack/medical/suture/medicated = 4,
		/obj/item/stack/medical/mesh/advanced = 4,
		/obj/item/reagent_containers/hypospray/medipen = 10,

		// Light
		/obj/item/flashlight = 6,
		/obj/item/flashlight/flare/torch = 15,
		/obj/item/flashlight/flare = 15,
		/obj/item/flashlight/lantern = 6,


		// Other
		/obj/item/stock_parts/power_store/cell = 6,
		/obj/item/stock_parts/power_store/cell/high = 4,
		/obj/item/reagent_containers/spray/cleaner = 3,
		/obj/item/radio/off = 7,
		/obj/item/extinguisher/mini = 4,
		/obj/item/stack/rods{amount = 10} = 8,
		/obj/item/stack/sheet/iron{amount = 10} = 8,
		/obj/item/stack/sheet/glass{amount = 10} = 8,

		// Trash
		/obj/item/camera = 15,
		/obj/item/paper = 10,
		/obj/item/storage/fancy/cigarettes/cigpack_robust = 8,
		/obj/item/lighter = 8,
		/obj/item/lighter/greyscale = 2,
		/obj/item/storage/photo_album = 10,
		/obj/item/stack/medical/wrap/sticky_tape = 10,
		/obj/item/coin/silver = 10,
		/obj/item/assembly/timer = 10
	)
// AI EDIT END
