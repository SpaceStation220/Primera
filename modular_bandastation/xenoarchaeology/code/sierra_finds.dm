/// Подвижный бур Sierra использует штатную добычу руды и один отменяемый цикл на столкновение.
/obj/machinery/xenoartifact/giant_drill
	name = "гигантский инопланетный бур"
	desc = "Древний бур на гусеницах. Включите его рукой и толкайте в минеральную породу."
	icon = 'modular_bandastation/xenoarchaeology/icons/sierra/gigadrill.dmi'
	icon_state = "gigadrill"
	random_effects = FALSE
	layer = ABOVE_OBJ_LAYER
	/// Выбранное оператором состояние привода.
	var/enabled = FALSE
	/// Таймер принадлежит буру и удаляется при остановке или разрушении.
	var/drill_timer
	/// Исходная клетка исключает добычу после принудительного перемещения.
	var/turf/drilling_origin
	/// Порода повторно проверяется непосредственно перед добычей.
	var/turf/closed/mineral/drilling_target

/obj/machinery/xenoartifact/giant_drill/Destroy()
	cancel_drilling()
	return ..()

/obj/machinery/xenoartifact/giant_drill/update_icon_state()
	. = ..()
	icon_state = enabled ? "gigadrill_mov" : "gigadrill"

/obj/machinery/xenoartifact/giant_drill/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(. || lab_owner?.resolve() || !user.can_perform_action(src, NEED_HANDS|FORBID_TELEKINESIS_REACH))
		return
	enabled = !enabled
	if(!enabled)
		cancel_drilling()
	update_appearance()
	balloon_alert(user, enabled ? "бур включён" : "бур выключен")

/obj/machinery/xenoartifact/giant_drill/Bump(atom/bumped_atom)
	. = ..()
	if(. || !enabled || drill_timer || anchored || lab_owner?.resolve() || !isturf(loc) || !istype(bumped_atom, /turf/closed/mineral) || get_dist(src, bumped_atom) != 1)
		return
	drilling_origin = loc
	drilling_target = bumped_atom
	setDir(get_dir(src, bumped_atom))
	set_anchored(TRUE)
	drill_timer = addtimer(CALLBACK(src, PROC_REF(finish_drilling)), 1 SECONDS, TIMER_STOPPABLE)

/obj/machinery/xenoartifact/giant_drill/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change)
	. = ..()
	if(drill_timer)
		cancel_drilling()

/// Освобождает ссылки и исходную блокировку перед любыми вызовами, которые могут удалить бур.
/obj/machinery/xenoartifact/giant_drill/proc/cancel_drilling()
	if(drill_timer)
		deltimer(drill_timer)
		drill_timer = null
	if(drilling_origin)
		set_anchored(FALSE)
	drilling_origin = null
	drilling_target = null

/// Обрабатывает настоящую минеральную породу, сохраняя её руду, жилы и специальные реакции.
/obj/machinery/xenoartifact/giant_drill/proc/finish_drilling()
	drill_timer = null
	var/turf/origin = drilling_origin
	var/turf/closed/mineral/target = drilling_target
	cancel_drilling()
	if(!enabled || loc != origin || !istype(target) || get_dist(src, target) != 1 || lab_owner?.resolve())
		return
	var/direction = get_dir(src, target)
	target.gets_drilled()
	if(QDELETED(src) || !enabled || loc != origin || lab_owner?.resolve())
		return
	var/turf/destination = get_step(origin, direction)
	if(destination && !destination.density)
		Move(destination)

/obj/machinery/xenoartifact/giant_drill/analysis_description()
	return "Гусеничная добывающая машина. Включается рукой; при столкновении с минеральной породой бурит одну клетку за секунду и перемещается вперёд. Выключение останавливает бурение."

/// Исходный пилон Sierra светится и ремонтируется строителем; культовую ауру TG не получает.
/obj/machinery/xenoartifact/cult_pylon
	name = "древний культовый пилон"
	desc = "Парящий хрупкий кристалл, испускающий тусклый багровый свет."
	icon = 'modular_bandastation/xenoarchaeology/icons/sierra/pylon.dmi'
	icon_state = "pylon"
	random_effects = FALSE
	max_integrity = 20
	damage_deflection = 4
	light_power = 0.5
	light_range = 13
	light_color = "#3e0000"

/obj/machinery/xenoartifact/cult_pylon/update_icon_state()
	. = ..()
	icon_state = "pylon"

/obj/machinery/xenoartifact/cult_pylon/attack_basic_mob(mob/living/basic/user, list/modifiers)
	if(!istype(user, /mob/living/basic/construct))
		return ..()
	var/mob/living/basic/construct/builder = user
	if(!builder.can_repair || !builder.can_perform_action(src, FORBID_TELEKINESIS_REACH))
		return ..()
	update_integrity(min(max_integrity, get_integrity() + 5))
	return TRUE

/obj/machinery/xenoartifact/cult_pylon/analysis_description()
	return "Парящий кристаллический пилон. Излучает багровый свет; структура хрупкая. Конструкты-строители способны восстанавливать его повреждения."

/// Одноразовый маяк Sierra предлагает добровольную вербовку и может взорваться при отказе Синдиката.
/obj/machinery/xenoartifact/recruitment_beacon
	name = "зловещий маяк"
	desc = "Древнее устройство связи с подозрительным символом. Активация рукой открывает канал связи."
	icon = 'modular_bandastation/xenoarchaeology/icons/sierra/syndicate_beacon.dmi'
	icon_state = "syndbeacon"
	random_effects = FALSE
	/// Заряд расходуется до назначения роли или запуска самоуничтожения.
	var/used = FALSE
	/// Параллельные диалоги не могут расходовать один заряд.
	var/offering = FALSE
	/// Самоуничтожение отменяется при удалении устройства.
	var/selfdestruct_timer

/obj/machinery/xenoartifact/recruitment_beacon/Destroy()
	if(selfdestruct_timer)
		deltimer(selfdestruct_timer)
		selfdestruct_timer = null
	return ..()

/obj/machinery/xenoartifact/recruitment_beacon/update_icon_state()
	. = ..()
	icon_state = "syndbeacon"

/// Проверки подходят и для открытия диалога, и для подтверждения после ожидания.
/obj/machinery/xenoartifact/recruitment_beacon/proc/can_recruit(mob/living/carbon/human/user)
	if(!istype(user) || QDELETED(user) || !user.client)
		return FALSE
	var/original_ckey = user.ckey
	if(is_banned_from(original_ckey, list(ROLE_SYNDICATE, ROLE_TRAITOR)))
		return FALSE
	// Построение кеша запретов может ждать SQL; состояние проверяется после этого ожидания.
	return !QDELETED(src) && !used && isturf(loc) && !lab_owner?.resolve() \
		&& !QDELETED(user) && user.client && user.ckey == original_ckey && user.mind?.current == user \
		&& !length(user.mind.antag_datums) && user.can_perform_action(src, NEED_HANDS|FORBID_TELEKINESIS_REACH)

/obj/machinery/xenoartifact/recruitment_beacon/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return
	if(offering)
		balloon_alert(user, "канал недоступен!")
		return
	offering = TRUE
	if(!can_recruit(user))
		if(!QDELETED(src))
			offering = FALSE
			balloon_alert(user, "канал недоступен!")
		return
	var/datum/mind/original_mind = user.mind
	var/turf/origin = loc
	var/choice = tgui_alert(user, "Синдикат предлагает вам стать предателем станции. Подтверждение необратимо: маяк одноразовый, а вместо принятия заявки он может запустить самоуничтожение. Принять предложение?", name, list("Принять", "Отказаться"), timeout = 30 SECONDS)
	if(QDELETED(src))
		return
	if(choice != "Принять" || !can_recruit(user) || user.mind != original_mind || loc != origin)
		if(!QDELETED(src))
			offering = FALSE
		return
	used = TRUE
	offering = FALSE
	if(prob(50))
		to_chat(user, span_danger("Передача прервана. На маяке загорается предупреждение о самоуничтожении!"))
		message_admins("[ADMIN_LOOKUPFLW(user)] получил отказ зловещего маяка; запущено самоуничтожение в [ADMIN_VERBOSEJMP(src)].")
		log_game("[key_name(user)] активировал самоуничтожение археологического маяка в [loc_name(src)].")
		selfdestruct_timer = addtimer(CALLBACK(src, PROC_REF(selfdestruct)), rand(5, 20) SECONDS, TIMER_STOPPABLE)
		return
	var/datum/antagonist/traitor/recruit = new
	recruit.employer = pick(GLOB.syndicate_employers)
	if(!original_mind.add_antag_datum(recruit))
		message_admins("Не удалось назначить роль [ADMIN_LOOKUPFLW(user)] через археологический маяк в [ADMIN_VERBOSEJMP(src)]; заряд уже израсходован.")
		return
	message_admins("[ADMIN_LOOKUPFLW(user)] добровольно завербован зловещим археологическим маяком в [ADMIN_VERBOSEJMP(src)].")
	log_game("[key_name(user)] добровольно стал предателем через археологический маяк в [loc_name(src)].")

/// Сохраняет диапазон Sierra, но применяет штатные ограничения мощности взрыва этого билда.
/obj/machinery/xenoartifact/recruitment_beacon/proc/selfdestruct()
	selfdestruct_timer = null
	explosion(src, devastation_range = rand(5, 12), explosion_cause = src)
	if(!QDELETED(src))
		qdel(src)

/obj/machinery/xenoartifact/recruitment_beacon/analysis_description()
	return "Одноразовый вербовочный маяк Синдиката. Открывает канал для добровольного перехода на сторону Синдиката. Отказ оператора безопасен; отказ принимающей стороны может запустить самоуничтожение."
