#define XENO_SPECTROMETER_MAX_WAVELENGTH 10000
#define XENO_SPECTROMETER_MAX_TEMPERATURE 1000
#define XENO_SPECTROMETER_MAX_COOLANT_RATE 10

/// Ручной цикл Sierra поверх штатных площадки, блокировки, остановки и отчёта лаборатории.
/obj/machinery/xenoarch_lab/analyzer/controlled
	name = "управляемый спектрометр артефактов"
	desc = "Настраиваемый анализатор: следите за длиной волны, охлаждением и всплесками излучения. Закрытый защитный экран приостанавливает анализ, но не охлаждает ротор."
	icon = 'modular_bandastation/xenoarchaeology/icons/sierra/virology.dmi'
	icon_state = "analyser"
	scan_animation = null
	circuit = /obj/item/circuitboard/machine/xenoarch/controlled_spectrometer
	scan_duration = 80
	/// Тепловая нагрузка контура в градусах Цельсия.
	var/scanner_temperature = 20
	/// Обороты ротора и направление изменения скорости.
	var/scanner_rpm = 0
	var/rpm_direction = 1
	/// Остаток ресурса уплотнения, в процентах.
	var/seal_integrity = 100
	/// Расход смеси из внутреннего контура, единиц реагента в секунду.
	var/coolant_rate = 0
	/// Настройка оператора и плавно меняющаяся требуемая длина волны, в условных единицах.
	var/wavelength = 5000
	var/optimal_wavelength = 5000
	var/target_wavelength = 5000
	/// Секунды до следующего изменения требуемой волны и всплеска излучения.
	var/wavelength_timer = 0
	var/radiation_timer = 0
	var/radiation_burst = 0
	/// Защитный экран останавливает луч и его прогресс.
	var/shield_closed = TRUE
	COOLDOWN_DECLARE(radiation_pulse_cooldown)

/obj/machinery/xenoarch_lab/analyzer/controlled/Initialize(mapload)
	. = ..()
	create_reagents(500, NO_REACT)

/obj/machinery/xenoarch_lab/analyzer/controlled/update_icon_state()
	. = ..()
	icon_state = active ? "analyser_processing" : "analyser"

/obj/machinery/xenoarch_lab/analyzer/controlled/start_scan()
	if(seal_integrity <= 0 || scanner_temperature >= XENO_SPECTROMETER_MAX_TEMPERATURE)
		balloon_alert_to_viewers("требуется обслуживание!")
		return FALSE
	. = ..()
	if(!.)
		return
	wavelength_timer = 0
	radiation_timer = rand(10, 20)
	radiation_burst = 0
	var/obj/machinery/xenoartifact/artifact = target_ref?.resolve()
	if(istype(artifact))
		artifact.anchored = TRUE

/obj/machinery/xenoarch_lab/analyzer/controlled/stop_work()
	. = ..()
	scanner_rpm = 0
	rpm_direction = 1
	radiation_burst = 0
	radiation_timer = 0
	coolant_rate = 0

/// Характеристики смеси вычисляются по фактическим реагентам, без второй копии объёма.
/obj/machinery/xenoarch_lab/analyzer/controlled/proc/get_coolant_quality()
	if(!reagents.total_volume)
		return 0
	var/static/list/coolants = list(
		/datum/reagent/water = 0.5,
		/datum/reagent/medicine/leporazine = 0.7,
		/datum/reagent/medicine/cryoxadone = 0.9,
		/datum/reagent/cryostylane = 1,
	)
	var/quality = 0
	for(var/datum/reagent/coolant as anything in reagents.reagent_list)
		quality += coolant.volume * (coolants[coolant.type] || 0.1)
	return quality / reagents.total_volume

/obj/machinery/xenoarch_lab/analyzer/controlled/proc/get_scan_efficiency()
	return clamp(1 - abs(optimal_wavelength - wavelength) * 3 / XENO_SPECTROMETER_MAX_WAVELENGTH, 0, 1)

/obj/machinery/xenoarch_lab/analyzer/controlled/process(seconds_per_tick)
	// Сначала родитель проверяет питание, площадку и владение; прогресс начисляется после расчёта эффективности.
	. = ..(0)
	if(!active)
		scanner_temperature = max(20, scanner_temperature - 10 * seconds_per_tick)
		return
	scanner_rpm = clamp(scanner_rpm + rpm_direction * 50 * seconds_per_tick, 1, 1000)
	if(scanner_rpm >= 1000)
		rpm_direction = -pick(0.5, 2.5, 5.5)
	else if(scanner_rpm <= 1)
		rpm_direction = pick(0.5, 2.5, 5.5)
	scanner_temperature += scanner_rpm * 0.05 * seconds_per_tick
	var/coolant_used = min(reagents.total_volume, coolant_rate * seconds_per_tick)
	if(coolant_used > 0)
		scanner_temperature = max(20, scanner_temperature - coolant_used * get_coolant_quality() * 20)
		reagents.remove_all(coolant_used)
	wavelength_timer -= seconds_per_tick
	if(wavelength_timer <= 0)
		wavelength_timer = pick(4, 8, 15)
		target_wavelength = rand(100, XENO_SPECTROMETER_MAX_WAVELENGTH)
	optimal_wavelength += clamp(target_wavelength - optimal_wavelength, -700 * seconds_per_tick, 700 * seconds_per_tick)
	radiation_burst = max(0, radiation_burst - seconds_per_tick)
	radiation_timer -= seconds_per_tick
	if(radiation_timer <= 0)
		radiation_burst = 5
		radiation_timer = rand(10, 25)
	if(!shield_closed)
		seal_integrity = max(0, seal_integrity - scanner_temperature / 1000 * seconds_per_tick)
	if(seal_integrity <= 0 || scanner_temperature >= XENO_SPECTROMETER_MAX_TEMPERATURE)
		stop_work()
		balloon_alert_to_viewers("аварийная остановка!")
		return
	if(!shield_closed && radiation_burst > 0 && COOLDOWN_FINISHED(src, radiation_pulse_cooldown))
		COOLDOWN_START(src, radiation_pulse_cooldown, 2 SECONDS)
		radiation_pulse(src, max_range = 3, threshold = RAD_LIGHT_INSULATION)
	return ..(shield_closed ? 0 : seconds_per_tick * get_scan_efficiency())

/obj/machinery/xenoarch_lab/analyzer/controlled/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/stack/nanopaste) && !istype(tool, /obj/item/reagent_containers/cup))
		return ..()
	if(active || !ready() || !user.Adjacent(src) || !user.is_holding(tool) || !user.can_perform_action(src, NEED_DEXTERITY|NEED_HANDS))
		return ITEM_INTERACT_BLOCKING
	if(istype(tool, /obj/item/stack/nanopaste))
		if(seal_integrity >= 100)
			balloon_alert(user, "уплотнение исправно")
			return ITEM_INTERACT_BLOCKING
		if(!do_after(user, 3 SECONDS, src))
			return ITEM_INTERACT_BLOCKING
		if(QDELETED(src) || QDELETED(tool) || QDELETED(user) || active || !ready() || seal_integrity >= 100 || !user.Adjacent(src) || !user.is_holding(tool) || !user.can_perform_action(src, NEED_DEXTERITY|NEED_HANDS))
			return ITEM_INTERACT_BLOCKING
		var/obj/item/stack/nanopaste/paste = tool
		if(!paste.use(1))
			return ITEM_INTERACT_BLOCKING
		seal_integrity = min(100, seal_integrity + 10)
		balloon_alert(user, "уплотнение восстановлено")
		return ITEM_INTERACT_SUCCESS
	var/obj/item/reagent_containers/cup/container = tool
	var/draining = text2num(LAZYACCESS(modifiers, RIGHT_CLICK))
	if(draining ? !container.is_refillable() : !container.is_drainable())
		balloon_alert(user, "ёмкость закрыта!")
		return ITEM_INTERACT_BLOCKING
	var/transferred = draining \
		? reagents.trans_to(container, container.amount_per_transfer_from_this) \
		: container.reagents.trans_to(src, container.amount_per_transfer_from_this)
	if(!transferred)
		balloon_alert(user, "нет жидкости или места!")
		return ITEM_INTERACT_BLOCKING
	balloon_alert(user, "[draining ? "слито" : "залито"]: [round(transferred, 0.1)] ед.")
	return ITEM_INTERACT_SUCCESS

/obj/machinery/xenoarch_lab/analyzer/controlled/examine(mob/user)
	. = ..()
	. += span_notice("Остановите прибор перед переливом. ЛКМ открытой ёмкостью — залить хладагент, ПКМ — слить в ёмкость. Объём задаётся дозой перелива ёмкости.")

/obj/machinery/xenoarch_lab/analyzer/controlled/ui_data(mob/user)
	. = ..()
	.["control"] = list(
		"temperature" = round(scanner_temperature, 0.1),
		"maxTemperature" = XENO_SPECTROMETER_MAX_TEMPERATURE,
		"rpm" = round(scanner_rpm),
		"seal" = round(seal_integrity, 0.1),
		"coolant" = round(reagents.total_volume, 0.1),
		"coolantCapacity" = reagents.maximum_volume,
		"coolantQuality" = get_coolant_quality(),
		"coolantRate" = coolant_rate,
		"maxCoolantRate" = XENO_SPECTROMETER_MAX_COOLANT_RATE,
		"wavelength" = wavelength,
		"optimalWavelength" = round(optimal_wavelength),
		"maxWavelength" = XENO_SPECTROMETER_MAX_WAVELENGTH,
		"efficiency" = shield_closed ? 0 : get_scan_efficiency(),
		"shieldClosed" = shield_closed,
		"radiationBurst" = radiation_burst > 0,
		"radiationTimer" = max(0, round(radiation_timer)),
	)

/obj/machinery/xenoarch_lab/analyzer/controlled/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(!ready() || !ui.user.can_perform_action(src, NEED_DEXTERITY|NEED_HANDS|ALLOW_SILICON_REACH))
		return FALSE
	switch(action)
		if("set_wavelength")
			var/value = params["value"]
			if(!isnum(value) || value < 1 || value > XENO_SPECTROMETER_MAX_WAVELENGTH || value != round(value))
				return FALSE
			wavelength = value
			return TRUE
		if("set_coolant_rate")
			var/value = params["value"]
			if(!isnum(value) || value < 0 || value > XENO_SPECTROMETER_MAX_COOLANT_RATE)
				return FALSE
			coolant_rate = round(value, 0.1)
			return TRUE
		if("toggle_shield")
			shield_closed = !shield_closed
			return TRUE

/obj/item/circuitboard/machine/xenoarch/controlled_spectrometer
	name = "controlled artifact spectrometer"
	build_path = /obj/machinery/xenoarch_lab/analyzer/controlled
	req_components = list(/datum/stock_part/scanning_module = 4, /datum/stock_part/servo = 2, /obj/item/reagent_containers/cup/beaker = 1, /obj/item/stack/sheet/glass = 1)

#undef XENO_SPECTROMETER_MAX_WAVELENGTH
#undef XENO_SPECTROMETER_MAX_TEMPERATURE
#undef XENO_SPECTROMETER_MAX_COOLANT_RATE
