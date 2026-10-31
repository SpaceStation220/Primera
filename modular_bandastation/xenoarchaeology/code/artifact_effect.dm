/// Эффект принадлежит одному артефакту или батарее и освобождает владельца при удалении.
/datum/xenoartifact_effect
	/// Режим излучения: касание, аура или накопленный импульс.
	var/release_method
	/// Радиус действия в клетках.
	var/range
	/// Условие активации.
	var/trigger
	/// Единственный владелец эффекта; эффект не разделяется с батареями.
	var/atom/holder
	var/activated = FALSE
	var/current_charge = 0
	var/maximum_charges
	/// Заряд за две секунды, как в исходном модуле.
	var/recharge_speed = 1
	var/artifact_id = ""
	/// REF удалённого объекта может переиспользоваться; заряд привязан к уникальному экземпляру излучения.
	var/emission_signature
	var/activation_touch_cost = 3
	var/activation_aura_cost = 0
	var/activation_pulse_cost
	var/log_name = "неизвестный эффект"
	var/type_name = XENO_EFFECT_UNKNOWN

/datum/xenoartifact_effect/New(atom/location)
	. = ..()
	holder = location
	emission_signature = GUID()
	release_method = pick(XENO_ALL_RELEASE_METHODS)
	trigger = pick(XENO_POSSIBLE_TRIGGERS)
	maximum_charges = rand(5, 50)
	range = rand(2, 10)
	activation_pulse_cost = maximum_charges

/datum/xenoartifact_effect/Destroy(force)
	turn_effect_off()
	holder = null
	return ..()

/datum/xenoartifact_effect/proc/ToggleActivate(reveal_toggle = TRUE)
	toggle_artifact_effect(reveal_toggle)

/datum/xenoartifact_effect/proc/toggle_artifact_effect(reveal_toggle)
	activated = !activated
	if(activated)
		START_PROCESSING(SSobj, src)
	else
		STOP_PROCESSING(SSobj, src)
	if(QDELETED(holder))
		return
	holder.update_appearance()
	if(reveal_toggle)
		holder.visible_message(span_warning("[holder] [activated ? "начинает вибрировать и светиться" : "затихает"]."))

/datum/xenoartifact_effect/proc/turn_effect_off()
	STOP_PROCESSING(SSobj, src)
	activated = FALSE
	if(istype(src, /datum/xenoartifact_effect/light) && !QDELETED(holder))
		holder.set_light(0)

/datum/xenoartifact_effect/proc/try_drain_charge(amount)
	if(!activated || QDELETED(holder) || amount < 0 || current_charge < amount)
		return FALSE
	current_charge -= amount
	return TRUE

/datum/xenoartifact_effect/proc/do_effect_touch(mob/living/user)
	if(!istype(user) || QDELETED(user) || !get_xenoartifact_susceptibility(user))
		return FALSE
	return try_drain_charge(activation_touch_cost)

/datum/xenoartifact_effect/proc/do_effect_aura(seconds_per_tick)
	return seconds_per_tick > 0 && try_drain_charge(activation_aura_cost / 2 * seconds_per_tick)

/datum/xenoartifact_effect/proc/do_effect_pulse(seconds_per_tick)
	if(try_drain_charge(activation_pulse_cost))
		return activation_pulse_cost
	return FALSE

/datum/xenoartifact_effect/proc/do_effect_destroy()
	return

/datum/xenoartifact_effect/process(seconds_per_tick)
	if(!activated || QDELETED(holder))
		return PROCESS_KILL
	current_charge = min(current_charge + recharge_speed / 2 * seconds_per_tick, maximum_charges)
	if(release_method == XENO_EFFECT_AURA)
		do_effect_aura(seconds_per_tick)
	else if(release_method == XENO_EFFECT_PULSE && current_charge >= activation_pulse_cost)
		// Импульс — отдельное событие; его сила не зависит от длины тика подсистемы.
		do_effect_pulse(2)

/// Копируются только параметры излучения; ссылки на прежнего владельца и жертв не передаются.
/datum/xenoartifact_effect/proc/copy_to(atom/new_holder)
	var/datum/xenoartifact_effect/result = new type(new_holder)
	for(var/parameter in list("release_method", "range", "trigger", "maximum_charges", "recharge_speed", "activation_touch_cost", "activation_aura_cost", "activation_pulse_cost", "log_name", "type_name", "artifact_id", "grav_type", "current_gas_type", "max_pressure", "spawn_temp", "target_temp", "target_temp_low", "target_temp_high", "radiation_amount"))
		if(parameter in vars)
			result.vars[parameter] = vars[parameter]
	return result

/// Анализ раскрывает класс излучения и семейство триггера, сохраняя экспериментальную часть.
/datum/xenoartifact_effect/proc/get_description()
	var/category
	switch(type_name)
		if(XENO_EFFECT_ENERGY)
			category = "Концентрированная энергия"
		if(XENO_EFFECT_PSIONIC)
			category = "Псионические волны"
		if(XENO_EFFECT_ELECTRO)
			category = "Электромагнитная энергия"
		if(XENO_EFFECT_PARTICLE)
			category = "Высокочастотные частицы"
		if(XENO_EFFECT_ORGANIC)
			category = "Органически активные частицы"
		if(XENO_EFFECT_BLUESPACE)
			category = "Межпространственные колебания"
		if(XENO_EFFECT_SYNTH)
			category = "Атомный синтез"
		else
			category = "Неизвестное низкоэнергетическое излучение"
	var/method
	switch(release_method)
		if(XENO_EFFECT_TOUCH)
			method = "при касании"
		if(XENO_EFFECT_AURA)
			method = "постоянной аурой"
		if(XENO_EFFECT_PULSE)
			method = "периодическими импульсами"
	var/activation
	switch(trigger)
		if(XENO_TRIGGER_TOUCH, XENO_TRIGGER_WATER, XENO_TRIGGER_ACID, XENO_TRIGGER_VOLATILE, XENO_TRIGGER_TOXIN)
			activation = "физическое или химическое взаимодействие"
		if(XENO_TRIGGER_FORCE, XENO_TRIGGER_ENERGY, XENO_TRIGGER_HEAT, XENO_TRIGGER_COLD)
			activation = "энергетическое воздействие"
		else
			activation = "условия окружающей атмосферы"
	return "- Класс: [category]\n- Передача: [method]\n- Условие активации: [activation]\n- Радиус: [range] м."

/// Биозащита, латексные перчатки и научные очки уменьшают влияние артефактов.
/proc/get_xenoartifact_susceptibility(mob/living/carbon/human/human)
	if(!istype(human))
		return 1
	var/protection = 0
	var/obj/item/bodypart/chest/chest = human.get_bodypart(BODY_ZONE_CHEST)
	var/obj/item/bodypart/head/head = human.get_bodypart(BODY_ZONE_HEAD)
	if(chest && human.get_worn_bodypart_armor_value(chest, BIO) >= 85)
		protection += 0.5
	if(head && human.get_worn_bodypart_armor_value(head, BIO) >= 85)
		protection += 0.3
	if(istype(human.gloves, /obj/item/clothing/gloves/latex))
		protection += 0.1
	if(istype(human.glasses, /obj/item/clothing/glasses/science))
		protection += 0.1
	return clamp(1 - protection, 0, 1)
