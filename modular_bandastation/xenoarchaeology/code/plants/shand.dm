/obj/item/seeds/shand
	name = "shand seed pack"
	desc = "Семена шанда. Растение даёт листья с бромом, натрием и медью. Уплотнение реагентов уменьшает урожайность."
	icon = 'modular_bandastation/xenoarchaeology/icons/plants/seeds.dmi'
	icon_state = "shand"
	species = "shand"
	plantname = "Шанд"
	product = /obj/item/food/grown/shand
	lifespan = 55
	endurance = 35
	yield = 5
	growing_icon = 'modular_bandastation/xenoarchaeology/icons/plants/growing.dmi'
	icon_grow = "shand-stage"
	growthstages = 3
	genes = list(/datum/plant_gene/trait/repeated_harvest, /datum/plant_gene/trait/maxchem)
	reagents_add = list(/datum/reagent/bromine = 0.1, /datum/reagent/sodium = 0.1, /datum/reagent/copper = 0.1)

/obj/item/food/grown/shand
	seed = /obj/item/seeds/shand
	name = "shand"
	desc = "Маслянистые листья шанда с запахом химической лаборатории."
	icon = 'modular_bandastation/xenoarchaeology/icons/plants/harvest.dmi'
	icon_state = "shand"
	filling_color = "#FF4500"
	bite_consumption_mod = 0.5
	foodtypes = FRUIT
	tastes = list("реактивы" = 1)

/obj/item/food/grown/shand/juice_typepath()
	return /datum/reagent/bromine
