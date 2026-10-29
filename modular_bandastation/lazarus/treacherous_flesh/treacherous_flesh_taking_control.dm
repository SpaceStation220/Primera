/// The original host keeps their own mind, antagonist datums and memories here.
/mob/living/trapped_mind
	name = "Заключённый разум"
	density = FALSE
	invisibility = INVISIBILITY_ABSTRACT
	initial_language_holder = /datum/language_holder/treacherous_flesh
	/// Parasite responsible for returning this mind to its body.
	var/mob/living/treacherous_flesh/parasite
	/// Prevents repeated simultaneous resistance attempts.
	var/resisting = FALSE

/mob/living/trapped_mind/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_IMMOBILIZED, INNATE_TRAIT)

/mob/living/trapped_mind/Destroy()
	parasite = null
	return ..()

/mob/living/trapped_mind/add_tts_component()
	AddComponent(/datum/component/tts_component, /datum/tts_seed/silero/anubarak)

/mob/living/trapped_mind/say(message, bubble_type, list/spans, sanitize = TRUE, datum/language/language, ignore_spam, forced, filterproof, message_range, datum/saymode/saymode, list/message_mods)
	message = trim(copytext_char(html_encode(message), 1, MAX_MESSAGE_LEN))
	if(!length(message) || QDELETED(parasite?.host))
		return
	to_chat(src, span_purple("<b>[name]:</b> [message]"))
	to_chat(parasite.host, span_purple("<b>[name]:</b> [message]"))
	cast_tts(list(src, parasite.host), message, src, is_local = FALSE)
	log_talk(message, LOG_SAY, tag = "Lazarus trapped mind")

/mob/living/trapped_mind/emote(act, m_type = null, message = null, intentional = FALSE, force_silence = FALSE)
	return FALSE

/// Moves minds, rather than swapping ckeys and leaving their identities behind.
/mob/living/treacherous_flesh/proc/take_control()
	if(QDELETED(host) || trapped_mind || !host.mind || !mind || host.stat == DEAD)
		return FALSE
	trapped_mind = new(host)
	trapped_mind.parasite = src
	trapped_mind.name = host.real_name
	trapped_mind.real_name = host.real_name
	controlling_mind = mind
	host.mind.transfer_to(trapped_mind, force_key_move = TRUE)
	trapped_mind.reset_perspective(host)
	controlling_mind.transfer_to(host, force_key_move = TRUE)
	var/datum/action/return_control/return_action = new(src)
	return_action.Grant(host)
	host_actions += return_action
	var/datum/action/resist_control/resist_action = new(src)
	resist_action.Grant(trapped_mind)
	return TRUE

/// Restores both players even if control ends by surgery, a cure or deletion.
/mob/living/treacherous_flesh/proc/restore_control()
	if(!trapped_mind)
		return
	var/can_return_host = host && !QDELING(host) && (!host.mind || host.mind == controlling_mind)
	if(host && controlling_mind?.current == host)
		if(QDELING(src) || QDELING(host))
			// Mind transfer reads both bodies' language holders, which deletion has invalidated.
			host.ghostize(can_reenter_corpse = FALSE, forced = TRUE)
		else
			controlling_mind.transfer_to(src, force_key_move = TRUE)
	if(trapped_mind.mind && can_return_host)
		trapped_mind.mind.transfer_to(host, force_key_move = TRUE)
	else if(trapped_mind.mind)
		trapped_mind.ghostize(can_reenter_corpse = FALSE)
	controlling_mind = null
	QDEL_NULL(trapped_mind)
	for(var/datum/action/return_control/action in host_actions.Copy())
		host_actions -= action
		qdel(action)
	if(host)
		reset_perspective(host)

/datum/action/return_control
	name = "Вернуть контроль"
	desc = "Вернуть тело его прежнему владельцу."
	button_icon = 'modular_bandastation/lazarus/icons/lazarus_actions.dmi'
	button_icon_state = "return_control"

/datum/action/return_control/Trigger(mob/clicker, trigger_flags)
	if(!..())
		return FALSE
	var/mob/living/treacherous_flesh/parasite = target
	if(!istype(parasite) || owner != parasite.host || !parasite.trapped_mind)
		return FALSE
	parasite.restore_control()
	return TRUE

/datum/action/resist_control
	name = "Сопротивляться контролю"
	desc = "Вернуть управление телом через минуту сопротивления, если разум ещё не порабощён."
	button_icon = 'modular_bandastation/lazarus/icons/lazarus_actions.dmi'
	button_icon_state = "enslave_mind"

/datum/action/resist_control/Trigger(mob/clicker, trigger_flags)
	if(!..())
		return FALSE
	var/mob/living/trapped_mind/prisoner = owner
	var/mob/living/treacherous_flesh/parasite = target
	if(!istype(prisoner) || !istype(parasite) || parasite.trapped_mind != prisoner || prisoner.resisting || parasite.host_enslaved || parasite.evolution_stage >= LAZARUS_FLESH_FINAL_STAGE)
		return FALSE
	prisoner.resisting = TRUE
	to_chat(prisoner, span_warning("Вы начинаете возвращать контроль над телом."))
	sleep(1 MINUTES)
	if(QDELETED(prisoner) || QDELETED(parasite))
		return FALSE
	prisoner.resisting = FALSE
	if(parasite.trapped_mind != prisoner || parasite.host_enslaved || parasite.evolution_stage >= LAZARUS_FLESH_FINAL_STAGE)
		return FALSE
	parasite.restore_control()
	return TRUE
