/// Площадка связывает соседние лабораторные машины с объектом на её клетке.
/obj/machinery/xenoarch_pad
	name = "площадка анализа артефактов"
	desc = "Поставьте артефакт на площадку, а анализатор или сборщик частиц — рядом."
	icon = 'modular_bandastation/xenoarchaeology/icons/artifacts/machinery.dmi'
	icon_state = "xenoarch_scanner"
	anchored = TRUE
	density = FALSE
	layer = 4.25
	use_power = NO_POWER_USE
	circuit = /obj/item/circuitboard/machine/xenoarch/pad
	/// Слабая связь нужна только для анимации площадки во время работы соседней машины.
	var/datum/weakref/scan_owner

/obj/machinery/xenoarch_pad/Initialize(mapload)
	. = ..()
	var/static/mutable_appearance/scanner_bottom
	if(isnull(scanner_bottom))
		scanner_bottom = mutable_appearance(icon, "xenoarch_scanner_bottom", ABOVE_NORMAL_TURF_LAYER)
	add_overlay(scanner_bottom)

/obj/machinery/xenoarch_pad/Destroy()
	scan_owner = null
	return ..()

/obj/machinery/xenoarch_pad/update_icon_state()
	. = ..()
	var/obj/machinery/xenoarch_lab/lab = scan_owner?.resolve()
	icon_state = lab?.active ? "xenoarch_scanner_scanning" : "xenoarch_scanner"

/// Лаборатория хранит слабую ссылку на внешнюю цель и владеет только вставленными предметами.
/obj/machinery/xenoarch_lab
	abstract_type = /obj/machinery/xenoarch_lab
	icon = 'modular_bandastation/xenoarchaeology/icons/artifacts/machinery.dmi'
	icon_state = "xenoarch_console"
	density = TRUE
	anchored = TRUE
	idle_power_usage = 50
	active_power_usage = 750
	use_power = IDLE_POWER_USE
	interaction_flags_machine = parent_type::interaction_flags_machine | INTERACT_MACHINE_OFFLINE
	var/mode
	var/active = FALSE
	/// Секунды анализа, в отличие от зарядов батареи.
	var/progress = 0
	var/scan_duration = 10
	var/report = ""
	var/datum/weakref/target_ref
	var/datum/weakref/working_pad
	var/target_was_anchored = FALSE
	/// Сигнатура хранится строкой и не удерживает эффект или артефакт.
	var/signature

/obj/machinery/xenoarch_lab/Destroy()
	stop_work()
	return ..()

/obj/machinery/xenoarch_lab/screwdriver_act(mob/living/user, obj/item/tool)
	stop_work()
	return default_deconstruction_screwdriver(user, tool)

/obj/machinery/xenoarch_lab/crowbar_act(mob/living/user, obj/item/tool)
	return default_deconstruction_crowbar(user, tool)

/obj/machinery/xenoarch_lab/wrench_act(mob/living/user, obj/item/tool)
	stop_work()
	return default_unfasten_wrench(user, tool)

/obj/machinery/xenoarch_lab/on_set_is_operational(old_value)
	. = ..()
	if(!is_operational)
		stop_work()

/obj/machinery/xenoarch_lab/proc/get_battery()
	return locate(/obj/item/xenoarch/particle_battery) in contents

/obj/machinery/xenoarch_lab/proc/get_sample()
	return locate(/obj/item/xenoarch/core_sampler) in contents

/// При каждом обращении площадка ищется заново: перенос или удаление не оставляет висячей связи.
/obj/machinery/xenoarch_lab/proc/get_pad()
	for(var/obj/machinery/xenoarch_pad/pad in orange(1, src))
		if(pad.anchored)
			return pad
	return null

/obj/machinery/xenoarch_lab/proc/find_scan_target(obj/machinery/xenoarch_pad/pad)
	for(var/obj/target in get_turf(pad))
		if(target.invisibility || HAS_TRAIT(target, TRAIT_UNDERFLOOR))
			continue
		if(istype(target, /obj/machinery/xenoartifact) || istype(target, /obj/machinery/power/xenoarch_crystal) || ismecha(target) || istype(target, /obj/structure/constructshell) || istype(target, /obj/machinery/power/supermatter_crystal/shard))
			return target
	return null

/obj/machinery/xenoarch_lab/proc/ready()
	return !QDELETED(src) && is_operational && anchored && !panel_open

/obj/machinery/xenoarch_lab/proc/stop_work()
	var/obj/machinery/xenoarch_pad/pad = working_pad?.resolve()
	if(pad?.scan_owner?.resolve() == src)
		pad.scan_owner = null
		pad.update_appearance()
	working_pad = null
	var/obj/machinery/xenoartifact/artifact = target_ref?.resolve()
	if(istype(artifact) && artifact.lab_owner?.resolve() == src)
		artifact.lab_owner = null
		artifact.anchored = target_was_anchored
	var/obj/item/xenoarch/particle_battery/battery = get_battery()
	if(mode == "draining")
		battery?.battery_effect?.turn_effect_off()
		mode = "harvester"
	active = FALSE
	progress = 0
	target_ref = null
	signature = null
	update_use_power(IDLE_POWER_USE)
	update_appearance()

/// Все варианты лаборатории используют один набор переходов запуска, отмены и отключения.
/obj/machinery/xenoarch_lab/update_icon_state()
	. = ..()
	switch(mode)
		if("spectrometer")
			icon_state = active ? "spectrometer_processing" : "spectrometer"
		if("harvester", "draining")
			icon_state = active ? "harvester_on" : get_battery() ? "harvester_battery" : "harvester"
		else
			icon_state = "xenoarch_console"

/obj/machinery/xenoarch_lab/Exited(atom/movable/gone, direction)
	. = ..()
	if(istype(gone, /obj/item/xenoarch/particle_battery))
		var/obj/item/xenoarch/particle_battery/battery = gone
		battery.battery_effect?.turn_effect_off()
	if(istype(gone, /obj/item/xenoarch))
		stop_work()

/obj/machinery/xenoarch_lab/Entered(atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	. = ..()
	if(istype(arrived, /obj/item/xenoarch/particle_battery))
		update_appearance()

/obj/machinery/xenoarch_lab/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	var/loading_sample = mode == "spectrometer" && istype(tool, /obj/item/xenoarch/core_sampler)
	var/loading_battery = mode == "harvester" && istype(tool, /obj/item/xenoarch/particle_battery)
	if(!loading_sample && !loading_battery)
		return ..()
	if(active || !ready())
		return ITEM_INTERACT_BLOCKING
	if(loading_sample && !get_sample())
		var/obj/item/xenoarch/core_sampler/sample = tool
		if(sample.sample_data && user.transferItemToLoc(tool, src))
			return ITEM_INTERACT_SUCCESS
	if(loading_battery && !get_battery() && user.transferItemToLoc(tool, src))
		return ITEM_INTERACT_SUCCESS
	return ..()

/obj/machinery/xenoarch_lab/proc/start_scan()
	if(active || !ready())
		return FALSE
	if(mode == "spectrometer")
		var/obj/item/xenoarch/core_sampler/sample = get_sample()
		if(!sample?.sample_data)
			return FALSE
	else if(mode == "analyzer")
		var/obj/machinery/xenoarch_pad/pad = get_pad()
		if(!pad)
			return FALSE
		var/obj/target = find_scan_target(pad)
		if(!target)
			return FALSE
		if(istype(target, /obj/machinery/xenoartifact))
			var/obj/machinery/xenoartifact/artifact = target
			if(artifact.lab_owner?.resolve())
				return FALSE
			target_was_anchored = artifact.anchored
			artifact.lab_owner = WEAKREF(src)
		target_ref = WEAKREF(target)
		working_pad = WEAKREF(pad)
	else
		return FALSE
	progress = 0
	active = TRUE
	update_use_power(ACTIVE_POWER_USE)
	update_appearance()
	var/obj/machinery/xenoarch_pad/pad = working_pad?.resolve()
	if(pad)
		pad.scan_owner = WEAKREF(src)
		pad.update_appearance()
	if(mode == "analyzer")
		flick("xenoarch_console_working", src)
	return TRUE

/obj/machinery/xenoarch_lab/proc/start_harvest()
	if(active || mode != "harvester" || !ready())
		return FALSE
	var/obj/item/xenoarch/particle_battery/battery = get_battery()
	var/obj/machinery/xenoarch_pad/pad = get_pad()
	if(!battery || !pad || battery.stored_charge >= battery.capacity)
		return FALSE
	var/obj/machinery/xenoartifact/artifact = locate() in get_turf(pad)
	if(!artifact || artifact.lab_owner?.resolve())
		return FALSE
	var/datum/xenoartifact_effect/effect
	for(var/datum/xenoartifact_effect/candidate in list(artifact.first_effect, artifact.secondary_effect))
		if(!candidate.activated)
			continue
		if(effect)
			return FALSE
		effect = candidate
	if(!effect)
		return FALSE
	var/new_signature = effect.emission_signature
	if(battery.stored_charge && battery.source_signature != new_signature)
		return FALSE
	if(!battery.stored_charge)
		QDEL_NULL(battery.battery_effect)
		battery.battery_effect = effect.copy_to(battery)
		battery.source_signature = new_signature
	target_ref = WEAKREF(artifact)
	target_was_anchored = artifact.anchored
	artifact.anchored = TRUE
	artifact.lab_owner = WEAKREF(src)
	signature = new_signature
	active = TRUE
	update_use_power(ACTIVE_POWER_USE)
	working_pad = WEAKREF(pad)
	pad.scan_owner = WEAKREF(src)
	pad.update_appearance()
	update_appearance()
	return TRUE

/obj/machinery/xenoarch_lab/process(seconds_per_tick)
	if(!active)
		return
	if(!ready())
		stop_work()
		return
	if(mode == "draining")
		var/obj/item/xenoarch/particle_battery/battery = get_battery()
		if(!battery?.battery_effect)
			stop_work()
			return
		battery.set_charge(battery.stored_charge - 2.5 * seconds_per_tick)
		if(battery.battery_effect.release_method == XENO_EFFECT_TOUCH)
			for(var/mob/living/victim in range(1, src))
				battery.battery_effect.do_effect_touch(victim)
		if(!battery.stored_charge)
			stop_work()
			QDEL_NULL(battery.battery_effect)
			battery.source_signature = null
		return
	if(mode == "spectrometer")
		if(!get_sample())
			stop_work()
			return
	else
		var/obj/target = target_ref?.resolve()
		var/obj/machinery/xenoarch_pad/pad = get_pad()
		if(!target || !pad || get_turf(target) != get_turf(pad))
			stop_work()
			return
		var/obj/machinery/xenoartifact/artifact = target
		if(istype(artifact) && artifact.lab_owner?.resolve() != src)
			stop_work()
			return
		if(mode == "harvester")
			var/obj/item/xenoarch/particle_battery/battery = get_battery()
			var/active_effects = 0
			for(var/datum/xenoartifact_effect/effect in list(artifact.first_effect, artifact.secondary_effect))
				if(effect.activated)
					active_effects++
					if(effect.emission_signature != signature)
						stop_work()
						return
			if(!battery?.battery_effect || active_effects != 1)
				stop_work()
				return
			battery.set_charge(battery.stored_charge + 2.5 * seconds_per_tick)
			if(battery.stored_charge == battery.capacity)
				stop_work()
			return
	progress += seconds_per_tick
	if(progress >= scan_duration)
		finish_scan()

/obj/machinery/xenoarch_lab/proc/finish_scan()
	if(mode == "spectrometer")
		var/obj/item/xenoarch/core_sampler/sample = get_sample()
		var/list/data = sample.sample_data
		var/list/fields = /obj/item/xenoarch/stabilizer::fields
		report = "Керн [data["id"]]. Возраст: [round(data["age"])] лет. Требуемое поле: [fields[data["field"]]]."
		qdel(sample)
	else
		var/obj/target = target_ref.resolve()
		if(istype(target, /obj/machinery/xenoartifact))
			var/obj/machinery/xenoartifact/artifact = target
			report = artifact.analysis_description()
		else if(istype(target, /obj/machinery/power/xenoarch_crystal))
			report = "Псевдоорганическая кристаллическая решётка генерирует энергию. Закрепите над узлом кабеля, добавьте два отрезка провода и коснитесь для включения. Мощность: 250 кВт."
		else if(ismecha(target))
			report = "Древний экзокостюм с современной компоновкой. Вероятна временная аномалия. Проверьте корпус, оборудование и батарею перед использованием."
		else if(istype(target, /obj/structure/constructshell))
			report = "Каменный идол с полостью, пригодной для заселения конструктом."
		else
			report = "Образец сверхматерии. Энергетически нестабилен; требует штатных мер обращения со сверхматерией."
	stop_work()
	print_report()

/obj/machinery/xenoarch_lab/proc/print_report()
	if(!length(report) || !ready())
		return FALSE
	var/obj/item/paper/xenoarch_report/paper = new(drop_location())
	paper.add_raw_text(html_encode(report))
	playsound(src, 'sound/machines/printer.ogg', 25, FALSE)
	return TRUE

/obj/machinery/xenoarch_lab/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "XenoartifactLab", name)
		ui.open()

/obj/machinery/xenoarch_lab/ui_data(mob/user)
	var/obj/item/xenoarch/particle_battery/battery = get_battery()
	var/obj/item/xenoarch/core_sampler/sample = get_sample()
	return list("mode" = mode, "active" = active, "operational" = ready(), "progress" = progress / scan_duration, "report" = report, "hasPad" = !!get_pad(), "hasSample" = !!sample, "hasBattery" = !!battery, "charge" = battery?.stored_charge || 0, "capacity" = battery?.capacity || 200)

/obj/machinery/xenoarch_lab/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	switch(action)
		if("stop")
			stop_work()
			return TRUE
		if("eject")
			stop_work()
			for(var/obj/item/xenoarch/item in contents)
				item.forceMove(drop_location())
			return TRUE
		if("scan")
			return start_scan()
		if("harvest")
			return start_harvest()
		if("drain")
			var/obj/item/xenoarch/particle_battery/battery = get_battery()
			if(active || !ready() || mode != "harvester" || !battery?.battery_effect || battery.stored_charge <= 0)
				return FALSE
			mode = "draining"
			active = TRUE
			battery.battery_effect.ToggleActivate()
			update_use_power(ACTIVE_POWER_USE)
			update_appearance()
			log_combat(ui.user, src, "начал опасный разряд батареи артефакта")
			return TRUE

/obj/machinery/xenoarch_lab/analyzer
	name = "анализатор артефактов"
	desc = "Изучает излучение артефакта на соседней площадке и печатает отчёт."
	mode = "analyzer"
	circuit = /obj/item/circuitboard/machine/xenoarch/analyzer

/obj/machinery/xenoarch_lab/spectrometer
	icon_state = "spectrometer"
	name = "радиоуглеродный спектрометр"
	desc = "Анализирует керн, определяя возраст находки и требуемое стабилизирующее поле."
	mode = "spectrometer"
	circuit = /obj/item/circuitboard/machine/xenoarch/spectrometer

/obj/machinery/xenoarch_lab/harvester
	icon_state = "harvester"
	name = "сборщик экзотических частиц"
	desc = "Копирует единственное активное излучение артефакта на площадке в батарею. Разряд батареи высвобождает накопленный эффект рядом с машиной."
	mode = "harvester"
	circuit = /obj/item/circuitboard/machine/xenoarch/harvester

/obj/item/paper/xenoarch_report
	name = "archaeological analysis report"

/obj/item/circuitboard/machine/xenoarch/pad
	name = "artifact analysis pad"
	build_path = /obj/machinery/xenoarch_pad

/obj/item/circuitboard/machine/xenoarch/analyzer
	name = "artifact radiation analyzer"
	build_path = /obj/machinery/xenoarch_lab/analyzer
	req_components = list(/datum/stock_part/scanning_module = 2, /obj/item/stack/sheet/glass = 1)

/obj/item/circuitboard/machine/xenoarch/spectrometer
	name = "radiocarbon spectrometer"
	build_path = /obj/machinery/xenoarch_lab/spectrometer
	req_components = list(/datum/stock_part/scanning_module = 4, /obj/item/reagent_containers/cup/beaker = 1, /obj/item/stack/sheet/glass = 1)

/obj/item/circuitboard/machine/xenoarch/harvester
	name = "exotic particle harvester"
	build_path = /obj/machinery/xenoarch_lab/harvester
	req_components = list(/datum/stock_part/scanning_module = 2, /datum/stock_part/capacitor = 4, /datum/stock_part/servo = 2, /datum/stock_part/amplifier = 1, /datum/stock_part/filter = 1)
