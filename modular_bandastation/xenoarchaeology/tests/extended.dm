#include "../code/artifact_defines.dm"

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
