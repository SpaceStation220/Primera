/// The archive and the engram share the lifetime of the installed positronic core.
/datum/ipc_os_program/humanity
	id = "humanity"
	name = "Мнемонический архив"
	description = "Личные записи энграммы и знакомые способы вернуться к себе."
	icon = "book-open"
	builtin = TRUE
	installed = TRUE
	passive = TRUE
	ready = TRUE
	var/mob/living/carbon/human/body
	var/list/records = list()
	var/anchor = "reflection"
	var/habit_emote
	var/keepsake_description
	var/starting_photo_given = FALSE
	var/datum/weakref/keepsake
	var/stage = 1
	var/candidate = 1
	var/candidate_since = 0
	var/saved_sanity
	var/list/saved_quirks = list()
	var/list/speakers = list()
	var/conversation_since
	var/next_social = 0
	var/next_effect = 0
	var/next_message = 0
	var/list/unread_messages
	var/last_message
	/// Rate multipliers for timed actions and running on the ground.
	var/action_rate = 1
	var/run_rate = 1
	var/eye_episode = FALSE
	var/eye_frame = 1
	var/client/servo_listener
	var/mutable_appearance/display_eyes
	var/datum/humanity_ambience/ambience
	var/next_anchor = 0
	var/next_trauma = 0
	var/action_token = 0
	var/anchoring = FALSE
	var/injured = FALSE
	var/was_dead = FALSE
	var/visual_timer
	var/list/edges

/datum/ipc_os_program/humanity/available()
	return os?.generation() == "III"

/datum/ipc_os_program/humanity/proc/attach(mob/living/carbon/human/new_body)
	if(body == new_body || !new_body || !available() || os.host != new_body)
		return
	body = new_body
	body.mob_mood.humanity = src
	body.mob_mood.set_enabled(TRUE)
	body.remove_movespeed_modifier(MOVESPEED_ID_SANITY)
	body.remove_actionspeed_modifier(ACTIONSPEED_ID_SANITY)
	body.remove_status_effect(/datum/status_effect/hallucination/sanity)
	body.mob_mood.set_sanity(isnull(saved_sanity) ? 110 : saved_sanity, maximum = SANITY_MAXIMUM, override = TRUE)
	refresh_speed()
	for(var/quirk_type in saved_quirks)
		body.add_quirk(quirk_type, add_unique = FALSE, announce = FALSE)
	injured = body.health < body.maxHealth * 0.5
	was_dead = body.stat == DEAD
	candidate = stage
	next_effect = world.time + effect_interval()
	next_message = world.time + message_interval()
	RegisterSignal(body, COMSIG_LIVING_LIFE, PROC_REF(on_life))
	RegisterSignal(body, COMSIG_CARBON_SANITY_UPDATE, PROC_REF(on_sanity))
	RegisterSignal(body, COMSIG_MOB_LOGIN, PROC_REF(on_login))
	RegisterSignal(body, COMSIG_MOVABLE_HEAR, PROC_REF(on_hear))
	RegisterSignal(body, COMSIG_CARBON_POST_REMOVE_LIMB, PROC_REF(on_limb))
	RegisterSignal(body, COMSIG_LIVING_HEALTH_UPDATE, PROC_REF(on_health))
	RegisterSignal(body, COMSIG_LIVING_DEATH, PROC_REF(on_death))
	RegisterSignal(body, COMSIG_LIVING_REVIVE, PROC_REF(on_revive))
	RegisterSignal(body, COMSIG_MOB_LOGOUT, PROC_REF(on_logout))
	body.mob_mood?.update_mood_icon()

/datum/ipc_os_program/humanity/proc/detach()
	if(!body)
		return
	stop()
	reset_session()
	UnregisterSignal(body, list(COMSIG_LIVING_LIFE, COMSIG_MOVABLE_HEAR, COMSIG_CARBON_POST_REMOVE_LIMB, COMSIG_LIVING_HEALTH_UPDATE, COMSIG_LIVING_DEATH, COMSIG_LIVING_REVIVE, COMSIG_MOB_LOGOUT, COMSIG_MOB_LOGIN, COMSIG_CARBON_SANITY_UPDATE))
	if(body.mob_mood)
		saved_sanity = body.mob_mood.sanity
	saved_quirks.Cut()
	for(var/datum/quirk/quirk as anything in body.quirks?.Copy())
		if(is_humanity_quirk(quirk.type))
			saved_quirks += quirk.type
			body.remove_quirk(quirk.type)
	if(body.mob_mood)
		body.mob_mood.set_enabled(FALSE)
		body.mob_mood.humanity = null
		refresh_speed()
	action_rate = 1
	run_rate = 1
	body = null

/datum/ipc_os_program/humanity/Destroy()
	detach()
	keepsake = null
	return ..()

/datum/ipc_os_program/humanity/start()
	if(!..())
		return FALSE
	refresh_speed()
	sync_ambience()
	return TRUE

/datum/ipc_os_program/humanity/stop()
	if(running)
		reset_session()
	refresh_speed()
	return ..()

/datum/ipc_os_program/humanity/proc/reset_session()
	clear_visual()
	release_ambience()
	action_token++
	anchoring = FALSE
	speakers.Cut()
	conversation_since = null
	candidate = stage
	next_effect = world.time + effect_interval()
	next_message = world.time + message_interval()
	SStgui.close_uis(src)

/datum/ipc_os_program/humanity/proc/on_logout()
	SIGNAL_HANDLER
	reset_session()

/datum/ipc_os_program/humanity/proc/on_death()
	SIGNAL_HANDLER
	was_dead = TRUE
	refresh_speed()
	reset_session()

/datum/ipc_os_program/humanity/proc/on_revive()
	SIGNAL_HANDLER
	if(was_dead)
		was_dead = FALSE
		refresh_speed()
		record_trauma(/datum/mood_event/humanity_trauma/revival, TRUE)

/datum/ipc_os_program/humanity/proc/on_health()
	SIGNAL_HANDLER
	var/serious = body.health < body.maxHealth * 0.5
	if(serious && !injured)
		injured = TRUE
		record_trauma(/datum/mood_event/humanity_trauma)
	else if(injured && body.health >= body.maxHealth * 0.85)
		injured = FALSE
		if(body.stat != DEAD)
			body.add_mood_event("humanity_repair", /datum/mood_event/humanity_repair)

/datum/ipc_os_program/humanity/proc/on_limb(datum/source, obj/item/bodypart/limb, special, dismembered)
	SIGNAL_HANDLER
	if(limb.body_zone == BODY_ZONE_HEAD && display_eyes)
		show_display_eyes(0)
	if(dismembered && !special)
		record_trauma(/datum/mood_event/humanity_trauma/limb, TRUE)

/datum/ipc_os_program/humanity/proc/record_trauma(event_type, replace = FALSE)
	if(!body || body.stat == DEAD || (!replace && world.time < next_trauma))
		return
	next_trauma = world.time + 3 MINUTES
	body.add_mood_event("humanity_trauma", event_type)

/datum/ipc_os_program/humanity/proc/on_login()
	SIGNAL_HANDLER
	body.mob_mood?.update_mood_icon()
	next_effect = world.time + 2 SECONDS
	next_message = world.time + message_interval()

/datum/ipc_os_program/humanity/proc/on_sanity(datum/source, amount)
	SIGNAL_HANDLER
	sync_stage(amount)

/datum/ipc_os_program/humanity/proc/on_life()
	SIGNAL_HANDLER
	if(body.stat == DEAD || !body.mob_mood?.enabled)
		return
	refresh_speed()
	sync_stage(body.mob_mood.sanity)
	sync_ambience()
	if(!private_session())
		if(visual_timer)
			clear_visual()
		return
	if(world.time >= next_social)
		evaluate_conversation()
	if(stage > 1 && world.time >= next_effect)
		ambient_effect()
	if(stage > 1 && world.time >= next_message)
		to_chat(body, span_notice(draw_message()))
		next_message = world.time + message_interval()

/datum/ipc_os_program/humanity/proc/private_session()
	return body && os.can_view(body)

/datum/ipc_os_program/humanity/proc/process_mood(seconds_per_tick)
	var/datum/mood/mood = body?.mob_mood
	if(!mood?.enabled || body.stat == DEAD)
		return
	// SAD4/SAD3, SAD2/SAD1, neutral, HAPPY1/HAPPY2, HAPPY3/HAPPY4 in native level order.
	var/static/list/rates_per_minute = list(-3.5, -3.5, -2.2, -2.2, -1, 0.25, 0.25, 0.8, 0.8)
	var/amount = clamp(mood.sanity + rates_per_minute[mood.mood_level] * seconds_per_tick / 60, SANITY_INSANE, SANITY_MAXIMUM)
	mood.set_sanity(amount, minimum = SANITY_INSANE, maximum = SANITY_MAXIMUM)

/datum/ipc_os_program/humanity/proc/refresh_speed()
	if(!body)
		return
	var/new_action_rate = 1
	var/new_run_rate = 1
	if(body.mob_mood?.humanity == src && body.mob_mood.enabled && os.is_operational())
		new_action_rate += 0.1 * clamp((body.mob_mood.sanity - SANITY_UNSTABLE) / (SANITY_GREAT - SANITY_UNSTABLE), 0, 1)
		new_run_rate += 0.02 * (5 - stage)
	if(action_rate != new_action_rate)
		action_rate = new_action_rate
		body.update_actionspeed()
	if(run_rate != new_run_rate)
		run_rate = new_run_rate
		body.update_movespeed()

/mob/living/carbon/human/update_actionspeed()
	. = ..()
	if(mob_mood?.humanity)
		. /= mob_mood.humanity.action_rate
		cached_multiplicative_actions_slowdown = .

/datum/ipc_os_program/humanity/proc/sync_stage(amount)
	var/level = SANITY_LEVEL_NEUTRAL
	if(amount <= SANITY_UNSTABLE)
		level = SANITY_LEVEL_CRAZY
	else if(amount <= SANITY_DISTURBED)
		level = SANITY_LEVEL_UNSTABLE
	else if(amount <= SANITY_NEUTRAL)
		level = SANITY_LEVEL_DISTURBED
	var/static/list/recovery = list(0, SANITY_NEUTRAL + 3, SANITY_DISTURBED + 3, SANITY_UNSTABLE + 3)
	if(level - 1 < stage && amount < recovery[stage])
		level = stage + 1
	update_stage(level)

/datum/ipc_os_program/humanity/proc/update_stage(level)
	var/proposed = clamp(level - 1, 1, 4)
	if(candidate != proposed)
		candidate = proposed
		candidate_since = world.time
	if(stage == candidate || (candidate != 4 && world.time < candidate_since + 10 SECONDS))
		return
	set_stage(candidate)

/datum/ipc_os_program/humanity/proc/set_stage(new_stage)
	var/previous = stage
	clear_visual()
	stage = new_stage
	refresh_speed()
	candidate = stage
	candidate_since = world.time
	unread_messages = null
	body?.mob_mood?.update_mood_icon()
	sync_ambience()
	next_effect = world.time + effect_interval()
	next_message = world.time + message_interval()
	if(private_session())
		if(stage < previous)
			to_chat(body, span_notice("Знакомые черты снова складываются в одно лицо."))
			play_cue('modular_bandastation/species/sound/ipc/humanity_settle.ogg', 36)
		else if(stage > previous)
			ambient_effect()
	SStgui.update_uis(src)

/datum/ipc_os_program/humanity/proc/on_hear(mob/source, list/heard)
	SIGNAL_HANDLER
	var/mob/living/carbon/human/speaker = heard[HEARING_SPEAKER]
	if(!private_session() || !istype(speaker) || !GET_CLIENT(speaker) || IS_UNCONSCIOUS_OR_CRIT(speaker) || heard[HEARING_RADIO_FREQ] || !heard[HEARING_RAW_MESSAGE])
		return
	var/list/modes = heard[HEARING_MESSAGE_MODE]
	if(modes?[MODE_CUSTOM_SAY_ERASE_INPUT] || HAS_TRAIT(body, TRAIT_DEAF) || speaker.z != body.z || get_dist(body, speaker) > min(4, heard[HEARING_RANGE]))
		return
	var/datum/weakref/key = WEAKREF(speaker)
	if(isnull(speakers[key]) || world.time >= speakers[key] + 10 SECONDS)
		speakers[key] = world.time

/datum/ipc_os_program/humanity/proc/evaluate_conversation()
	next_social = world.time + 12 SECONDS
	var/others = 0
	var/replied = FALSE
	var/psychologist = FALSE
	for(var/datum/weakref/key as anything in speakers.Copy())
		var/mob/living/carbon/human/speaker = key.resolve()
		if(!speaker || world.time > speakers[key] + 25 SECONDS || IS_UNCONSCIOUS_OR_CRIT(speaker) || !GET_CLIENT(speaker) || !(speaker in view(4, body)))
			speakers -= key
			continue
		if(speaker == body)
			replied = TRUE
		else
			others++
			if(istype(speaker.mind?.assigned_role, /datum/job/psychologist))
				psychologist = TRUE
	if(!others)
		conversation_since = null
		return
	if(isnull(conversation_since))
		conversation_since = world.time
	var/strength = min(3, others)
	if(replied || anchor == "social")
		strength++
	if(replied && psychologist && world.time >= conversation_since + 45 SECONDS)
		strength += world.time >= conversation_since + 2 MINUTES ? 2 : 1
	var/static/list/social_events = list(/datum/mood_event/humanity_social, /datum/mood_event/humanity_social/two, /datum/mood_event/humanity_social/three, /datum/mood_event/humanity_social/four, /datum/mood_event/humanity_social/five, /datum/mood_event/humanity_social/six)
	body.add_mood_event("humanity_social", social_events[min(6, strength)])

/datum/mood_event/humanity_trauma
	description = "Ощущаемая форма тела расходится с картой повреждений."
	mood_change = -4
	timeout = 2 MINUTES

/datum/mood_event/humanity_trauma/limb
	description = "Карта корпуса уже изменилась. Ощущение утраченной конечности всё ещё со мной."
	mood_change = -6

/datum/mood_event/humanity_trauma/revival
	description = "Между двумя мгновениями сознания остался провал."
	mood_change = -6

/datum/mood_event/humanity_trauma/emp
	description = "Отголосок разряда ещё чувствуется в теле."
	timeout = 60 SECONDS

/datum/mood_event/humanity_repair
	description = "Движение снова совпадает с ощущением собственного тела."
	mood_change = 2
	timeout = 90 SECONDS

/datum/mood_event/humanity_social
	description = "Рядом звучат знакомые живые голоса."
	mood_change = 1
	timeout = 30 SECONDS

/datum/mood_event/humanity_social/two
	mood_change = 2
/datum/mood_event/humanity_social/three
	mood_change = 3
/datum/mood_event/humanity_social/four
	mood_change = 4
/datum/mood_event/humanity_social/five
	mood_change = 5
/datum/mood_event/humanity_social/six
	mood_change = 6

/datum/mood_event/humanity_anchor
	description = "Что-то очень личное снова отзывается во мне."
	mood_change = 3
	timeout = 90 SECONDS

/datum/mood_event/humanity_anchor/reflection
	mood_change = 2
