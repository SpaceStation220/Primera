#define ST_STATION_RADAR_RANGE 600
#define ST_STATION_RADAR_COOLDOWN (20 SECONDS)

/// Map-placeable station radar with an ordinary computer frame and circuit board.
/obj/machinery/computer/stationtrauma_station_radar
	name = "консоль управления радаром"
	desc = "Показывает окрестности станции и позволяет запустить активное сканирование."
	icon_state = MAP_SWITCH("computer", "/obj/machinery/computer/shuttle")
	icon_screen = "shuttle"
	icon_keyboard = "tech_key"
	circuit = /obj/item/circuitboard/computer/stationtrauma_station_radar

/obj/item/circuitboard/computer/stationtrauma_station_radar
	name = "консоль управления радаром"
	greyscale_colors = CIRCUIT_COLOR_COMMAND
	build_path = /obj/machinery/computer/stationtrauma_station_radar

/// Resolve the station installation from the machine's actual location.
/obj/machinery/computer/stationtrauma_station_radar/proc/radar_sector()
	if(!anchored || !is_operational || panel_open || !is_station_level(z) || istype(get_area(src), /area/shuttle))
		return null
	var/datum/stationtrauma_overmap_sector/space/home/sector = SSstationtrauma_space_voyage.sectors["epsilon_eridani"]
	return sector?.ready ? sector : null

/obj/machinery/computer/stationtrauma_station_radar/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	open_overmap_console(user, ui, "StationRadar")

/obj/machinery/computer/stationtrauma_station_radar/ui_status(mob/user, datum/ui_state/state)
	if(!radar_sector() || (!isobserver(user) && !can_interact(user)))
		return UI_CLOSE
	return overmap_console_status(user, ..())

/obj/machinery/computer/stationtrauma_station_radar/ui_data(mob/user)
	if(ui_status(user, ui_state(user)) < UI_UPDATE)
		return list()
	var/datum/stationtrauma_overmap_sector/space/home/sector = radar_sector()
	return sector?.station_radar_data() || list()

/obj/machinery/computer/stationtrauma_station_radar/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(action != "scan" || ui_status(ui.user, state) != UI_INTERACTIVE)
		return FALSE
	var/datum/stationtrauma_overmap_sector/space/home/sector = radar_sector()
	if(!sector?.sample_station_radar(active = TRUE))
		return FALSE
	playsound(src, 'sound/machines/radar-ping.ogg', 50, FALSE)
	return TRUE

/// Sample contact echoes around the station, using the same sensor rules as a ship.
/datum/stationtrauma_overmap_sector/space/home/proc/sample_station_radar(active = FALSE)
	var/datum/stationtrauma_overmap_site/space/docking_target/station = sites["traffic:station"]
	if(!ready || QDELETED(station))
		return FALSE
	if(!station_radar)
		station_radar = new(process_movement = FALSE)
	if(active)
		if(!isnull(station_radar.last_ping) && world.time < station_radar.last_ping + ST_STATION_RADAR_COOLDOWN)
			return FALSE
		station_radar.last_ping = world.time
	else if(world.time < station_radar.next_listen)
		return TRUE
	station_radar.next_listen = world.time + 2 SECONDS
	station_radar.pos_x = station.pos_x
	station_radar.pos_y = station.pos_y
	// A fixed sensor borrows the sector for the synchronous sweep without registering as a ship.
	station_radar.sector = src
	station_radar.observe_ships(ST_STATION_RADAR_RANGE, passive = !active)
	station_radar.sector = null
	return TRUE

/// Serialize the station's public chart and sampled contacts, never per-crew discoveries.
/datum/stationtrauma_overmap_sector/space/home/proc/station_radar_data()
	if(!sample_station_radar())
		return null
	var/datum/stationtrauma_overmap_site/space/docking_target/station = sites["traffic:station"]
	var/list/routes = list()
	for(var/site_id in sites)
		var/datum/stationtrauma_overmap_site/space/site = sites[site_id]
		if(!site.discovered || site.needs_scan || site.host || site.failed)
			continue
		var/kind
		var/label
		if(istype(site, /datum/stationtrauma_overmap_site/space/docking_target))
			kind = "station"
			label = "Станция"
		else if(istype(site, /datum/stationtrauma_overmap_site/space/planet))
			kind = "planet"
			label = "Планета"
		else if(istype(site, /datum/stationtrauma_overmap_site/space/jump_point))
			kind = "jump"
			label = "Блюспейс-переход"
		else
			continue
		routes += list(list(
			"id" = site_id, "name" = site.name, "kind" = kind, "type" = label,
			"x" = site.pos_x, "y" = site.pos_y, "failed" = FALSE,
			"distance" = round(station_radar.distance_to(site)),
		))
	var/scan_age = isnull(station_radar.last_ping) ? null : (world.time - station_radar.last_ping) / (1 SECONDS)
	var/scan_cooldown = isnull(scan_age) ? 0 : max(0, ST_STATION_RADAR_COOLDOWN / (1 SECONDS) - scan_age)
	return list(
		"sector" = id, "sector_name" = name, "vessel_name" = station.name,
		"x" = station.pos_x, "y" = station.pos_y, "au_scale" = ST_SPACE_AU_SCALE,
		"star" = list("x" = 0, "y" = 0, "name" = star_name, "radius" = star_radius),
		"celestial_bodies" = celestial_bodies, "routes" = routes,
		"ship_contacts" = station_radar.ship_echo_data(),
		"sensor_range" = ST_STATION_RADAR_RANGE, "scan_age" = scan_age,
		"scan_ready" = !scan_cooldown, "scan_cooldown" = scan_cooldown,
		"course" = 0, "dock_range" = 0, "interference" = 0,
		"preparing" = FALSE, "relocating" = FALSE,
		"path" = list(), "zones" = list(), "terrain" = list(), "trajectory" = list(),
	)

#undef ST_STATION_RADAR_RANGE
#undef ST_STATION_RADAR_COOLDOWN
