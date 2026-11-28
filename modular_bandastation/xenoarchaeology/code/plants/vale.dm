/obj/item/seeds/vale
	name = "vale seed pack"
	desc = "Семена вейла. Декоративное светящееся растение с горючими веществами в листьях."
	icon = 'modular_bandastation/xenoarchaeology/icons/plants/seeds.dmi'
	icon_state = "vale"
	species = "vale"
	plantname = "Вейл"
	product = /obj/item/food/grown/vale
	lifespan = 55
	endurance = 35
	yield = 5
	growing_icon = 'modular_bandastation/xenoarchaeology/icons/plants/growing.dmi'
	icon_grow = "vale-stage"
	growthstages = 4
	genes = list(/datum/plant_gene/trait/repeated_harvest, /datum/plant_gene/trait/glow/pink)
	reagents_add = list(/datum/reagent/stable_plasma = 0.1, /datum/reagent/toxin/plasma = 0.1, /datum/reagent/napalm = 0.1)

/obj/item/food/grown/vale
	seed = /obj/item/seeds/vale
	name = "vale"
	desc = "Светящиеся листья вейла. Держите подальше от открытого огня."
	icon = 'modular_bandastation/xenoarchaeology/icons/plants/harvest.dmi'
	icon_state = "vale"
	filling_color = "#FF4500"
	bite_consumption_mod = 0.5
	foodtypes = FRUIT
	tastes = list("плазма" = 1)

/obj/item/food/grown/vale/juice_typepath()
	return /datum/reagent/toxin/plasma
