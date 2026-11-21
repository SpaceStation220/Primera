/obj/item/seeds/jurlmah
	name = "jurlmah seed pack"
	desc = "Семена джурлмы. Холодные светящиеся плоды содержат вещества для охлаждения, сна и криолечения."
	icon = 'modular_bandastation/xenoarchaeology/icons/plants/seeds.dmi'
	icon_state = "jurlmah"
	species = "jurlmah"
	plantname = "Джурлма"
	product = /obj/item/food/grown/jurlmah
	lifespan = 55
	endurance = 35
	yield = 5
	growing_icon = 'modular_bandastation/xenoarchaeology/icons/plants/growing.dmi'
	icon_grow = "jurlmah-stage"
	growthstages = 5
	genes = list(/datum/plant_gene/trait/repeated_harvest, /datum/plant_gene/trait/glow/blue)
	reagents_add = list(/datum/reagent/medicine/cryoxadone = 0.1, /datum/reagent/inverse/healing/tirimol  = 0.1, /datum/reagent/consumable/frostoil = 0.1)

/obj/item/food/grown/jurlmah
	seed = /obj/item/seeds/jurlmah
	name = "jurlmah"
	desc = "Покрытый инеем плод джурлмы. Холодит пальцы."
	icon = 'modular_bandastation/xenoarchaeology/icons/plants/harvest.dmi'
	icon_state = "jurlmah"
	filling_color = "#FF4500"
	bite_consumption_mod = 0.5
	foodtypes = FRUIT
	tastes = list("снег" = 1)

/obj/item/food/grown/jurlmah/juice_typepath()
	return /datum/reagent/medicine/cryoxadone
