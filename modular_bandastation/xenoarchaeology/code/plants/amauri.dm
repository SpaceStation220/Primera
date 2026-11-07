/obj/item/seeds/amauri
	name = "amauri seed pack"
	desc = "Семена амаури. Растение даёт ядовитые луковицы, содержащие токсины и взвесь горячего льда."
	icon = 'modular_bandastation/xenoarchaeology/icons/plants/seeds.dmi'
	icon_state = "amauri"
	species = "amauri"
	plantname = "Амаури"
	product = /obj/item/food/grown/amauri
	lifespan = 55
	endurance = 35
	yield = 5
	growing_icon = 'modular_bandastation/xenoarchaeology/icons/plants/growing.dmi'
	icon_grow = "amauri-stage"
	growthstages = 3
	genes = list(/datum/plant_gene/trait/repeated_harvest, /datum/plant_gene/trait/preserved)
	reagents_add = list(/datum/reagent/toxin = 0.1, /datum/reagent/toxin/venom = 0.1, /datum/reagent/toxin/hot_ice = 0.1)

/obj/item/food/grown/amauri
	seed = /obj/item/seeds/amauri
	name = "amauri"
	desc = "Ядовитая луковица амаури. Непригодна для обычной еды."
	icon = 'modular_bandastation/xenoarchaeology/icons/plants/harvest.dmi'
	icon_state = "amauri"
	filling_color = "#FF4500"
	bite_consumption_mod = 0.5
	foodtypes = FRUIT
	tastes = list("яд" = 1)

/obj/item/food/grown/amauri/juice_typepath()
	return /datum/reagent/toxin
