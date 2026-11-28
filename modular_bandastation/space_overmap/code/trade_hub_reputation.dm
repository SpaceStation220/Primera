#define TRADE_REPUTATION_NEUTRAL 50
#define TRADE_REPUTATION_POINTS_PER_PERCENT 2

/obj/machinery/trade_hub_core
	/// Standing granted to ordinary Nanotrasen employees by this operator.
	var/nt_reputation = TRADE_REPUTATION_NEUTRAL
	/// Optional standing for crew assigned to the NT patrol destroyer.
	var/patrol_reputation
	/// Optional standing for agents recognized by this operator.
	var/syndicate_reputation
	/// Exact supply pack types this operator offers only at 80 standing or higher.
	var/list/private_packs

/// Price and catalogue rules follow the current operator of the terminal, even when cargo pays.
/obj/machinery/trade_hub_core/proc/get_reputation(mob/user)
	var/datum/mind/operator = user?.mind
	if(!isliving(user) || !operator || operator.current != user)
		return TRADE_REPUTATION_NEUTRAL
	var/datum/job/job = operator.assigned_role
	if(!isnull(syndicate_reputation))
		var/static/list/syndicate_roles = list(
			/datum/antagonist/brother,
			/datum/antagonist/nukeop,
			/datum/antagonist/battlecruiser,
			/datum/antagonist/syndicate_monkey,
		)
		var/static/list/syndicate_jobs = list(
			/datum/job/space_syndicate,
			/datum/job/lavaland_syndicate,
			/datum/job/syndicate_cybersun,
			/datum/job/syndicate_cybersun_captain,
		)
		var/datum/antagonist/traitor/agent = operator.has_antag_datum(/datum/antagonist/traitor)
		if((agent && !(agent.employer in GLOB.nanotrasen_employers)) || operator.has_antag_datum_in_list(syndicate_roles) || is_type_in_list(job, syndicate_jobs))
			return clamp(syndicate_reputation, 0, 100)
	if(istype(job, /datum/job/away_mission))
		var/datum/job/away_mission/away_job = job
		if(istype(away_job.get_away_mission(), /datum/roundstart_away_mission/nt_patrol))
			return clamp(isnull(patrol_reputation) ? nt_reputation : patrol_reputation, 0, 100)
	// Visitors use the station job faction so the lobby can assign them station slots.
	var/static/list/guest_jobs = list(
		/datum/job/donor/representative,
		/datum/job/donor/tourist_tsf,
		/datum/job/donor/tourist_ussp,
		/datum/job/donor/migrant,
		/datum/job/prisoner,
	)
	if(job?.faction == FACTION_STATION && !is_type_in_list(job, guest_jobs))
		return clamp(nt_reputation, 0, 100)
	return TRADE_REPUTATION_NEUTRAL

/// Minimum standing to see and order a local offer, in addition to its existing cargo unlocks.
/obj/machinery/trade_hub_core/proc/required_reputation(datum/supply_pack/pack)
	if(pack.type in private_packs)
		return 80
	if(pack.type in corporate_pack_types)
		return 70
	if(pack.group == "Armory" || pack.group == "Requisitions")
		return 35
	if(pack.group == "Security" || pack.group == "Science")
		return 25
	return 0

/// Credits paid by the customer for a crate at the current standing.
/obj/machinery/trade_hub_core/proc/purchase_price(base, reputation)
	if(!IS_FINITE(base) || base <= 0)
		return 0
	var/discount = (reputation - TRADE_REPUTATION_NEUTRAL) / TRADE_REPUTATION_POINTS_PER_PERCENT
	return max(1, round(base * (1 - discount / 100), 1))

/// Credits paid to the customer per accepted unit at the current standing.
/obj/machinery/trade_hub_core/proc/sale_price(base, reputation)
	if(!IS_FINITE(base) || base <= 0)
		return 0
	var/premium = (reputation - TRADE_REPUTATION_NEUTRAL) / TRADE_REPUTATION_POINTS_PER_PERCENT
	return max(1, round(base * (1 + premium / 100), 1))

#undef TRADE_REPUTATION_POINTS_PER_PERCENT
#undef TRADE_REPUTATION_NEUTRAL
