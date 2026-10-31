/obj/item/seeds/nofruit
	name = "nofruit seed pack"
	desc = "Семена нофрута. Необычное растение, ценимое любителями тишины. Его плоды подавляют речь и жесты."
	icon = 'modular_bandastation/xenoarchaeology/icons/plants/seeds.dmi'
	icon_state = "nofruit"
	species = "nofruit"
	plantname = "Нофрут"
	product = /obj/item/food/grown/nofruit
	lifespan = 55
	endurance = 35
	yield = 5
	growing_icon = 'modular_bandastation/xenoarchaeology/icons/plants/growing.dmi'
	icon_grow = "nofruit-stage"
	growthstages = 4
	genes = list(/datum/plant_gene/trait/repeated_harvest)
	reagents_add = list(/datum/reagent/consumable/nothing = 0.1, /datum/reagent/toxin/mimesbane = 0.1, /datum/reagent/toxin/mutetoxin = 0.1)

/obj/item/food/grown/nofruit
	seed = /obj/item/seeds/nofruit
	name = "nofruit"
	desc = "Кубический нофрут. Листок на верхушке отчаянно жестикулирует."
	icon = 'modular_bandastation/xenoarchaeology/icons/plants/harvest.dmi'
	icon_state = "nofruit"
	filling_color = "#FF4500"
	bite_consumption_mod = 0.5
	foodtypes = FRUIT
	tastes = list("ничего" = 1)

/obj/item/food/grown/nofruit/juice_typepath()
	return /datum/reagent/consumable/nothing
