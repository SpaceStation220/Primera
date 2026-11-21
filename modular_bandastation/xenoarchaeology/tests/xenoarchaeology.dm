/// Полный цикл проходит через обработчики инструментов, включая сканирование, измерение и очистку.
/datum/unit_test/xenoarchaeology_tools/Run()
	var/obj/item/xenoarch/strange_rock/rock = allocate(__IMPLIED_TYPE__)
	var/turf/reward_turf = get_turf(rock)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, reward_turf)
	var/obj/item/xenoarch/handheld_scanner/scanner = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(user.put_in_active_hand(scanner), "Не удалось взять сканер")
	rock.item_interaction(user, scanner)
	TEST_ASSERT(rock.scanned, "Сканирование не открыло параметры образца")
	user.dropItemToGround(scanner)
	var/obj/item/xenoarch/measuring_tape/tape = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(user.put_in_active_hand(tape), "Не удалось взять измеритель")
	rock.item_interaction(user, tape)
	TEST_ASSERT(rock.measured, "Измеритель не отметил глубину")
	TEST_ASSERT_EQUAL(rock.declent_ru(NOMINATIVE), "археологический образец", "Русское имя образца не загружено")
	user.dropItemToGround(tape)
	var/obj/item/xenoarch/hammer/cm5/hammer = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(user.put_in_active_hand(hammer), "Не удалось взять молоток")
	rock.item_depth = 37
	rock.dug_depth = 31
	rock.hidden_item = /obj/item/xenoarch/broken_item
	rock.item_interaction(user, hammer)
	TEST_ASSERT_EQUAL(rock.dug_depth, 36, "Молоток снял неверный слой")
	user.dropItemToGround(hammer)
	var/obj/item/xenoarch/brush/brush = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(user.put_in_active_hand(brush), "Не удалось взять кисточку")
	rock.item_interaction(user, brush)
	TEST_ASSERT_EQUAL(rock.dug_depth, 37, "Кисточка не достигла предмета")
	rock.item_interaction(user, brush)
	var/obj/item/xenoarch/broken_item/find = locate() in reward_turf
	TEST_ASSERT_NOTNULL(find, "Не извлечена осадочная оболочка")
	find.loot = /obj/item/flashlight
	find.item_interaction(user, brush)
	var/obj/item/flashlight/reward = locate() in reward_turf
	TEST_ASSERT_NOTNULL(reward, "Кисточка не очистила находку")
	qdel(reward)

/// Граница глубины требует отдельного движения кисточкой, а повторная выдача невозможна.
/datum/unit_test/xenoarchaeology_excavation/Run()
	var/obj/item/xenoarch/strange_rock/rock = allocate(__IMPLIED_TYPE__)
	var/turf/reward_turf = get_turf(rock)
	rock.item_depth = 20
	rock.dug_depth = 15
	rock.hidden_item = /obj/item/flashlight
	TEST_ASSERT(!rock.try_dig(0), "Нулевой удар изменяет образец")
	TEST_ASSERT(!rock.try_dig(-1), "Отрицательный удар изменяет образец")
	TEST_ASSERT(!rock.try_dig(0.5), "Дробная глубина разрешена")
	TEST_ASSERT_EQUAL(rock.dug_depth, 15, "Неверный удар изменил глубину")
	TEST_ASSERT(rock.try_dig(4), "Не удалось снять допустимый слой")
	TEST_ASSERT_EQUAL(rock.dug_depth, 19, "Удар не учёл уже снятую глубину")
	TEST_ASSERT(!rock.try_uncover(), "Кисточка извлекла предмет до нужной глубины")
	TEST_ASSERT_EQUAL(rock.dug_depth, 20, "Кисточка не сняла ровно 1 см")
	TEST_ASSERT(!(locate(/obj/item/flashlight) in reward_turf), "До извлечения уже появилась награда")
	TEST_ASSERT(rock.try_uncover(), "Предмет не извлечён на правильной глубине")
	TEST_ASSERT(!rock.try_uncover(), "Повторное извлечение выдало ещё одну награду")
	var/reward_count = 0
	for(var/obj/item/flashlight/created in reward_turf)
		if(!QDELETED(created))
			reward_count++
	TEST_ASSERT_EQUAL(reward_count, 1, "Из одного камня создано несколько наград")
	var/obj/item/flashlight/reward = locate() in reward_turf
	TEST_ASSERT_NOTNULL(reward, "Извлечение не создало награду")
	qdel(reward)

/// Чрезмерно глубокий удар уничтожает образец без награды.
/datum/unit_test/xenoarchaeology_overdig/Run()
	var/obj/item/xenoarch/strange_rock/rock = allocate(__IMPLIED_TYPE__)
	var/turf/reward_turf = get_turf(rock)
	rock.item_depth = 20
	rock.dug_depth = 19
	rock.hidden_item = /obj/item/flashlight
	TEST_ASSERT(!rock.try_dig(2), "Превышение глубины сочтено успешным")
	TEST_ASSERT(QDELETED(rock), "Превышение глубины не уничтожило образец")
	TEST_ASSERT(!(locate(/obj/item/flashlight) in reward_turf), "Разрушенный образец выдал награду")

/// Осадочная оболочка также выдаёт содержимое только один раз.
/datum/unit_test/xenoarchaeology_recovery/Run()
	var/obj/item/xenoarch/broken_item/find = allocate(__IMPLIED_TYPE__)
	var/turf/reward_turf = get_turf(find)
	find.loot = /obj/item/flashlight
	TEST_ASSERT(find.recover(), "Не удалось очистить осадочную оболочку")
	TEST_ASSERT(!find.recover(), "Повторная очистка разрешена после выдачи содержимого")
	var/obj/item/flashlight/reward = locate() in reward_turf
	TEST_ASSERT_NOTNULL(reward, "Очистка не создала содержимое")
	qdel(reward)

/// Два пользователя не могут начать действие над одним образцом, а отмена сохраняет штраф NovaSector.
/datum/unit_test/xenoarchaeology_interruption/Run()
	var/obj/item/xenoarch/strange_rock/rock = allocate(__IMPLIED_TYPE__)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent/slow, get_turf(rock))
	var/mob/living/carbon/human/other_user = allocate(/mob/living/carbon/human/consistent/slow, get_turf(rock))
	var/obj/item/xenoarch/hammer/hammer = allocate(__IMPLIED_TYPE__)
	var/obj/item/xenoarch/hammer/other_hammer = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(user.put_in_active_hand(hammer), "Первый пользователь не взял инструмент")
	TEST_ASSERT(other_user.put_in_active_hand(other_hammer), "Второй пользователь не взял инструмент")
	TEST_ASSERT(rock.can_work(user, hammer), "Корректная исходная ситуация не допускает работу")
	rock.dug_depth = 0
	rock.item_depth = 20
	INVOKE_ASYNC(rock, TYPE_PROC_REF(/obj/item/xenoarch/sample, work), user, hammer, 5 SECONDS)
	TEST_ASSERT(rock.working, "Действие не удерживает блокировку образца")
	TEST_ASSERT(!rock.work(other_user, other_hammer, 0 SECONDS), "Второй пользователь обошёл блокировку")
	user.dropItemToGround(hammer)
	sleep(1 SECONDS)
	TEST_ASSERT(!rock.working, "Отмена не освободила образец")
	TEST_ASSERT(rock.dug_depth >= 1 && rock.dug_depth <= 5, "Отмена не добавила 1–5 см")
	TEST_ASSERT(!rock.can_work(user, hammer), "Можно работать выпавшим из рук инструментом")
	TEST_ASSERT(user.put_in_active_hand(hammer), "Не удалось повторно взять инструмент")
	rock.forceMove(other_user)
	TEST_ASSERT(!rock.can_work(user, hammer), "Можно работать с образцом в чужом инвентаре")
	rock.forceMove(get_step(get_step(get_turf(user), EAST), EAST))
	TEST_ASSERT(!rock.can_work(user, hammer), "Можно работать с недоступным образцом")

/// Удаление цели во время ожидания не продолжает раскопки и не выдаёт содержимое.
/datum/unit_test/xenoarchaeology_target_deleted/Run()
	var/obj/item/xenoarch/strange_rock/rock = allocate(__IMPLIED_TYPE__)
	var/turf/reward_turf = get_turf(rock)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent/slow, reward_turf)
	var/obj/item/xenoarch/hammer/hammer = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(user.put_in_active_hand(hammer), "Не удалось взять инструмент")
	rock.hidden_item = /obj/item/flashlight
	INVOKE_ASYNC(rock, TYPE_PROC_REF(/obj/item/xenoarch/sample, work), user, hammer, 5 SECONDS)
	TEST_ASSERT(rock.working, "Не началось действие над образцом")
	qdel(rock)
	sleep(1 SECONDS)
	TEST_ASSERT(!(locate(/obj/item/flashlight) in reward_turf), "Удалённый образец выдал содержимое")

/// Добыча каждого варианта породы оставляет образец, не подменяя рудный тип.
/datum/unit_test/xenoarchaeology_minerals/Run()
	for(var/turf/closed/mineral/xenoarchaeology/rock_type as anything in typesof(/turf/closed/mineral/xenoarchaeology))
		var/turf/closed/mineral/xenoarchaeology/rock = run_loc_floor_bottom_left.ChangeTurf(rock_type, rock_type::baseturfs)
		TEST_ASSERT_NULL(rock.mineral_type, "Образец неправильно записан в поле рудного типа")
		rock.change_ore(/obj/item/stack/ore/iron)
		TEST_ASSERT_NULL(rock.mineral_type, "Рудная жила заменила археологическое включение")
		TEST_ASSERT_EQUAL(rock.mineral_amt, 1, "Рудная жила изменила число образцов")
		TEST_ASSERT_EQUAL(rock.scan_state, "rock_strange", "Рудная жила изменила результат сканирования")
		var/expected_ground = rock.turf_type
		rock.gets_drilled()
		var/turf/excavated = locate(rock.x, rock.y, rock.z)
		TEST_ASSERT(isopenturf(excavated), "Добыча не оставила открытый грунт")
		TEST_ASSERT_EQUAL(excavated.type, expected_ground, "Добыча изменила тип грунта породы")
		var/obj/item/xenoarch/strange_rock/sample = locate() in excavated
		TEST_ASSERT_NOTNULL(sample, "Добыча не оставила археологический образец")
		qdel(sample)

/datum/unit_test/xenoarchaeology_minerals/Destroy()
	run_loc_floor_bottom_left.ChangeTurf(/turf/open/indestructible)
	return ..()
