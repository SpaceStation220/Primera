/obj/item/seeds/vaporsac
	name = "vaporsac seed pack"
	desc = "Семена паромешка. Его плоды при раздавливании выпускают дым с содержащимися в них реагентами."
	icon = 'modular_bandastation/xenoarchaeology/icons/plants/seeds.dmi'
	icon_state = "vaporsac"
	species = "vaporsac"
	plantname = "Паромешок"
	product = /obj/item/food/grown/vaporsac
	lifespan = 55
	endurance = 35
	yield = 5
	growing_icon = 'modular_bandastation/xenoarchaeology/icons/plants/growing.dmi'
	icon_grow = "vaporsac-stage"
	growthstages = 3
	genes = list(/datum/plant_gene/trait/squash, /datum/plant_gene/trait/smoke)
	reagents_add = list(/datum/reagent/nitrous_oxide = 0.1, /datum/reagent/medicine/muscle_stimulant = 0.1, /datum/reagent/medicine/coagulant = 0.1)

/obj/item/food/grown/vaporsac
	seed = /obj/item/seeds/vaporsac
	name = "vaporsac"
	desc = "Лёгкий плод паромешка, наполненный химическими веществами для аэрозольного распыления."
	icon = 'modular_bandastation/xenoarchaeology/icons/plants/harvest.dmi'
	icon_state = "vaporsac"
	filling_color = "#FF4500"
	bite_consumption_mod = 0.5
	foodtypes = FRUIT
	tastes = list("сон" = 1)

/obj/item/food/grown/vaporsac/juice_typepath()
	return /datum/reagent/nitrous_oxide
