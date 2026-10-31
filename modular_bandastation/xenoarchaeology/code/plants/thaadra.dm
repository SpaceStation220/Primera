/obj/item/seeds/thaadra
	name = "thaadra seed pack"
	desc = "Семена таадры. Цветы содержат серебро, сансуфентанил и кордиолис гепатико; смесь требует осторожного применения."
	icon = 'modular_bandastation/xenoarchaeology/icons/plants/seeds.dmi'
	icon_state = "thaadra"
	species = "thaadra"
	plantname = "Таадра"
	product = /obj/item/food/grown/thaadra
	lifespan = 55
	endurance = 35
	yield = 5
	growing_icon = 'modular_bandastation/xenoarchaeology/icons/plants/growing.dmi'
	icon_grow = "thaadra-stage"
	growthstages = 4
	genes = list(/datum/plant_gene/trait/repeated_harvest, /datum/plant_gene/trait/preserved)
	reagents_add = list(/datum/reagent/silver = 0.1, /datum/reagent/medicine/sansufentanyl = 0.1, /datum/reagent/medicine/cordiolis_hepatico = 0.1)

/obj/item/food/grown/thaadra
	seed = /obj/item/seeds/thaadra
	name = "thaadra"
	desc = "Лепестки таадры, насыщенные серебром и необычными медицинскими реагентами."
	icon = 'modular_bandastation/xenoarchaeology/icons/plants/harvest.dmi'
	icon_state = "thaadra"
	filling_color = "#FF4500"
	bite_consumption_mod = 0.5
	foodtypes = FRUIT
	tastes = list("серебро" = 1)

/obj/item/food/grown/thaadra/juice_typepath()
	return /datum/reagent/silver
