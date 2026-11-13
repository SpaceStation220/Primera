#include "../code/artifact_defines.dm"

/// Минеральная клетка восстанавливается и после раннего провала проверки таймера бура.
/datum/unit_test/xenoarch_sierra_drill_fixture
	abstract_type = /datum/unit_test/xenoarch_sierra_drill_fixture
	/// Восстанавливаемая клетка породы.
	var/turf/rock
	/// Исходный тип клетки тестовой карты.
	var/original_turf_type
	/// Бур принадлежит allocate; ссылка нужна для отмены перед восстановлением карты.
	var/obj/machinery/xenoartifact/giant_drill/drill
	/// Оператор штатного включения и выключения.
	var/mob/living/carbon/human/operator

/datum/unit_test/xenoarch_sierra_drill_fixture/proc/prepare_drill()
	drill = allocate(__IMPLIED_TYPE__)
	operator = allocate(/mob/living/carbon/human/consistent)
	rock = get_step(drill, EAST)
	original_turf_type = rock.type
	rock = rock.ChangeTurf(/turf/closed/mineral/iron)
	drill.attack_hand(operator, list())
	drill.Move(rock)

/datum/unit_test/xenoarch_sierra_drill_fixture/Destroy()
	drill?.cancel_drilling()
	drill = null
	operator = null
	if(rock)
		rock.ChangeTurf(original_turf_type)
	rock = null
	return ..()

/// Настоящее столкновение запускает таймер, выдаёт руду и перемещает бур в новую клетку.
/datum/unit_test/xenoarchaeology_sierra_drill
	parent_type = /datum/unit_test/xenoarch_sierra_drill_fixture

/datum/unit_test/xenoarchaeology_sierra_drill/Run()
	prepare_drill()
	TEST_ASSERT_NOTNULL(drill.drill_timer, "Столкновение не запустило бур")
	var/deadline = world.time + 3 SECONDS
	UNTIL(!drill.drill_timer || world.time >= deadline)
	TEST_ASSERT(isopenturf(rock), "Бур не добыл минеральную породу")
	TEST_ASSERT_EQUAL(get_turf(drill), rock, "Бур не переместился после добычи")
	TEST_ASSERT(!drill.anchored, "Бур остался закреплён после цикла")
	var/obj/item/stack/ore/iron/ore = locate() in rock
	TEST_ASSERT_NOTNULL(ore, "Добыча бура потеряла штатную руду")
	allocated += ore

/// Выключение и принудительное перемещение отменяют реальный таймер до его штатного срока.
/datum/unit_test/xenoarchaeology_sierra_drill_cancel
	parent_type = /datum/unit_test/xenoarch_sierra_drill_fixture

/datum/unit_test/xenoarchaeology_sierra_drill_cancel/Run()
	prepare_drill()
	TEST_ASSERT_NOTNULL(drill.drill_timer, "Не начат цикл для отмены")
	drill.attack_hand(operator, list())
	TEST_ASSERT_NULL(drill.drill_timer, "Выключение не удалило таймер")
	var/deadline = world.time + 2 SECONDS
	UNTIL(world.time >= deadline)
	TEST_ASSERT(istype(rock, /turf/closed/mineral), "Выключенный бур добыл руду")
	drill.attack_hand(operator, list())
	drill.Move(rock)
	TEST_ASSERT_NOTNULL(drill.drill_timer, "Повторное включение не разрешило цикл")
	drill.forceMove(get_step(drill, NORTH))
	TEST_ASSERT_NULL(drill.drill_timer, "Перемещение не отменило цикл")
	deadline = world.time + 2 SECONDS
	UNTIL(world.time >= deadline)
	TEST_ASSERT(istype(rock, /turf/closed/mineral), "Перемещённый бур продолжил добычу")

/// Новые типы проходят настоящую раскопку, получают происхождение и анализируются общей лабораторией.
/datum/unit_test/xenoarchaeology_sierra_finds
	parent_type = /datum/unit_test/xenoarch_catalogue_fixture

/datum/unit_test/xenoarchaeology_sierra_finds/Run()
	for(var/find_type in list(/obj/machinery/xenoartifact/giant_drill, /obj/machinery/xenoartifact/recruitment_beacon, /obj/machinery/xenoartifact/cult_pylon))
		prepare_find(TRUE, find_type)
		TEST_ASSERT_NOTNULL(target, "Не извлечена находка [find_type]")
		TEST_ASSERT(target.icon_state in icon_states(target.icon), "Нет исходного спрайта [find_type]")
		if(istype(target, /obj/machinery/xenoartifact/giant_drill))
			var/obj/machinery/xenoartifact/giant_drill/drill = target
			drill.enabled = TRUE
			TEST_ASSERT(!lab.start_scan(), "Анализатор принял включённый бур")
			drill.enabled = FALSE
		TEST_ASSERT(lab.start_scan(), "Не начат анализ [find_type]")
		lab.process(lab.scan_duration)
		var/datum/component/xenoarch_catalogue_identity/identity = target.GetComponent(/datum/component/xenoarch_catalogue_identity)
		TEST_ASSERT_EQUAL(identity.excavation_id, source_id, "Потеряно происхождение [find_type]")
		TEST_ASSERT_NOTNULL(GLOB.xenoarch_catalogue[identity.catalogue_id], "Не создан паспорт [find_type]")
		var/obj/machinery/xenoarch_drone_pad/receiver = allocate(__IMPLIED_TYPE__)
		TEST_ASSERT(receiver.valid_payload(target), "Дрон не принимает извлечённый [find_type]")
		var/datum/xenoarch_catalogue_entry/entry = GLOB.xenoarch_catalogue[identity.catalogue_id]
		GLOB.xenoarch_catalogue -= identity.catalogue_id
		qdel(entry)
		GLOB.xenoarch_catalogue_next_id = original_counter
		qdel(target)
		qdel(pad)
		qdel(lab)

/// Пилон восстанавливает строитель, а обычное прикосновение человека не лечит конструкцию.
/datum/unit_test/xenoarchaeology_sierra_pylon/Run()
	var/obj/machinery/xenoartifact/cult_pylon/pylon = allocate(__IMPLIED_TYPE__)
	pylon.update_integrity(10)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	pylon.attack_hand(user, list())
	TEST_ASSERT_EQUAL(pylon.get_integrity(), 10, "Обычное прикосновение отремонтировало пилон")
	var/mob/living/basic/construct/artificer/builder = allocate(__IMPLIED_TYPE__)
	pylon.attack_basic_mob(builder, list())
	TEST_ASSERT_EQUAL(pylon.get_integrity(), 15, "Строитель не восстановил 5 прочности")
	pylon.attack_basic_mob(builder, list())
	TEST_ASSERT_EQUAL(pylon.get_integrity(), 20, "Повторный ремонт не восстановил пилон")
	pylon.attack_basic_mob(builder, list())
	TEST_ASSERT_EQUAL(pylon.get_integrity(), 20, "Ремонт превысил максимальную прочность")

/** Закрытая ёмкость не воздействует на находку; открытая наносит реальную дозу через reagent exposure. */
/datum/unit_test/xenoarchaeology_reagent_application/Run()
	var/obj/machinery/xenoartifact/test_fixture/artifact = allocate(__IMPLIED_TYPE__)
	artifact.first_effect = new /datum/xenoartifact_effect/heal(artifact)
	artifact.first_effect.trigger = XENO_TRIGGER_WATER
	artifact.first_effect.release_method = XENO_EFFECT_TOUCH
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/reagent_containers/cup/beaker/beaker = allocate(__IMPLIED_TYPE__)
	beaker.reagents.add_reagent(/datum/reagent/water, 40)
	user.put_in_active_hand(beaker)
	beaker.has_lid = TRUE
	click_wrapper(user, artifact)
	TEST_ASSERT(!artifact.first_effect.activated, "Закрытая ёмкость активировала химический триггер")
	TEST_ASSERT_EQUAL(beaker.reagents.total_volume, 40, "Закрытая ёмкость потеряла реагенты")
	beaker.has_lid = FALSE
	click_wrapper(user, artifact)
	TEST_ASSERT(artifact.first_effect.activated, "Реальное нанесение воды не активировало триггер")
	TEST_ASSERT_EQUAL(beaker.reagents.total_volume, 40 - beaker.amount_per_transfer_from_this, "Нанесённая доза не израсходована")

/// Предсказуемый носитель эффекта без случайного атмосферного триггера.
/obj/machinery/xenoartifact/test_fixture
	random_effects = FALSE
	resistance_flags = INDESTRUCTIBLE

/obj/machinery/xenoartifact/test_fixture/process(seconds_per_tick)
	return

/// У теста радара свой участок: он проверяет выдачу и конкуренцию, а не признаки шахтёрского z.
/obj/item/xenoarch/radar/test_fixture/valid_ground(turf/ground)
	return isopenturf(ground)

/datum/unit_test/xenoarchaeology_advanced/Run()
	var/obj/item/xenoarch/hammer/advanced/hammer = allocate(__IMPLIED_TYPE__)
	for(var/invalid in list(-1, 0, 1.5, 31, "30"))
		TEST_ASSERT(!hammer.set_depth(invalid), "Молоток принял недопустимую глубину [invalid]")
	TEST_ASSERT(hammer.set_depth(30), "Молоток не принял предельную глубину")
	TEST_ASSERT_EQUAL(hammer.dig_amount, 30, "Настройка глубины не сохранена")
	var/obj/item/xenoarch/strange_rock/rock = allocate(__IMPLIED_TYPE__)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent/slow)
	hammer.set_depth(1)
	user.put_in_active_hand(hammer)
	rock.dug_depth = 0
	rock.item_depth = 60
	INVOKE_ASYNC(rock, TYPE_PROC_REF(/atom, item_interaction), user, hammer)
	TEST_ASSERT(rock.working, "Не началась раскопка регулируемым молотком")
	hammer.set_depth(30)
	sleep(0.5 SECONDS)
	TEST_ASSERT_EQUAL(rock.dug_depth, 1, "Смена настройки во время удара изменила уже начатую раскопку")

/datum/unit_test/xenoarchaeology_machines/Run()
	var/obj/machinery/xenoarch/digger/digger = allocate(__IMPLIED_TYPE__)
	digger.set_is_operational(TRUE)
	var/obj/item/xenoarch/strange_rock/rock = allocate(__IMPLIED_TYPE__, digger)
	rock.hidden_item = /obj/item/flashlight
	digger.process(digger.process_duration / 2)
	TEST_ASSERT(!QDELETED(rock), "Машина закончила обработку слишком рано")
	digger.set_is_operational(FALSE)
	digger.process(digger.process_duration)
	TEST_ASSERT(!QDELETED(rock), "Отключённая машина выдала находку")
	TEST_ASSERT_EQUAL(digger.progress, 0, "Потеря питания не сбросила незавершённую обработку")
	digger.set_is_operational(TRUE)
	digger.process(digger.process_duration)
	TEST_ASSERT(QDELETED(rock), "Раскопщик не обработал образец")
	var/obj/item/flashlight/reward = locate() in get_turf(digger)
	TEST_ASSERT_NOTNULL(reward, "Раскопщик потерял награду")
	qdel(reward)
	var/obj/item/xenoarch/strange_rock/boulder/boulder = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(!digger.accepts(boulder), "Малый раскопщик принимает крупный валун")
	var/obj/machinery/xenoarch/researcher/researcher = allocate(__IMPLIED_TYPE__)
	researcher.set_is_operational(TRUE)
	var/obj/item/xenoarch/broken_item/animal/shell = allocate(__IMPLIED_TYPE__, researcher)
	researcher.process(researcher.process_duration)
	TEST_ASSERT(QDELETED(shell), "Исследователь не обработал подкласс оболочки")
	TEST_ASSERT_EQUAL(researcher.research, 15, "Подкласс оболочки не дал 15 очков")
	TEST_ASSERT(!researcher.redeem("unknown"), "Исследователь принял постороннюю награду")
	TEST_ASSERT(!researcher.redeem("crate"), "Награда выдана без достаточного числа очков")
	researcher.research = 100
	TEST_ASSERT(researcher.redeem("crate"), "Не выдана оплаченная награда")
	TEST_ASSERT_EQUAL(researcher.research, 0, "Очки не списаны")
	TEST_ASSERT(!researcher.redeem("crate"), "Повторная заявка выдала бесплатную награду")

/datum/unit_test/xenoarchaeology_radar/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	user.mind_initialize()
	var/obj/item/xenoarch/radar/test_fixture/radar = allocate(__IMPLIED_TYPE__)
	user.put_in_active_hand(radar)
	var/turf/ground = get_turf(user)
	user.mind.xenoarch_site = list(ground.x, ground.y, ground.z, 1)
	TEST_ASSERT(radar.dig_site(user, ground), "Радар не извлёк образцы в допустимом участке")
	TEST_ASSERT_NULL(user.mind.xenoarch_site, "Израсходованный участок остался активным")
	var/count = 0
	for(var/obj/item/xenoarch/strange_rock/rock in ground)
		count++
	TEST_ASSERT(count >= 1 && count <= 3, "Радар выдал неверное число образцов")
	TEST_ASSERT_EQUAL(user.mind.get_skill_exp(/datum/skill/xenoarchaeology), count * 25, "Опыт не соответствует числу найденных образцов")
	TEST_ASSERT(!radar.dig_site(user, ground), "Участок допускает повторную выдачу")

/datum/unit_test/xenoarchaeology_large_find/Run()
	var/obj/item/xenoarch/strange_rock/boulder/boulder = allocate(__IMPLIED_TYPE__)
	boulder.artifact_type = /obj/machinery/xenoartifact/test_fixture
	boulder.stabilised = TRUE
	boulder.dug_depth = boulder.item_depth
	var/turf/ground = get_turf(boulder)
	TEST_ASSERT(boulder.try_uncover(), "Стабилизированная находка не извлечена")
	TEST_ASSERT(!boulder.try_uncover(), "Крупная находка выдана повторно")
	var/obj/machinery/xenoartifact/test_fixture/artifact = locate() in ground
	TEST_ASSERT_NOTNULL(artifact, "Крупный артефакт потерян")
	TEST_ASSERT_EQUAL(artifact.get_integrity(), artifact.max_integrity, "Стабилизированная находка повреждена")
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/xenoarch/core_sampler/sampler = allocate(__IMPLIED_TYPE__)
	user.put_in_active_hand(sampler)
	var/obj/item/xenoarch/strange_rock/boulder/sampled = allocate(__IMPLIED_TYPE__)
	sampled.item_interaction(user, sampler)
	var/field = sampled.stabilising_field
	qdel(sampled)
	TEST_ASSERT_EQUAL(sampler.sample_data["field"], field, "Керн потерял данные после удаления исходного валуна")
	var/obj/machinery/xenoarch_lab/spectrometer/spectrometer = allocate(__IMPLIED_TYPE__)
	spectrometer.set_is_operational(TRUE)
	sampler.forceMove(spectrometer)
	TEST_ASSERT(spectrometer.start_scan(), "Спектрометр не принял керн")
	spectrometer.process(spectrometer.scan_duration)
	TEST_ASSERT(length(spectrometer.report), "Спектрометр не подготовил отчёт")
	TEST_ASSERT(QDELETED(sampler), "Одноразовый керн не израсходован")

/datum/unit_test/xenoarchaeology_harvesting/Run()
	var/turf/pad_turf = get_step(run_loc_floor_bottom_left, EAST)
	var/obj/machinery/xenoarch_pad/pad = allocate(__IMPLIED_TYPE__, pad_turf)
	var/obj/machinery/xenoartifact/test_fixture/artifact = allocate(__IMPLIED_TYPE__, pad_turf)
	artifact.first_effect = new /datum/xenoartifact_effect/heal(artifact)
	artifact.first_effect.trigger = XENO_TRIGGER_FORCE
	artifact.first_effect.ToggleActivate(FALSE)
	var/obj/machinery/xenoarch_lab/harvester/harvester = allocate(__IMPLIED_TYPE__)
	harvester.set_is_operational(TRUE)
	var/obj/item/xenoarch/particle_battery/battery = allocate(__IMPLIED_TYPE__, harvester)
	TEST_ASSERT(harvester.start_harvest(), "Не начат сбор активного эффекта")
	TEST_ASSERT_EQUAL(pad.icon_state, "xenoarch_scanner_scanning", "Площадка не показывает сбор")
	TEST_ASSERT(artifact.anchored, "Сборщик не зафиксировал артефакт")
	TEST_ASSERT(battery.battery_effect != artifact.first_effect, "Батарея удерживает исходный эффект вместо копии")
	TEST_ASSERT(battery.battery_effect.emission_signature != artifact.first_effect.emission_signature, "Копия эффекта получила идентификатор исходного экземпляра")
	harvester.process(2)
	TEST_ASSERT_EQUAL(battery.stored_charge, 5, "Неверная скорость сбора частиц")
	harvester.set_is_operational(FALSE)
	TEST_ASSERT_EQUAL(pad.icon_state, "xenoarch_scanner", "Площадка не остановила анимацию после потери питания")
	TEST_ASSERT(!harvester.active && !artifact.anchored, "Потеря питания не освободила артефакт")
	TEST_ASSERT_NULL(artifact.lab_owner, "Сборщик удерживает блокировку после остановки")
	harvester.set_is_operational(TRUE)
	TEST_ASSERT(harvester.start_harvest(), "Не удалось продолжить зарядку от той же сигнатуры")
	qdel(pad)
	harvester.process(2)
	TEST_ASSERT(!harvester.active, "Удаление площадки не остановило сбор")
	TEST_ASSERT_EQUAL(battery.stored_charge, 5, "После удаления площадки начислен лишний заряд")
	qdel(artifact)
	TEST_ASSERT(!QDELETED(battery.battery_effect), "Удаление артефакта уничтожило копию в батарее")
	var/obj/item/xenoarch/particle_utilizer/utilizer = allocate(__IMPLIED_TYPE__)
	battery.forceMove(utilizer)
	TEST_ASSERT(utilizer.start_emission(TRUE), "Излучатель не включился по таймеру")
	TEST_ASSERT(utilizer.stop_at > world.time, "Таймер излучателя не установлен")
	utilizer.process(2)
	TEST_ASSERT_EQUAL(battery.stored_charge, 4, "Неверный расход излучателя")
	battery.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT(!utilizer.active && !battery.battery_effect.activated, "Извлечение батареи не выключило эффект")

/// Все семейства эффектов проходят через реальные методы, включая разрушающий импульс.
/datum/unit_test/xenoarchaeology_effects/Run()
	var/obj/machinery/xenoartifact/test_fixture/holder = allocate(__IMPLIED_TYPE__)
	var/mob/living/carbon/human/receiver = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/other = allocate(/mob/living/carbon/human/consistent)
	receiver.mind_initialize()
	other.mind_initialize()
	for(var/effect_type in GLOB.xenoarch_primary_effects | GLOB.xenoarch_secondary_effects)
		var/datum/xenoartifact_effect/effect = new effect_type(holder)
		effect.range = 1
		effect.activated = TRUE
		effect.current_charge = effect.maximum_charges
		effect.do_effect_touch(receiver)
		effect.current_charge = effect.maximum_charges
		effect.do_effect_aura(1)
		effect.current_charge = effect.maximum_charges
		effect.do_effect_pulse(1)
		effect.do_effect_destroy()
		qdel(effect)
		TEST_ASSERT(!QDELETED(holder), "Эффект удалил защищённый тестовый носитель: [effect_type]")

/datum/unit_test/xenoarchaeology_replicator/Run()
	var/obj/machinery/xenoartifact/replicator/replicator = allocate(__IMPLIED_TYPE__)
	replicator.set_is_operational(TRUE)
	var/obj/item/paper/input = allocate(__IMPLIED_TYPE__, replicator)
	replicator.feedstock = input
	TEST_ASSERT(!replicator.select_recipe(0), "Репликатор принял нулевой индекс")
	TEST_ASSERT(!replicator.select_recipe(1.5), "Репликатор принял дробный индекс")
	TEST_ASSERT(!replicator.select_recipe(999), "Репликатор принял индекс вне списка")
	TEST_ASSERT(replicator.select_recipe(1), "Репликатор не запустился с сырьём")
	TEST_ASSERT(!replicator.select_recipe(1), "Репликатор повторно поставил то же сырьё в очередь")
	replicator.process(replicator.duration)
	TEST_ASSERT(QDELETED(input), "Репликатор не израсходовал сырьё")
	TEST_ASSERT_NULL(replicator.feedstock, "Репликатор удерживает израсходованный предмет")
	TEST_ASSERT(!replicator.select_recipe(1), "Репликатор производит без нового сырья")

/// Все чертежи модуля должны быть достижимы через его три узла исследований.
/datum/unit_test/xenoarchaeology_designs/Run()
	var/list/unlocked = list()
	for(var/node_type in list(/datum/techweb_node/basic_xenoarch, /datum/techweb_node/adv_xenoarch, /datum/techweb_node/xenoarch_machines))
		var/datum/techweb_node/node = SSresearch.techweb_nodes[node_type]
		TEST_ASSERT_NOTNULL(node, "Не зарегистрирован узел [node_type]")
		unlocked |= node.unlocked_designs
	for(var/design_type in subtypesof(/datum/design/xenoarch) + subtypesof(/datum/design/board/xenoarch))
		if(isnull(SSresearch.techweb_designs[design_type]))
			continue
		TEST_ASSERT(design_type in unlocked, "Чертёж [design_type] недоступен в технологиях")

/datum/unit_test/xenoarchaeology_special_devices/Run()
	var/obj/machinery/power/xenoarch_crystal/crystal = allocate(__IMPLIED_TYPE__)
	var/datum/powernet/network = allocate(__IMPLIED_TYPE__)
	network.add_machine(crystal)
	crystal.anchored = TRUE
	crystal.wired = TRUE
	crystal.enabled = TRUE
	crystal.process(1)
	TEST_ASSERT_EQUAL(network.newavail, 250 KILO WATTS, "Кристалл выдаёт неверную мощность")
	network.newavail = 0
	crystal.process(2)
	TEST_ASSERT_EQUAL(network.newavail, 250 KILO WATTS, "Мощность кристалла зависит от длительности тика")
	crystal.wired = FALSE
	network.newavail = 0
	crystal.process(2)
	TEST_ASSERT_EQUAL(network.newavail, 0, "Кристалл генерирует энергию без проводов")
	var/obj/machinery/xenoartifact/cloner/cloner = allocate(__IMPLIED_TYPE__)
	cloner.set_is_operational(TRUE)
	cloner.growth_duration = 10
	cloner.growth = 9
	cloner.spawn_type = /mob/living/basic/mothroach
	cloner.process(2)
	TEST_ASSERT_EQUAL(cloner.growth, 1, "Капсула потеряла остаток времени роста")
	TEST_ASSERT_NOTNULL(locate(/mob/living/basic/mothroach) in get_turf(cloner), "Капсула не вырастила организм")
	cloner.set_is_operational(FALSE)
	cloner.process(2)
	TEST_ASSERT_EQUAL(cloner.growth, 0, "При потере питания рост не обращается вспять")

/// Проверяем загруженные DMI, включая наследование, вместо одних только строк в исходниках.
/datum/unit_test/xenoarchaeology_sprites/Run()
	var/list/object_types = typesof(/obj/item/xenoarch) + typesof(/obj/machinery/xenoarch) + typesof(/obj/machinery/xenoarch_lab) + typesof(/obj/machinery/xenoartifact)
	object_types += list(/obj/item/storage/bag/xenoarch, /obj/item/storage/bag/xenoarch/advanced, /obj/item/storage/belt/utility/xenoarch, /obj/machinery/xenoarch_pad, /obj/machinery/power/xenoarch_crystal, /obj/item/stock_parts/power_store/cell/xenoarch)
	object_types += list(/obj/vehicle/sealed/mecha/reticence/loaded/xenoarch, /obj/vehicle/sealed/mecha/odysseus/xenoarch, /obj/vehicle/sealed/mecha/savannah_ivanov/xenoarch, /obj/vehicle/sealed/mecha/durand/xenoarch)
	object_types += typesof(/obj/item/xenoarch_fossil) + list(/obj/machinery/xenoarch_container, /obj/structure/xenoarch_skeleton, /obj/machinery/xenoarch_drone_pad)
	for(var/obj/object_type as anything in object_types)
		if(initial(object_type.abstract_type) == object_type)
			continue
		var/obj/object = allocate(object_type)
		TEST_ASSERT(object.icon_state in icon_states(object.icon), "Нет спрайта [object.icon_state] у [object_type]")
		TEST_ASSERT_NOTEQUAL(object.icon_state, "debug_artefact", "Осталась отладочная иконка у [object_type]")
		if(isitem(object))
			var/obj/item/item = object
			var/hand_state = item.inhand_icon_state || item.icon_state
			TEST_ASSERT(hand_state in icon_states(item.lefthand_file), "Нет предмета в левой руке: [object_type]")
			TEST_ASSERT(hand_state in icon_states(item.righthand_file), "Нет предмета в правой руке: [object_type]")
			if(item.slot_flags & ITEM_SLOT_BELT)
				var/belt_state = item.worn_icon_state || item.icon_state
				TEST_ASSERT(belt_state in icon_states(item.worn_icon || 'icons/mob/clothing/belt.dmi'), "Нет предмета на поясе: [object_type]")
		if(ismecha(object))
			var/obj/vehicle/sealed/mecha/mech = object
			if(!istype(mech, /obj/vehicle/sealed/mecha/savannah_ivanov))
				TEST_ASSERT(mech.base_icon_state in icon_states(mech.icon), "Нет закрытого корпуса [object_type]")
			var/obj/structure/mecha_wreckage/wreck = allocate(mech.wreckage)
			TEST_ASSERT(wreck.icon_state in icon_states(wreck.icon), "Нет обломков [object_type]")
			qdel(wreck)
		qdel(object)
	var/obj/item/xenoarch/wave_scanner/backpack = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(backpack.worn_icon_state in icon_states(backpack.worn_icon), "Нет ранца сканера на персонаже")
	var/obj/machinery/xenoartifact/test_fixture/artifact = allocate(__IMPLIED_TYPE__)
	artifact.first_effect = new /datum/xenoartifact_effect/light(artifact)
	for(var/style in 1 to 13)
		artifact.artifact_style = style
		for(var/active in list(FALSE, TRUE))
			artifact.first_effect.activated = active
			artifact.update_appearance()
			TEST_ASSERT(artifact.icon_state in icon_states(artifact.icon), "Нет варианта артефакта [style], активность [active]")
	artifact.first_effect.activated = FALSE
	var/obj/item/xenoarch/particle_battery/battery = allocate(__IMPLIED_TYPE__)
	var/obj/item/xenoarch/particle_utilizer/utilizer = allocate(__IMPLIED_TYPE__)
	battery.forceMove(utilizer)
	for(var/charge in list(0, 50, 100, 150, 200))
		battery.set_charge(charge)
		TEST_ASSERT(battery.icon_state in icon_states(battery.icon), "Нет индикатора батареи при [charge]")
		for(var/active in list(FALSE, TRUE))
			utilizer.active = active
			utilizer.update_appearance()
			TEST_ASSERT(utilizer.icon_state in icon_states(utilizer.icon), "Нет индикатора излучателя при [charge], [active]")
	utilizer.stop_emission()
	battery.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(utilizer.icon_state, "utilizer", "После извлечения батареи остался индикатор")
	var/obj/machinery/xenoarch_lab/harvester/harvester = allocate(__IMPLIED_TYPE__)
	battery.forceMove(harvester)
	TEST_ASSERT_EQUAL(harvester.icon_state, "harvester_battery", "Сборщик не показывает установленную батарею")
	harvester.active = TRUE
	harvester.update_appearance()
	TEST_ASSERT_EQUAL(harvester.icon_state, "harvester_on", "Сборщик не показывает работу")
	harvester.stop_work()
	battery.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(harvester.icon_state, "harvester", "Сборщик не вернулся к пустому состоянию")

/// Разрушение выбрасывает батарею до Destroy(), когда get_battery() уже не может её найти.
/datum/unit_test/xenoarchaeology_drain_destruction/Run()
	for(var/release_method in list(XENO_EFFECT_AURA, XENO_EFFECT_PULSE))
		var/obj/machinery/xenoarch_lab/harvester/harvester = allocate(__IMPLIED_TYPE__)
		harvester.set_is_operational(TRUE)
		var/obj/item/xenoarch/particle_battery/battery = allocate(__IMPLIED_TYPE__, harvester)
		battery.battery_effect = new /datum/xenoartifact_effect/heal(battery)
		battery.battery_effect.release_method = release_method
		battery.set_charge(100)
		harvester.mode = "draining"
		harvester.active = TRUE
		battery.battery_effect.ToggleActivate(FALSE)
		TEST_ASSERT(battery.battery_effect.activated, "Не начался опасный разряд")
		harvester.take_damage(harvester.max_integrity * 10, BRUTE, BULLET)
		TEST_ASSERT(QDELETED(harvester), "Урон не разрушил сборщик")
		TEST_ASSERT(!QDELETED(battery) && isturf(battery.loc), "Разрушение не сохранило выпавшую батарею")
		TEST_ASSERT(!battery.battery_effect.activated, "Выпавшая батарея продолжает излучать")
		TEST_ASSERT_EQUAL(battery.battery_effect.process(2), PROCESS_KILL, "Эффект выпавшей батареи продолжает обработку")
		qdel(battery)

/// Несколько тиков пересекают цель, а длинный тик не должен пересечь абсолютный минимум.
/datum/unit_test/xenoarchaeology_cooling/Run()
	var/obj/machinery/xenoartifact/test_fixture/holder = allocate(__IMPLIED_TYPE__)
	var/datum/xenoartifact_effect/temperature/cold/effect = new(holder)
	holder.first_effect = effect
	var/turf/open/ground = get_turf(holder)
	TEST_ASSERT_NOTNULL(ground.air, "На тестовой клетке отсутствует атмосфера")
	ground.air.temperature = 293
	effect.target_temp = 50
	effect.ToggleActivate(FALSE)
	for(var/tick in 1 to 4)
		effect.do_effect_aura(2)
		TEST_ASSERT(ground.air.temperature >= effect.target_temp, "Охлаждение пересекло заданную температуру")
	TEST_ASSERT_EQUAL(ground.air.temperature, 50, "Охлаждение не достигло цели")
	ground.air.temperature = 293
	effect.target_temp = TCMB
	effect.do_effect_aura(60)
	TEST_ASSERT_EQUAL(ground.air.temperature, TCMB, "Длинный тик пересёк нижний предел температуры")
	TEST_ASSERT(ground.air.return_pressure() >= 0, "Охлаждение создало отрицательное давление")

/// Обычная жила меняет соседнюю пустую породу, сохраняя археологическое включение.
/datum/unit_test/xenoarchaeology_ore_veins/Run()
	var/turf/closed/mineral/xenoarchaeology/rock = run_loc_floor_bottom_left.ChangeTurf(/turf/closed/mineral/xenoarchaeology)
	var/turf/closed/mineral/neighbor = get_step(rock, NORTH).ChangeTurf(/turf/closed/mineral)
	rock.spread_vein(/obj/item/stack/ore/iron)
	TEST_ASSERT_NULL(rock.mineral_type, "Распространение жилы заменило археологический образец")
	TEST_ASSERT_EQUAL(rock.scan_state, "rock_strange", "Распространение жилы подменило метку сканера")
	neighbor.spread_vein(/obj/item/stack/ore/iron)
	TEST_ASSERT_EQUAL(neighbor.mineral_type, /obj/item/stack/ore/iron, "Жила не распространяется в обычную породу")
	rock.gets_drilled()
	TEST_ASSERT_NOTNULL(locate(/obj/item/xenoarch/strange_rock) in run_loc_floor_bottom_left, "После распространения жилы потерян образец")

/datum/unit_test/xenoarchaeology_ore_veins/Destroy()
	get_step(run_loc_floor_bottom_left, NORTH).ChangeTurf(/turf/open/indestructible)
	run_loc_floor_bottom_left.ChangeTurf(/turf/open/indestructible)
	return ..()

/// Проходим настоящую цепочку удара, а не только возвращаемый флаг item_interaction().
/datum/unit_test/xenoarchaeology_machine_attacks/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/crowbar/weapon = allocate(__IMPLIED_TYPE__)
	user.put_in_active_hand(weapon)
	user.set_combat_mode(TRUE)
	for(var/machine_type in list(/obj/machinery/xenoarch/scanner, /obj/machinery/xenoarch/digger, /obj/machinery/xenoarch/researcher, /obj/machinery/xenoarch_lab/analyzer, /obj/machinery/xenoarch_lab/spectrometer, /obj/machinery/xenoarch_lab/harvester))
		var/obj/machinery/machine = allocate(machine_type)
		for(var/unavailable_state in list("power", "anchor", "panel", "active"))
			machine.set_is_operational(unavailable_state != "power")
			machine.set_anchored(unavailable_state != "anchor")
			machine.panel_open = unavailable_state == "panel"
			if(istype(machine, /obj/machinery/xenoarch_lab))
				var/obj/machinery/xenoarch_lab/lab = machine
				lab.active = unavailable_state == "active"
			var/old_integrity = machine.get_integrity()
			weapon.melee_attack_chain(user, machine)
			TEST_ASSERT(machine.get_integrity() < old_integrity, "[machine_type] блокирует удар в состоянии [unavailable_state]")
		qdel(machine)

/// Фиксируем выбор мутации, чтобы проверка разрушения не зависела от случайного вида изменения ДНК.
/datum/xenoartifact_effect/dnaswitch/test_fixture
	var/mutation_attempts = 0

/datum/xenoartifact_effect/dnaswitch/test_fixture/roll_and_change_genes(mob/living/carbon/human/receiver, chance)
	mutation_attempts++
	receiver.dna.add_mutation(/datum/mutation/clumsy, MUTATION_SOURCE_ACTIVATED)

/datum/unit_test/xenoarchaeology_dna_destruction/Run()
	var/obj/machinery/xenoartifact/holder = allocate(__IMPLIED_TYPE__)
	QDEL_NULL(holder.first_effect)
	QDEL_NULL(holder.secondary_effect)
	var/datum/xenoartifact_effect/dnaswitch/test_fixture/effect = new(holder)
	holder.first_effect = effect
	var/mob/living/carbon/human/receiver = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT_NULL(receiver.dna.get_mutation(/datum/mutation/clumsy), "Тестовый персонаж уже имеет проверяемую мутацию")
	holder.take_damage(holder.max_integrity * 10, BRUTE, BULLET)
	TEST_ASSERT(QDELETED(holder), "Урон не разрушил артефакт")
	TEST_ASSERT_EQUAL(effect.mutation_attempts, 4, "Разрушение не вызвало четыре изменения генов")
	TEST_ASSERT_NOTNULL(receiver.dna.get_mutation(/datum/mutation/clumsy), "Разрушение не изменило ДНК персонажа")

/// Платы используют собственную унаследованную иконку, а не состояния собранных станков.
/datum/unit_test/xenoarchaeology_circuit_sprites/Run()
	for(var/obj/item/circuitboard/machine/xenoarch/board_type as anything in subtypesof(/obj/item/circuitboard/machine/xenoarch))
		TEST_ASSERT(initial(board_type.icon_state) in icon_states(initial(board_type.icon)), "Нет исходного спрайта платы [board_type]")

/// Нагрев ограничен целью и даёт один результат за одинаковое время обработки.
/datum/unit_test/xenoarchaeology_heating/Run()
	var/obj/machinery/xenoartifact/test_fixture/holder = allocate(__IMPLIED_TYPE__)
	var/datum/xenoartifact_effect/temperature/heat/effect = allocate(__IMPLIED_TYPE__, holder)
	effect.activated = TRUE
	effect.target_temp = 500
	effect.target_temp_high = 20000
	var/turf/open/ground = get_turf(holder)
	var/datum/gas_mixture/air = ground.return_air()
	air.temperature = 300
	effect.do_effect_aura(2)
	var/long_tick_temperature = air.temperature
	TEST_ASSERT(air.temperature > 300 && air.temperature <= 500, "Нагрев перескочил заданную температуру")
	air.temperature = 300
	effect.do_effect_aura(1)
	effect.do_effect_aura(1)
	TEST_ASSERT(abs(air.temperature - long_tick_temperature) < 0.01, "Нагрев зависит от разбиения времени на тики")
	effect.do_effect_aura(1000)
	TEST_ASSERT_EQUAL(air.temperature, 500, "Длинный тик не остановился на целевой температуре")

/// Запрет обмена проверяется до создания разума, обычный обмен обратим.
/datum/unit_test/xenoarchaeology_mindswap_protection/Run()
	var/obj/machinery/xenoartifact/test_fixture/holder = allocate(__IMPLIED_TYPE__)
	var/datum/xenoartifact_effect/bodyswap/effect = allocate(__IMPLIED_TYPE__, holder)
	var/mob/living/carbon/human/first = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/second = allocate(/mob/living/carbon/human/consistent)
	first.mind_initialize()
	second.mind_initialize()
	var/datum/mind/first_mind = first.mind
	var/datum/mind/second_mind = second.mind
	for(var/blocked_trait in list(TRAIT_NO_MINDSWAP, TRAIT_MIND_TEMPORARILY_GONE))
		ADD_TRAIT(first, blocked_trait, REF(src))
		TEST_ASSERT(!effect.swap_bodies(), "Обмен обошёл [blocked_trait]")
		TEST_ASSERT_EQUAL(first.mind, first_mind, "Защищённый персонаж сменил разум")
		TEST_ASSERT_EQUAL(second.mind, second_mind, "Партнёр защищённого персонажа сменил разум")
		REMOVE_TRAIT(first, blocked_trait, REF(src))
	for(var/role_type in list(/datum/antagonist/wizard, /datum/antagonist/cult, /datum/antagonist/changeling, /datum/antagonist/rev))
		var/datum/antagonist/role = allocate(role_type)
		role.owner = first_mind
		LAZYADD(first_mind.antag_datums, role)
		TEST_ASSERT(!effect.can_swap_mind(first), "Разрешён обмен защищённого антагониста [role_type]")
		qdel(role)
	TEST_ASSERT(effect.swap_bodies(), "Обычные персонажи не обменялись телами")
	TEST_ASSERT_EQUAL(first.mind, second_mind, "В первое тело не перенесён второй разум")
	TEST_ASSERT_EQUAL(second.mind, first_mind, "Во второе тело не перенесён первый разум")
	effect.return_bodies()
	TEST_ASSERT_EQUAL(first.mind, first_mind, "Первый разум не вернулся")
	TEST_ASSERT_EQUAL(second.mind, second_mind, "Второй разум не вернулся")

/// Один импульс действительно создаёт паразитическую конечность у каждой цели.
/datum/unit_test/xenoarchaeology_bodyhorror_targets/Run()
	var/obj/machinery/xenoartifact/test_fixture/holder = allocate(__IMPLIED_TYPE__)
	var/datum/xenoartifact_effect/bodyhorror/effect = allocate(__IMPLIED_TYPE__, holder)
	var/list/targets = list(allocate(/mob/living/carbon/human/consistent), allocate(/mob/living/carbon/human/consistent))
	effect.activated = TRUE
	effect.current_charge = effect.maximum_charges
	effect.do_effect_pulse(2)
	for(var/mob/living/carbon/human/target as anything in targets)
		var/infected_limbs = 0
		for(var/obj/item/bodypart/part as anything in target.bodyparts)
			var/mob/living/basic/living_limb_flesh/parasite = locate() in part
			if(parasite)
				infected_limbs++
				TEST_ASSERT_EQUAL(parasite.current_bodypart, part, "Паразит не зарегистрирован на конечности")
		TEST_ASSERT_EQUAL(infected_limbs, 1, "Импульс пропустил одну из целей или заменил лишние конечности")

/// Защищённая первая машина не мешает оживлению следующей разрешённой.
/datum/unit_test/xenoarchaeology_machinery_targets/Run()
	var/obj/machinery/xenoartifact/test_fixture/holder = allocate(__IMPLIED_TYPE__)
	var/datum/xenoartifact_effect/machinery_mess/effect = allocate(__IMPLIED_TYPE__, holder)
	effect.range = 1
	allocate(/obj/machinery/xenoarch/scanner)
	allocate(/obj/machinery/xenoarch/scanner)
	var/list/machines = list()
	for(var/obj/machinery/machine in range(1, holder))
		if(machine != holder)
			machines += machine
	TEST_ASSERT_EQUAL(length(machines), 2, "Не подготовлены две машины")
	var/obj/machinery/protected = machines[1]
	var/obj/machinery/vulnerable = machines[2]
	protected.resistance_flags |= INDESTRUCTIBLE
	// Вероятность при таком интервале равна 100%; порядок обхода берётся из настоящего range().
	effect.try_animate(10000)
	TEST_ASSERT(!QDELETED(protected), "Оживлена неразрушимая машина")
	TEST_ASSERT(QDELETED(vulnerable), "Защищённая машина оборвала обход остальных целей")
	TEST_ASSERT_NOTNULL(locate(/mob/living/basic/mimic/copy/machine) in get_turf(holder), "Не создан живой механизм")

/// Частичная защита уменьшает тошноту, разрушение вызывает тошноту без сна.
/datum/unit_test/xenoarchaeology_disgust_protection/Run()
	var/obj/machinery/xenoartifact/test_fixture/holder = allocate(__IMPLIED_TYPE__)
	var/datum/xenoartifact_effect/disgust/effect = allocate(__IMPLIED_TYPE__, holder)
	var/mob/living/carbon/human/target = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/clothing/suit/bio_suit/suit = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(target.equip_to_slot_if_possible(suit, ITEM_SLOT_OCLOTHING), "Не надет биокостюм")
	effect.apply_disgust(target, 20)
	TEST_ASSERT_EQUAL(target.disgust, 10, "Биокостюм не уменьшил тошноту вдвое")
	target.set_disgust(0)
	effect.do_effect_destroy()
	TEST_ASSERT(target.disgust > 0, "Разрушение не вызвало тошноту")
	TEST_ASSERT(!target.IsSleeping(), "Разрушение артефакта тошноты вызвало сон")

/// Полный комплект блокирует оба эффекта настроения во всех режимах.
/datum/unit_test/xenoarchaeology_feelings_protection/Run()
	var/obj/machinery/xenoartifact/test_fixture/holder = allocate(__IMPLIED_TYPE__)
	var/mob/living/carbon/human/target = allocate(/mob/living/carbon/human/consistent)
	var/list/protection = list(
		/obj/item/clothing/suit/bio_suit = ITEM_SLOT_OCLOTHING,
		/obj/item/clothing/head/bio_hood = ITEM_SLOT_HEAD,
		/obj/item/clothing/gloves/latex = ITEM_SLOT_GLOVES,
		/obj/item/clothing/glasses/science = ITEM_SLOT_EYES,
	)
	for(var/item_type in protection)
		TEST_ASSERT(target.equip_to_slot_if_possible(allocate(item_type), protection[item_type]), "Не надет предмет защиты [item_type]")
	TEST_ASSERT_EQUAL(get_xenoartifact_susceptibility(target), 0, "Комплект не даёт полной защиты")
	for(var/effect_type in list(/datum/xenoartifact_effect/feelings/good, /datum/xenoartifact_effect/feelings/bad))
		var/datum/xenoartifact_effect/feelings/effect = allocate(effect_type, holder)
		effect.activated = TRUE
		effect.current_charge = effect.maximum_charges
		effect.do_effect_touch(target)
		effect.do_effect_aura(2)
		effect.do_effect_pulse(2)
		effect.do_effect_destroy()
		TEST_ASSERT_EQUAL(target.get_timed_status_effect_duration(/datum/status_effect/dizziness), 0, "Полная защита пропустила головокружение [effect_type]")
		for(var/category in list("drastic_effect_good", "minor_effect_good", "drastic_effect_bad", "minor_effect_bad"))
			TEST_ASSERT_NULL(target.mob_mood?.mood_events[category], "Полная защита пропустила настроение [category]")
		var/obj/item/glasses = target.glasses
		target.temporarilyRemoveItemFromInventory(glasses)
		TEST_ASSERT(abs(effect.run_send_messages(target, 0, 0) - 0.1) < 0.001, "Не учтена частичная защита настроения")
		TEST_ASSERT(target.equip_to_slot_if_possible(glasses, ITEM_SLOT_EYES), "Не возвращены защитные очки")

/// Повторное поражение продлевает статус при необходимости и никогда не сокращает его.
/datum/unit_test/xenoarchaeology_status_duration/Run()
	var/obj/machinery/xenoartifact/test_fixture/holder = allocate(__IMPLIED_TYPE__)
	var/mob/living/carbon/human/target = allocate(/mob/living/carbon/human/consistent)
	var/datum/xenoartifact_effect/drugs/drugs = allocate(__IMPLIED_TYPE__, holder)
	drugs.do_drugs(target, 120)
	drugs.do_drugs(target, 10)
	TEST_ASSERT_EQUAL(target.get_timed_status_effect_duration(/datum/status_effect/drugginess), 120 SECONDS, "Слабое воздействие сократило наркотический эффект")
	var/datum/xenoartifact_effect/sleepy/sleepy = allocate(__IMPLIED_TYPE__, holder)
	target.Sleeping(60 SECONDS)
	sleepy.do_effect_destroy()
	TEST_ASSERT_EQUAL(target.AmountSleeping(), 60 SECONDS, "Разрушение сократило уже действующий сон")

/// Импульсы теста удаляются из очереди и при раннем выходе с ошибкой.
/datum/unit_test/xenoarchaeology_radiation_interval
	/// Очередь до проверки нужна, чтобы не удалить чужие импульсы при очистке.
	var/list/original_processing

/datum/unit_test/xenoarchaeology_radiation_interval/Destroy()
	if(original_processing)
		for(var/datum/radiation_pulse_information/pulse as anything in (SSradiation.processing - original_processing))
			SSradiation.processing -= pulse
			qdel(pulse)
	original_processing = null
	return ..()

/// Число и сила реальных импульсов не зависят от длины тика.
/datum/unit_test/xenoarchaeology_radiation_interval/Run()
	TEST_ASSERT(SSradiation.can_fire, "Подсистема радиации отключена")
	original_processing = SSradiation.processing.Copy()
	var/obj/machinery/xenoartifact/test_fixture/holder = allocate(__IMPLIED_TYPE__)
	var/datum/xenoartifact_effect/radiate/effect = allocate(__IMPLIED_TYPE__, holder)
	effect.activated = TRUE
	effect.radiation_amount = 3
	effect.do_effect_aura(1)
	TEST_ASSERT_EQUAL(length(SSradiation.processing - original_processing), 0, "Аура излучает чаще двух секунд")
	effect.do_effect_aura(1)
	TEST_ASSERT_EQUAL(length(SSradiation.processing - original_processing), 1, "Два коротких тика не дали импульс")
	effect.do_effect_aura(4)
	TEST_ASSERT_EQUAL(length(SSradiation.processing - original_processing), 3, "Длинный тик потерял импульсы")
	effect.do_effect_aura(0.5)
	effect.do_effect_aura(1.5)
	TEST_ASSERT_EQUAL(length(SSradiation.processing - original_processing), 4, "Потерян дробный остаток времени")
	for(var/datum/radiation_pulse_information/pulse as anything in (SSradiation.processing - original_processing))
		TEST_ASSERT_EQUAL(pulse.chance, 30, "Длина тика изменила силу отдельного импульса")

/// Настоящая катушка получает разряд ровно на границе указанной начальной дальности.
/datum/unit_test/xenoarchaeology_tesla_range/Run()
	var/obj/machinery/xenoartifact/test_fixture/holder = allocate(__IMPLIED_TYPE__)
	var/datum/xenoartifact_effect/tesla/effect = allocate(__IMPLIED_TYPE__, holder)
	TEST_ASSERT(effect.range >= 4 && effect.range <= 8, "Дальность Теслы вне исходного диапазона")
	effect.range = 4
	effect.activated = TRUE
	TEST_ASSERT(findtext(effect.get_description(), "Радиус: 4 м."), "Паспорт показывает другую дальность")
	var/turf/outside = get_step(get_step(get_step(get_step(get_step(holder, EAST), EAST), EAST), EAST), EAST)
	var/obj/machinery/power/energy_accumulator/tesla_coil/coil = allocate(__IMPLIED_TYPE__, outside)
	coil.set_anchored(TRUE)
	effect.current_charge = effect.maximum_charges
	effect.do_effect_pulse(2)
	TEST_ASSERT_EQUAL(coil.stored_energy, 0, "Первая цель за указанным радиусом получила разряд")
	coil.forceMove(get_step(outside, WEST))
	effect.current_charge = effect.maximum_charges
	effect.do_effect_pulse(2)
	TEST_ASSERT(coil.stored_energy > 0, "Цель на границе указанного радиуса не получила разряд")
	var/datum/xenoartifact_effect/tesla/copy = effect.copy_to(holder)
	allocated += copy
	TEST_ASSERT_EQUAL(copy.range, effect.range, "Батарея изменила дальность Теслы")

/// Штатный запрет телепортации возвращает отказ вместо ложного успеха.
/datum/unit_test/xenoarchaeology_teleport_failure/Run()
	var/obj/machinery/xenoartifact/test_fixture/holder = allocate(__IMPLIED_TYPE__)
	var/datum/xenoartifact_effect/teleport/effect = allocate(__IMPLIED_TYPE__, holder)
	var/mob/living/carbon/human/target = allocate(/mob/living/carbon/human/consistent)
	var/turf/origin = get_turf(target)
	ADD_TRAIT(target, TRAIT_NO_TELEPORT, REF(src))
	TEST_ASSERT(!effect.teleport_around(target, 2), "Заблокированный перенос сообщил об успехе")
	TEST_ASSERT_EQUAL(get_turf(target), origin, "Обойдён штатный запрет телепортации")

/// Прямой клик целеуказателем не становится сырьём ни в пустом, ни в занятом репликаторе.
/datum/unit_test/xenoarchaeology_replicator_delivery
	parent_type = /datum/unit_test/xenoarch_drone_fixture

/datum/unit_test/xenoarchaeology_replicator_delivery/Run()
	prepare_transport()
	var/obj/machinery/xenoartifact/replicator/replicator = allocate(__IMPLIED_TYPE__, get_turf(loader))
	for(var/loaded in list(FALSE, TRUE))
		var/obj/item/paper/feedstock
		if(loaded)
			feedstock = allocate(__IMPLIED_TYPE__, replicator)
			replicator.feedstock = feedstock
		click_wrapper(user, replicator)
		TEST_ASSERT_NOTNULL(receiver.current_flight, "Прямой клик не отправил репликатор, сырьё: [loaded]")
		TEST_ASSERT(user.is_holding(designator), "Репликатор поглотил целеуказатель")
		TEST_ASSERT_EQUAL(replicator.feedstock, feedstock, "Наведение изменило сырьё репликатора")
		TEST_ASSERT_EQUAL(replicator.loc, receiver.current_flight, "В рейс передан другой груз")
		qdel(receiver.current_flight)
