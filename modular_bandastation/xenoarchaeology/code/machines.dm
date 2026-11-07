/// Общая ограниченная очередь образцов без отдельного невидимого контейнера и сильных ссылок.
/obj/machinery/xenoarch
	abstract_type = /obj/machinery/xenoarch
	icon = 'modular_bandastation/xenoarchaeology/icons/base/xenoarch_machines.dmi'
	icon_state = "basic"
	density = TRUE
	anchored = TRUE
	idle_power_usage = 100
	active_power_usage = 500
	use_power = IDLE_POWER_USE
	interaction_flags_machine = parent_type::interaction_flags_machine | INTERACT_MACHINE_OFFLINE
	/// Время обработки одного образца, в секундах.
	var/process_duration = 10
	/// Накопленное время обработки первого образца, в секундах.
	var/progress = 0
	/// Максимальное число образцов, исключая штатные детали машины.
	var/capacity = 25

/obj/machinery/xenoarch/RefreshParts()
	. = ..()
	var/improvement = 0
	for(var/datum/stock_part/part in component_parts)
		improvement += max(0, part.tier - 1)
	process_duration = max(1, initial(process_duration) - improvement * 0.1)

/obj/machinery/xenoarch/screwdriver_act(mob/living/user, obj/item/tool)
	return default_deconstruction_screwdriver(user, tool)

/obj/machinery/xenoarch/crowbar_act(mob/living/user, obj/item/tool)
	return default_deconstruction_crowbar(user, tool)

/obj/machinery/xenoarch/wrench_act(mob/living/user, obj/item/tool)
	return default_unfasten_wrench(user, tool)

/obj/machinery/xenoarch/proc/accepts(obj/item/xenoarch/sample/sample)
	return istype(sample, /obj/item/xenoarch/strange_rock) && !sample.anchored && !sample.working && !sample.resolved && !QDELETED(sample)

/obj/machinery/xenoarch/proc/sample_count()
	var/amount = 0
	for(var/obj/item/xenoarch/sample/sample in contents)
		amount++
	return amount

/// Поштучная проверка и перенос через API storage сохраняют сигналы и ограничения предметов.
/obj/machinery/xenoarch/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/storage/bag/xenoarch) && !accepts(tool))
		return ..()
	if(panel_open || !anchored || !is_operational)
		return ITEM_INTERACT_BLOCKING
	if(istype(tool, /obj/item/storage/bag/xenoarch))
		var/inserted = 0
		for(var/obj/item/xenoarch/sample/sample in tool.contents)
			if(sample_count() >= capacity)
				break
			if(accepts(sample) && tool.atom_storage.attempt_remove(sample, src, silent = TRUE))
				inserted++
		balloon_alert(user, "загружено: [inserted]")
		return ITEM_INTERACT_SUCCESS
	if(accepts(tool) && sample_count() < capacity && user.transferItemToLoc(tool, src))
		balloon_alert(user, "образец загружен")
		return ITEM_INTERACT_SUCCESS
	return ..()

/obj/machinery/xenoarch/Exited(atom/movable/gone, direction)
	. = ..()
	if(istype(gone, /obj/item/xenoarch/sample))
		progress = 0

/obj/machinery/xenoarch/process(seconds_per_tick)
	if(!is_operational || !anchored || panel_open || !sample_count())
		progress = 0
		update_use_power(IDLE_POWER_USE)
		return
	update_use_power(ACTIVE_POWER_USE)
	progress += seconds_per_tick
	if(progress < process_duration)
		return
	progress = 0
	for(var/obj/item/xenoarch/sample/sample in contents)
		if(accepts(sample))
			process_sample(sample)
		break

/obj/machinery/xenoarch/proc/process_sample(obj/item/xenoarch/strange_rock/sample)
	return

/obj/machinery/xenoarch/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "Xenoarchaeology", name)
		ui.open()

/obj/machinery/xenoarch/ui_data(mob/user)
	return list("queued" = sample_count(), "capacity" = capacity, "progress" = progress / process_duration, "operational" = is_operational && anchored && !panel_open)

/obj/machinery/xenoarch/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(action == "eject")
		for(var/obj/item/xenoarch/sample/sample in contents)
			sample.forceMove(drop_location())
		progress = 0
		return TRUE

/obj/machinery/xenoarch/scanner
	icon_state = "scanner"
	name = "сканер археологических образцов"
	desc = "Измеряет образцы и отмечает точную глубину находки. Завершённые образцы выдаются на пол."
	circuit = /obj/item/circuitboard/machine/xenoarch/scanner

/obj/machinery/xenoarch/scanner/process_sample(obj/item/xenoarch/strange_rock/sample)
	sample.scanned = TRUE
	sample.measured = TRUE
	sample.precise_scan = TRUE
	sample.forceMove(drop_location())

/obj/machinery/xenoarch/digger
	icon_state = "digger"
	name = "автоматический археологический раскопщик"
	desc = "Бережно извлекает находки из археологических образцов. Осадочные оболочки всё ещё нужно очищать кисточкой."
	circuit = /obj/item/circuitboard/machine/xenoarch/digger

/obj/machinery/xenoarch/digger/process_sample(obj/item/xenoarch/strange_rock/sample)
	sample.forceMove(drop_location())
	sample.dug_depth = sample.item_depth
	sample.try_uncover()

/obj/machinery/xenoarch/researcher
	icon_state = "researcher"
	name = "археологический исследователь"
	desc = "Перерабатывает образцы за 10 очков и осадочные оболочки за 15 очков. Накопленные очки можно обменять на находки."
	circuit = /obj/item/circuitboard/machine/xenoarch/researcher
	/// Внутренние очки машины; не являются очками общей сети исследований.
	var/research = 0
	/// Максимум очков, при котором очередь останавливается без уничтожения следующего образца.
	var/max_research = 300

/obj/machinery/xenoarch/researcher/accepts(obj/item/xenoarch/sample/sample)
	return istype(sample) && !sample.anchored && !sample.working && !sample.resolved && !QDELETED(sample)

/obj/machinery/xenoarch/researcher/process_sample(obj/item/xenoarch/sample/sample)
	var/value = istype(sample, /obj/item/xenoarch/broken_item) ? 15 : 10
	if(research + value > max_research)
		return
	sample.resolved = TRUE
	research += value
	qdel(sample)

/obj/machinery/xenoarch/researcher/ui_data(mob/user)
	. = ..()
	.["research"] = research
	.["maxResearch"] = max_research

/// Статический выбор проверяется сервером; списание предшествует созданию награды.
/obj/machinery/xenoarch/researcher/proc/redeem(reward)
	if(!is_operational || !anchored || panel_open)
		return FALSE
	var/cost
	var/reward_type
	switch(reward)
		if("crate")
			cost = 100
			reward_type = /obj/structure/closet/crate/necropolis/tendril
		if("crystal")
			cost = 100
			reward_type = pick(subtypesof(/obj/machinery/anomalous_crystal) - /obj/machinery/anomalous_crystal/theme_warp)
		if("technology")
			cost = 60
			if(!length(SSresearch.techweb_nodes_experimental))
				return FALSE
			reward_type = /obj/item/disk/design_disk/bepis/remove_tech
		else
			return FALSE
	if(research < cost)
		return FALSE
	research -= cost
	new reward_type(drop_location())
	return TRUE

/obj/machinery/xenoarch/researcher/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(action == "redeem")
		return redeem(params["reward"])

/obj/item/circuitboard/machine/xenoarch
	abstract_type = /obj/item/circuitboard/machine/xenoarch
	greyscale_colors = CIRCUIT_COLOR_SCIENCE
	req_components = list(/datum/stock_part/servo = 1, /datum/stock_part/scanning_module = 1)

/obj/item/circuitboard/machine/xenoarch/scanner
	name = "archaeological sample scanner"
	build_path = /obj/machinery/xenoarch/scanner

/obj/item/circuitboard/machine/xenoarch/digger
	name = "automatic archaeological excavator"
	build_path = /obj/machinery/xenoarch/digger

/obj/item/circuitboard/machine/xenoarch/researcher
	name = "archaeological sample researcher"
	build_path = /obj/machinery/xenoarch/researcher
