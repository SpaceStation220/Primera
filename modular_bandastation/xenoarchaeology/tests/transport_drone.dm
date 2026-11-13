/** Реальные раскопка и анализ из существующего fixture, без подделки происхождения. */
/datum/unit_test/xenoarch_drone_fixture
	parent_type = /datum/unit_test/xenoarch_catalogue_fixture
	abstract_type = /datum/unit_test/xenoarch_drone_fixture
	/// Оператор с настоящей картой научного доступа.
	var/mob/living/carbon/human/user
	/// Приёмник одной доставки.
	var/obj/machinery/xenoarch_drone_pad/receiver
	/// Отдельная внутренняя площадка погрузки.
	var/obj/machinery/xenoarch_drone_pad/loader
	/// Синхронизация и отправка идут через настоящие взаимодействия.
	var/obj/item/xenoarch/drone_designator/designator
	/// Сохраняемое во время рейса подавление проверяется на действующем контейнере.
	var/obj/machinery/xenoarch_container/container
	/// Одна внешняя клетка временно получает питание тестовой области, сохраняя другой z-level.
	var/turf/cross_level_turf
	/// Исходная область возвращается даже после раннего провала проверки.
	var/area/cross_level_original_area

/** Питание тестовой области не зависит от APC; отказ задаётся штатным setter. */
/datum/unit_test/xenoarch_drone_fixture/proc/prepare_transport(user_type = /mob/living/carbon/human/consistent)
	prepare_find()
	lab.start_scan()
	lab.process(lab.scan_duration)
	user = allocate(user_type)
	var/obj/item/clothing/under/rank/rnd/scientist/uniform = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(user.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING), "Не надета форма для крепления ID")
	var/obj/item/card/id/advanced/card = allocate(__IMPLIED_TYPE__)
	card.access = list(ACCESS_RESEARCH)
	TEST_ASSERT(user.equip_to_slot_if_possible(card, ITEM_SLOT_ID), "Не надета карта научного доступа")
	loader = allocate(__IMPLIED_TYPE__)
	receiver = allocate(__IMPLIED_TYPE__, get_step(get_step(loader, EAST), EAST))
	loader.set_is_operational(TRUE)
	receiver.set_is_operational(TRUE)
	designator = allocate(__IMPLIED_TYPE__)
	user.put_in_active_hand(designator)
	user.forceMove(get_turf(receiver))
	click_wrapper(user, receiver, list(RIGHT_CLICK = "1"))
	TEST_ASSERT_EQUAL(designator.destination_ref?.resolve(), receiver, "Не привязан доступный приёмник")
	user.forceMove(get_turf(loader))
	var/obj/machinery/xenoartifact/artifact = target
	artifact.random_effects = TRUE
	container = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(container.close_machine(target), "Контейнер не принял раскопанную находку")

/datum/unit_test/xenoarch_drone_fixture/Destroy()
	if(cross_level_turf && cross_level_original_area)
		cross_level_turf.change_area(get_area(cross_level_turf), cross_level_original_area)
	cross_level_turf = null
	cross_level_original_area = null
	user = null
	receiver = null
	loader = null
	designator = null
	container = null
	return ..()

/** Настоящий таймер доставляет контейнер на другой z-level, сохраняя сам объект, паспорт и подавление. */
/datum/unit_test/xenoarchaeology_drone_delivery
	parent_type = /datum/unit_test/xenoarch_drone_fixture

/datum/unit_test/xenoarchaeology_drone_delivery/Run()
	prepare_transport()
	var/turf/destination_turf
	for(var/level in 1 to world.maxz)
		var/turf/candidate = locate(50, 50, level)
		if(level != loader.z && candidate && !candidate.is_transition_turf() && !candidate.is_blocked_turf() && check_teleport_valid(container, candidate, TELEPORT_CHANNEL_QUANTUM))
			destination_turf = candidate
			break
	TEST_ASSERT_NOTNULL(destination_turf, "Нет доступной клетки на другом z-level для доставки")
	cross_level_turf = destination_turf
	cross_level_original_area = get_area(destination_turf)
	destination_turf.change_area(cross_level_original_area, get_area(loader))
	receiver.forceMove(destination_turf)
	var/obj/item/stock_parts/power_store/cell/cell = container.get_cell()
	var/charge_before = cell.charge
	var/datum/component/xenoarch_catalogue_identity/identity = target.GetComponent(/datum/component/xenoarch_catalogue_identity)
	var/id_before = identity.catalogue_id
	var/datum/xenoarch_catalogue_entry/entry_before = GLOB.xenoarch_catalogue[id_before]
	TEST_ASSERT_EQUAL(designator.interact_with_atom(container, user, list()), ITEM_INTERACT_SUCCESS, "Не отправлен контейнер с площадки внутри помещения")
	var/obj/effect/xenoarch_transport_flight/flight = receiver.current_flight
	TEST_ASSERT_NOTNULL(flight, "Нет рейса после принятой отправки")
	TEST_ASSERT_EQUAL(container.loc, flight, "Груз не принадлежит рейсу")
	TEST_ASSERT_EQUAL(designator.interact_with_atom(container, user, list()), ITEM_INTERACT_BLOCKING, "Повторный запрос забрал летящий груз")
	var/deadline = world.time + 35 SECONDS
	UNTIL(QDELETED(flight) || world.time >= deadline)
	TEST_ASSERT(QDELETED(flight), "Рейс не завершился штатным таймером")
	TEST_ASSERT_EQUAL(container.loc, destination_turf, "Контейнер не доставлен на другой z-level")
	TEST_ASSERT_EQUAL(target.loc, container, "Потеряно содержимое контейнера")
	var/obj/machinery/xenoartifact/artifact = target
	TEST_ASSERT(artifact.containment_suppressed, "Доставка сняла подавление артефакта")
	TEST_ASSERT(cell.charge < charge_before, "Контейнер перестал расходовать батарею во время полёта")
	TEST_ASSERT_EQUAL(identity.catalogue_id, id_before, "Перевозка изменила метку находки")
	TEST_ASSERT_EQUAL(GLOB.xenoarch_catalogue[id_before], entry_before, "Доставка заменила паспорт")
	TEST_ASSERT_NULL(receiver.current_flight, "Приёмник не освободился после доставки")

/** Отзыв, отключение, утрата приёмника и разряд камеры возвращают тот же груз без удаления находки. */
/datum/unit_test/xenoarchaeology_drone_recovery
	parent_type = /datum/unit_test/xenoarch_drone_fixture

/datum/unit_test/xenoarchaeology_drone_recovery/Run()
	prepare_transport()
	var/turf/origin = get_turf(container)
	TEST_ASSERT_EQUAL(designator.interact_with_atom(container, user, list()), ITEM_INTERACT_SUCCESS, "Не начат рейс для проверки отключения")
	receiver.set_is_operational(FALSE)
	TEST_ASSERT_EQUAL(container.loc, origin, "Отключение приёмника потеряло груз")
	receiver.set_is_operational(TRUE)
	designator.interact_with_atom(container, user, list())
	user.forceMove(get_turf(receiver))
	receiver.interact(user)
	TEST_ASSERT_EQUAL(container.loc, origin, "Отзыв не вернул контейнер")
	user.forceMove(origin)
	designator.interact_with_atom(container, user, list())
	qdel(receiver)
	TEST_ASSERT_EQUAL(container.loc, origin, "Удаление площадки потеряло груз")
	TEST_ASSERT_EQUAL(target.loc, container, "Удаление площадки уничтожило артефакт")
	receiver = allocate(__IMPLIED_TYPE__, get_step(get_step(loader, EAST), EAST))
	receiver.set_is_operational(TRUE)
	user.forceMove(get_turf(receiver))
	receiver.item_interaction(user, designator)
	user.forceMove(origin)
	TEST_ASSERT_EQUAL(designator.interact_with_atom(container, user, list()), ITEM_INTERACT_SUCCESS, "Не начат повторный рейс")
	var/obj/item/stock_parts/power_store/cell/cell = container.get_cell()
	cell.charge = 0
	container.process(1)
	TEST_ASSERT(!QDELETED(target) && target.loc == origin, "Разряд контейнера в пути потерял находку")
	qdel(receiver)
	TEST_ASSERT_EQUAL(container.loc, origin, "Возврат разряженного контейнера потерял его")
	cell.charge = cell.maxcharge
	TEST_ASSERT(container.close_machine(target), "Контейнер не закрылся после замены заряда")
	receiver = allocate(__IMPLIED_TYPE__, get_step(get_step(loader, EAST), EAST))
	receiver.set_is_operational(TRUE)
	user.forceMove(get_turf(receiver))
	receiver.item_interaction(user, designator)
	user.forceMove(origin)
	TEST_ASSERT_EQUAL(designator.interact_with_atom(container, user, list()), ITEM_INTERACT_SUCCESS, "Не начат рейс для проверки занятой посадки")
	var/obj/structure/closet/blocker = allocate(__IMPLIED_TYPE__, get_turf(receiver))
	blocker.density = TRUE
	var/obj/effect/xenoarch_transport_flight/flight = receiver.current_flight
	var/deadline = world.time + 35 SECONDS
	UNTIL(QDELETED(flight) || world.time >= deadline)
	TEST_ASSERT(QDELETED(flight), "Недопустимая доставка не завершила рейс")
	TEST_ASSERT_EQUAL(container.loc, origin, "Контейнер отправлен на занятую площадку")
	TEST_ASSERT_EQUAL(target.loc, container, "После отказа доставки утерян артефакт")
	qdel(blocker)
	TEST_ASSERT_EQUAL(designator.interact_with_atom(container, user, list()), ITEM_INTERACT_SUCCESS, "Приёмник не восстановился после отказа посадки")
	qdel(container)
	TEST_ASSERT_NULL(receiver.current_flight, "Удаление груза не освободило приёмник")
	TEST_ASSERT(!QDELETED(target) && target.loc == origin, "Разрушение контейнера в рейсе потеряло его содержимое")

/** Наведение прерывается настоящим do_after; смена руки, груза и приёмника не продолжают отправку. */
/datum/unit_test/xenoarchaeology_drone_interruption
	parent_type = /datum/unit_test/xenoarch_drone_fixture

/datum/unit_test/xenoarchaeology_drone_interruption/Run()
	prepare_transport(/mob/living/carbon/human/consistent/slow)
	var/turf/origin = get_turf(container)
	INVOKE_ASYNC(designator, TYPE_PROC_REF(/obj/item, interact_with_atom), container, user, list())
	TEST_ASSERT(designator.busy, "Не началось наведение")
	user.dropItemToGround(designator)
	var/deadline = world.time + 4 SECONDS
	UNTIL(!designator.busy || world.time >= deadline)
	TEST_ASSERT_NULL(receiver.current_flight, "Выпавший целеуказатель отправил груз")
	TEST_ASSERT_EQUAL(container.loc, origin, "Прерванное наведение переместило груз")
	user.put_in_active_hand(designator)
	INVOKE_ASYNC(designator, TYPE_PROC_REF(/obj/item, interact_with_atom), container, user, list())
	container.forceMove(get_step(origin, NORTH))
	deadline = world.time + 4 SECONDS
	UNTIL(!designator.busy || world.time >= deadline)
	TEST_ASSERT_NULL(receiver.current_flight, "Перемещённый во время наведения груз отправлен")
	container.forceMove(origin)
	INVOKE_ASYNC(designator, TYPE_PROC_REF(/obj/item, interact_with_atom), container, user, list())
	var/obj/item/card/id/card = user.get_idcard()
	card.access = list()
	deadline = world.time + 4 SECONDS
	UNTIL(!designator.busy || world.time >= deadline)
	TEST_ASSERT_NULL(receiver.current_flight, "Потеря научного доступа не проверена после наведения")
	card.access = list(ACCESS_RESEARCH)
	INVOKE_ASYNC(designator, TYPE_PROC_REF(/obj/item, interact_with_atom), container, user, list())
	designator.destination_ref = null
	deadline = world.time + 4 SECONDS
	UNTIL(!designator.busy || world.time >= deadline)
	TEST_ASSERT_NULL(receiver.current_flight, "Сменившаяся привязка не проверена после наведения")

/** Ограничения проверяются сервером, включая вложенных глубже четырёх уровней пассажиров. */
/datum/unit_test/xenoarchaeology_drone_boundaries
	parent_type = /datum/unit_test/xenoarch_drone_fixture

/datum/unit_test/xenoarchaeology_drone_boundaries/Run()
	prepare_transport()
	var/obj/item/storage/box/box = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(!receiver.valid_payload(box), "Дрон принимает произвольные ящики")
	TEST_ASSERT(receiver.valid_payload(container), "Закрытый контейнер не разрешён")
	container.anchored = TRUE
	TEST_ASSERT(!receiver.valid_payload(container), "Дрон поднимает закреплённый груз")
	container.anchored = FALSE
	var/atom/nested = container
	for(var/depth in 1 to 5)
		var/obj/item/storage/box/inner = allocate(__IMPLIED_TYPE__, nested)
		nested = inner
	var/mob/living/carbon/human/passenger = allocate(/mob/living/carbon/human/consistent, nested)
	TEST_ASSERT(!receiver.valid_payload(container), "Вложенный пассажир обошёл проверку глубины")
	qdel(passenger)
	ADD_TRAIT(target, TRAIT_NO_TELEPORT, TRAIT_GENERIC)
	TEST_ASSERT(!receiver.valid_payload(container), "Контейнер обошёл запрет телепорта вложенной находки")
	REMOVE_TRAIT(target, TRAIT_NO_TELEPORT, TRAIT_GENERIC)
	var/area/source_area = get_area(container)
	TEST_ASSERT(!source_area.outdoors, "Fixture должен начинать погрузку внутри помещения")
	qdel(loader)
	TEST_ASSERT(!designator.can_dispatch(container, user, receiver), "Погрузка внутри без площадки разрешена")
	source_area.outdoors = TRUE
	var/outside_allowed = designator.can_dispatch(container, user, receiver)
	source_area.outdoors = FALSE
	TEST_ASSERT(outside_allowed, "Погрузка снаружи требует дополнительной площадки")
	var/original_flags = source_area.area_flags
	source_area.outdoors = TRUE
	source_area.area_flags |= NOTELEPORT
	var/teleport_blocked = !designator.can_dispatch(container, user, receiver)
	source_area.area_flags = original_flags
	source_area.outdoors = FALSE
	TEST_ASSERT(teleport_blocked, "Целеуказатель обошёл NOTELEPORT")

/** ЛКМ по погрузочной площадке отправляет груз и не заменяет приёмник; перепривязка требует ПКМ. */
/datum/unit_test/xenoarchaeology_drone_pad_dispatch
	parent_type = /datum/unit_test/xenoarch_drone_fixture

/datum/unit_test/xenoarchaeology_drone_pad_dispatch/Run()
	prepare_transport()
	click_wrapper(user, loader)
	TEST_ASSERT_NOTNULL(receiver.current_flight, "ЛКМ по площадке не отправил контейнер")
	TEST_ASSERT_EQUAL(designator.destination_ref.resolve(), receiver, "Погрузка перепривязала указатель к отправителю")
	TEST_ASSERT_EQUAL(container.loc, receiver.current_flight, "Площадка не передала груз рейсу")
	qdel(receiver.current_flight)
	var/obj/machinery/xenoartifact/test_fixture/second = allocate(__IMPLIED_TYPE__, get_turf(loader))
	click_wrapper(user, loader)
	TEST_ASSERT_NULL(receiver.current_flight, "Неоднозначный груз отправлен")
	qdel(second)
	container.forceMove(get_step(loader, NORTH))
	click_wrapper(user, loader)
	TEST_ASSERT_EQUAL(designator.destination_ref.resolve(), receiver, "Пустая площадка заменила сохранённый приёмник")
	click_wrapper(user, loader, list(RIGHT_CLICK = "1"))
	TEST_ASSERT_EQUAL(designator.destination_ref.resolve(), loader, "Не сохранён явно выбранный приёмник")

/** При посадке виден снимок груза; настоящий объект освобождается только после таймера спуска. */
/datum/unit_test/xenoarchaeology_drone_landing
	parent_type = /datum/unit_test/xenoarch_drone_fixture

/datum/unit_test/xenoarchaeology_drone_landing/Run()
	prepare_transport()
	TEST_ASSERT_EQUAL(designator.interact_with_atom(container, user, list()), ITEM_INTERACT_SUCCESS, "Не начат рейс для посадки")
	var/obj/effect/xenoarch_transport_flight/flight = receiver.current_flight
	// Пропускаем крейсерский участок; посадка и выгрузка используют настоящий таймер.
	deltimer(flight.flight_timer)
	flight.deliver()
	var/atom/movable/flick_visual/visual = flight.landing_visual_ref?.resolve()
	TEST_ASSERT_NOTNULL(visual, "Нет посадочной анимации")
	TEST_ASSERT_EQUAL(length(visual.underlays), length(flight.underlays), "Дрон спускается без изображения груза")
	TEST_ASSERT(length(visual.underlays) > 0, "Снимок груза пуст")
	TEST_ASSERT_EQUAL(container.loc, flight, "Груз выгружен до завершения спуска")
	TEST_ASSERT(get_turf(container) != get_turf(receiver), "Настоящий груз появился на приёмнике во время спуска")
	TEST_ASSERT_EQUAL(receiver.current_flight, flight, "Приёмник освободился до выгрузки")
	var/deadline = world.time + 5 SECONDS
	UNTIL(QDELETED(flight) || world.time >= deadline)
	TEST_ASSERT(QDELETED(flight), "Посадка не завершилась таймером")
	TEST_ASSERT_EQUAL(container.loc, get_turf(receiver), "После спуска груз не выгружен")
	TEST_ASSERT_EQUAL(target.loc, container, "Посадка потеряла содержимое камеры")
	TEST_ASSERT(QDELETED(visual) || !length(visual.underlays), "Улетающий дрон сохранил копию выгруженного груза")
	TEST_ASSERT_NULL(receiver.current_flight, "Завершённая посадка удерживает приёмник")

/** Сбой во время спуска удаляет визуальный груз и возвращает настоящий отправителю. */
/datum/unit_test/xenoarchaeology_drone_landing_cancel
	parent_type = /datum/unit_test/xenoarch_drone_fixture

/datum/unit_test/xenoarchaeology_drone_landing_cancel/Run()
	prepare_transport()
	var/turf/origin = get_turf(container)
	for(var/failure in list("power", "blocked", "teleport"))
		TEST_ASSERT_EQUAL(designator.interact_with_atom(container, user, list()), ITEM_INTERACT_SUCCESS, "Не начат рейс для сбоя [failure]")
		var/obj/effect/xenoarch_transport_flight/flight = receiver.current_flight
		deltimer(flight.flight_timer)
		flight.deliver()
		var/atom/movable/flick_visual/visual = flight.landing_visual_ref?.resolve()
		TEST_ASSERT_NOTNULL(visual, "Не начался спуск перед сбоем [failure]")
		var/obj/structure/closet/blocker
		switch(failure)
			if("power")
				receiver.set_is_operational(FALSE)
			if("blocked")
				blocker = allocate(__IMPLIED_TYPE__, get_turf(receiver))
				blocker.density = TRUE
			if("teleport")
				ADD_TRAIT(container, TRAIT_NO_TELEPORT, REF(src))
		var/deadline = world.time + 5 SECONDS
		UNTIL(QDELETED(flight) || world.time >= deadline)
		TEST_ASSERT(QDELETED(flight), "Сбой [failure] не отменил посадку")
		TEST_ASSERT(QDELETED(visual), "После сбоя [failure] остался визуальный груз")
		TEST_ASSERT_EQUAL(container.loc, origin, "Сбой [failure] потерял груз")
		TEST_ASSERT_EQUAL(target.loc, container, "Сбой [failure] потерял содержимое камеры")
		TEST_ASSERT_NULL(receiver.current_flight, "Сбой [failure] удерживает приёмник")
		receiver.set_is_operational(TRUE)
		REMOVE_TRAIT(container, TRAIT_NO_TELEPORT, REF(src))
		if(blocker)
			qdel(blocker)
