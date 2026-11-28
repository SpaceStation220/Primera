/datum/unit_test/component_duping/Run()
	var/list/bad_dms = list()
	for(var/t in typesof(/datum/component))
		var/datum/component/comp = t
		if(!isnum(initial(comp.dupe_mode)))
			bad_dms += t
	TEST_ASSERT(!length(bad_dms), "Components with invalid dupe modes: ([bad_dms.Join(",")])")

/// Verifies /datum/component/magnet C++-filtered item loop pulls attracted items and ignores unrelated items.
/datum/unit_test/magnet_component_items_only/Run()
	var/turf/origin = run_loc_floor_bottom_left
	var/turf/target_turf = locate(origin.x + 2, origin.y, origin.z)
	var/obj/structure/closet/crate/anchor = allocate(/obj/structure/closet/crate, origin)
	var/obj/item/stack/sheet/mineral/diamond/diamond = allocate(/obj/item/stack/sheet/mineral/diamond, target_turf)
	var/obj/item/crowbar/crowbar = allocate(/obj/item/crowbar, target_turf)

	var/datum/component/magnet/magnet = anchor.AddComponent(/datum/component/magnet, pull_range = 4, attracted_typecache = list(/obj/item/stack/sheet/mineral/diamond))
	TEST_ASSERT(magnet.items_only, "Item-only magnet did not enable items_only fast path")

	magnet.process(1)

	TEST_ASSERT_EQUAL(diamond.loc, locate(origin.x + 1, origin.y, origin.z), "Magnet failed to pull attracted diamond item")
	TEST_ASSERT_EQUAL(crowbar.loc, target_turf, "Magnet pulled an unattracted crowbar")

/// Verifies SSradiation.pulse notifies COMSIG_IN_RANGE_OF_IRRADIATION listeners at threshold >= RAD_NO_INSULATION without irradiating targets, while irradiating humans and items below threshold.
/datum/unit_test/radiation_pulse_threshold_and_listeners/Run()
	var/turf/origin = run_loc_floor_bottom_left
	var/mob/living/carbon/human/consistent/human = allocate(/mob/living/carbon/human/consistent, origin)
	var/obj/item/wrench/wrench = allocate(/obj/item/wrench, origin)
	var/obj/item/geiger_counter/geiger = allocate(/obj/item/geiger_counter, origin)

	var/datum/radiation_pulse_information/high_threshold_pulse = allocate(/datum/radiation_pulse_information)
	high_threshold_pulse.source_ref = WEAKREF(origin)
	high_threshold_pulse.max_range = 1
	high_threshold_pulse.threshold = RAD_NO_INSULATION
	high_threshold_pulse.chance = 100
	high_threshold_pulse.turfs_to_process = list(origin)

	SSradiation.pulse(origin, high_threshold_pulse)

	TEST_ASSERT_NOTNULL(geiger.last_perceived_radiation_danger, "Geiger counter did not receive COMSIG_IN_RANGE_OF_IRRADIATION at RAD_NO_INSULATION")
	TEST_ASSERT(!HAS_TRAIT(wrench, TRAIT_IRRADIATED), "Wrench was unexpectedly irradiated at RAD_NO_INSULATION threshold")
	TEST_ASSERT(!HAS_TRAIT(human, TRAIT_IRRADIATED), "Human was unexpectedly irradiated at RAD_NO_INSULATION threshold")

	var/datum/radiation_pulse_information/lethal_pulse = allocate(/datum/radiation_pulse_information)
	lethal_pulse.source_ref = WEAKREF(origin)
	lethal_pulse.max_range = 1
	lethal_pulse.threshold = 0
	lethal_pulse.chance = 100
	lethal_pulse.turfs_to_process = list(origin)

	SSradiation.pulse(origin, lethal_pulse)

	TEST_ASSERT(HAS_TRAIT(wrench, TRAIT_IRRADIATED), "Wrench was not irradiated by threshold 0 pulse")
	TEST_ASSERT(HAS_TRAIT(human, TRAIT_IRRADIATED), "Human was not irradiated by threshold 0 pulse")

/// Verifies /obj/machinery/digital_clock skips redundant overlay rebuilds within the same station minute and rebuilds when emagged.
/datum/unit_test/digital_clock_overlay_cache/Run()
	var/obj/machinery/digital_clock/clock = allocate(/obj/machinery/digital_clock, run_loc_floor_bottom_left)
	if(clock.machine_stat & NOPOWER)
		clock.use_power = NO_POWER_USE
		clock.power_change()

	clock.process(1)
	var/initial_overlays = length(clock.overlays)
	TEST_ASSERT_EQUAL(clock.last_display_time, round_timestamp(format = "hh:mm"), "Digital clock did not cache the rendered hh:mm time")
	TEST_ASSERT(initial_overlays >= 5, "Digital clock built too few initial overlays ([initial_overlays])")

	clock.cut_overlays()
	clock.process(1)
	TEST_ASSERT_EQUAL(length(clock.overlays), 0, "Digital clock rebuilt overlays without a minute change")

	clock.emag_act()
	clock.process(1)
	TEST_ASSERT_EQUAL(length(clock.overlays), initial_overlays, "Emagged digital clock did not refresh scrambled overlays")
