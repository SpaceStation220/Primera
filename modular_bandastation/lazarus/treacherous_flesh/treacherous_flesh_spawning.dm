/// An inactive parasite can be taken only while its original host remains viable.
/obj/effect/mob_spawn/ghost_role/treacherous_flesh
	name = "Зародыш коварной плоти"
	desc = "Небольшой красный сгусток."
	icon = 'modular_bandastation/lazarus/icons/treacherous_flesh.dmi'
	icon_state = "spawner"
	density = FALSE
	mob_type = /mob/living/treacherous_flesh
	prompt_name = "коварной плотью"
	role_ban = ROLE_SENTIENCE
	spawner_job_path = /datum/job/treacherous_flesh
	you_are_text = "Вы — коварная плоть, паразит внутри живого носителя."
	flavour_text = "Не раскрывайтесь раньше времени. Развивайтесь, используйте химикаты, заражайте окружающих и помогите биоморфам ассимилировать колонию."
	important_text = "Вы — антагонист. Вы не помните прошлые жизни."
	/// Original host, released when the egg is consumed or removed.
	var/mob/living/carbon/human/host

/obj/effect/mob_spawn/ghost_role/treacherous_flesh/Initialize(mapload, mob/living/carbon/human/new_host)
	host = new_host || (ishuman(loc) ? loc : null)
	. = ..()
	if(!host)
		return INITIALIZE_HINT_QDEL
	RegisterSignal(host, COMSIG_QDELETING, PROC_REF(host_deleted))
	lazarus_update_infection_marker(host)

/obj/effect/mob_spawn/ghost_role/treacherous_flesh/Destroy()
	UnregisterSignal(host, COMSIG_QDELETING)
	lazarus_update_infection_marker(host)
	host = null
	return ..()

/obj/effect/mob_spawn/ghost_role/treacherous_flesh/proc/host_deleted(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/obj/effect/mob_spawn/ghost_role/treacherous_flesh/allow_spawn(mob/user, silent = FALSE)
	return !QDELETED(host) && host.stat != DEAD && (host.mob_biotypes & MOB_ORGANIC) && !host.treacherous_flesh && loc == host

/obj/effect/mob_spawn/ghost_role/treacherous_flesh/create(mob/mob_possessor, newname, apply_prefs)
	if(!allow_spawn(mob_possessor))
		return CANCEL_SPAWN
	return ..()

/obj/effect/mob_spawn/ghost_role/treacherous_flesh/special(mob/living/treacherous_flesh/spawned_mob, mob/mob_possessor, apply_prefs)
	spawned_mob.infest(host)
	. = ..()
	if(spawned_mob.mind && !spawned_mob.mind.has_antag_datum(/datum/antagonist/treacherous_flesh))
		spawned_mob.mind.add_antag_datum(/datum/antagonist/treacherous_flesh)

/// Forced-only event so an installed module does not alter ordinary rounds.
/datum/round_event_control/treacherous_flesh
	name = "Treacherous Flesh"
	typepath = /datum/round_event/ghost_role/treacherous_flesh
	weight = 0
	max_occurrences = 0
	category = EVENT_CATEGORY_INVASION
	description = "Предлагает призраку стать паразитом внутри случайного человека."

/datum/round_event/ghost_role/treacherous_flesh
	role_name = "коварная плоть"

/datum/round_event/ghost_role/treacherous_flesh/spawn_role()
	var/list/hosts = list()
	for(var/mob/living/carbon/human/human as anything in GLOB.human_list)
		if(human.client && human.stat != DEAD && (human.mob_biotypes & MOB_ORGANIC) && !lazarus_host_infested(human) && is_station_level(human.z))
			hosts += human
	if(!length(hosts))
		return MAP_ERROR
	var/mob/dead/observer/candidate = SSpolling.poll_ghost_candidates(question = "Хотите стать коварной плотью?", check_jobban = ROLE_SENTIENCE, role = ROLE_SENTIENCE, alert_pic = /mob/living/treacherous_flesh, role_name_text = role_name, amount_to_pick = 1)
	if(!isobserver(candidate) || !candidate.client || !candidate.key || is_banned_from(candidate.ckey, list(ROLE_SENTIENCE, ROLE_SYNDICATE)))
		return NOT_ENOUGH_PLAYERS
	for(var/mob/living/carbon/human/human as anything in hosts.Copy())
		if(QDELETED(human) || human.stat == DEAD || !human.client || lazarus_host_infested(human) || !is_station_level(human.z))
			hosts -= human
	if(!length(hosts))
		return MAP_ERROR
	var/mob/living/carbon/human/host = pick(hosts)
	var/mob/living/treacherous_flesh/flesh = new(get_turf(host))
	if(!flesh.infest(host))
		qdel(flesh)
		return MAP_ERROR
	var/datum/mind/new_mind = new(candidate.key)
	new_mind.transfer_to(flesh, force_key_move = TRUE)
	if(!new_mind.has_antag_datum(/datum/antagonist/treacherous_flesh))
		new_mind.add_antag_datum(/datum/antagonist/treacherous_flesh)
	spawned_mobs += flesh
	message_admins("[ADMIN_LOOKUPFLW(flesh)] появился как коварная плоть внутри [ADMIN_LOOKUPFLW(host)].")
	return SUCCESSFUL_SPAWN
