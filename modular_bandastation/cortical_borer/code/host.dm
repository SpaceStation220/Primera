/// Attach only after the action has completed all distance, state and exclusivity checks.
/mob/living/basic/cortical_borer/proc/enter_host(mob/living/carbon/human/new_host)
	if(!can_infest(new_host))
		return FALSE
	host = new_host
	host_revision++
	catatonic_bonus = !host.client
	sneaking = FALSE
	RegisterSignal(host, COMSIG_PREQDELETED, PROC_REF(on_host_deleted))
	RegisterSignal(host, COMSIG_MOB_STATCHANGE, PROC_REF(on_host_stat_changed))
	RegisterSignal(host, COMSIG_CARBON_LOSE_ORGAN, PROC_REF(on_host_organ_removed))
	RegisterSignal(host, COMSIG_LIVING_HEALTHSCAN, PROC_REF(on_healthscan))
	forceMove(host)
	ADD_TRAIT(src, TRAIT_IMMOBILIZED, REF(src))
	reset_perspective(host)
	infest_action.Remove(src)
	dominate_action.Remove(src)
	hide_action.Remove(src)
	for(var/datum/cortical_borer_focus/focus as anything in focuses)
		focus.apply_host(src)
	if(host.client)
		var/datum/weakref/host_ref = WEAKREF(host)
		if(!(host_ref in previous_hosts))
			previous_hosts += host_ref
			max_chemicals = min(355, max_chemicals + 15)
	log_combat(src, host, "infested as a cortical borer")
	to_chat(host, span_warning("Что-то шевелится глубоко в вашей голове."))
	to_chat(src, span_notice("Вы внутри [host]. Откройте панель борера для общения, химии и управления."))
	return TRUE

/// Restore identities and all temporary effects before dropping the parasite out of the body.
/mob/living/basic/cortical_borer/proc/leave_host()
	if(!host)
		return
	var/mob/living/carbon/human/old_host = host
	var/turf/exit_turf = get_turf(old_host)
	release_control()
	for(var/datum/cortical_borer_focus/focus as anything in focuses)
		focus.remove_host(src)
	UnregisterSignal(old_host, list(COMSIG_PREQDELETED, COMSIG_MOB_STATCHANGE, COMSIG_CARBON_LOSE_ORGAN, COMSIG_LIVING_HEALTHSCAN))
	if(!QDELETED(host_chat_action))
		host_chat_action.Remove(old_host)
	host = null
	host_contacted = FALSE
	REMOVE_TRAIT(src, TRAIT_IMMOBILIZED, REF(src))
	host_revision++
	busy = FALSE
	sneaking = FALSE
	catatonic_bonus = FALSE
	reset_perspective()
	if(loc == old_host)
		forceMove(exit_turf)
	if(!QDELETED(src))
		infest_action.Grant(src)
		dominate_action.Grant(src)
		hide_action.Grant(src)
	if(!QDELETED(old_host))
		old_host.med_hud_set_status()
	log_combat(src, old_host, "left as a cortical borer")

/// Preconditions for taking control; mindshield deliberately provides no immunity.
/mob/living/basic/cortical_borer/proc/can_control()
	if(!can_act(src, require_host = TRUE, allow_control = FALSE) || controlling || !mind || host.key && !host.mind)
		return FALSE
	if(HAS_TRAIT(host, TRAIT_BLOOD_WORM_HOST) || HAS_TRAIT(host, TRAIT_XENO_HOST))
		return FALSE
	// The cult's body-transfer handlers currently ignore mob_override; keep this prototype out of that path.
	if(host.mind?.has_antag_datum(/datum/antagonist/cult))
		return FALSE
	return !HAS_TRAIT(host, TRAIT_MIND_TEMPORARILY_GONE) && !HAS_TRAIT(host, TRAIT_TEMPORARY_BODY)

/// Synchronously move both minds, retaining the original mind rather than replacing it with a dummy.
/mob/living/basic/cortical_borer/proc/assume_control()
	if(!can_control())
		return FALSE
	borer_mind = mind
	host_mind = host.mind
	captive = new(src)
	captive.borer = src
	captive.name = "Пленённый разум [host.real_name]"
	controlling = TRUE
	ADD_TRAIT(host, TRAIT_MIND_TEMPORARILY_GONE, REF(src))
	host_revision++
	transferring = TRUE
	if(host_mind)
		RegisterSignal(host_mind, COMSIG_MIND_TRANSFERRED, PROC_REF(on_external_mind_transfer))
		host_mind.transfer_to(captive)
	RegisterSignal(borer_mind, COMSIG_MIND_TRANSFERRED, PROC_REF(on_external_mind_transfer))
	borer_mind.transfer_to(host)
	transferring = FALSE
	menu_action.Grant(host)
	if(host_contacted)
		host_chat_action.Grant(captive)
	resist_action.Grant(captive)
	captive.reset_perspective(host)
	host.med_hud_set_status()
	to_chat(host, span_userdanger("Вы взяли тело носителя под контроль. Панель борера позволяет вернуть управление."))
	to_chat(captive, span_userdanger("Паразит захватил ваше тело! Нажмите «Сопротивляться» или используйте Resist."))
	log_combat(src, host, "assumed control as a cortical borer")
	return TRUE

/// Idempotent return: only return minds which are still in the bodies we borrowed.
/mob/living/basic/cortical_borer/proc/release_control(delete_captive = TRUE)
	if(!controlling)
		return
	controlling = FALSE
	REMOVE_TRAIT(host, TRAIT_MIND_TEMPORARILY_GONE, REF(src))
	host_revision++
	busy = FALSE
	sneaking = FALSE
	transferring = TRUE
	UnregisterSignal(borer_mind, COMSIG_MIND_TRANSFERRED)
	if(host_mind)
		UnregisterSignal(host_mind, COMSIG_MIND_TRANSFERRED)
	if(borer_mind?.current == host)
		borer_mind.transfer_to(src)
	if(host_mind?.current == captive)
		if(!QDELETED(host))
			host_mind.transfer_to(host)
		else
			captive.ghostize(can_reenter_corpse = FALSE)
	host_mind = null
	transferring = FALSE
	if(!QDELETED(menu_action))
		menu_action.Grant(src)
	if(!QDELETED(resist_action))
		resist_action.Remove(captive)
	if(captive)
		captive.borer = null
		// Unexpected external possession must be ghosted before deleting this temporary mob.
		if(captive.key)
			captive.ghostize(can_reenter_corpse = FALSE)
	if(delete_captive)
		QDEL_NULL(captive)
	else
		captive = null
	if(host)
		if(host_contacted && !QDELETED(host_chat_action) && !QDELETED(host))
			host_chat_action.Grant(host)
		if(!QDELETED(host))
			host.med_hud_set_status()
		to_chat(host, span_notice("Вы вновь управляете своим телом."))
	if(host && !QDELETED(host))
		reset_perspective(host)

/// External transfers are authoritative; never pull a mind back from a new unrelated body.
/mob/living/basic/cortical_borer/proc/on_external_mind_transfer(datum/mind/source, mob/old_body)
	SIGNAL_HANDLER
	if(!transferring)
		leave_host()

/mob/living/basic/cortical_borer/proc/on_host_deleted(datum/source)
	SIGNAL_HANDLER
	var/mob/living/carbon/human/deleting_host = host
	leave_host()
	deleting_host?.ghostize(can_reenter_corpse = FALSE, forced = TRUE)

/mob/living/basic/cortical_borer/proc/on_host_stat_changed(datum/source, new_stat, old_stat)
	SIGNAL_HANDLER
	if(new_stat == DEAD)
		release_control()

/// The carbon signal runs inside the parent's on_mob_remove, before brain identity transfer.
/mob/living/basic/cortical_borer/proc/on_host_organ_removed(datum/source, obj/item/organ/organ, special)
	SIGNAL_HANDLER
	if(organ.slot == ORGAN_SLOT_BRAIN)
		leave_host()

/// A conscious, immobile placeholder gives the host a perspective and a way to resist.
/mob/living/cortical_borer_host
	name = "пленённый разум"
	density = FALSE
	invisibility = INVISIBILITY_ABSTRACT
	move_resist = INFINITY
	status_flags = NONE
	initial_language_holder = /datum/language_holder/human_basic
	/// Its owning parasite handles return and destruction.
	var/mob/living/basic/cortical_borer/borer
	/// Prevent parallel resistance attempts and preserve progress against repeated clicks.
	var/resisting = FALSE
	/// Torment cancels the current channel, without blocking future attempts.
	var/resistance_interrupted = FALSE

/mob/living/cortical_borer_host/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_IMMOBILIZED, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_HANDS_BLOCKED, INNATE_TRAIT)
	RegisterSignal(src, COMSIG_PREQDELETED, PROC_REF(before_captive_deletion))

/// Do not recursively qdel the same captive while its outer qdel is still in PREQDELETED.
/mob/living/cortical_borer_host/proc/before_captive_deletion()
	SIGNAL_HANDLER
	if(borer?.captive == src)
		borer.release_control(delete_captive = FALSE)

/mob/living/cortical_borer_host/Login()
	. = ..()
	if(borer?.host)
		reset_perspective(borer.host)

/mob/living/cortical_borer_host/Destroy()
	if(borer?.captive == src)
		borer.release_control()
	borer = null
	return ..()

/mob/living/cortical_borer_host/resist()
	if(!borer?.controlling || resisting || !client)
		return
	resisting = TRUE
	resistance_interrupted = FALSE
	var/mob/living/basic/cortical_borer/parasite = borer
	var/revision = parasite.host_revision
	to_chat(src, span_notice("Вы сосредотачиваетесь на возвращении контроля. Сопротивление займёт некоторое время."))
	to_chat(parasite.host, span_warning("Пленённый разум начал сопротивляться!"))
	var/delay = rand(35, 45) SECONDS + parasite.host.get_organ_loss(ORGAN_SLOT_BRAIN)
	if(do_after(src, delay, target = parasite, show_progress = FALSE, extra_checks = CALLBACK(src, PROC_REF(can_resist_borer), parasite, revision)) && can_resist_borer(parasite, revision))
		parasite.host.adjust_organ_loss(ORGAN_SLOT_BRAIN, rand(5, 10))
		parasite.release_control()
	if(!QDELETED(src))
		resisting = FALSE

/// Keep the same attachment and consciousness throughout a resistance attempt.
/mob/living/cortical_borer_host/proc/can_resist_borer(mob/living/basic/cortical_borer/parasite, revision)
	return !QDELETED(parasite) && !resistance_interrupted && borer == parasite && parasite.captive == src && parasite.controlling && parasite.host_revision == revision && client && stat == STABLE

/mob/living/cortical_borer_host/say(message, bubble_type, list/spans = list(), sanitize = TRUE, datum/language/language, ignore_spam = FALSE, forced, filterproof = FALSE, message_range = 7, datum/saymode/saymode, list/message_mods = list())
	borer?.communicate(src, message)
