/obj/item/seeds/gelthi
	name = "gelthi seed pack"
	desc = "Семена гелти. Сладкие стручки содержат мёд, посыпку и подсластитель."
	icon = 'modular_bandastation/xenoarchaeology/icons/plants/seeds.dmi'
	icon_state = "gelthi"
	species = "gelthi"
	plantname = "Гелти"
	product = /obj/item/food/grown/gelthi
	lifespan = 55
	endurance = 35
	yield = 5
	growing_icon = 'modular_bandastation/xenoarchaeology/icons/plants/growing.dmi'
	icon_grow = "gelthi-stage"
	growthstages = 3
	genes = list(/datum/plant_gene/trait/repeated_harvest, /datum/plant_gene/trait/squash)
	// Соковыжиматель превращает nutriment в указанный сок; исходному растению его не хватало.
	reagents_add = list(/datum/reagent/consumable/nutriment = 0.1, /datum/reagent/consumable/sprinkles = 0.1, /datum/reagent/consumable/astrotame = 0.1, /datum/reagent/consumable/honey = 0.2)

/obj/item/food/grown/gelthi
	seed = /obj/item/seeds/gelthi
	name = "gelthi"
	desc = "Гроздь сладких стручков гелти. Их можно выжать в сахар."
	icon = 'modular_bandastation/xenoarchaeology/icons/plants/harvest.dmi'
	icon_state = "gelthi"
	filling_color = "#FF4500"
	bite_consumption_mod = 0.5
	foodtypes = FRUIT
	tastes = list("приторная сладость" = 1)

/obj/item/food/grown/gelthi/juice_typepath()
	return /datum/reagent/consumable/sugar
