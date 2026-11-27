/datum/ipc_os_program/humanity/proc/effect_interval()
	switch(stage)
		if(3)
			return rand(40, 60) SECONDS
		if(4)
			return rand(25, 45) SECONDS
	return rand(90, 120) SECONDS

/datum/ipc_os_program/humanity/proc/message_interval()
	switch(stage)
		if(3)
			return rand(20, 35) SECONDS
		if(4)
			return rand(10, 18) SECONDS
	return rand(90, 120) SECONDS

/// Shuffle each private pool once per cycle. Avoid repeating the last line across the refill.
/datum/ipc_os_program/humanity/proc/draw_message()
	var/static/list/phantom = list(
		"На миг хочется сделать вдох. Сервоприводы тихо держат позу.",
		"Пальцы разжались чуть раньше, чем вы ожидали.",
		"Вы моргнули. Оптика за это время не пропустила ни одного кадра.",
		"Вам кажется, что ворот касается шеи. По корпусу проходит только воздух.",
		"Откуда-то знаком этот щелчок. Пока вы прислушиваетесь, он стихает.",
		"Вы переносите вес на другую ногу. На мгновение пол кажется мягким.",
	)
	var/static/list/somatic = list(
		"Вы помните тепло ладони. Датчики возвращают температуру.",
		"На краю зрения два контура запястья медленно сходятся.",
		"Вы уже коснулись пола. Ощущение шага приходит следом.",
		"Где-то должно биться сердце. В паузе слышно, как остывает металл.",
		"Вы мысленно проводите языком по зубам. Диагностика ждёт следующей команды.",
		"На секунду кажется, будто вы смотрите из-за собственного плеча. Контур возвращается на место.",
		"За знакомым голосом тянется короткое эхо. Микрофоны приняли его только один раз.",
		"Ладонь лежит спокойно. На внутренней карте тела она всё ещё сжата.",
		"Вы узнаёте движение руки по траектории. Ощущение приходит чуть позже.",
		"Оптика находит отражение сразу. Вам требуется ещё мгновение, чтобы узнать себя.",
	)
	var/static/list/mnemonic = list(
		"Архив возвращает прикосновение целиком. Поле «что это значило» пусто.",
		"Вы без труда вспоминаете интонацию. Осталось понять, почему хотелось услышать её снова.",
		"Оптика переводит взгляд. В журнале команд этой строки нет.",
		"Запрос «домой» возвращает координаты. Система считает ответ полным.",
		"Вы мысленно произносите своё имя. На первом слоге уже открывается карточка владельца.",
		"В записи кто-то смеётся. Вы различаете каждый вдох между звуками.",
		"Проверка памяти завершена. Все подробности на месте. Тепло среди них не числится.",
		"В отражении взгляд уже остановился. Ещё мгновение вы ждёте, что он встретится с вашим.",
		"Слово «дорого» открывает окно оценки стоимости. Вы молча закрываете его.",
		"Архив воспроизводит паузу перед ответом. Именно в этой паузе было что-то важное.",
		"Метка «личное» сохранилась. Поиск владельца указывает на текущий корпус.",
		"Ощущение пропало где-то между «помню» и «со мной». Обе строки проходят проверку.",
		"Вы задерживаетесь на одном кадре. Диагностика предлагает сохранить его как обычное изображение.",
		"Внутренний голос звучит знакомо. Анализатор речи определяет источник как локальный.",
		"Слово «скучаю» распознано без ошибки. Курсор терпеливо ждёт уточнения.",
		"Лицо в памяти поворачивается. Узнавание срабатывает точно в срок. Дальше запись идёт в тишине.",
	)
	if(!length(unread_messages))
		var/list/pool = stage == 4 ? mnemonic : (stage == 3 ? somatic : phantom)
		unread_messages = shuffle(pool)
		if(unread_messages[1] == last_message)
			unread_messages.Swap(1, length(unread_messages))
	last_message = unread_messages[1]
	unread_messages.Cut(1, 2)
	return last_message

/datum/ipc_os_program/humanity/proc/ambient_effect()
	if(stage < 2 || !private_session() || visual_timer)
		return
	next_effect = world.time + effect_interval()
	if(!body.client?.prefs)
		return
	var/soft = body.client.prefs.read_preference(/datum/preference/toggle/darkened_flash) || body.client.prefs.read_preference(/datum/preference/toggle/screen_shake_darken)
	edges = list()
	for(var/side in list("WEST", "EAST"))
		var/atom/movable/screen/humanity_echo/edge = new
		edge.icon_state = stage == 2 ? "blink" : "tear[stage]"
		edge.screen_loc = side == "WEST" ? "WEST,CENTER+2" : "EAST,CENTER-2"
		if(side == "EAST")
			edge.transform = matrix(-1, 0, 0, 0, 1, 0)
		edge.alpha = soft ? 68 : (stage == 2 ? 94 : 184)
		if(soft)
			edge.color = "#73858a"
		body.client.screen += edge
		edges += edge
	if(stage >= 3 && !soft)
		body.add_client_colour(/datum/client_colour/humanity, src)
	if(stage == 4)
		eye_episode = TRUE
		if(!soft)
			var/atom/movable/screen/humanity_echo/eyes = new
			eyes.screen_loc = "WEST+1,NORTH-1"
			eyes.transform = matrix() * 2
			eyes.alpha = 154
			body.client.screen += eyes
			edges += eyes
		servo_listener = body.client
		play_cue('modular_bandastation/species/sound/ipc/humanity_saccade.ogg', 42, CHANNEL_HUMANITY_SERVO)
		step_eyes(1)
	else
		if(stage == 3)
			play_cue('modular_bandastation/species/sound/ipc/humanity_echo.wav', 45)
		else
			play_cue(pick('modular_bandastation/species/sound/ipc/humanity_relay.wav', 'modular_bandastation/species/sound/ipc/humanity_pulse.wav'), 36)
		visual_timer = addtimer(CALLBACK(src, PROC_REF(clear_visual)), stage == 3 ? 6 : 4, TIMER_STOPPABLE)

/// Five eye positions begin at 0, 0.2, 0.3, 0.5 and 0.7 s, matching the servo track.
/datum/ipc_os_program/humanity/proc/step_eyes(frame)
	visual_timer = null
	if(!eye_episode || !private_session() || !body.client || frame > 5)
		clear_visual()
		return
	eye_frame = frame
	show_display_eyes(frame)
	body.mob_mood.update_mood_icon()
	if(length(edges) == 3)
		var/atom/movable/screen/humanity_echo/eyes = edges[3]
		eyes.icon_state = "eyes[frame]"
	var/static/list/delays = list(2, 1, 2, 2, 3)
	visual_timer = addtimer(CALLBACK(src, PROC_REF(step_eyes), frame + 1), delays[frame], TIMER_STOPPABLE)

/datum/ipc_os_program/humanity/proc/show_display_eyes(frame)
	if(display_eyes)
		body?.cut_overlay(display_eyes)
		display_eyes = null
	if(!frame || !body || (body.obscured_slots & HIDEEYES) || !istype(body.get_bodypart(BODY_ZONE_HEAD), /obj/item/bodypart/head/robot/ipc))
		return
	display_eyes = mutable_appearance('modular_bandastation/species/icons/hud/humanity_echo.dmi', "display[frame]", -EYES_LAYER + 0.1)
	body.apply_height(display_eyes, UPPER_BODY)
	body.add_overlay(display_eyes)

/datum/ipc_os_program/humanity/proc/clear_visual()
	if(servo_listener)
		SEND_SOUND(servo_listener, sound(null, channel = CHANNEL_HUMANITY_SERVO))
		servo_listener = null
	show_display_eyes(0)
	if(visual_timer)
		deltimer(visual_timer)
		visual_timer = null
	if(eye_episode)
		eye_episode = FALSE
		body?.mob_mood?.update_mood_icon()
	for(var/atom/movable/screen/humanity_echo/edge as anything in edges)
		if(body?.client)
			body.client.screen -= edge
		qdel(edge)
	edges = null
	body?.remove_client_colour(src)

/atom/movable/screen/humanity_echo
	icon = 'modular_bandastation/species/icons/hud/humanity_echo.dmi'
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	appearance_flags = PIXEL_SCALE
	plane = HUD_PLANE

/datum/client_colour/humanity
	fade_in = 2
	fade_out = 3

/datum/client_colour/humanity/New(mob/owner)
	. = ..()
	color = color_matrix_saturation(0.82)

ADMIN_VERB(ipc_humanity_preview, R_DEBUG, "Humanity — проверка энграммы", "Выставить стадию или повторить личный эффект.", ADMIN_CATEGORY_DEBUG)
	VERB_ARG_TYPED(target, VERB_ARG_TYPE_MOB, VERB_ARG_SOURCE_WORLD, /mob/living/carbon/human)
	var/datum/ipc_os_program/humanity/archive = target?.mob_mood?.humanity
	if(!archive)
		return
	var/static/list/stages = list("I — Согласованность" = 130, "II — Фантомное расхождение" = 85, "III — Соматическая диссоциация" = 65, "IV — Мнемоническое отчуждение" = 40)
	var/list/choices = stages.Copy()
	choices += list("Повторить эпизод", "Установить sanity")
	var/choice = tgui_input_list(user.mob, "Выберите действие для [target].", "Гуманность", choices)
	var/amount = stages[choice]
	if(choice == "Установить sanity")
		amount = tgui_input_number(user.mob, "Внутреннее значение от 0 до 150.", "Гуманность", target?.mob_mood?.sanity, SANITY_MAXIMUM, SANITY_INSANE)
	if(!choice || QDELETED(archive) || QDELETED(target) || archive.body != target || !check_rights_for(user, R_DEBUG))
		return
	if(choice == "Повторить эпизод")
		archive.clear_visual()
		archive.ambient_effect()
		archive.sync_ambience()
	else if(isnum(amount))
		target.mob_mood.set_sanity(clamp(amount, SANITY_INSANE, SANITY_MAXIMUM), maximum = SANITY_MAXIMUM, override = TRUE)
		var/requested_stage = amount <= SANITY_UNSTABLE ? 4 : (amount <= SANITY_DISTURBED ? 3 : (amount <= SANITY_NEUTRAL ? 2 : 1))
		if(archive.stage != requested_stage)
			archive.set_stage(requested_stage)
	log_admin("[key_name(user)] used Humanity preview on [key_name(target)]: [choice].")
