/obj/item/seeds/telriis
	name = "telriis seed pack"
	desc = "Семена тельриса. Молочная трава, способная распространяться в соседние лотки."
	icon = 'modular_bandastation/xenoarchaeology/icons/plants/seeds.dmi'
	icon_state = "telriis"
	species = "telriis"
	plantname = "Тельрис"
	product = /obj/item/food/grown/telriis
	lifespan = 55
	endurance = 35
	yield = 5
	growing_icon = 'modular_bandastation/xenoarchaeology/icons/plants/growing.dmi'
	icon_grow = "telriis-stage"
	growthstages = 4
	plant_icon_offset = 7
	genes = list(/datum/plant_gene/trait/repeated_harvest, /datum/plant_gene/trait/invasive)
	// Соковыжиматель превращает nutriment в указанный сок; исходному растению его не хватало.
	reagents_add = list(/datum/reagent/consumable/nutriment = 0.1, /datum/reagent/consumable/milk = 0.1, /datum/reagent/consumable/soymilk = 0.1, /datum/reagent/consumable/korta_milk = 0.1)

/obj/item/food/grown/telriis
	seed = /obj/item/seeds/telriis
	name = "telriis"
	desc = "Сноп тельриса. Содержит несколько видов молока и выжимается в кокосовое молоко."
	icon = 'modular_bandastation/xenoarchaeology/icons/plants/harvest.dmi'
	icon_state = "telriis"
	filling_color = "#FF4500"
	bite_consumption_mod = 0.5
	foodtypes = FRUIT
	tastes = list("молоко" = 1)

/obj/item/food/grown/telriis/juice_typepath()
	return /datum/reagent/consumable/coconut_milk
