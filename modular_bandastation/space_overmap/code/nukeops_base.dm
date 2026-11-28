/datum/dynamic_ruleset/roundstart/nukies/New(list/dynamic_config)
	..()
	if(type == /datum/dynamic_ruleset/roundstart/nukies && islist(dynamic_config))
		apply_overmap_nukeops_slots()

/datum/dynamic_ruleset/midround/from_ghosts/nukies/New(list/dynamic_config)
	..()
	if(type == /datum/dynamic_ruleset/midround/from_ghosts/nukies && islist(dynamic_config))
		apply_overmap_nukeops_slots()

/// Offer the map's slots while keeping the population-based minimum within that capacity.
/datum/dynamic_ruleset/proc/apply_overmap_nukeops_slots()
	var/list/overmap_config = SSmapping.current_map?.space_overmap
	var/slots = overmap_config?["nukeops_slots"]
	if(!overmap_config?["nukeops"] || !ISINTEGER(slots) || slots < 1)
		return
	max_antag_cap = slots
	if(islist(min_antag_cap))
		var/list/minimum_cap = min_antag_cap
		minimum_cap = minimum_cap.Copy()
		var/maximum = minimum_cap["maximum"]
		minimum_cap["maximum"] = isnum(maximum) ? min(maximum, slots) : slots
		min_antag_cap = minimum_cap
	else
		min_antag_cap = min(min_antag_cap, slots)

/// Medium berth mapped on the lazy Syndicate base, commissioned when the team needs its ship.
/obj/machinery/computer/stationtrauma_dock_controller/medium/nukeops_base
	site_id = "nukeops_base"
	dock_name = "База Синдиката"
	overmap_x = -2060
	overmap_y = 360

/// Private destinations are known only to the assault shuttle registered for the operation.
/datum/stationtrauma_overmap_site/space/nukeops_berth
	discovered = FALSE
	needs_scan = TRUE
	/// The physical hull authorized to plot this destination.
	var/datum/weakref/ship_ref

/// The dock at the team's base is also its return objective.
/datum/stationtrauma_overmap_site/space/nukeops_base
	parent_type = /datum/stationtrauma_overmap_site/space/nukeops_berth

/// A separate approach on Cyberiad's level, without a docking collar or dispatcher request.
/datum/stationtrauma_overmap_site/space/nukeops_berth/eva
	id = "nukeops_eva"
	name = "Кибериада — внешняя высадка"
	physical_docking = TRUE

/obj/docking_port/stationary/stationtrauma_space_site/nukeops_eva
	name = "Кибериада — внешняя высадка"
	shuttle_id = "nukeops_eva"
	area_type = /area/space

/// Place the private chart selection beside Cyberiad's public traffic contact.
/datum/stationtrauma_overmap_sector/space/home/proc/register_nukeops_eva(obj/docking_port/mobile/stationtrauma_space/nukeops/ship)
	var/datum/stationtrauma_overmap_site/space/nukeops_berth/eva/approach = sites["nukeops_eva"]
	if(!QDELETED(approach))
		approach.ship_ref = WEAKREF(ship)
		return
	var/obj/docking_port/stationary/stationtrauma_space_site/nukeops_eva/berth = locate() in SSshuttle.stationary_docking_ports
	var/datum/stationtrauma_overmap_site/space/docking_target/station = sites["traffic:station"]
	if(QDELETED(berth) || !is_station_level(berth.z) || QDELETED(station))
		log_mapping("Cyberiad has no mapped EVA berth for the Shershen.")
		return
	approach = new
	approach.ship_ref = WEAKREF(ship)
	approach.pos_x = station.pos_x
	approach.pos_y = station.pos_y + 80
	approach.berth = berth
	sites[approach.id] = approach

/// Load the flight hull only after the corresponding lazy base and its private approach are available.
/datum/controller/subsystem/stationtrauma_space_voyage/proc/load_nukeops_shershen()
	RETURN_TYPE(/obj/docking_port/mobile/stationtrauma_space/nukeops)
	var/datum/stationtrauma_overmap_sector/space/home/home = sectors["epsilon_eridani"]
	if(!SSmapping.current_map?.space_overmap?["nukeops"] || !home?.ready)
		return null
	var/datum/turf_reservation/base = SSmapping.lazy_load_template(LAZY_TEMPLATE_KEY_NUKIEBASE)
	var/load_deadline = world.time + 30 SECONDS
	UNTIL(!loading_ship_template || QDELETED(home) || world.time >= load_deadline)
	if(QDELETED(base) || QDELETED(home) || loading_ship_template)
		return null

	var/obj/machinery/computer/stationtrauma_dock_controller/medium/nukeops_base/berth_controller
	for(var/obj/machinery/computer/stationtrauma_dock_controller/medium/nukeops_base/controller as anything in SSmachines.get_machines_by_type(/obj/machinery/computer/stationtrauma_dock_controller/medium/nukeops_base))
		if(get_turf(controller) in base.reserved_turfs)
			berth_controller = controller
			break
	if(QDELETED(berth_controller))
		log_mapping("The overmap Syndicate base has no mapped medium dock controller.")
		return null

	var/datum/stationtrauma_overmap_site/space/nukeops_base/site = berth_controller.owned_slot?.published_site
	var/obj/docking_port/mobile/stationtrauma_space/nukeops/ship = site?.ship_ref?.resolve()
	if(!QDELETED(ship) && !QDELETED(ship.overmap))
		return ship
	ship = null
	if(QDELETED(site))
		site = new
		var/problem = berth_controller.publish_slot(initializing = TRUE, private_site = site)
		if(problem)
			qdel(site)
			log_mapping("The overmap Syndicate base could not publish its berth: [problem]")
			return null

	loading_ship_template = TRUE
	try
		ship = load_stationtrauma_space_ship(
			"_maps/map_files/overmap_ships/syndi.dmm",
			attach_to_sector = TRUE,
			place_ship = CALLBACK(src, PROC_REF(dock_nukeops_shershen), site),
		)
	catch(var/exception/failure)
		log_mapping("Could not load the overmap Syndicate ship: [failure]")
	loading_ship_template = FALSE
	if(QDELETED(ship))
		if(!QDELETED(berth_controller.owned_slot) && !berth_controller.owned_slot.active_berth)
			qdel(berth_controller.owned_slot, force = TRUE)
		return null
	if(!QDELETED(home))
		home.register_nukeops_eva(ship)
	return ship

/datum/controller/subsystem/stationtrauma_space_voyage/proc/dock_nukeops_shershen(datum/stationtrauma_overmap_site/space/nukeops_base/site, obj/docking_port/mobile/stationtrauma_space/nukeops/ship)
	if(QDELETED(site) || !istype(ship) || QDELETED(ship.overmap))
		return FALSE
	site.ship_ref = WEAKREF(ship)
	ship.starting_dock = site.id
	return ship.overmap.place_starting_dock()
