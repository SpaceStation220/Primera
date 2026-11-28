/** Каждый сценарий убирает только свои записи и восстанавливает счётчик после удаления находок. */
/datum/unit_test/xenoarch_catalogue_fixture
	abstract_type = /datum/unit_test/xenoarch_catalogue_fixture
	/// Список записей, принадлежащих другим сценариям и не подлежащих удалению.
	var/list/original_ids
	/// Счётчик до создания находок этого сценария.
	var/original_counter
	/// Лаборатория, завершающая анализ через штатный process.
	var/obj/machinery/xenoarch_lab/analyzer/lab
	/// Площадка рядом с лабораторией.
	var/obj/machinery/xenoarch_pad/pad
	/// Найденная или изготовленная цель анализа, принадлежащая allocated.
	var/obj/target
	/// Геологическая метка до удаления исходного валуна.
	var/source_id

/** Реальная раскопка отличает серверное происхождение от обычного создания того же типа. */
/datum/unit_test/xenoarch_catalogue_fixture/proc/prepare_find(excavated = TRUE, target_type = /obj/machinery/xenoartifact/test_fixture)
	original_ids = list()
	for(var/id in GLOB.xenoarch_catalogue)
		original_ids += id
	original_counter = GLOB.xenoarch_catalogue_next_id
	if(excavated)
		var/obj/item/xenoarch/strange_rock/boulder/boulder = allocate(__IMPLIED_TYPE__)
		boulder.artifact_type = target_type
		boulder.stabilised = TRUE
		boulder.dug_depth = boulder.item_depth
		source_id = boulder.artifact_id
		boulder.try_uncover()
		target = locate(target_type) in run_loc_floor_bottom_left
		if(!target)
			return Fail("Не удалось подготовить раскопанную находку")
		allocated += target
	else
		target = allocate(target_type)
	pad = allocate(/obj/machinery/xenoarch_pad, get_turf(target))
	lab = allocate(/obj/machinery/xenoarch_lab/analyzer, get_step(pad, NORTH))
	lab.set_is_operational(TRUE)

/datum/unit_test/xenoarch_catalogue_fixture/Destroy()
	if(original_ids)
		for(var/id in GLOB.xenoarch_catalogue.Copy())
			if(id in original_ids)
				continue
			var/datum/xenoarch_catalogue_entry/entry = GLOB.xenoarch_catalogue[id]
			GLOB.xenoarch_catalogue -= id
			qdel(entry)
	original_ids = null
	lab = null
	pad = null
	target = null
	. = ..()
	if(!isnull(original_counter))
		GLOB.xenoarch_catalogue_next_id = original_counter
	return .

/** Оба анализатора используют один паспорт, который переживает удаление находки. */
/datum/unit_test/xenoarchaeology_catalogue_snapshot
	parent_type = /datum/unit_test/xenoarch_catalogue_fixture

/datum/unit_test/xenoarchaeology_catalogue_snapshot/Run()
	prepare_find()
	TEST_ASSERT(lab.start_scan(), "Не начался анализ находки")
	lab.process(lab.scan_duration)
	var/datum/xenoarch_catalogue_entry/entry = GLOB.xenoarch_catalogue[lab.catalogue_id]
	TEST_ASSERT_NOTNULL(entry, "Завершённый анализ не создал паспорт")
	TEST_ASSERT_EQUAL(entry.report, lab.report, "В паспорт попал иной отчёт")
	TEST_ASSERT_EQUAL(entry.excavation_id, source_id, "Утеряно происхождение из валуна")
	var/obj/machinery/xenoarch_lab/analyzer/controlled/manual = allocate(__IMPLIED_TYPE__, get_step(pad, EAST))
	manual.set_is_operational(TRUE)
	TEST_ASSERT(manual.start_scan(), "Ручной прибор не принял повторный анализ")
	manual.shield_closed = FALSE
	manual.progress = manual.scan_duration - 1
	manual.wavelength_timer = 1000
	manual.radiation_timer = 1000
	manual.target_wavelength = manual.wavelength
	manual.optimal_wavelength = manual.wavelength
	manual.process(1)
	TEST_ASSERT_EQUAL(manual.catalogue_id, entry.id, "Повторный анализ создал новую метку")
	TEST_ASSERT_EQUAL(length(GLOB.xenoarch_catalogue), length(original_ids) + 1, "Повторный анализ дублирует паспорт")
	qdel(target)
	target = null
	TEST_ASSERT(!QDELETED(entry), "Удаление находки удалило журнал")
	TEST_ASSERT_EQUAL(GLOB.xenoarch_catalogue[entry.id], entry, "После удаления находки паспорт недоступен")

/** Переполнение сохраняет награду, а другой станок не позволяет получить её дважды. */
/datum/unit_test/xenoarchaeology_catalogue_reward
	parent_type = /datum/unit_test/xenoarch_catalogue_fixture

/datum/unit_test/xenoarchaeology_catalogue_reward/Run()
	prepare_find()
	TEST_ASSERT(lab.start_scan(), "Не начался анализ для регистрации")
	lab.process(lab.scan_duration)
	var/datum/xenoarch_catalogue_entry/entry = GLOB.xenoarch_catalogue[lab.catalogue_id]
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/machinery/xenoarch/researcher/full = allocate(__IMPLIED_TYPE__)
	var/obj/machinery/xenoarch/researcher/other = allocate(__IMPLIED_TYPE__)
	full.set_is_operational(TRUE)
	other.set_is_operational(TRUE)
	full.research = full.max_research
	var/datum/tgui/full_ui = allocate(/datum/tgui, user, full, "Xenoarchaeology")
	var/datum/tgui/other_ui = allocate(/datum/tgui, user, other, "Xenoarchaeology")
	TEST_ASSERT(!other.ui_act("catalogue_claim", list("id" = entry.id), other_ui), "Награда доступна до регистрации")
	TEST_ASSERT(full.ui_act("catalogue_register", list("id" = entry.id, "registered_by" = "Подделка"), full_ui), "Полный станок препятствует регистрации")
	TEST_ASSERT_EQUAL(entry.registered_by, user.real_name, "Подпись взята из пользовательских параметров")
	TEST_ASSERT(!entry.reward_claimed, "Полный станок списал право на награду")
	TEST_ASSERT_EQUAL(full.research, full.max_research, "Регистрация переполнила станок")
	TEST_ASSERT(other.ui_act("catalogue_claim", list("id" = entry.id), other_ui), "Нельзя получить отложенную награду на другом станке")
	TEST_ASSERT_EQUAL(other.research, 20, "Выдано не 20 очков")
	TEST_ASSERT(!full.ui_act("catalogue_register", list("id" = entry.id), full_ui), "Повторная регистрация принята")
	TEST_ASSERT(!other.ui_act("catalogue_claim", list("id" = entry.id), other_ui), "Выдана повторная награда")
	TEST_ASSERT_EQUAL(other.research, 20, "Повторный запрос изменил очки")

/** Изготовленный идол получает паспорт без награды даже при подмене параметров UI. */
/datum/unit_test/xenoarchaeology_catalogue_crafted
	parent_type = /datum/unit_test/xenoarch_catalogue_fixture

/datum/unit_test/xenoarchaeology_catalogue_crafted/Run()
	prepare_find(FALSE, /obj/structure/constructshell)
	TEST_ASSERT(lab.start_scan(), "Не начался анализ изготовленного идола")
	lab.process(lab.scan_duration)
	var/datum/xenoarch_catalogue_entry/entry = GLOB.xenoarch_catalogue[lab.catalogue_id]
	TEST_ASSERT_NOTNULL(entry, "Для изготовленного объекта не сохранён информационный паспорт")
	TEST_ASSERT_NULL(entry.excavation_id, "Изготовленный объект получил происхождение из раскопок")
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/machinery/xenoarch/researcher/machine = allocate(__IMPLIED_TYPE__)
	machine.set_is_operational(TRUE)
	var/datum/tgui/ui = allocate(/datum/tgui, user, machine, "Xenoarchaeology")
	TEST_ASSERT(machine.ui_act("catalogue_register", list("id" = entry.id), ui), "Нельзя подписать информационную запись")
	TEST_ASSERT(!machine.ui_act("catalogue_claim", list("id" = entry.id, "excavation_id" = "Подделка"), ui), "Изготовленный идол принёс очки")
	TEST_ASSERT_EQUAL(machine.research, 0, "Награда не связана с происхождением")

/** Проверка настоящей UI-границы: версия, неизменяемый паспорт, состояние окна и дальность. */
/datum/unit_test/xenoarchaeology_catalogue_editing
	parent_type = /datum/unit_test/xenoarch_catalogue_fixture

/datum/unit_test/xenoarchaeology_catalogue_editing/Run()
	prepare_find()
	TEST_ASSERT(lab.start_scan(), "Не начался анализ для журнала")
	lab.process(lab.scan_duration)
	var/datum/xenoarch_catalogue_entry/entry = GLOB.xenoarch_catalogue[lab.catalogue_id]
	var/old_report = entry.report
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/machinery/xenoarch/researcher/machine = allocate(__IMPLIED_TYPE__)
	machine.set_is_operational(TRUE)
	var/datum/tgui/ui = allocate(/datum/tgui, user, machine, "Xenoarchaeology")
	TEST_ASSERT(!machine.ui_act("catalogue_save", list("id" = "неизвестный", "revision" = 0, "title" = "A", "notes" = "B"), ui), "UI создал запись по поддельному ID")
	TEST_ASSERT(machine.ui_act("catalogue_save", list("id" = entry.id, "revision" = 0, "title" = "Наблюдение", "notes" = "Слабое свечение", "report" = "Подделка"), ui), "Не сохранено наблюдение")
	TEST_ASSERT_EQUAL(entry.notes, "Слабое свечение", "Потерян текст наблюдения")
	TEST_ASSERT_EQUAL(entry.report, old_report, "UI подменил неизменяемый паспорт")
	TEST_ASSERT(!machine.ui_act("catalogue_save", list("id" = entry.id, "revision" = 0, "title" = "Чужой черновик", "notes" = "Перезапись"), ui), "Устаревшая версия затёрла запись")
	TEST_ASSERT_EQUAL(entry.notes, "Слабое свечение", "Потеряны наблюдения первого автора")
	ui.status = UI_CLOSE
	machine.ui_act("catalogue_register", list("id" = entry.id), ui)
	TEST_ASSERT_NULL(entry.registered_by, "Закрытый UI зарегистрировал запись")
	ui.status = UI_INTERACTIVE
	user.forceMove(get_step(get_step(machine, NORTH), NORTH))
	TEST_ASSERT(!machine.ui_act("catalogue_register", list("id" = entry.id), ui), "Удалённый пользователь подписал паспорт")
