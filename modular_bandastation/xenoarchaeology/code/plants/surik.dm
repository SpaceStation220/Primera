/obj/item/seeds/surik
	name = "surik seed pack"
	desc = "Семена сурика. Огнестойкое растение даёт кристаллы с редкими реагентами."
	icon = 'modular_bandastation/xenoarchaeology/icons/plants/seeds.dmi'
	icon_state = "surik"
	species = "surik"
	plantname = "Сурик"
	product = /obj/item/food/grown/surik
	lifespan = 55
	endurance = 35
	yield = 5
	growing_icon = 'modular_bandastation/xenoarchaeology/icons/plants/growing.dmi'
	icon_grow = "surik-stage"
	growthstages = 4
	genes = list(/datum/plant_gene/trait/repeated_harvest, /datum/plant_gene/trait/fire_resistance)
	reagents_add = list(/datum/reagent/brimdust = 0.1, /datum/reagent/medicine/omnizine/godblood = 0.1, /datum/reagent/wittel = 0.1)

/obj/item/food/grown/surik
	seed = /obj/item/seeds/surik
	name = "surik"
	desc = "Мерцающий кристалл сурика. Внутри словно пульсирует вулкан."
	icon = 'modular_bandastation/xenoarchaeology/icons/plants/harvest.dmi'
	icon_state = "surik"
	filling_color = "#FF4500"
	bite_consumption_mod = 0.5
	foodtypes = FRUIT
	tastes = list("кристаллы" = 1)

/obj/item/food/grown/surik/juice_typepath()
	return /datum/reagent/brimdust
