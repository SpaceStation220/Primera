/// Без overmap время рейса фиксировано для любых доступных z-level.
#define XENOARCH_DRONE_FLIGHT_TIME (30 SECONDS)
/// Посадка входит в общее время доставки; груз освобождается после спуска.
#define XENOARCH_DRONE_LANDING_TIME (3 SECONDS)

/** Приёмник одной доставки. Целеуказатель связывается с конкретной площадкой, без отдельной сети Sierra. */
/obj/machinery/xenoarch_drone_pad
	name = "archaeological transport drone pad"
	desc = "Посадочная площадка грузового дрона. ПКМ целеуказателем сохраняет приёмник; ЛКМ по другой площадке с грузом отправляет его туда. Нажатие рукой отзывает текущий рейс. Требуется научный доступ."
	icon = 'modular_bandastation/xenoarchaeology/icons/sierra/landing_pad.dmi'
	icon_state = "pad_base"
	density = FALSE
	anchored = TRUE
	layer = ABOVE_NORMAL_TURF_LAYER
	idle_power_usage = 50
	active_power_usage = 500
	obj_flags = CAN_BE_HIT | UNIQUE_RENAME
	interaction_flags_machine = parent_type::interaction_flags_machine | INTERACT_MACHINE_OFFLINE
	req_access = list(ACCESS_RESEARCH)
	circuit = /obj/item/circuitboard/machine/xenoarch/drone_pad
	/// Площадка владеет рейсом, а не самим грузом; удаление возвращает находку отправителю.
	var/obj/effect/xenoarch_transport_flight/current_flight

/obj/machinery/xenoarch_drone_pad/Destroy()
	QDEL_NULL(current_flight)
	return ..()

/** Закрытая панель, питание и крепление проверяются повторно при прибытии. */
/obj/machinery/xenoarch_drone_pad/proc/ready()
	return !QDELETED(src) && isturf(loc) && anchored && is_operational && !panel_open

/obj/machinery/xenoarch_drone_pad/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/xenoarch/drone_designator))
		return ..()
	if(!ready() || !allowed(user) || !user.is_holding(tool) || !user.can_perform_action(src, NEED_DEXTERITY|NEED_HANDS|FORBID_TELEKINESIS_REACH))
		balloon_alert(user, "приёмник недоступен!")
		return ITEM_INTERACT_BLOCKING
	var/obj/item/xenoarch/drone_designator/designator = tool
	var/obj/machinery/xenoarch_drone_pad/receiver = designator.destination_ref?.resolve()
	if(!receiver || text2num(LAZYACCESS(modifiers, RIGHT_CLICK)))
		designator.destination_ref = WEAKREF(src)
		balloon_alert(user, "приёмник сохранён")
		return ITEM_INTERACT_SUCCESS
	if(receiver == src)
		balloon_alert(user, "это площадка назначения!")
		return ITEM_INTERACT_BLOCKING
	var/obj/payload
	for(var/obj/candidate in loc)
		if(!valid_payload(candidate))
			continue
		if(payload)
			balloon_alert(user, "несколько грузов: укажите нужный!")
			return ITEM_INTERACT_BLOCKING
		payload = candidate
	if(!payload)
		balloon_alert(user, "нет подходящего груза!")
		return ITEM_INTERACT_BLOCKING
	return designator.interact_with_atom(payload, user, modifiers)

/obj/machinery/xenoarch_drone_pad/interact(mob/user)
	if(!allowed(user) || !user.can_perform_action(src, NEED_DEXTERITY|NEED_HANDS|FORBID_TELEKINESIS_REACH))
		return
	if(current_flight)
		QDEL_NULL(current_flight)
		balloon_alert(user, "рейс отозван")
	else
		balloon_alert(user, "синхронизируйте целеуказатель")

/obj/machinery/xenoarch_drone_pad/on_set_is_operational(old_value)
	. = ..()
	if(!is_operational)
		QDEL_NULL(current_flight)
	update_appearance()

/obj/machinery/xenoarch_drone_pad/on_set_panel_open(old_value)
	. = ..()
	if(panel_open)
		QDEL_NULL(current_flight)

/obj/machinery/xenoarch_drone_pad/screwdriver_act(mob/living/user, obj/item/tool)
	return default_deconstruction_screwdriver(user, tool)

/obj/machinery/xenoarch_drone_pad/crowbar_act(mob/living/user, obj/item/tool)
	return default_deconstruction_crowbar(user, tool)

/obj/machinery/xenoarch_drone_pad/wrench_act(mob/living/user, obj/item/tool)
	. = default_unfasten_wrench(user, tool)
	if(!anchored)
		QDEL_NULL(current_flight)

/obj/machinery/xenoarch_drone_pad/update_overlays()
	. = ..()
	if(panel_open)
		. += mutable_appearance(icon, "pad_maintenance")
	else if(ready())
		. += mutable_appearance(icon, current_flight ? "pad_incoming" : "pad_waiting")

/obj/machinery/xenoarch_drone_pad/examine(mob/user)
	. = ..()
	. += span_notice("Назовите площадку ручкой. ПКМ целеуказателем сохраняет её как приёмник; ЛКМ по другой площадке отправляет стоящий на ней груз. Первый ЛКМ непривязанным указателем также сохраняет приёмник.")
	if(current_flight)
		. += span_notice("Дрон прибудет через [DisplayTimeText(max(0, current_flight.arrival_time - world.time))]. Нажмите рукой для возврата груза.")

/** Ручной вызов дрона для находок. Повторная проверка после наведения исключает отправку чужого груза. */
/obj/item/xenoarch/drone_designator
	name = "archaeological drone designator"
	desc = "Целеуказатель транспортного дрона. Сохраните приёмную площадку ПКМ, затем примените ЛКМ к находке, закрытому аномальному контейнеру или другой площадке с грузом. В помещении нужна отдельная площадка погрузки."
	icon = 'modular_bandastation/xenoarchaeology/icons/sierra/drone_control.dmi'
	icon_state = "pad_designator"
	inhand_icon_state = "electronic"
	worn_icon_state = "electronic"
	lefthand_file = 'icons/mob/inhands/items/devices_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items/devices_righthand.dmi'
	w_class = WEIGHT_CLASS_SMALL
	slot_flags = ITEM_SLOT_BELT
	/// Синхронизация не удерживает удалённый приёмник.
	var/datum/weakref/destination_ref
	/// Один целеуказатель не ведёт два параллельных наведения.
	var/busy = FALSE

/obj/item/xenoarch/drone_designator/Destroy()
	destination_ref = null
	return ..()

/obj/item/xenoarch/drone_designator/examine(mob/user)
	. = ..()
	var/obj/machinery/xenoarch_drone_pad/pad = destination_ref?.resolve()
	. += span_notice(pad ? "Приёмник: [pad.declent_ru(NOMINATIVE)], [get_area(pad)]." : "Приёмник не привязан или утрачен.")

/** Без людей, пассажиров, произвольных ящиков и обхода запрета перемещения во вложенных предметах. */
/obj/machinery/xenoarch_drone_pad/proc/valid_payload(obj/target)
	if(QDELETED(target) || target.anchored)
		return FALSE
	if(istype(target, /obj/machinery/xenoarch_container))
		var/obj/machinery/xenoarch_container/container = target
		var/obj/item/stock_parts/power_store/cell/cell = container.get_cell()
		if(container.state_open || !container.occupant || container.panel_open || !cell?.charge)
			return FALSE
	else
		var/datum/component/xenoarch_catalogue_identity/identity = target.GetComponent(/datum/component/xenoarch_catalogue_identity)
		if(!istype(target, /obj/machinery/xenoartifact) && !identity?.excavation_id)
			return FALSE
		if(istype(target, /obj/machinery/xenoartifact))
			var/obj/machinery/xenoartifact/artifact = target
			if(artifact.lab_owner?.resolve())
				return FALSE
	for(var/atom/movable/content as anything in target.get_all_contents())
		if(isliving(content) || content.has_buckled_mobs() || HAS_TRAIT(content, TRAIT_NO_TELEPORT))
			return FALSE
	return TRUE

/** Причина отказа одна для наведения и повторной проверки после него; null означает доступную погрузку. */
/obj/item/xenoarch/drone_designator/proc/get_dispatch_error(obj/target, mob/living/user, obj/machinery/xenoarch_drone_pad/receiver)
	if(QDELETED(src) || QDELETED(user) || !user.is_holding(src) || !user.can_perform_action(target, NEED_DEXTERITY|NEED_HANDS|FORBID_TELEKINESIS_REACH))
		return "груз недоступен!"
	if(!receiver || destination_ref?.resolve() != receiver)
		return "сначала сохраните приёмник!"
	if(!receiver.ready())
		return "проверьте питание и крепление приёмника!"
	if(receiver.current_flight)
		return "приёмник ожидает другой рейс!"
	if(!receiver.allowed(user))
		return "нет научного доступа!"
	if(!isturf(target?.loc))
		return "поставьте груз на пол!"
	if(target.loc == receiver.loc)
		return "груз уже на площадке назначения!"
	if(target.anchored)
		return "открепите груз!"
	if(!receiver.valid_payload(target))
		return "недопустимый груз или открытый контейнер!"
	var/area/source_area = get_area(target)
	if(!source_area.outdoors)
		var/obj/machinery/xenoarch_drone_pad/loader = locate() in target.loc
		if(!loader)
			return "поставьте груз на площадку погрузки!"
		if(!loader.ready() || loader.current_flight)
			return "площадка погрузки недоступна!"
		if(!loader.allowed(user))
			return "нет доступа к площадке погрузки!"
	var/turf/landing_turf = get_turf(receiver)
	if(landing_turf.is_blocked_turf())
		return "площадка назначения занята!"
	if(!check_teleport_valid(target, receiver, TELEPORT_CHANNEL_QUANTUM))
		return "в этой области доставка запрещена!"
	return null

/** Помещение требует площадки погрузки; свободная поверхность разрешена только снаружи. */
/obj/item/xenoarch/drone_designator/proc/can_dispatch(obj/target, mob/living/user, obj/machinery/xenoarch_drone_pad/receiver)
	return isnull(get_dispatch_error(target, user, receiver))

/obj/item/xenoarch/drone_designator/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!isobj(interacting_with) || istype(interacting_with, /obj/machinery/xenoarch_drone_pad))
		return ..()
	var/obj/target = interacting_with
	var/obj/machinery/xenoarch_drone_pad/receiver = destination_ref?.resolve()
	var/dispatch_error = busy ? "дождитесь наведения!" : get_dispatch_error(target, user, receiver)
	if(dispatch_error)
		balloon_alert(user, dispatch_error)
		return ITEM_INTERACT_BLOCKING
	busy = TRUE
	var/turf/origin = get_turf(target)
	balloon_alert(user, "наводим дрон...")
	var/success = do_after(user, 2 SECONDS, target = target)
	if(QDELETED(src))
		return ITEM_INTERACT_BLOCKING
	busy = FALSE
	if(!success || QDELETED(target) || target.loc != origin)
		return ITEM_INTERACT_BLOCKING
	dispatch_error = get_dispatch_error(target, user, receiver)
	if(dispatch_error)
		balloon_alert(user, dispatch_error)
		return ITEM_INTERACT_BLOCKING
	var/obj/effect/xenoarch_transport_flight/flight = new(origin, receiver, target)
	if(QDELETED(flight))
		return ITEM_INTERACT_BLOCKING
	log_game("[key_name(user)] отправляет [target] транспортным дроном из [loc_name(origin)] в [loc_name(receiver)].")
	balloon_alert(user, "дрон забрал груз: [DisplayTimeText(XENOARCH_DRONE_FLIGHT_TIME)]")
	return ITEM_INTERACT_SUCCESS

/** Груз остаётся во владельце на исходной клетке: авария не оставляет его в nullspace. */
/obj/effect/xenoarch_transport_flight
	name = "транспортный дрон"
	icon = 'modular_bandastation/xenoarchaeology/icons/sierra/landing_pad.dmi'
	icon_state = "pad_drone"
	anchored = TRUE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	layer = ABOVE_MOB_LAYER
	/// Груз не удаляется вместе с рейсом.
	var/obj/payload
	/// Приёмник владеет рейсом, обратная ссылка слабая.
	var/datum/weakref/receiver_ref
	/// Смещение приёмника во время полёта отменяет доставку.
	var/turf/destination
	/// Время для осмотра площадки и штатного таймера.
	var/arrival_time
	/// Отменяемый таймер принадлежит рейсу.
	var/flight_timer
	/// Визуальный дрон со снимком груза; не удерживаем временный flick_visual после его удаления.
	var/datum/weakref/landing_visual_ref
	/// Выгрузка сама вызывает Exited; это не аварийное извлечение.
	var/unloading = FALSE

/obj/effect/xenoarch_transport_flight/Initialize(mapload, obj/machinery/xenoarch_drone_pad/receiver, obj/target)
	. = ..()
	if(QDELETED(receiver) || QDELETED(target))
		return INITIALIZE_HINT_QDEL
	receiver_ref = WEAKREF(receiver)
	destination = get_turf(receiver)
	payload = target
	receiver.current_flight = src
	RegisterSignal(payload, COMSIG_QDELETING, PROC_REF(on_payload_deleted))
	var/mutable_appearance/cargo_appearance = new /mutable_appearance(payload)
	cargo_appearance.layer = FLOAT_LAYER
	cargo_appearance.plane = FLOAT_PLANE
	underlays += cargo_appearance
	payload.forceMove(src)
	if(QDELETED(src) || QDELETED(payload) || payload.loc != src)
		return INITIALIZE_HINT_QDEL
	arrival_time = world.time + XENOARCH_DRONE_FLIGHT_TIME
	flight_timer = addtimer(CALLBACK(src, PROC_REF(deliver)), XENOARCH_DRONE_FLIGHT_TIME - XENOARCH_DRONE_LANDING_TIME, TIMER_STOPPABLE)
	pixel_z = 96
	alpha = 0
	animate(src, alpha = 255, pixel_z = 0, time = 2 SECONDS)
	animate(alpha = 0, pixel_z = 96, time = 3 SECONDS)
	receiver.update_use_power(ACTIVE_POWER_USE)
	receiver.update_appearance()

/obj/effect/xenoarch_transport_flight/Destroy()
	if(flight_timer)
		deltimer(flight_timer)
		flight_timer = null
	var/atom/movable/flick_visual/landing_visual = landing_visual_ref?.resolve()
	if(landing_visual)
		qdel(landing_visual)
	landing_visual_ref = null
	if(payload)
		UnregisterSignal(payload, COMSIG_QDELETING)
	payload = null
	var/obj/machinery/xenoarch_drone_pad/receiver = receiver_ref?.resolve()
	if(receiver?.current_flight == src)
		receiver.current_flight = null
		receiver.update_use_power(IDLE_POWER_USE)
		receiver.update_appearance()
	receiver_ref = null
	destination = null
	underlays.Cut()
	for(var/atom/movable/content as anything in contents)
		content.forceMove(get_turf(src))
	return ..()

/obj/effect/xenoarch_transport_flight/Exited(atom/movable/gone, direction)
	. = ..()
	if(gone == payload && !unloading)
		qdel(src)

/obj/effect/xenoarch_transport_flight/proc/on_payload_deleted(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/** Проверки общие для начала посадки и выгрузки после её анимации. */
/obj/effect/xenoarch_transport_flight/proc/can_land(obj/machinery/xenoarch_drone_pad/receiver)
	return receiver?.ready() && receiver.current_flight == src && get_turf(receiver) == destination \
		&& !QDELETED(payload) && payload.loc == src && receiver.valid_payload(payload) \
		&& !destination.is_blocked_turf() && check_teleport_valid(payload, receiver, TELEPORT_CHANNEL_QUANTUM)

/** До касания площадки доступно только изображение груза, реальный объект остаётся в рейсе. */
/obj/effect/xenoarch_transport_flight/proc/deliver()
	if(landing_visual_ref)
		return
	flight_timer = null
	var/obj/machinery/xenoarch_drone_pad/receiver = receiver_ref?.resolve()
	if(!can_land(receiver))
		qdel(src)
		return
	var/atom/movable/flick_visual/drone = receiver.flick_overlay_view(mutable_appearance(icon, "pad_drone", ABOVE_MOB_LAYER), 5 SECONDS)
	drone.underlays += underlays
	drone.pixel_z = 96
	landing_visual_ref = WEAKREF(drone)
	animate(drone, pixel_z = 0, time = XENOARCH_DRONE_LANDING_TIME)
	flight_timer = addtimer(CALLBACK(src, PROC_REF(finish_delivery)), XENOARCH_DRONE_LANDING_TIME, TIMER_STOPPABLE)

/** После асинхронного спуска заново проверяем посадку и только затем передаём настоящий груз. */
/obj/effect/xenoarch_transport_flight/proc/finish_delivery()
	flight_timer = null
	var/obj/machinery/xenoarch_drone_pad/receiver = receiver_ref?.resolve()
	if(can_land(receiver))
		unloading = TRUE
		var/delivered = do_teleport(payload, receiver, no_effects = TRUE, channel = TELEPORT_CHANNEL_QUANTUM)
		if(QDELETED(src))
			return
		if(delivered)
			var/atom/movable/flick_visual/drone = landing_visual_ref?.resolve()
			if(drone)
				drone.underlays.Cut()
				animate(drone, alpha = 0, pixel_z = 96, time = 2 SECONDS)
			landing_visual_ref = null
			receiver.balloon_alert_to_viewers("груз доставлен")
	qdel(src)

/** Плата использует местную сборку машин и исходный набор четырёх сканеров с блюспейс-кристаллом Sierra. */
/obj/item/circuitboard/machine/xenoarch/drone_pad
	name = "archaeological transport drone pad"
	build_path = /obj/machinery/xenoarch_drone_pad
	req_components = list(/datum/stock_part/scanning_module = 4, /obj/item/stack/ore/bluespace_crystal = 1)
	def_components = list(/obj/item/stack/ore/bluespace_crystal = /obj/item/stack/ore/bluespace_crystal/artificial)

#undef XENOARCH_DRONE_FLIGHT_TIME
#undef XENOARCH_DRONE_LANDING_TIME
