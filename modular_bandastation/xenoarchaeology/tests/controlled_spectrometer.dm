/// Экран приостанавливает анализ, но жидкость действительно расходуется; завершение использует общий отчёт.
/datum/unit_test/xenoarchaeology_controlled_scan/Run()
	var/obj/machinery/xenoarch_pad/pad = allocate(__IMPLIED_TYPE__)
	var/obj/machinery/xenoarch_lab/analyzer/controlled/lab = allocate(__IMPLIED_TYPE__, get_step(pad, NORTH))
	var/obj/machinery/xenoartifact/test_fixture/artifact = allocate(__IMPLIED_TYPE__, get_turf(pad))
	lab.set_is_operational(TRUE)
	TEST_ASSERT_EQUAL(lab.icon_state, "analyser", "Управляемый прибор не использует исходное состояние Sierra")
	TEST_ASSERT_NULL(lab.scan_animation, "Прибор Sierra пытается проигрывать анимацию другой консоли")
	TEST_ASSERT(lab.start_scan(), "Ручной спектрометр не начал анализ")
	TEST_ASSERT_EQUAL(lab.icon_state, "analyser_processing", "Не включена рабочая анимация Sierra")
	TEST_ASSERT(artifact.anchored, "Артефакт не закреплён на время анализа")
	// Дрейф и всплески не относятся к проверке расхода и завершения: удерживаем условия постоянными.
	lab.wavelength_timer = 1000
	lab.radiation_timer = 1000
	lab.optimal_wavelength = lab.wavelength
	lab.target_wavelength = lab.wavelength
	lab.reagents.add_reagent(/datum/reagent/water, 50)
	lab.coolant_rate = 2
	lab.process(2)
	TEST_ASSERT_EQUAL(lab.reagents.total_volume, 46, "Контур не израсходовал 4 единицы за две секунды")
	TEST_ASSERT_EQUAL(lab.progress, 0, "Закрытый экран допускает анализ")
	lab.shield_closed = FALSE
	lab.process(2)
	TEST_ASSERT_EQUAL(lab.progress, 2, "Совпадающая волна не даёт полного прогресса")
	lab.progress = lab.scan_duration - 1
	lab.process(1)
	TEST_ASSERT(!lab.active, "Завершённый анализ продолжает работать")
	TEST_ASSERT_EQUAL(lab.icon_state, "analyser", "После анализа не вернулось исходное состояние Sierra")
	TEST_ASSERT_EQUAL(lab.report, artifact.analysis_description(), "Ручной прибор изменил формат результата")
	TEST_ASSERT_NULL(artifact.lab_owner, "Завершённый анализ удерживает артефакт")
	TEST_ASSERT(!artifact.anchored, "Не восстановлено исходное крепление артефакта")
	TEST_ASSERT_NULL(pad.scan_owner, "Площадка осталась занятой")
	TEST_ASSERT_NOTNULL(locate(/obj/item/paper/xenoarch_report) in get_turf(lab), "Отчёт не напечатан")

/// Перегрев и потеря питания освобождают прежнее владение и не выдают незавершённый отчёт.
/datum/unit_test/xenoarchaeology_controlled_abort/Run()
	var/obj/machinery/xenoarch_pad/pad = allocate(__IMPLIED_TYPE__)
	var/obj/machinery/xenoarch_lab/analyzer/controlled/lab = allocate(__IMPLIED_TYPE__, get_step(pad, NORTH))
	var/obj/machinery/xenoartifact/test_fixture/artifact = allocate(__IMPLIED_TYPE__, get_turf(pad))
	artifact.anchored = TRUE
	lab.set_is_operational(TRUE)
	TEST_ASSERT(lab.start_scan(), "Не начался сценарий перегрева")
	lab.scanner_temperature = 999
	lab.scanner_rpm = 1000
	lab.process(1)
	TEST_ASSERT(!lab.active, "Закрытый экран позволил игнорировать перегрев")
	TEST_ASSERT_NULL(artifact.lab_owner, "Перегрев не освободил артефакт")
	TEST_ASSERT(artifact.anchored, "Авария сняла исходное крепление артефакта")
	TEST_ASSERT_NULL(locate(/obj/item/paper/xenoarch_report) in get_turf(lab), "Авария создала отчёт")
	lab.scanner_temperature = 20
	TEST_ASSERT(lab.start_scan(), "Не начался сценарий отключения питания")
	lab.set_is_operational(FALSE)
	TEST_ASSERT(!lab.active, "Обесточенный прибор продолжает анализ")
	TEST_ASSERT_NULL(artifact.lab_owner, "Отключение питания оставило блокировку")
	TEST_ASSERT_NULL(pad.scan_owner, "Отключение питания оставило площадку занятой")
	lab.set_is_operational(TRUE)
	lab.seal_integrity = 0
	TEST_ASSERT(!lab.start_scan(), "Разрушенное уплотнение допускает запуск")

/** Появление более приоритетной свободной площадки не меняет площадку активного анализа. */
/datum/unit_test/xenoarchaeology_pad_binding/Run()
	var/obj/machinery/xenoarch_lab/analyzer/lab = allocate(__IMPLIED_TYPE__)
	lab.set_is_operational(TRUE)
	var/obj/machinery/xenoarch_pad/one = allocate(__IMPLIED_TYPE__, get_step(lab, NORTH))
	var/obj/machinery/xenoarch_pad/two = allocate(__IMPLIED_TYPE__, get_step(lab, EAST))
	var/obj/machinery/xenoarch_pad/preferred = lab.get_pad()
	var/obj/machinery/xenoarch_pad/working = preferred == one ? two : one
	preferred.set_anchored(FALSE)
	allocate(/obj/machinery/xenoartifact/test_fixture, get_turf(working))
	TEST_ASSERT(lab.start_scan(), "Не начался анализ на единственной доступной площадке")
	preferred.set_anchored(TRUE)
	lab.process(1)
	TEST_ASSERT(lab.active, "Другая свободная площадка прервала анализ")
	TEST_ASSERT_EQUAL(lab.progress, 1, "Потерян прогресс на исходной площадке")
	working.set_anchored(FALSE)
	lab.process(1)
	TEST_ASSERT(!lab.active, "Потеря крепления занятой площадки не остановила анализ")
	TEST_ASSERT_NULL(working.scan_owner, "Остановка не освободила занятую площадку")

/// Обычный анализатор, ручной прибор и сборщик не перехватывают одну занятую площадку.
/datum/unit_test/xenoarchaeology_pad_exclusive/Run()
	var/obj/machinery/xenoarch_pad/pad = allocate(__IMPLIED_TYPE__)
	var/obj/machinery/xenoarch_lab/analyzer/controlled/controlled = allocate(__IMPLIED_TYPE__, get_step(pad, NORTH))
	var/obj/machinery/xenoarch_lab/analyzer/analyzer = allocate(__IMPLIED_TYPE__, get_step(pad, EAST))
	var/obj/machinery/xenoarch_lab/harvester/harvester = allocate(__IMPLIED_TYPE__, get_step(pad, WEST))
	// У этих целей нет lab_owner: проверяется именно владение площадкой, а не артефактом.
	allocate(/obj/structure/constructshell, get_turf(pad))
	controlled.set_is_operational(TRUE)
	analyzer.set_is_operational(TRUE)
	TEST_ASSERT(controlled.start_scan(), "Не начался первый анализ")
	TEST_ASSERT_NULL(analyzer.get_pad(), "Обычный анализатор видит чужую занятую площадку")
	TEST_ASSERT_NULL(harvester.get_pad(), "Сборщик видит чужую занятую площадку")
	TEST_ASSERT(!analyzer.start_scan(), "Второй анализатор перехватил площадку")
	controlled.stop_work()
	TEST_ASSERT(analyzer.start_scan(), "Освобождённая площадка недоступна обычному анализатору")
	TEST_ASSERT_NULL(controlled.get_pad(), "Ручной прибор видит площадку занятого анализатора")
	analyzer.stop_work()
	TEST_ASSERT_EQUAL(controlled.get_pad(), pad, "После остановки площадка не освобождена")

/// Настройки проходят настоящую ui_act-границу, включая закрытый UI и недопустимые числа.
/datum/unit_test/xenoarchaeology_controlled_controls/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/machinery/xenoarch_lab/analyzer/controlled/lab = allocate(__IMPLIED_TYPE__)
	lab.set_is_operational(TRUE)
	var/datum/tgui/ui = allocate(/datum/tgui, user, lab, "XenoartifactLab")
	for(var/value in list(-1, 0, 1.5, 10001, "5000"))
		TEST_ASSERT(!lab.ui_act("set_wavelength", list("value" = value), ui), "Сервер принял недопустимую волну [value]")
	TEST_ASSERT(lab.ui_act("set_wavelength", list("value" = 4200), ui), "Сервер отклонил допустимую волну")
	TEST_ASSERT_EQUAL(lab.wavelength, 4200, "Настройка волны не применена")
	TEST_ASSERT(lab.ui_act("set_coolant_rate", list("value" = 2.5), ui), "Не установлен расход")
	TEST_ASSERT_EQUAL(lab.coolant_rate, 2.5, "Расход не соответствует вводу")
	TEST_ASSERT(!lab.ui_act("set_coolant_rate", list("value" = -1), ui), "Сервер принял отрицательный расход")
	ui.status = UI_CLOSE
	lab.ui_act("set_wavelength", list("value" = 1000), ui)
	TEST_ASSERT_EQUAL(lab.wavelength, 4200, "Закрытый UI изменил настройку")
	ui.status = UI_INTERACTIVE
	user.forceMove(get_step(get_step(lab, NORTH), NORTH))
	TEST_ASSERT(!lab.ui_act("toggle_shield", list(), ui), "Удалившийся пользователь управляет экраном")
	TEST_ASSERT(lab.shield_closed, "Удалённая команда открыла экран")

/** Настоящие ЛКМ/ПКМ переливают дозу ёмкости без диалогов; крышка и работающий прибор блокируют перелив. */
/datum/unit_test/xenoarchaeology_controlled_coolant/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/machinery/xenoarch_lab/analyzer/controlled/lab = allocate(__IMPLIED_TYPE__)
	lab.set_is_operational(TRUE)
	var/obj/item/reagent_containers/cup/beaker/beaker = allocate(__IMPLIED_TYPE__)
	beaker.amount_per_transfer_from_this = 5
	beaker.reagents.add_reagent(/datum/reagent/water, 40)
	user.put_in_active_hand(beaker)
	beaker.has_lid = TRUE
	click_wrapper(user, lab)
	TEST_ASSERT_EQUAL(lab.reagents.total_volume, 0, "Закрытый стакан залил хладагент")
	beaker.has_lid = FALSE
	click_wrapper(user, lab)
	TEST_ASSERT_EQUAL(lab.reagents.total_volume, 5, "ЛКМ не перелил заданную дозу в контур")
	TEST_ASSERT_EQUAL(beaker.reagents.total_volume, 35, "Залив не израсходовал дозу стакана")
	beaker.has_lid = TRUE
	click_wrapper(user, lab, list(RIGHT_CLICK = "1"))
	TEST_ASSERT_EQUAL(lab.reagents.total_volume, 5, "ПКМ слил контур в закрытую ёмкость")
	beaker.has_lid = FALSE
	click_wrapper(user, lab, list(RIGHT_CLICK = "1"))
	TEST_ASSERT_EQUAL(lab.reagents.total_volume, 0, "ПКМ не слил хладагент")
	TEST_ASSERT_EQUAL(beaker.reagents.total_volume, 40, "Хладагент не вернулся в стакан")
	var/obj/machinery/xenoarch_pad/pad = allocate(__IMPLIED_TYPE__, get_step(lab, NORTH))
	allocate(/obj/machinery/xenoartifact/test_fixture, get_turf(pad))
	TEST_ASSERT(lab.start_scan(), "Не начался анализ для проверки запрета перелива")
	click_wrapper(user, lab)
	TEST_ASSERT_EQUAL(lab.reagents.total_volume, 0, "Перелив разрешён во время анализа")
	lab.stop_work()
