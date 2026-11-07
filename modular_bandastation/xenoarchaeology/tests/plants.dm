/// Проверяем реальные стадии лотка, сбор, перенос генов и переработку каждого вида.
/datum/unit_test/xenoarchaeology_plants/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/list/juice_types = list(/datum/reagent/toxin, /datum/reagent/consumable/sugar, /datum/reagent/medicine/cryoxadone, /datum/reagent/consumable/nothing, /datum/reagent/bromine, /datum/reagent/brimdust, /datum/reagent/consumable/coconut_milk, /datum/reagent/silver, /datum/reagent/toxin/plasma, /datum/reagent/nitrous_oxide)
	var/index = 0
	for(var/obj/item/seeds/seed_type as anything in list(/obj/item/seeds/amauri, /obj/item/seeds/gelthi, /obj/item/seeds/jurlmah, /obj/item/seeds/nofruit, /obj/item/seeds/shand, /obj/item/seeds/surik, /obj/item/seeds/telriis, /obj/item/seeds/thaadra, /obj/item/seeds/vale, /obj/item/seeds/vaporsac))
		index++
		var/obj/machinery/hydroponics/tray = allocate(__IMPLIED_TYPE__)
		var/obj/item/seeds/seed = allocate(seed_type)
		seed.set_instability(0)
		seed.weed_chance = 0
		tray.set_seed(seed)
		tray.set_plant_health(seed.endurance, forced = TRUE)
		tray.waterlevel = 100
		tray.reagents.add_reagent(/datum/reagent/plantnutriment/eznutriment, tray.maxnutri)
		TEST_ASSERT(seed.icon_state in icon_states(seed.icon), "Нет семян [seed_type]")
		fcopy(getFlatIcon(seed), "data/xenoarch-plants/[seed.species]-seeds.png")
		for(var/stage in 1 to seed.growthstages)
			tray.age = CEILING(seed.maturation * stage / seed.growthstages, 1)
			var/mutable_appearance/plant_overlay = seed.get_tray_overlay(tray.age, HYDROTRAY_PLANT_GROWING, tray.plant_offset_y)
			TEST_ASSERT_EQUAL(plant_overlay.icon_state, "[seed.icon_grow][stage]", "Неверная стадия роста [seed_type]")
			TEST_ASSERT(plant_overlay.icon_state in icon_states(plant_overlay.icon), "Нет стадии [stage] у [seed_type]")
			tray.update_appearance()
			fcopy(getFlatIcon(tray), "data/xenoarch-plants/[seed.species]-stage[stage].png")
		tray.age = 0
		tray.lastproduce = 0
		for(var/cycle in 1 to (seed.maturation + seed.production + 2))
			tray.lastcycle = world.time - tray.cycledelay - 1
			tray.process(1)
			if(tray.plant_status == HYDROTRAY_PLANT_HARVESTABLE)
				break
		TEST_ASSERT_EQUAL(tray.plant_status, HYDROTRAY_PLANT_HARVESTABLE, "Не созрело растение [seed_type]")
		var/mutable_appearance/harvest_overlay = seed.get_tray_overlay(tray.age, HYDROTRAY_PLANT_HARVESTABLE, tray.plant_offset_y)
		TEST_ASSERT(harvest_overlay.icon_state in icon_states(harvest_overlay.icon), "Нет зрелого растения [seed_type]")
		fcopy(getFlatIcon(tray), "data/xenoarch-plants/[seed.species]-mature.png")
		var/expected_yield = seed.getYield()
		var/product_type = seed.product
		var/list/expected_reagents = seed.reagents_add.Copy()
		var/repeated = !!seed.get_gene(/datum/plant_gene/trait/repeated_harvest)
		var/list/products = seed.harvest(user)
		TEST_ASSERT_EQUAL(length(products), expected_yield, "Неверный урожай [seed_type]")
		TEST_ASSERT_EQUAL(!!tray.myseed, repeated, "Неверный повторный сбор [seed_type]")
		var/obj/item/food/grown/fruit = products[1]
		TEST_ASSERT_EQUAL(fruit.type, product_type, "Выдан чужой урожай [seed_type]")
		TEST_ASSERT_EQUAL(fruit.seed.type, seed_type, "Урожай потерял семена [seed_type]")
		TEST_ASSERT(fruit.icon_state in icon_states(fruit.icon), "Нет спрайта урожая [seed_type]")
		fcopy(getFlatIcon(fruit), "data/xenoarch-plants/[fruit.seed.species]-produce.png")
		for(var/reagent in expected_reagents)
			TEST_ASSERT(fruit.reagents.has_reagent(reagent), "Урожай [seed_type] не содержит [reagent]")
		TEST_ASSERT_EQUAL(fruit.juice_typepath(), juice_types[index], "Неверный сок [seed_type]")
		var/obj/item/reagent_containers/cup/beaker/large/beaker = allocate(__IMPLIED_TYPE__)
		var/obj/machinery/reagentgrinder/grinder = allocate(__IMPLIED_TYPE__)
		fruit.forceMove(grinder)
		var/before_juice = fruit.reagents.total_volume
		var/juice_result = fruit.juice(beaker.reagents, user, grinder)
		TEST_ASSERT(juice_result, "Не выжат урожай [seed_type]: до [before_juice], в стакане [beaker.reagents.total_volume], результат [juice_result]")
		TEST_ASSERT(beaker.reagents.has_reagent(juice_types[index]), "При выжимании [seed_type] не появился нужный реагент")
		beaker.reagents.clear_reagents()
		for(var/obj/item/food/grown/product as anything in products)
			if(QDELETED(product))
				continue
			product.forceMove(grinder)
			var/before_grind = product.reagents.total_volume
			var/before_target = beaker.reagents.total_volume
			var/grind_result = product.grind(beaker.reagents, user, grinder)
			TEST_ASSERT(grind_result, "Не перемолот урожай [seed_type]: до [before_grind], стакан [before_target]/[beaker.reagents.maximum_volume], после [beaker.reagents.total_volume], результат [grind_result]")
			beaker.reagents.clear_reagents()
		var/obj/item/seeds/dead_seed = allocate(seed_type)
		tray.set_seed(dead_seed)
		tray.set_plant_status(HYDROTRAY_PLANT_DEAD)
		var/mutable_appearance/dead_overlay = dead_seed.get_tray_overlay(tray.age, HYDROTRAY_PLANT_DEAD, tray.plant_offset_y)
		TEST_ASSERT(dead_overlay.icon_state in icon_states(dead_overlay.icon), "Нет погибшего растения [seed_type]")
		fcopy(getFlatIcon(tray), "data/xenoarch-plants/[dead_seed.species]-dead.png")
		qdel(tray)

/datum/unit_test/xenoarchaeology_plant_rewards/Run()
	var/list/loot = /obj/effect/spawner/random/xenoarch/plant::loot
	for(var/seed_type in list(/obj/item/seeds/amauri, /obj/item/seeds/gelthi, /obj/item/seeds/jurlmah, /obj/item/seeds/nofruit, /obj/item/seeds/shand, /obj/item/seeds/surik, /obj/item/seeds/telriis, /obj/item/seeds/thaadra, /obj/item/seeds/vale, /obj/item/seeds/vaporsac))
		TEST_ASSERT(seed_type in loot, "Семена [seed_type] недоступны из находок")
	var/obj/item/xenoarch/broken_item/plant/shell = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(shell.recover(), "Не раскрыта растительная находка")
	var/list/seeds = list()
	for(var/obj/item/seeds/seed in run_loc_floor_bottom_left)
		seeds += seed
	TEST_ASSERT_EQUAL(length(seeds), 2, "Из растительной находки должно выпасть две упаковки")
	for(var/obj/item/seeds/seed as anything in seeds)
		TEST_ASSERT(seed.type in loot, "Из находки выпали посторонние семена")
		qdel(seed)

/datum/unit_test/xenoarchaeology_vaporsac/Run()
	var/obj/item/food/grown/vaporsac/fruit = allocate(__IMPLIED_TYPE__)
	var/datum/plant_gene/trait/squash/squash = fruit.seed.get_gene(/datum/plant_gene/trait/squash)
	TEST_ASSERT_NOTNULL(squash, "У паромешка нет раздавливания")
	TEST_ASSERT_NOTNULL(fruit.seed.get_gene(/datum/plant_gene/trait/smoke), "У паромешка нет химического дыма")
	squash.squash_plant(fruit, run_loc_floor_bottom_left)
	TEST_ASSERT(QDELETED(fruit), "Раздавленный паромешок не удалён")
	sleep(0.5 SECONDS)
	var/found_smoke = FALSE
	for(var/obj/effect/particle_effect/fluid/smoke/chem/smoke in range(4, run_loc_floor_bottom_left))
		if(smoke.reagents.has_reagent(/datum/reagent/nitrous_oxide) && smoke.reagents.has_reagent(/datum/reagent/medicine/muscle_stimulant) && smoke.reagents.has_reagent(/datum/reagent/medicine/coagulant))
			found_smoke = TRUE
	TEST_ASSERT(found_smoke, "Дым паромешка не перенёс исходные реагенты")
