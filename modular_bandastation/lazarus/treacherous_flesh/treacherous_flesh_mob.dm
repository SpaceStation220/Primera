GLOBAL_LIST_EMPTY(lazarus_flesh)
GLOBAL_LIST_EMPTY(lazarus_biomorphs)

/mob/living/carbon/human
	/// The active Lazarus parasite; inactive eggs remain in contents instead.
	var/mob/living/treacherous_flesh/treacherous_flesh

/// A separate player and mind living inside an organic human host.
/mob/living/treacherous_flesh
	name = "Коварная плоть"
	icon = 'icons/mob/simple/animal.dmi'
	icon_state = "headslug"
	health = 60
	maxHealth = 60
	density = FALSE
	see_in_dark = 6
	faction = list("treacherous_flesh")
	hud_type = /datum/hud/treacherous_flesh
	initial_language_holder = /datum/language_holder/treacherous_flesh
	/// Body shared with the host's player.
	var/mob/living/carbon/human/host
	/// Chemicals available for abilities.
	var/chemicals = 0
	/// Evolution uses the original two-second life-cycle units.
	var/evolution_points = 0
	/// Index in the original five development stages.
	var/evolution_stage = 0
	/// Whether touching food, containers and surgical patients spreads infection.
	var/infecting = FALSE
	/// Whether the host voluntarily obeys all parasite commands.
	var/host_enslaved = FALSE
	/// Whether the parasite has revealed itself and opened two-way communication.
	var/contacted = FALSE
	/// Temporary body containing the displaced host's mind.
	var/mob/living/trapped_mind/trapped_mind
	/// The parasite's mind while it occupies its host's body.
	var/datum/mind/controlling_mind
	/// Actions granted to the host, removed when the parasite leaves.
	var/list/host_actions = list()
	/// Whether pheromones added the faction, rather than inheriting it.
	var/added_host_faction = FALSE
	/// Chemical/evolution counters owned by this mob's HUD.
	var/atom/movable/screen/treacherous_flesh_status/status_display

/mob/living/treacherous_flesh/Initialize(mapload)
	. = ..()
	GLOB.lazarus_flesh += src
	real_name = "[pick("Альфа", "Бета", "Гамма", "Сигма", "Дельта", "Омега")]-[rand(100, 999)]"
	name = real_name
	ADD_TRAIT(src, TRAIT_IMMOBILIZED, INNATE_TRAIT)
	grant_skills()

/mob/living/treacherous_flesh/Destroy()
	disinfest(delete = FALSE)
	ghostize(can_reenter_corpse = FALSE, forced = TRUE)
	GLOB.lazarus_flesh -= src
	status_display = null
	return ..()

/mob/living/treacherous_flesh/add_tts_component()
	AddComponent(/datum/component/tts_component, /datum/tts_seed/silero/anubarak)

/mob/living/treacherous_flesh/Login()
	. = ..()
	if(host)
		reset_perspective(host)
		var/datum/atom_hud/medical = GLOB.huds[DATA_HUD_MEDICAL_ADVANCED]
		medical.show_to(src)
	if(mind && !mind.has_antag_datum(/datum/antagonist/treacherous_flesh))
		mind.add_antag_datum(/datum/antagonist/treacherous_flesh)

/mob/living/treacherous_flesh/mind_initialize()
	. = ..()
	mind.set_assigned_role(SSjob.get_job_type(/datum/job/treacherous_flesh))
	if(!mind.has_antag_datum(/datum/antagonist/treacherous_flesh))
		mind.add_antag_datum(/datum/antagonist/treacherous_flesh)

/mob/living/treacherous_flesh/Life(seconds_per_tick = SSMOBS_DT)
	. = ..()
	if(!QDELETED(host))
		chemicals = clamp(chemicals + (infecting ? -2 : 1) * seconds_per_tick, 0, LAZARUS_FLESH_CHEMICAL_MAX)
		handle_evolution(seconds_per_tick)
	if(chemicals <= 0 && infecting)
		infecting = FALSE
		var/datum/action/treacherous_flesh/passive_infest/infection_action = locate() in actions
		if(infection_action)
			infection_action.button_icon_state = "passive_infest_off"
			infection_action.build_all_button_icons()
		to_chat(src, span_warning("Недостаточно химикатов для выделения заражённых тканей."))
	if(status_display)
		status_display.maptext = MAPTEXT("[round(chemicals)] / 200<br>Эволюция: [evolution_stage]")

/// Advances development at the donor's rate without depending on subsystem frequency.
/mob/living/treacherous_flesh/proc/handle_evolution(seconds_per_tick)
	if(evolution_stage >= LAZARUS_FLESH_FINAL_STAGE)
		return
	evolution_points += seconds_per_tick / 2
	var/static/list/thresholds = list(300, 900, 2100, 3600)
	while(evolution_stage < LAZARUS_FLESH_FINAL_STAGE && evolution_points > thresholds[evolution_stage + 1])
		evolution_stage++
		to_chat(src, span_boldnotice("Мы достигли [evolution_stage] стадии эволюции. Наше влияние на носителя усиливается."))
		SEND_SOUND(src, 'modular_bandastation/lazarus/sound/ling_alert.ogg')
		grant_skills()
	if(evolution_stage >= 3)
		sight |= SEE_MOBS

/// Attaches to a single organic host and subscribes only to that host's interactions.
/mob/living/treacherous_flesh/proc/infest(mob/living/carbon/human/new_host)
	if(QDELETED(new_host) || new_host.stat == DEAD || !(new_host.mob_biotypes & MOB_ORGANIC) || new_host.treacherous_flesh || host)
		return FALSE
	host = new_host
	new_host.treacherous_flesh = src
	forceMove(new_host)
	get_language_holder().copy_languages(new_host.get_language_holder(), LANGUAGE_ATOM)
	RegisterSignal(new_host, COMSIG_QDELETING, PROC_REF(on_host_deleted))
	RegisterSignal(new_host, COMSIG_LIVING_PICKED_UP_ITEM, PROC_REF(contaminate_item))
	RegisterSignal(new_host, COMSIG_ATOM_SURGERY_SUCCESS, PROC_REF(contaminate_patient))
	lazarus_update_infection_marker(new_host)
	reset_perspective(new_host)
	return TRUE

/// Releases host state, controlled minds and host-owned actions before either body is deleted.
/mob/living/treacherous_flesh/proc/disinfest(delete = TRUE)
	if(host)
		restore_control()
		UnregisterSignal(host, list(COMSIG_QDELETING, COMSIG_LIVING_PICKED_UP_ITEM, COMSIG_ATOM_SURGERY_SUCCESS))
		if(host.treacherous_flesh == src)
			host.treacherous_flesh = null
		lazarus_update_infection_marker(host)
		if(added_host_faction)
			host.remove_faction("treacherous_flesh")
		if(host_enslaved)
			host.mind?.remove_antag_datum(/datum/antagonist/lazarus_host)
		for(var/datum/action/action as anything in host_actions)
			qdel(action)
		host_actions.Cut()
		forceMove(get_turf(host))
	host = null
	infecting = FALSE
	added_host_faction = FALSE
	if(delete)
		qdel(src)

/mob/living/treacherous_flesh/proc/on_host_deleted(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/// Releases the player as the size appropriate to the current evolution stage.
/mob/living/treacherous_flesh/proc/burst_out()
	if(QDELETED(host))
		return
	restore_control()
	var/morph_type = /mob/living/basic/flesh_biomorph/lesser/small
	var/damage = 60
	if(evolution_stage == 2)
		morph_type = /mob/living/basic/flesh_biomorph/lesser/medium
		damage = 120
	else if(evolution_stage >= 3)
		morph_type = /mob/living/basic/flesh_biomorph/lesser/large
		damage = 200
	var/mob/living/basic/flesh_biomorph/biomorph = new morph_type(get_turf(host))
	mind?.transfer_to(biomorph, force_key_move = TRUE)
	host.adjust_brute_loss(damage)
	host.adjust_stamina_loss(100)
	host.emote("scream")
	disinfest()
	return biomorph

/mob/living/treacherous_flesh/UnarmedAttack(atom/attack_target, proximity_flag, list/modifiers)
	if(ishuman(attack_target))
		healthscan(src, attack_target, scanpower = SCANPOWER_ADVANCED)

/mob/living/treacherous_flesh/say(message, bubble_type, list/spans, sanitize = TRUE, datum/language/language, ignore_spam, forced, filterproof, message_range, datum/saymode/saymode, list/message_mods)
	lazarus_hivemind(src, message)

/mob/living/treacherous_flesh/emote(act, m_type = null, message = null, intentional = FALSE, force_silence = FALSE)
	return FALSE

/// Grants each development stage once; powers are owned by and deleted with this body.
/mob/living/treacherous_flesh/proc/grant_skills()
	var/static/list/stages = list(
		list(/datum/action/treacherous_flesh/message_host, /datum/action/treacherous_flesh/contact_host, /datum/action/treacherous_flesh/speed_up_evolution, /datum/action/treacherous_flesh/leave_the_body, /datum/action/treacherous_flesh/emit_pheromones),
		list(/datum/action/treacherous_flesh/fleshmend, /datum/action/treacherous_flesh/adrenaline, /datum/action/treacherous_flesh/panacea, /datum/action/treacherous_flesh/heat_up),
		list(/datum/action/treacherous_flesh/regrow_organs, /datum/action/treacherous_flesh/armblade, /datum/action/treacherous_flesh/chitin_armor, /datum/action/treacherous_flesh/passive_infest),
		list(/datum/action/treacherous_flesh/take_control, /datum/action/treacherous_flesh/enslave_mind),
		list(/datum/action/treacherous_flesh/ascension),
	)
	for(var/action_type in stages[evolution_stage + 1])
		if(locate(action_type) in actions)
			continue
		var/datum/action/treacherous_flesh/action = new action_type(src)
		action.Grant(src)

/// A separate HUD counter avoids changing the host's antagonist HUD.
/datum/hud/treacherous_flesh
	parent_type = /datum/hud/living

/datum/hud/treacherous_flesh/initialize_screen_objects()
	. = ..()
	var/mob/living/treacherous_flesh/user = mymob
	user.status_display = add_screen_object(/atom/movable/screen/treacherous_flesh_status, "lazarus_status", HUD_GROUP_INFO)

/atom/movable/screen/treacherous_flesh_status
	name = "Развитие паразита"
	screen_loc = "WEST:6,CENTER-2:15"
	maptext_width = 150
	maptext_height = 50

/atom/movable/screen/treacherous_flesh_status/Click()
	if(!istype(usr, /mob/living/treacherous_flesh))
		return
	var/mob/living/treacherous_flesh/flesh = usr
	to_chat(flesh, span_notice("Эволюция: [flesh.evolution_stage]/4; прогресс: [round(flesh.evolution_points)]; химикаты: [round(flesh.chemicals)]/200."))
