// AI EDIT START - Adapt the Lazarus event to the native Primera APIs and regression harness
/** The native loader must retain the entire colony, including its western observer point. */
/datum/unit_test/lazarus_loaded_map/Run()
	if(SSmapping.current_map?.map_name != LAZARUS_MAP_NAME)
		return
	TEST_ASSERT(world.maxx >= 400 && world.maxy >= 350, "The world must fit the complete 400x350 colony before map loading.")
	var/obj/effect/landmark/observer_start/observer = locate() in GLOB.landmarks_list
	TEST_ASSERT_NOTNULL(observer, "Lazarus must retain its observer start landmark.")
	TEST_ASSERT(is_station_level(observer.z) && istype(get_area(observer), /area/lazarus), "The observer landmark must be inside the loaded colony on a station level.")
	TEST_ASSERT(length(GLOB.the_station_areas), "Lazarus areas must be registered in the native station area list.")
	var/list/station_levels = SSmapping.levels_by_trait(ZTRAIT_STATION)
	var/colony_turf_count = 0
	var/lazarus_tile_count = 0
	var/list/states_by_icon = list()
	for(var/area/lazarus/colony_area in GLOB.areas)
		for(var/station_level in station_levels)
			var/list/area_turfs = colony_area.get_turfs_by_zlevel(station_level)
			colony_turf_count += length(area_turfs)
			for(var/turf/open/floor/floor in area_turfs)
				if(istype(floor, /turf/open/floor/glass) && !floor.icon_state && (floor.smoothing_flags & SMOOTH_BITMASK))
					continue // Glass renders its smoothing overlays instead of a base sprite.
				TEST_ASSERT(floor.icon && length(floor.icon_state), "[floor.type] at ([floor.x], [floor.y], [floor.z]) has no floor sprite.")
				var/list/states = states_by_icon[floor.icon]
				if(isnull(states))
					states = icon_states(floor.icon, TRUE)
					states_by_icon[floor.icon] = states
				TEST_ASSERT(floor.icon_state in states, "[floor.type] at ([floor.x], [floor.y], [floor.z]) has missing state '[floor.icon_state]' in '[floor.icon]'.")
				if(istype(floor, /turf/open/floor/iron/lazarus))
					lazarus_tile_count++
					var/previous_state = floor.icon_state
					TEST_ASSERT_EQUAL(floor.base_icon_state, previous_state, "The loaded colony tile did not retain its source state as its base.")
					floor.update_appearance(UPDATE_ICON_STATE)
					TEST_ASSERT_EQUAL(floor.icon_state, previous_state, "Updating a colony tile replaced its source sprite.")
					TEST_ASSERT_EQUAL(floor.base_icon_state, previous_state, "Updating a colony tile changed its source base state.")
	TEST_ASSERT_EQUAL(colony_turf_count, 140000, "All 140000 source colony turfs must survive native dynamic map loading.")
	TEST_ASSERT(lazarus_tile_count, "The loaded colony contains no converted donor floor tiles.")
	var/turf/open/misc/asteroid/lazarus/dirt = locate() in world
	TEST_ASSERT_NOTNULL(dirt, "The colony must contain its natural ground.")
	for(var/damaged_state in dirt.broken_states())
		TEST_ASSERT(icon_exists(dirt.damaged_dmi, damaged_state), "Excavating colony soil must not generate a missing damage sprite.")


/** Harvesting must keep the event's scarce wood yield and reject repeated harvests. */
/datum/unit_test/lazarus_mapping_trees/Run()
	var/obj/item/stack/sheet/mineral/wood/planks = allocate(/obj/item/stack/sheet/mineral/wood)
	var/has_ceiling_recipe = FALSE
	for(var/datum/stack_recipe/recipe in planks.get_main_recipes())
		if(recipe.result_type == /obj/item/lazarus_wooden_ceiling)
			has_ceiling_recipe = TRUE
	TEST_ASSERT_EQUAL(has_ceiling_recipe, SSmapping.current_map?.map_name == LAZARUS_MAP_NAME, "The colony ceiling must appear in the real plank menu only on Lazarus.")
	var/mob/living/carbon/human/colonist = allocate(/mob/living/carbon/human/consistent)
	var/obj/structure/flora/lazarus_tree/tree = allocate(/obj/structure/flora/lazarus_tree)
	var/obj/item/hatchet/hatchet = allocate(/obj/item/hatchet)
	var/obj/item/knife/kitchen/knife = allocate(/obj/item/knife/kitchen)
	TEST_ASSERT(tree.can_harvest(colonist, hatchet), "A hatchet must harvest event trees.")
	TEST_ASSERT(!tree.can_harvest(colonist, knife), "A knife must not replace the source's chopping tools.")
	var/list/wood = tree.harvest(colonist)
	allocated += wood
	TEST_ASSERT(length(wood) >= 2 && length(wood) <= 8, "Chopping must produce the source's two independent batches of one to four logs.")
	for(var/obj/item/grown/log/tree/lazarus/log as anything in wood)
		TEST_ASSERT_EQUAL(log.plank_count, 1, "Event logs must yield one plank, rather than the native ten.")
	TEST_ASSERT(!tree.harvest(colonist), "Concurrent or repeated completion must not duplicate harvested wood.")
	var/obj/structure/flora/lazarus_tree/broken_tree = allocate(/obj/structure/flora/lazarus_tree)
	var/list/broken_wood = broken_tree.harvest(product_amount_multiplier = 0.6)
	allocated += broken_wood
	TEST_ASSERT(length(broken_wood) >= 1 && length(broken_wood) <= 4, "Destruction must produce one batch of one to four logs.")
// AI EDIT END
