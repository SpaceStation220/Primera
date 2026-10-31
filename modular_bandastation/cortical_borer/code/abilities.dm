/// Channel control without allowing a second request to start another transfer.
/mob/living/basic/cortical_borer/proc/begin_control(mob/user)
	if(busy || user != src || !can_control())
		return
	busy = TRUE
	var/revision = host_revision
	to_chat(src, span_notice("Вы устанавливаете связь с мозгом носителя..."))
	var/delay = 30 SECONDS + host.get_organ_loss(ORGAN_SLOT_BRAIN) * 0.5 SECONDS
	var/succeeded = do_after(src, delay, host, timed_action_flags = IGNORE_TARGET_LOC_CHANGE, extra_checks = CALLBACK(src, PROC_REF(can_control)))
	if(QDELETED(src) || revision != host_revision)
		return
	busy = FALSE
	if(succeeded && can_control())
		assume_control()

/// Release control first, then leave the same host after the source's 20-second delay.
/mob/living/basic/cortical_borer/proc/begin_leave(mob/user)
	if(busy || !can_act(user) || !host || loc != host)
		return
	if(controlling)
		release_control()
	busy = TRUE
	var/revision = host_revision
	to_chat(src, span_notice("Вы отсоединяетесь от синапсов носителя..."))
	var/succeeded = do_after(src, 20 SECONDS, host, timed_action_flags = IGNORE_TARGET_LOC_CHANGE)
	if(QDELETED(src) || revision != host_revision)
		return
	busy = FALSE
	if(succeeded && can_act(src, allow_control = FALSE) && host && loc == host)
		leave_host()

/// Private speech follows filters, mute and spam rules; delayed inputs bind to an attachment revision.
/mob/living/basic/cortical_borer/proc/communicate(mob/speaker, message, hive = FALSE)
	var/revision = host_revision
	if(!can_communicate(speaker, hive))
		return
	if(isnull(message))
		message = tgui_input_text(speaker, "Введите мысленное сообщение.", hive ? "Связь бореров" : "Связь с носителем", max_length = MAX_MESSAGE_LEN)
	if(!istext(message) || !length(message) || QDELETED(src) || QDELETED(speaker))
		return
	message = trim(copytext_char(sanitize(message, apply_ic_filter = TRUE), 1, MAX_MESSAGE_LEN))
	if(!message || !speaker.try_speak(message) || QDELETED(src) || revision != host_revision || !can_communicate(speaker, hive))
		return
	var/formatted = span_purple("<b>[hive ? "Связь бореров" : "Мысленная связь"], [speaker.real_name]:</b> [message]")
	if(hive)
		for(var/datum/antagonist/cortical_borer/antag in GLOB.antagonists)
			to_chat(antag.owner?.current, formatted)
	else
		if(speaker == controller() && !host_contacted)
			host_contacted = TRUE
			host_chat_action.Grant(controlling ? captive : host)
			to_chat(controlling ? captive : host, span_notice("Вы можете ответить кнопкой «Связаться с паразитом»."))
		to_chat(controller(), formatted)
		to_chat(controlling ? captive : host, formatted)
	speaker.log_talk(message, LOG_SAY, tag = hive ? "borer hive" : "borer host")
	for(var/mob/dead/observer/ghost in GLOB.dead_mob_list)
		to_chat(ghost, "[FOLLOW_LINK(ghost, speaker)] [formatted]")

/// Original hosts retain speech access even when sugar has suppressed the parasite.
/mob/living/basic/cortical_borer/proc/can_communicate(mob/speaker, hive)
	if(QDELETED(speaker) || stat != STABLE || speaker.stat != STABLE)
		return FALSE
	if(hive)
		return speaker == controller() && borer_mind?.has_antag_datum(/datum/antagonist/cortical_borer)
	return host && (speaker == controller() || (host_contacted && speaker == (controlling ? captive : host)))

/// Forced public speech remains subject to the host's physical speech restrictions.
/mob/living/basic/cortical_borer/proc/force_host_speech(mob/user)
	if(!can_act(user, require_host = TRUE, allow_control = FALSE) || !COOLDOWN_FINISHED(src, speech_cooldown))
		return
	var/revision = host_revision
	var/message = tgui_input_text(user, "Что должен сказать носитель?", "Речь носителя", max_length = MAX_MESSAGE_LEN)
	if(!istext(message) || !length(message) || QDELETED(src) || QDELETED(user))
		return
	message = trim(copytext_char(sanitize(message, apply_ic_filter = TRUE), 1, MAX_MESSAGE_LEN))
	if(!user.try_speak(message) || revision != host_revision || !can_act(user, require_host = TRUE, allow_control = FALSE) || !COOLDOWN_FINISHED(src, speech_cooldown))
		return
	COOLDOWN_START(src, speech_cooldown, 1.5 SECONDS)
	log_combat(src, host, "forced speech as a cortical borer", addition = message)
	host.say(message)

/// Reproduction is an atomic debit followed by the birth; no input or yield occurs in between.
/mob/living/basic/cortical_borer/proc/reproduce(mob/user)
	if(!controlling || !can_act(user, require_host = TRUE))
		return FALSE
	var/datum/cortical_borer_focus/reproductive/reproductive_focus = locate() in focuses
	var/cost = reproduction_cost()
	if(chemicals < cost || !get_turf(host))
		return FALSE
	chemicals -= cost
	var/mob/living/basic/cortical_borer/child = new(get_turf(host), generation + 1)
	child.offer_to_ghosts()
	if(reproductive_focus)
		var/roll = rand(1, 100)
		var/extra_children = roll <= 10 ? 1 : (roll <= 15 ? 2 : 0)
		for(var/index in 1 to extra_children)
			var/mob/living/basic/cortical_borer/additional_child = new(get_turf(host), generation + 1)
			additional_child.offer_to_ghosts()
	host.visible_message(span_danger("[host] изрыгает извивающегося мозгового червя!"))
	log_combat(src, host, "reproduced as a cortical borer")
	reproductions++
	evolution_points++
	advance_rank()
	return TRUE

/// Only offspring are automatically offered; admin-spawned founders stay unclaimed until assigned.
/mob/living/basic/cortical_borer/proc/offer_to_ghosts()
	AddComponent(/datum/component/ghost_direct_control, ban_type = ROLE_TRAITOR, role_name = "мозговой червь", poll_question = "Стать личинкой мозгового червя?", assumed_control_message = "Вы — личинка мозгового червя. Найдите носителя и откройте панель способностей.")

/// Torment weakens a free host, or interrupts one resistance attempt without disabling further attempts.
/mob/living/basic/cortical_borer/proc/torment(mob/user)
	if(!can_act(user, require_host = TRUE) || !COOLDOWN_FINISHED(src, torment_cooldown))
		return
	var/cost = torment_cost()
	if(chemicals < cost)
		return
	chemicals -= cost
	COOLDOWN_START(src, torment_cooldown, 10 SECONDS)
	if(controlling)
		to_chat(captive, span_userdanger("Волна психической агонии разрывает вашу концентрацию!"))
		if(captive?.resisting)
			captive.resistance_interrupted = TRUE
	else
		host.adjust_stamina_loss(host.max_stamina)
	log_combat(src, host, "tormented as a cortical borer")

/// Prices are shared with UI data; the frontend never recomputes rank or focus rules.
/mob/living/basic/cortical_borer/proc/reproduction_cost()
	return (locate(/datum/cortical_borer_focus/reproductive) in focuses) ? 30 : 100

/// Final cost includes only upgrades the server has already granted.
/mob/living/basic/cortical_borer/proc/torment_cost()
	return 70 - (rank - 1) * 10 - ((locate(/datum/cortical_borer_focus/sting) in focuses) ? 15 : 0)

/// Purchase a server-owned focus type once, with fractional prices preserved from Paradise.
/mob/living/basic/cortical_borer/proc/learn_focus(mob/user, focus_id)
	if(!can_act(user, require_host = TRUE) || !istext(focus_id))
		return FALSE
	for(var/datum/cortical_borer_focus/focus_type as anything in subtypesof(/datum/cortical_borer_focus))
		if(focus_id != initial(focus_type.id))
			continue
		if((locate(focus_type) in focuses) || evolution_points < initial(focus_type.cost))
			return FALSE
		evolution_points -= initial(focus_type.cost)
		var/datum/cortical_borer_focus/focus = new focus_type
		focuses += focus
		focus.apply_host(src)
		update_borer_size()
		return TRUE
	return FALSE
