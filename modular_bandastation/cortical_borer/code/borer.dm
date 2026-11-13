/// A player-controlled parasite. Control of a host is temporary; its mind is never replaced or deleted.
/mob/living/basic/cortical_borer
	name = "cortical borer"
	real_name = "мозговой червь"
	desc = "Маленький слизнеподобный паразит, ищущий тёплого носителя."
	icon = 'modular_bandastation/cortical_borer/icons/borer.dmi'
	icon_state = "brainslug"
	icon_living = "brainslug"
	icon_dead = "brainslug_dead"
	gender = NEUTER
	health = 30
	maxHealth = 30
	mob_size = MOB_SIZE_TINY
	density = FALSE
	pass_flags = PASSTABLE | PASSMOB
	faction = list(FACTION_CREATURE)
	speed = 2
	melee_damage_lower = 0
	melee_damage_upper = 0
	obj_damage = 0
	environment_smash = ENVIRONMENT_SMASH_NONE
	habitable_atmos = null
	unsuitable_atmos_damage = 0
	minimum_survivable_temperature = 0
	maximum_survivable_temperature = 1500
	speak_emote = list("стрекочет")
	initial_language_holder = /datum/language_holder/human_basic
	/// The living body we inhabit, independently of who currently controls it.
	var/mob/living/carbon/human/host
	/// The temporary body holding the original host's mind during control.
	var/mob/living/cortical_borer_host/captive
	/// Our own mind, also retained while it is in the host.
	var/datum/mind/borer_mind
	/// The displaced host mind. Never infer its identity from the host's current mind.
	var/datum/mind/host_mind
	/// Suppresses cleanup callbacks during our own synchronous mind transfers.
	var/transferring = FALSE
	/// Whether the parasite is driving its host.
	var/controlling = FALSE
	/// One long action at a time, invalidated whenever the host changes.
	var/busy = FALSE
	/// Incremented on attachment changes so an old input cannot affect a subsequent infestation.
	var/host_revision = 0
	/// Chemical resource, capacity and per-second recovery.
	var/chemicals = 10
	var/max_chemicals = 250
	var/chemical_rate = 0.5
	/// Generation is inherited by children, rank is earned individually.
	var/generation = 1
	/// Young, mature, adult, elder (1 through 4).
	var/rank = 1
	/// Reproductions towards the next rank and spendable evolution points.
	var/reproductions = 0
	var/evolution_points = 0
	/// Weak references avoid retaining previous hosts just to recognise them.
	var/list/datum/weakref/previous_hosts = list()
	/// Learned focus datums, owned and deleted by this mob.
	var/list/datum/cortical_borer_focus/focuses = list()
	/// True when host effects were applied using the unoccupied-host coefficients.
	var/catatonic_bonus = FALSE
	/// Whether we have introduced ourselves to the current host through private speech.
	var/host_contacted = FALSE
	/// Hiding a controlled host's medical HUD is independent of the furniture-hiding action.
	var/sneaking = FALSE
	/// Stored actions are moved between the parasite and its controlled body.
	var/datum/action/innate/cortical_borer/menu/menu_action
	var/datum/action/innate/cortical_borer/communicate/host_chat_action
	var/datum/action/innate/cortical_borer/resist/resist_action
	var/datum/action/innate/cortical_borer/hide/hide_action
	var/datum/action/cooldown/mob_cooldown/cortical_borer/infest/infest_action
	var/datum/action/cooldown/mob_cooldown/cortical_borer/dominate/dominate_action
	COOLDOWN_DECLARE(secretion_cooldown)
	COOLDOWN_DECLARE(torment_cooldown)
	COOLDOWN_DECLARE(speech_cooldown)

/mob/living/basic/cortical_borer/Initialize(mapload, new_generation = 1)
	. = ..()
	generation = new_generation
	real_name = "Мозговой червь [rand(1000, 9999)]"
	name = real_name
	ADD_TRAIT(src, TRAIT_VENTCRAWLER_ALWAYS, INNATE_TRAIT)
	menu_action = new(src)
	host_chat_action = new(src)
	resist_action = new(src)
	hide_action = new(src)
	infest_action = new(src)
	dominate_action = new(src)
	menu_action.Grant(src)
	hide_action.Grant(src)
	infest_action.Grant(src)
	dominate_action.Grant(src)
	// mind.transfer_to() cannot use a body after qdel has marked it as deleting.
	RegisterSignal(src, COMSIG_PREQDELETED, PROC_REF(before_borer_deletion))
	update_borer_size()

/// Return both minds before the language holders or actions enter teardown.
/mob/living/basic/cortical_borer/proc/before_borer_deletion()
	SIGNAL_HANDLER
	leave_host()
	if(key)
		ghostize(can_reenter_corpse = FALSE, forced = TRUE)

/mob/living/basic/cortical_borer/Login()
	. = ..()
	if(!. || !client)
		return
	borer_mind = mind
	if(!mind.has_antag_datum(/datum/antagonist/cortical_borer))
		mind.add_antag_datum(/datum/antagonist/cortical_borer)
	// The parent Login built these before borer_mind and the role were assigned.
	update_mob_action_buttons(UPDATE_BUTTON_STATUS)
	if(host)
		reset_perspective(host)

/mob/living/basic/cortical_borer/Destroy()
	leave_host()
	if(key)
		ghostize(can_reenter_corpse = FALSE)
	QDEL_NULL(menu_action)
	QDEL_NULL(host_chat_action)
	QDEL_NULL(resist_action)
	QDEL_NULL(hide_action)
	QDEL_NULL(infest_action)
	QDEL_NULL(dominate_action)
	QDEL_LIST(focuses)
	borer_mind = null
	previous_hosts = null
	return ..()

/mob/living/basic/cortical_borer/death(gibbed)
	. = ..()
	if(.)
		leave_host()

/mob/living/basic/cortical_borer/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change)
	. = ..()
	if(host && loc != host)
		leave_host()

/// Moving our mind into the host logs out this body, but is not a disconnected player sleeping.
/mob/living/basic/cortical_borer/handle_ssd(seconds_per_tick, times_fired)
	if(controlling)
		return
	return ..()

/mob/living/basic/cortical_borer/Life(seconds_per_tick, times_fired)
	. = ..()
	if(stat == DEAD)
		return
	adjust_brute_loss(-list(0.05, 0.075, 0.1, 0.15)[rank] * seconds_per_tick)
	if(!host || host.stat == DEAD)
		return
	if(is_docile())
		if(controlling)
			to_chat(host, span_warning("Сахар в крови ослабляет паразита и освобождает ваш разум!"))
			release_control()
		return
	if(!sneaking)
		var/rate = chemical_rate + (rank >= 3 ? 0.1 : 0) + ((locate(/datum/cortical_borer_focus/secretion) in focuses) ? 0.25 : 0)
		chemicals = min(max_chemicals, chemicals + rate * seconds_per_tick)
	if(controlling && SPT_PROB(2.5, seconds_per_tick))
		host.adjust_organ_loss(ORGAN_SLOT_BRAIN, rand(1, 2))
	if(rank == 4)
		host.heal_overall_damage(0.2 * seconds_per_tick, 0.2 * seconds_per_tick)
	for(var/datum/cortical_borer_focus/focus as anything in focuses)
		focus.on_life(src, seconds_per_tick)

/// Resolve the actor without relying on key ownership of the empty parasite body.
/mob/living/basic/cortical_borer/proc/controller()
	return controlling ? host : src

/mob/living/basic/cortical_borer/say(message, bubble_type, list/spans = list(), sanitize = TRUE, datum/language/language, ignore_spam = FALSE, forced, filterproof = FALSE, message_range = 7, datum/saymode/saymode, list/message_mods = list())
	if(host)
		communicate(src, message)
		return
	return ..()

/// Sugar checks are live at every effect, not cached from the last Life tick.
/mob/living/basic/cortical_borer/proc/is_docile()
	return host?.reagents?.has_reagent(/datum/reagent/consumable/sugar)

/// The single server-side availability check used by both actions and UI requests.
/mob/living/basic/cortical_borer/proc/can_act(mob/user, require_host = FALSE, allow_control = TRUE)
	if(QDELETED(src) || QDELETED(user) || user != controller() || stat == DEAD || user.stat != STABLE || IS_UNCONSCIOUS(user))
		return FALSE
	if(borer_mind?.current != user || !borer_mind?.has_antag_datum(/datum/antagonist/cortical_borer) || is_docile())
		return FALSE
	if(require_host && (QDELETED(host) || loc != host || host.stat == DEAD))
		return FALSE
	if(controlling && !allow_control)
		return FALSE
	return TRUE

/// Checks compatibility before and after infestation, including exclusive possession.
/mob/living/basic/cortical_borer/proc/can_infest(mob/living/carbon/human/victim)
	if(!istype(victim) || QDELETED(victim) || victim.stat == DEAD || host || stat != STABLE)
		return FALSE
	if(!(victim.mob_biotypes & MOB_ORGANIC) || !victim.get_bodypart(BODY_ZONE_HEAD))
		return FALSE
	var/obj/item/organ/brain/brain = victim.get_organ_slot(ORGAN_SLOT_BRAIN)
	if(!brain || !(brain.organ_flags & ORGAN_ORGANIC))
		return FALSE
	if(victim.get_cortical_borer() || HAS_TRAIT(victim, TRAIT_BLOOD_WORM_HOST) || HAS_TRAIT(victim, TRAIT_XENO_HOST))
		return FALSE
	return !HAS_TRAIT(victim, TRAIT_MIND_TEMPORARILY_GONE) && !HAS_TRAIT(victim, TRAIT_TEMPORARY_BODY)

/// Recalculate our own size from earned state, avoiding accumulated scale errors.
/mob/living/basic/cortical_borer/proc/update_borer_size()
	var/new_scale = rank == 1 ? 0.5 : 1
	if(locate(/datum/cortical_borer_focus/abdomen) in focuses)
		new_scale *= 0.8
	transform = matrix().Scale(new_scale)

/// Rank requirements are incremental, matching the source's 3 + 6 + 10 progression.
/mob/living/basic/cortical_borer/proc/advance_rank()
	var/list/requirements = list(3, 6, 10)
	if(rank >= 4 || reproductions < requirements[rank])
		return
	reproductions -= requirements[rank]
	rank++
	setMaxHealth(maxHealth + (rank == 4 ? 10 : 5))
	update_borer_size()
	to_chat(controller(), span_notice("Вы развились! Новый ранг: [list("молодой", "зрелый", "взрослый", "старейшина")[rank]]."))

/// Locate only in this body's contents; never search a client-provided world reference.
/mob/living/carbon/proc/get_cortical_borer()
	var/mob/living/basic/cortical_borer/borer = locate() in contents
	return borer?.host == src ? borer : null
