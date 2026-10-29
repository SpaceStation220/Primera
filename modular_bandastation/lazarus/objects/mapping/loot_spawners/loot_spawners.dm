/obj/effect/spawner/random/lazarus
	icon = 'modular_bandastation/lazarus/icons/mapping.dmi'
	icon_state = "lootmark"

/obj/effect/spawner/random/lazarus/trash
	name = "trash spawner"
	icon_state = "trash"

	spawn_loot_count = 1
	loot = list(
		/obj/item/stack/cable_coil {amount = 1} = 10,
		/obj/item/stack/cable_coil {amount = 2} = 10,
		/obj/item/stack/cable_coil {amount = 5} = 10,
		/obj/item/stack/cable_coil {amount = 10} = 5,
		/obj/item/stack/rods{amount = 1} = 10,
		/obj/item/stack/rods{amount = 2} = 10,
		/obj/item/stack/rods{amount = 3} = 10,
		/obj/item/stack/rods{amount = 5} = 5,
		/obj/item/stack/sheet/iron{amount = 1} = 20,
		/obj/item/stack/sheet/cardboard{amount = 1} = 20,
		/obj/item/stack/ore/glass{amount = 1} = 40,
		/obj/item/cigbutt = 60,
		/obj/item/trash/popcorn = 10,
		/obj/item/trash/candy = 30,
		/obj/item/trash/cheesie = 10,
		/obj/item/trash/chips = 10,
		/obj/item/trash/sosjerky = 10,
		/obj/item/trash/syndi_cakes = 10,
		/obj/item/plate = 10,
		/obj/item/trash/ready_donk = 10,
		/obj/item/trash/can = 10,
		/obj/item/ammo_casing/c45/spent = 30,
	)

/obj/effect/spawner/random/lazarus/medical
	name = "medicine spawner"
	icon_state = "medical"

	spawn_loot_count = 1
	loot = list(
		// FIRST AID KITS
		/obj/item/storage/medkit/regular = 15,
		/obj/item/storage/medkit/fire = 5,
		/obj/item/storage/medkit/brute = 5,
		/obj/item/storage/medkit/o2 = 5,
		/obj/item/storage/medkit/toxin = 5,
		/obj/item/storage/medkit/advanced = 5,

		// MED KITS
		/obj/item/stack/medical/bruise_pack = 30,
		/obj/item/stack/medical/suture/medicated = 30,
		/obj/item/stack/medical/ointment = 30,
		/obj/item/stack/medical/mesh/advanced = 30,
		/obj/item/stack/medical/wrap/gauze = 10,

		// MENDERS
		/obj/item/reagent_containers/medigel/lazarus/brute = 15,
		/obj/item/reagent_containers/medigel/lazarus/burn = 15,

		// OTHER
		/obj/item/reagent_containers/hypospray/medipen = 30,
		/obj/item/healthanalyzer = 10,
		/obj/item/healthanalyzer/advanced = 10,
		/obj/item/reagent_containers/cup/bottle/lazarus_oculine = 10,
		/obj/item/reagent_containers/cup/bottle/morphine = 10,
		/obj/item/reagent_containers/cup/bottle/lazarus_reagent = 10,
		/obj/item/vending_refill/medical = 10,
	)

/obj/effect/spawner/random/lazarus/engineering
	name = "engi loot spawner"
	icon_state = "engineering"

	spawn_loot_count = 1
	loot = list(
		// BOXES
		/obj/item/storage/toolbox/mechanical = 10,
		/obj/item/storage/toolbox/electrical = 10,
		/obj/item/storage/toolbox/emergency = 10,
		/obj/item/storage/medkit/lazarus_machine = 5,

		// TOOLS
		/obj/item/crowbar = 5,
		/obj/item/wirecutters = 5,
		/obj/item/wrench = 5,
		/obj/item/screwdriver = 5,
		/obj/item/multitool = 5,
		/obj/item/weldingtool = 3,
		/obj/item/weldingtool/largetank = 2,

		// EQUIPMENT
		/obj/item/clothing/head/utility/welding = 4,
		/obj/item/clothing/glasses/welding = 4,
		/obj/item/clothing/gloves/color/fyellow = 5,
		/obj/item/clothing/gloves/color/yellow = 3,

		// MATERIALS
		/obj/item/stack/rods{amount = 10} = 8,
		/obj/item/stack/sheet/iron{amount = 10} = 8,
		/obj/item/stack/sheet/glass{amount = 10} = 8,
	)

/obj/effect/spawner/random/lazarus/food
	name = "food spawner"
	icon_state = "food"

	spawn_loot_count = 1
	loot = list(
		// FOOD
		/obj/item/food/boiledrice = 10,
		/obj/item/food/friedegg = 10,
		/obj/item/food/meat/steak/plain = 10,
		/obj/item/food/breadslice/plain = 10,
		/obj/item/food/bread/plain = 2,
		/obj/item/food/salad/greek_salad = 10,
		/obj/item/food/salad/caesar_salad = 10,

		// DRINKS
		/obj/item/reagent_containers/cup/bowl/soup/lazarus_chicken = 15,
		/obj/item/reagent_containers/cup/soda_cans/cola = 10,
		/obj/item/reagent_containers/cup/soda_cans/sodawater = 10,
		/obj/item/reagent_containers/cup/soda_cans/lazarus_kvass = 10,
	)
