// AI EDIT START - Adapt the Lazarus event to the native Primera APIs and regression harness
/** Parasite abilities revalidate the same host after every prompt and delay. */
/datum/action/treacherous_flesh
	button_icon = 'modular_bandastation/lazarus/icons/lazarus_actions.dmi'
	background_icon = 'modular_bandastation/lazarus/icons/lazarus_actions.dmi'
	background_icon_state = "bg_flesh"
	/// Chemical cost from the IceEvent version.
	var/chemical_cost = 0
	/// Body that owns these powers, including while its mind controls the host.
	var/mob/living/treacherous_flesh/user
	/// Escape remains possible after the host dies.
	var/ignore_death = FALSE
	/// Serializes asynchronous activations of this action.
	var/busy = FALSE

/datum/action/treacherous_flesh/New(mob/living/treacherous_flesh/new_user)
	user = new_user
	return ..(new_user)

/datum/action/treacherous_flesh/Destroy()
	user = null
	return ..()

/datum/action/treacherous_flesh/IsAvailable(feedback = FALSE)
	return ..() && !busy && valid_host(user?.host)

/** Checks identity as well as existence so a delayed power cannot affect another host. */
/datum/action/treacherous_flesh/proc/valid_host(mob/living/carbon/human/expected_host)
	return !QDELETED(user) && !QDELETED(expected_host) && !user.trapped_mind && user.host == expected_host && expected_host.treacherous_flesh == user && (ignore_death || expected_host.stat != DEAD)

/datum/action/treacherous_flesh/Trigger(mob/clicker, trigger_flags)
	if(!..() || QDELETED(src) || busy || owner != user || !valid_host(user?.host))
		return FALSE
	busy = TRUE
	. = activate()
	if(!QDELETED(src))
		busy = FALSE

/** Implemented by each power after the common authorization and reentry checks. */
/datum/action/treacherous_flesh/proc/activate()
	return FALSE

/** Equipment powers must check the cost before dropping the host's existing items. */
/datum/action/treacherous_flesh/proc/check_chems(mob/living/carbon/human/expected_host)
	if(!valid_host(expected_host))
		return FALSE
	if(user.chemicals < chemical_cost)
		to_chat(user, span_warning("Нужно [chemical_cost] химикатов."))
		return FALSE
	return TRUE

/** Spends chemicals only while the original host is still available. */
/datum/action/treacherous_flesh/proc/take_chems(mob/living/carbon/human/expected_host)
	if(!check_chems(expected_host))
		return FALSE
	user.chemicals -= chemical_cost
	return TRUE

/** Shared gradual metamorphosis, retaining the donor's durations and rechecking each yield. */
/datum/action/treacherous_flesh/proc/wait_for_host(duration, mob/living/carbon/human/expected_host)
	for(var/elapsed = 0; elapsed < duration; elapsed += 10 SECONDS)
		if(!valid_host(expected_host))
			return FALSE
		expected_host.emote("scream")
		expected_host.adjust_stamina_loss(30)
		sleep(min(10 SECONDS, duration - elapsed))
	return valid_host(expected_host)

/datum/action/treacherous_flesh/message_host
	name = "Сообщить носителю"
	desc = "Послать незнакомый голос в разум носителя."
	button_icon_state = "message"

/datum/action/treacherous_flesh/message_host/activate()
	var/mob/living/carbon/human/host = user.host
	var/message = tgui_input_text(user, "Сообщение для носителя", name, max_length = MAX_MESSAGE_LEN)
	if(!length(message) || !valid_host(host))
		return FALSE
	message = html_encode(message)
	to_chat(host, span_boldnotice("Вы слышите голос в своей голове... <i>[message]</i>"))
	to_chat(user, span_notice("Носитель слышит: [message]"))
	user.cast_tts(list(user, host), message, user, is_local = FALSE)
	user.log_talk(message, LOG_SAY, tag = "Lazarus to host")
	return TRUE

/datum/action/treacherous_flesh/contact_host
	name = "Установить контакт"
	desc = "Раскрыть своё существование и дать носителю телепатический ответ."
	button_icon_state = "contact_host"

/** Reveals the parasite only after confirmation and revalidation of its original host. */
/datum/action/treacherous_flesh/contact_host/activate()
	var/mob/living/carbon/human/host = user.host
	if(user.contacted || tgui_alert(user, "Раскрыть своё существование носителю?", name, list("Да", "Нет")) != "Да" || !valid_host(host))
		return FALSE
	user.contacted = TRUE
	var/datum/action/communicate_parasite/reply = new(user)
	reply.Grant(host)
	user.host_actions += reply
	var/datum/action/treacherous_flesh/communicate_host/talk = new(user)
	talk.Grant(user)
	to_chat(host, span_boldwarning("Вы чувствуете чужой разум внутри себя. Теперь вы можете мысленно поговорить с ним."))
	SEND_SOUND(host, 'modular_bandastation/lazarus/sound/ling_alert.ogg')
	for(var/datum/action/treacherous_flesh/message_host/message_action in user.actions.Copy())
		qdel(message_action)
	return TRUE

/datum/action/treacherous_flesh/communicate_host
	name = "Разговаривать с носителем"
	desc = "Передать носителю телепатическое сообщение от своего имени."
	button_icon_state = "message"

/datum/action/treacherous_flesh/communicate_host/activate()
	var/mob/living/carbon/human/host = user.host
	var/message = tgui_input_text(user, "Сообщение для носителя", name, max_length = MAX_MESSAGE_LEN)
	if(!length(message) || !valid_host(host))
		return FALSE
	message = html_encode(message)
	to_chat(user, span_purple("<b>[user.name]:</b> [message]"))
	to_chat(host, span_purple("<b>[user.name]:</b> [message]"))
	user.cast_tts(list(user, host), message, user, is_local = FALSE)
	user.log_talk(message, LOG_SAY, tag = "Lazarus to host")
	return TRUE

/datum/action/communicate_parasite
	name = "Разговаривать с гостем"
	desc = "Мысленно ответить существу внутри вас."
	button_icon = 'modular_bandastation/lazarus/icons/lazarus_actions.dmi'
	button_icon_state = "message"

/datum/action/communicate_parasite/Trigger(mob/clicker, trigger_flags)
	if(!..())
		return FALSE
	var/mob/living/treacherous_flesh/parasite = target
	var/mob/living/carbon/human/host = owner
	if(!istype(parasite) || !istype(host) || parasite.host != host)
		return FALSE
	var/message = tgui_input_text(host, "Сообщение для гостя", name, max_length = MAX_MESSAGE_LEN)
	if(!length(message) || QDELETED(parasite) || QDELETED(host) || owner != host || parasite.host != host || host.stat == DEAD)
		return FALSE
	message = html_encode(message)
	to_chat(host, span_purple("<b>[host.name]:</b> [message]"))
	to_chat(parasite, span_purple("<b>[host.name]:</b> [message]"))
	host.cast_tts(list(host, parasite), message, host, is_local = FALSE)
	host.log_talk(message, LOG_SAY, tag = "Lazarus to parasite")
	return TRUE

/datum/action/treacherous_flesh/speed_up_evolution
	name = "Ускорить эволюцию"
	desc = "За 100 химикатов получить 60 очков эволюции, рискуя навредить носителю."
	button_icon_state = "speed_up_evolution"
	chemical_cost = 100

/** Buys evolution progress, retaining the donor's three harmful outcomes and harmless rolls. */
/datum/action/treacherous_flesh/speed_up_evolution/activate()
	var/mob/living/carbon/human/host = user.host
	if(!take_chems(host))
		return FALSE
	var/outcome = rand(0, 5)
	if(outcome == 3)
		host.adjust_organ_loss(ORGAN_SLOT_BRAIN, 10)
		host.adjust_stamina_loss(50)
		host.emote("scream")
	else if(outcome == 4)
		host.set_timed_status_effect(10 SECONDS, /datum/status_effect/dizziness)
		host.set_timed_status_effect(10 SECONDS, /datum/status_effect/confusion)
		host.adjust_stamina_loss(100)
	else if(outcome == 5)
		host.adjust_brute_loss(20)
		host.emote("scream")
		sleep(5 SECONDS)
		if(!valid_host(host))
			return FALSE
		host.adjust_brute_loss(20)
		new /mob/living/basic/flesh_biomorph/lesser/small(get_turf(host))
	user.evolution_points += 60
	user.handle_evolution(0)
	return TRUE

/datum/action/treacherous_flesh/fleshmend
	name = "Быстрое исцеление"
	desc = "Быстро восстановить плоть носителя за 30 химикатов. Огонь мешает регенерации."
	button_icon_state = "fleshmend"
	chemical_cost = 30

/datum/action/treacherous_flesh/fleshmend/activate()
	if(user.host.has_status_effect(/datum/status_effect/fleshmend) || !take_chems(user.host))
		return FALSE
	user.host.apply_status_effect(/datum/status_effect/fleshmend)
	return TRUE

/datum/action/treacherous_flesh/adrenaline
	name = "Передозировка адреналином"
	desc = "Снять оглушение и наполнить тело стимуляторами за 50 химикатов."
	button_icon_state = "adrenaline"
	chemical_cost = 50

/datum/action/treacherous_flesh/adrenaline/activate()
	if(!take_chems(user.host))
		return FALSE
	user.host.SetSleeping(0)
	user.host.SetAllImmobility(0)
	user.host.set_stamina_loss(0)
	user.host.set_resting(FALSE, instant = TRUE)
	user.host.reagents.add_reagent(/datum/reagent/medicine/synaptizine, 15)
	user.host.reagents.add_reagent(/datum/reagent/medicine/changelingadrenaline, 1)
	return TRUE

/datum/action/treacherous_flesh/panacea
	name = "Анатомическая панацея"
	desc = "Очистить организм от болезней, токсинов и мутаций за 50 химикатов."
	button_icon_state = "panacea"
	chemical_cost = 50

/datum/action/treacherous_flesh/panacea/activate()
	if(!take_chems(user.host))
		return FALSE
	var/mob/living/carbon/human/host = user.host
	var/obj/item/organ/body_egg/egg = host.get_organ_by_type(/obj/item/organ/body_egg)
	if(egg)
		egg.Remove(host)
		egg.forceMove(get_turf(host))
	host.reagents.add_reagent(/datum/reagent/medicine/mutadone, 1)
	host.reagents.add_reagent(/datum/reagent/medicine/pen_acid, 20)
	host.reagents.add_reagent(/datum/reagent/medicine/mannitol, 25)
	for(var/datum/disease/disease as anything in host.diseases?.Copy())
		if(disease.severity != DISEASE_SEVERITY_POSITIVE)
			disease.cure()
	return TRUE

/datum/action/treacherous_flesh/regrow_organs
	name = "Отрастить органы"
	desc = "Восстановить органы и потерянные конечности за 100 химикатов."
	button_icon_state = "regrow_organs"
	chemical_cost = 100

/datum/action/treacherous_flesh/regrow_organs/activate()
	if(!take_chems(user.host))
		return FALSE
	user.host.emote("scream")
	user.host.regenerate_limbs()
	user.host.dna.species.regenerate_organs(user.host, replace_current = FALSE)
	for(var/obj/item/organ/organ as anything in user.host.organs)
		organ.set_organ_damage(0)
	return TRUE

/datum/action/treacherous_flesh/heat_up
	name = "Органическая грелка"
	desc = "Добавить носителю 1500 единиц запаса тепла за 20 химикатов."
	button_icon_state = "heat_up"
	chemical_cost = 20

/datum/action/treacherous_flesh/heat_up/activate()
	if(!take_chems(user.host))
		return FALSE
	user.host.frostbite = clamp(user.host.frostbite + 1500, 0, FROSTBITE_WARM)
	return TRUE

/datum/action/treacherous_flesh/armblade
	name = "Рука-лезвие"
	desc = "Преобразовать руку носителя в клинок за 25 химикатов. Повторное нажатие убирает только созданный клинок."
	button_icon_state = "armblade"
	chemical_cost = 25
	/// The exact weapon created by this action, never unrelated held items.
	var/obj/item/melee/arm_blade/blade

/datum/action/treacherous_flesh/armblade/Destroy()
	QDEL_NULL(blade)
	return ..()

/datum/action/treacherous_flesh/armblade/activate()
	if(!QDELETED(blade))
		QDEL_NULL(blade)
		return TRUE
	var/mob/living/carbon/human/host = user.host
	if(!check_chems(host))
		return FALSE
	var/obj/item/held = host.get_active_held_item()
	if(held && !host.dropItemToGround(held))
		return FALSE
	if(!take_chems(host))
		return FALSE
	blade = new(host)
	if(!host.put_in_hands(blade, del_on_fail = TRUE))
		blade = null
		user.chemicals += chemical_cost
		return FALSE
	return TRUE

/datum/action/treacherous_flesh/chitin_armor
	name = "Хитиновый панцирь"
	desc = "Покрыть носителя бронёй за 40 химикатов. Поддержание бесплатно."
	button_icon_state = "chitin_armor"
	chemical_cost = 40
	/// Only these generated pieces may be removed by this power.
	var/obj/item/clothing/suit/armor/changeling/armor
	var/obj/item/clothing/head/helmet/changeling/helmet

/datum/action/treacherous_flesh/chitin_armor/Destroy()
	QDEL_NULL(armor)
	QDEL_NULL(helmet)
	return ..()

/datum/action/treacherous_flesh/chitin_armor/activate()
	if(!QDELETED(armor) || !QDELETED(helmet))
		QDEL_NULL(armor)
		QDEL_NULL(helmet)
		return TRUE
	var/mob/living/carbon/human/host = user.host
	if(!check_chems(host))
		return FALSE
	if(!host.canUnEquip(host.wear_suit, force = FALSE) || !host.canUnEquip(host.head, force = FALSE))
		return FALSE
	if((host.wear_suit && !host.dropItemToGround(host.wear_suit)) || (host.head && !host.dropItemToGround(host.head)))
		return FALSE
	if(!take_chems(host))
		return FALSE
	armor = new(host)
	helmet = new(host)
	if(!host.equip_to_slot_if_possible(armor, ITEM_SLOT_OCLOTHING) || !host.equip_to_slot_if_possible(helmet, ITEM_SLOT_HEAD))
		QDEL_NULL(armor)
		QDEL_NULL(helmet)
		user.chemicals += chemical_cost
		return FALSE
	return TRUE

/datum/action/treacherous_flesh/passive_infest
	name = "Пассивное заражение"
	desc = "Заражать пищу, жидкости и пациентов. Пока активно, расходуется четыре химиката за исходный двухсекундный цикл."
	button_icon_state = "passive_infest_off"

/datum/action/treacherous_flesh/passive_infest/activate()
	if(!user.infecting && user.chemicals <= 2)
		return FALSE
	user.infecting = !user.infecting
	button_icon_state = user.infecting ? "passive_infest_on" : "passive_infest_off"
	build_all_button_icons()
	return TRUE

/datum/action/treacherous_flesh/emit_pheromones
	name = "Выделять феромоны"
	desc = "Защитить носителя от биоморфов, добавив его в их стаю."
	button_icon_state = "pheromones_off"
	/// Whether this particular action is active.
	var/active = FALSE

/** Toggles only the faction membership added by this parasite's pheromones. */
/datum/action/treacherous_flesh/emit_pheromones/activate()
	active = !active
	if(active)
		user.added_host_faction = !user.host.has_faction("treacherous_flesh")
		user.host.add_faction("treacherous_flesh")
	else if(user.added_host_faction)
		user.host.remove_faction("treacherous_flesh")
		user.added_host_faction = FALSE
	button_icon_state = active ? "pheromones_on" : "pheromones_off"
	build_all_button_icons()
	return TRUE

/datum/action/treacherous_flesh/enslave_mind
	name = "Поработить разум"
	desc = "За 150 химикатов и 30 секунд поработить носителя. Щит разума защищает от порабощения."
	button_icon_state = "enslave_mind"
	chemical_cost = 150

/** Enslaves a living, unshielded host after its confirmation and metamorphosis complete. */
/datum/action/treacherous_flesh/enslave_mind/activate()
	var/mob/living/carbon/human/host = user.host
	if(user.host_enslaved || HAS_TRAIT(host, TRAIT_MINDSHIELD) || tgui_alert(user, "Поработить разум носителя?", name, list("Да", "Нет")) != "Да")
		return FALSE
	if(!valid_host(host) || HAS_TRAIT(host, TRAIT_MINDSHIELD) || !take_chems(host) || !wait_for_host(30 SECONDS, host) || HAS_TRAIT(host, TRAIT_MINDSHIELD))
		return FALSE
	user.host_enslaved = TRUE
	var/datum/mind/host_mind = user.trapped_mind?.mind || host.mind
	host_mind?.add_antag_datum(/datum/antagonist/lazarus_host)
	return TRUE

/datum/action/treacherous_flesh/leave_the_body
	name = "Покинуть тело"
	desc = "За восемь секунд вырваться из носителя низшим биоморфом. Обратного пути нет. Доступно и после смерти носителя."
	button_icon_state = "leave_the_body"
	ignore_death = TRUE

/** Confirms irreversible escape before waiting and releasing the parasite's player. */
/datum/action/treacherous_flesh/leave_the_body/activate()
	var/mob/living/carbon/human/host = user.host
	if(tgui_alert(user, "Покинуть тело навсегда?", name, list("Да", "Нет")) != "Да" || !wait_for_host(8 SECONDS, host))
		return FALSE
	return user.burst_out()

/datum/action/treacherous_flesh/take_control
	name = "Захватить контроль"
	desc = "За минуту захватить управление телом. Носитель может сопротивляться. Во время контроля другие способности недоступны."
	button_icon_state = "take_control"

/** Confirms possession and keeps the same host valid throughout the one-minute takeover. */
/datum/action/treacherous_flesh/take_control/activate()
	var/mob/living/carbon/human/host = user.host
	if(user.trapped_mind || tgui_alert(user, "Захватить тело носителя?", name, list("Да", "Нет")) != "Да" || !wait_for_host(1 MINUTES, host))
		return FALSE
	return user.take_control()

/datum/action/treacherous_flesh/ascension
	name = "Вознестись"
	desc = "За 200 химикатов и 30 секунд стать высшим биоморфом. Носитель станет крупным низшим биоморфом."
	button_icon_state = "ascension"
	chemical_cost = 200

/** Transfers both players to their successor bodies only after the native confirmation and wait. */
/datum/action/treacherous_flesh/ascension/activate()
	var/mob/living/carbon/human/host = user.host
	if(tgui_alert(user, "Начать окончательное возвышение?", name, list("Да", "Нет")) != "Да" || !take_chems(host) || !wait_for_host(30 SECONDS, host))
		return FALSE
	user.restore_control()
	var/mob/living/basic/flesh_biomorph/lesser/large/host_body = new(get_turf(host))
	var/mob/living/basic/flesh_biomorph/high/parasite_body = new(get_turf(host))
	host.mind?.transfer_to(host_body, force_key_move = TRUE)
	user.mind?.transfer_to(parasite_body, force_key_move = TRUE)
	parasite_body.name = "[initial(parasite_body.name)] ([user.name])"
	parasite_body.real_name = parasite_body.name
	user.disinfest(delete = FALSE)
	host.gib()
	qdel(user)
	return TRUE
// AI EDIT END
