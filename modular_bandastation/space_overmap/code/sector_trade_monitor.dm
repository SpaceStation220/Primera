/// Delay between requests for a fresh station-sector trade report.
#define SECTOR_TRADE_REPORT_INTERVAL (5 MINUTES)

/datum/stationtrauma_overmap_sector/space
	/// Last collected trade report, shared by the station's consoles.
	var/list/trade_report
	/// World time at which the last report was collected.
	var/trade_report_at

/** Snapshot demand, stock and base prices before applying any individual trading terms. */
/datum/stationtrauma_overmap_sector/space/proc/refresh_trade_report()
	if(!isnull(trade_report_at) && world.time < trade_report_at + SECTOR_TRADE_REPORT_INTERVAL)
		return FALSE

	var/list/hubs = list()
	for(var/obj/machinery/trade_hub_core/core as anything in SSmachines.get_machines_by_type_and_subtypes(/obj/machinery/trade_hub_core))
		if(QDELETED(core))
			continue
		var/turf/location = get_turf(core)
		var/outpost_name = trade_outpost_names?["[location?.z]"]
		if(!outpost_name)
			continue

		var/list/offers = list()
		if(core.ensure_catalog())
			for(var/pack_id in core.stock)
				var/datum/supply_pack/pack = SSshuttle.trade_hub_supply_packs[pack_id]
				if(pack)
					offers[pack_id] = list("stock" = core.stock[pack_id], "price" = pack.get_cost())

		var/list/requests = list()
		for(var/request_type in core.requests)
			var/datum/trade_hub_request/request = core.requests[request_type]
			var/status = "open"
			if(request.renew_at || (!isnull(request.remaining) && request.remaining <= 0))
				status = "renewing"
			else if(request.ready_at)
				status = "restocking"
			requests += list(list(
				"id" = "[request_type]",
				"name" = request.name,
				"status" = status,
				"quantity" = isnull(request.remaining) ? null : min(request.remaining, request.batch_size - request.delivered),
				"unit_reward" = request.unit_reward,
				"high_demand" = request.high_demand,
			))
		var/list/reward_market = core.reward_market_data(reputation = 50)
		for(var/list/quote as anything in reward_market["quotes"])
			requests += list(list(
				"id" = quote["id"],
				"name" = quote["name"],
				"status" = "open",
				"quantity" = null,
				"rate_percent" = quote["rate"],
				"rate_seconds_left" = reward_market["seconds_left"],
			))
		hubs += list(list(
			"core" = WEAKREF(core),
			"name" = outpost_name,
			"input_problem" = trade_hub_machine_reason(core, "Ядро узла") || core.get_input_reason(),
			"output_problem" = trade_hub_machine_reason(core, "Ядро узла") || core.get_output_reason(),
			"offers" = offers,
			"requests" = requests,
		))
	trade_report = hubs
	trade_report_at = world.time
	return TRUE

/** Apply current operator credentials to a private copy of the last sector snapshot. */
/datum/stationtrauma_overmap_sector/space/proc/trade_report_for(mob/user)
	if(isnull(trade_report))
		return null
	var/list/department_hubs = list()
	for(var/obj/machinery/computer/trade_hub/terminal as anything in SSmachines.get_machines_by_type_and_subtypes(/obj/machinery/computer/trade_hub))
		if(!trade_outpost_names["[terminal.z]"] || trade_hub_cargo_payment_reason(user, terminal))
			continue
		var/obj/machinery/trade_hub_core/core = terminal.get_core()
		if(core)
			department_hubs[core] = TRUE

	var/list/personal_access = trade_hub_cash_access(user)
	var/list/hubs = list()
	for(var/list/snapshot as anything in trade_report)
		var/datum/weakref/core_ref = snapshot["core"]
		var/obj/machinery/trade_hub_core/core = core_ref.resolve()
		if(!core)
			continue
		var/reputation = core.get_reputation(user)
		var/list/access = department_hubs[core] ? null : personal_access
		var/list/offers = list()
		var/list/stock = snapshot["offers"]
		for(var/pack_id in stock)
			var/datum/supply_pack/pack = SSshuttle.trade_hub_supply_packs[pack_id]
			if(!(pack_id in core.stock) || !core.can_trade_pack(pack, access, reputation))
				continue
			var/list/offer = stock[pack_id]
			offers += list(list(
				"id" = "[pack_id]", "name" = pack.name, "group" = core.groups[pack_id],
				"stock" = offer["stock"], "price" = core.purchase_price(offer["price"], reputation),
			))
		var/list/requests = list()
		for(var/list/request as anything in snapshot["requests"])
			var/list/quote = request.Copy()
			var/price_key = isnull(quote["rate_percent"]) ? "unit_reward" : "rate_percent"
			quote[price_key] = core.sale_price(request[price_key], reputation)
			requests += list(quote)
		hubs += list(list(
			"id" = REF(core), "name" = snapshot["name"], "specialization" = core.specialization, "reputation" = reputation,
			"input_problem" = snapshot["input_problem"], "output_problem" = snapshot["output_problem"],
			"offers" = offers, "requests" = requests,
		))
	return hubs

/** Board used to repair or rebuild the station's trade monitor. */
/obj/item/circuitboard/computer/sector_trade_monitor
	name = "консоль торговых заявок"
	build_path = /obj/machinery/computer/sector_trade_monitor

/** Read-only access to the trade report of the sector containing the mapped station. */
/obj/machinery/computer/sector_trade_monitor
	name = "консоль торговых заявок"
	desc = "Показывает закупочные и отпускные цены, спрос и остатки товаров на узлах сектора станции."
	icon_state = MAP_SWITCH("computer", "/obj/machinery/computer/cargo")
	icon_screen = "supply"
	circuit = /obj/item/circuitboard/computer/sector_trade_monitor
	req_access = list(ACCESS_COMMAND)

/** Match the configured station site to its actual native station berth. */
/obj/machinery/computer/sector_trade_monitor/proc/resolve_station_sector()
	var/station_id = SSmapping.current_map.space_overmap?["station_id"]
	if(!station_id)
		return null
	var/list/sectors = SSstationtrauma_space_voyage.sectors
	for(var/sector_id in sectors)
		var/datum/stationtrauma_overmap_sector/space/sector = sectors[sector_id]
		if(!sector.ready)
			continue
		var/datum/stationtrauma_overmap_site/space/site = sector.sites[station_id]
		if(!QDELETED(site?.berth) && is_station_level(site.berth.z))
			return sector
	return null

/** Apply the installation and ID checks when reading or requesting a report. */
/obj/machinery/computer/sector_trade_monitor/proc/can_operate(mob/user)
	return !QDELETED(user) && anchored && is_operational && !panel_open && is_station_level(z) \
		&& !istype(get_area(src), /area/shuttle) && can_interact(user) && allowed(user)

/obj/machinery/computer/sector_trade_monitor/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	if(!ui && !allowed(user))
		to_chat(user, span_warning("Для работы с консолью нужен доступ командования."))
		return
	open_overmap_console(user, ui, "SectorTradeMonitor")

/obj/machinery/computer/sector_trade_monitor/ui_status(mob/user, datum/ui_state/state)
	if(!can_operate(user))
		return UI_CLOSE
	return overmap_console_status(user, ..())

/obj/machinery/computer/sector_trade_monitor/ui_data(mob/user)
	if(!can_operate(user))
		return list()
	var/datum/stationtrauma_overmap_sector/space/sector = resolve_station_sector()
	var/report_at = sector?.trade_report_at
	return list(
		"sector" = sector?.name,
		"hubs" = sector?.trade_report_for(user),
		"age_seconds" = isnull(report_at) ? null : floor((world.time - report_at) / (1 SECONDS)),
		"refresh_seconds" = isnull(report_at) ? 0 : max(0, ceil((report_at + SECTOR_TRADE_REPORT_INTERVAL - world.time) / (1 SECONDS))),
	)

/obj/machinery/computer/sector_trade_monitor/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(..())
		return TRUE
	if(action != "refresh" || ui_status(ui.user, state) != UI_INTERACTIVE)
		return FALSE
	var/datum/stationtrauma_overmap_sector/space/sector = resolve_station_sector()
	return sector?.refresh_trade_report()

#undef SECTOR_TRADE_REPORT_INTERVAL
