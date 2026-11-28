/** The main passage and powered compartments of the Syndicate assault shuttle. */
/area/shuttle/stationtrauma_space/syndi
	name = "Шершень: центральный коридор"
	icon = 'modular_bandastation/space_overmap/icons/nt_patrol_areas.dmi'
	icon_state = "passage"
	requires_power = TRUE

/area/shuttle/stationtrauma_space/syndi/bridge
	name = "Шершень: рубка"
	icon_state = "bridge"

/area/shuttle/stationtrauma_space/syndi/medical
	name = "Шершень: медотсек"
	icon_state = "medbay"

/area/shuttle/stationtrauma_space/syndi/crew
	name = "Шершень: жилой отсек"
	icon_state = "barracks"

/area/shuttle/stationtrauma_space/syndi/armory
	name = "Шершень: оружейная"
	icon_state = "armory"

/area/shuttle/stationtrauma_space/syndi/engineering
	name = "Шершень: машинное отделение"
	icon_state = "engineering"

/area/shuttle/stationtrauma_space/syndi/engineering/reactor
	name = "Шершень: реакторная"
	icon_state = "reactor"

/** Exposed hull plating and equipment travel with the pressurized compartments. */
/area/shuttle/stationtrauma_space/syndi/exterior
	name = "Шершень: наружная обшивка"
	icon_state = "exterior"
	monitored_compartment = FALSE
	requires_power = FALSE
	vacuum_by_design = TRUE

/** Keep the shuttle's identity on its removable registration board. */
/obj/item/circuitboard/computer/stationtrauma_transponder/syndi
	build_path = /obj/machinery/computer/stationtrauma_transponder/syndi
	callsign = "Шершень"
	registration_faction = "Синдикат"

/obj/machinery/computer/stationtrauma_transponder/syndi
	circuit = /obj/item/circuitboard/computer/stationtrauma_transponder/syndi

/obj/docking_port/mobile/stationtrauma_space/nukeops
	/// The operative team that launched this hull, if any.
	var/datum/weakref/nuclear_team_ref

/obj/docking_port/mobile/stationtrauma_space/nukeops/on_departure()
	var/datum/team/nuclear/team = nuclear_team_ref?.resolve()
	if(team)
		team.overmap_has_departed = TRUE

/obj/docking_port/mobile/stationtrauma_space/nukeops/permits_docking(datum/stationtrauma_overmap_site/space/site)
	. = ..()
	if(!. || !istype(site, /datum/stationtrauma_overmap_site/space/nukeops_berth/eva))
		return
	// A ship leaving M during our approach does not abort a manoeuvre already underway.
	return !QDELETED(overmap) && (site.docking_owner == overmap || station_medium_berth_occupied())

/obj/docking_port/mobile/stationtrauma_space/nukeops/proc/station_medium_berth_occupied()
	var/datum/stationtrauma_overmap_site/space/docking_target/station = overmap.sites["traffic:station"]
	for(var/datum/stationtrauma_overmap_site/space/site as anything in station?.berths)
		var/obj/docking_port/stationary/stationtrauma_space_station/standard/slot = site.berth
		if(!istype(slot) || slot.accepted_ship_class != ST_SHIP_MEDIUM || QDELETED(slot.active_berth))
			continue
		var/obj/docking_port/mobile/occupant = slot.active_berth.get_docked()
		if(!QDELETED(occupant) && occupant != src)
			return TRUE
	return FALSE

/obj/docking_port/mobile/stationtrauma_space/nukeops/check_dock(obj/docking_port/stationary/target, silent = FALSE)
	if(istype(target, /obj/docking_port/stationary/stationtrauma_space_site/nukeops_eva))
		var/list/footprint = target.return_turfs()
		if(!is_station_level(target.z) || length(footprint) != width * height)
			return FALSE
		// Native preflight repeats this check before moving the ship, including after a yield.
		for(var/turf/tile as anything in footprint)
			if(!isspaceturf(tile))
				return FALSE
	return ..()
