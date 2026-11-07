/// Образец с единственным владельцем текущего действия и однократной выдачей содержимого.
/obj/item/xenoarch/sample
	inhand_icon_state = "Gibtonite ore"
	lefthand_file = 'icons/mob/inhands/items_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items_righthand.dmi'
	abstract_type = /obj/item/xenoarch/sample
	icon_state = "rock"
	custom_materials = null
	/// Блокирует одновременную работу нескольких игроков с образцом.
	var/working = FALSE
	/// Устанавливается до выдачи награды или удаления, включая отложенный qdel.
	var/resolved = FALSE

/// Проверяет доступность образца и инструмента как до, так и после ожидания.
/obj/item/xenoarch/sample/proc/can_work(mob/living/user, obj/item/tool)
	if(QDELETED(src) || resolved || QDELETED(user) || QDELETED(tool))
		return FALSE
	if(!user.is_holding(tool) || (!isturf(loc) && loc != user))
		return FALSE
	return user.can_perform_action(src, NEED_DEXTERITY|NEED_HANDS|FORBID_TELEKINESIS_REACH)

/// Удерживает блокировку образца на время действия и повторно проверяет его доступность.
/obj/item/xenoarch/sample/proc/work(mob/living/user, obj/item/tool, duration)
	if(working)
		balloon_alert(user, "с образцом уже работают!")
		return FALSE
	if(!can_work(user, tool))
		return FALSE
	working = TRUE
	var/success = do_after(user, duration, target = src, extra_checks = CALLBACK(src, PROC_REF(can_work), user, tool))
	if(QDELETED(src))
		return FALSE
	working = FALSE
	if(!success)
		// Штраф относится к уже начатому действию: смена рук или отход тоже прерывают раскопку.
		if(!resolved)
			work_interrupted()
			if(!QDELETED(user))
				balloon_alert(user, "работа прервана!")
		return FALSE
	return can_work(user, tool)

/// Последствия прерывания зависят от вида образца.
/obj/item/xenoarch/sample/proc/work_interrupted()
	return

/// Камень с неизвестной глубиной находки; сначала снимается порода, затем извлекается содержимое.
/obj/item/xenoarch/strange_rock
	parent_type = /obj/item/xenoarch/sample
	name = "archaeological rock"
	desc = "Минеральный образец с посторонним включением. Просканируйте и измерьте его перед раскопками. Прерывание действия повреждает образец."
	/// Максимальная глубина образца, в сантиметрах.
	var/max_depth
	/// Ширина интервала, в котором находится предмет.
	var/safe_depth
	/// Скрытая глубина находки.
	var/item_depth
	/// Глубина уже снятой породы.
	var/dug_depth
	/// Путь генератора награды; не ссылка на созданный предмет.
	var/hidden_item
	/// Показывать ли текущую глубину при осмотре.
	var/measured = FALSE
	/// Показывать ли параметры сканирования при осмотре.
	var/scanned = FALSE
	/// Улучшенный сканер показывает точную глубину находки.
	var/precise_scan = FALSE

/obj/item/xenoarch/strange_rock/Initialize(mapload)
	. = ..()
	var/tier = rand(1, 100)
	switch(tier)
		if(1 to 50)
			tier = 1
			hidden_item = /obj/effect/spawner/random/xenoarch/tier1
		if(51 to 87)
			tier = 2
			hidden_item = /obj/effect/spawner/random/xenoarch/tier2
		if(88 to 100)
			tier = 3
			hidden_item = /obj/effect/spawner/random/xenoarch/tier3
	max_depth = rand(21, 22 * tier)
	safe_depth = rand(1, 10)
	item_depth = rand(max_depth - safe_depth, max_depth)
	dug_depth = rand(0, 10)

/obj/item/xenoarch/strange_rock/examine(mob/user)
	. = ..()
	if(scanned)
		. += span_notice("Максимальная глубина: [max_depth] см. Безопасный интервал: [safe_depth] см. Перейдите на кисточку на глубине [max_depth - safe_depth] см.")
	else
		. += span_notice("Образец ещё не просканирован.")
	if(precise_scan)
		. += span_notice("Точная глубина находки: [item_depth] см.")
	if(measured)
		. += span_notice("Текущая глубина раскопки: [dug_depth] см.")
		if(dug_depth > item_depth)
			. += span_warning("Образец крошится: следующая попытка раскопки уничтожит его!")
	else
		. += span_notice("Глубина раскопки ещё не отмечена измерителем.")

/obj/item/xenoarch/strange_rock/work_interrupted()
	dug_depth += rand(1, 5)

/// Снимает положительный целый слой; превышение глубины безвозвратно разрушает находку.
/obj/item/xenoarch/strange_rock/proc/try_dig(dig_amount)
	if(QDELETED(src) || resolved || !isnum(dig_amount) || dig_amount <= 0 || dig_amount != round(dig_amount))
		return FALSE
	dug_depth += dig_amount
	if(dug_depth > item_depth)
		resolved = TRUE
		qdel(src)
		return FALSE
	return TRUE

/// Кисточка снимает 1 см или однократно извлекает предмет, если достигнута его глубина.
/obj/item/xenoarch/strange_rock/proc/try_uncover()
	if(QDELETED(src) || resolved)
		return FALSE
	if(dug_depth > item_depth)
		resolved = TRUE
		qdel(src)
		return FALSE
	if(dug_depth < item_depth)
		try_dig(1)
		return FALSE
	if(!ispath(hidden_item, /obj))
		return FALSE
	resolved = TRUE
	new hidden_item(drop_location())
	qdel(src)
	return TRUE

/obj/item/xenoarch/strange_rock/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(istype(tool, /obj/item/xenoarch/hammer))
		var/obj/item/xenoarch/hammer/hammer = tool
		var/depth = hammer.dig_amount
		balloon_alert(user, "снимаю породу...")
		if(work(user, tool, hammer.dig_speed))
			if(try_dig(depth))
				balloon_alert(user, "слой породы снят")
			else
				user.balloon_alert(user, "образец разрушен!")
		return ITEM_INTERACT_SUCCESS
	if(istype(tool, /obj/item/xenoarch/brush))
		var/obj/item/xenoarch/brush/brush = tool
		balloon_alert(user, "очищаю породу...")
		if(work(user, tool, brush.dig_speed))
			if(try_uncover())
				user.balloon_alert(user, "находка извлечена")
			else if(QDELETED(src))
				user.balloon_alert(user, "образец разрушен!")
			else
				balloon_alert(user, "нужна дальнейшая очистка")
		return ITEM_INTERACT_SUCCESS
	if(istype(tool, /obj/item/xenoarch/measuring_tape))
		if(measured)
			balloon_alert(user, "глубина уже отмечена")
		else if(work(user, tool, 4 SECONDS))
			measured = TRUE
			balloon_alert(user, "глубина отмечена")
		return ITEM_INTERACT_SUCCESS
	if(istype(tool, /obj/item/xenoarch/handheld_scanner))
		var/obj/item/xenoarch/handheld_scanner/scanner = tool
		if(precise_scan || (scanned && !scanner.advanced))
			balloon_alert(user, "образец уже просканирован")
		else if(work(user, tool, scanner.scanning_speed))
			scanned = TRUE
			precise_scan = scanner.advanced
			balloon_alert(user, "образец просканирован")
		return ITEM_INTERACT_SUCCESS
	return ..()

/// Извлечённая находка, которую ещё нужно очистить кисточкой от осадочной оболочки.
/obj/item/xenoarch/broken_item
	parent_type = /obj/item/xenoarch/sample
	name = "sediment encased tool"
	desc = "Предмет под слоем затвердевших отложений. Примените археологическую кисточку, чтобы очистить его."
	icon_state = "recover_tech"
	/// Путь генератора содержимого осадочной оболочки.
	var/loot = /obj/effect/spawner/random/xenoarch/tools

/// Однократно раскрывает оболочку; блокировка ставится до создания содержимого.
/obj/item/xenoarch/broken_item/proc/recover()
	if(QDELETED(src) || resolved || !ispath(loot, /obj))
		return FALSE
	resolved = TRUE
	new loot(drop_location())
	qdel(src)
	return TRUE

/obj/item/xenoarch/broken_item/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/xenoarch/brush))
		return ..()
	if(work(user, tool, 0 SECONDS) && recover())
		user.mind?.adjust_experience(/datum/skill/xenoarchaeology, 5)
		user.balloon_alert(user, "находка очищена")
	return ITEM_INTERACT_SUCCESS
