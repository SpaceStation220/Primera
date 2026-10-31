/// Независимый от станционного питания артефакт; эксперименты активируют два отдельных эффекта.
/obj/machinery/xenoartifact
	name = "инопланетный артефакт"
	desc = "Крупное устройство из неизвестного сплава. Его назначение и условия активации предстоит установить экспериментально."
	icon = 'modular_bandastation/xenoarchaeology/icons/artifacts/artifacts.dmi'
	icon_state = "artifact_1"
	anchored = FALSE
	density = TRUE
	use_power = NO_POWER_USE
	max_integrity = 1000
	resistance_flags = LAVA_PROOF|FIRE_PROOF|ACID_PROOF
	/// Эффекты принадлежат артефакту, батареи получают независимые копии.
	var/datum/xenoartifact_effect/first_effect
	var/datum/xenoartifact_effect/secondary_effect
	/// Один анализатор или сборщик может занимать артефакт одновременно.
	var/datum/weakref/lab_owner
	/// Особые устройства имеют собственную функцию вместо случайной пары эффектов.
	var/random_effects = TRUE
	/// Номер внешнего вида NovaSector; три цвета кристалла делят одну вероятность.
	var/artifact_style = 1
	COOLDOWN_DECLARE(touch_cooldown)

/obj/machinery/xenoartifact/Initialize(mapload)
	. = ..()
	if(random_effects)
		artifact_style = rand(1, 11)
		if(artifact_style == 11)
			artifact_style = rand(11, 13)
		var/effect_type = pick(GLOB.xenoarch_primary_effects)
		first_effect = new effect_type(src)
		if(prob(65))
			effect_type = pick(GLOB.xenoarch_secondary_effects)
			secondary_effect = new effect_type(src)
	RegisterSignal(src, COMSIG_ATOM_EXPOSE_REAGENT, PROC_REF(on_reagent))
	update_appearance()

/obj/machinery/xenoartifact/Destroy()
	QDEL_NULL(first_effect)
	QDEL_NULL(secondary_effect)
	lab_owner = null
	return ..()

/// Всплеск вызывается разрушением в игре, а не любым qdel при уборке или завершении теста.
/obj/machinery/xenoartifact/atom_destruction(damage_flag)
	first_effect?.do_effect_destroy()
	secondary_effect?.do_effect_destroy()
	return ..()

/obj/machinery/xenoartifact/update_icon_state()
	. = ..()
	var/active_suffix = (first_effect?.activated || secondary_effect?.activated) ? "_active" : ""
	icon_state = "artifact_[artifact_style][active_suffix]"

/// Смена состояния от дискретного воздействия и поддержание состояния от атмосферы различаются.
/obj/machinery/xenoartifact/proc/trigger_effects(trigger, atmospheric_state = null)
	for(var/datum/xenoartifact_effect/effect in list(first_effect, secondary_effect))
		if(effect.trigger != trigger)
			continue
		if(!isnull(atmospheric_state) && effect.activated == atmospheric_state)
			continue
		effect.ToggleActivate()

/obj/machinery/xenoartifact/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return
	if(!user.can_perform_action(src, NEED_HANDS|FORBID_TELEKINESIS_REACH))
		return
	touch(user)

/obj/machinery/xenoartifact/proc/analysis_description()
	. = "### Состав\nНеизвестный сплав."
	if(first_effect)
		. += "\n\n### Первичное излучение\n[first_effect.get_description()]"
	if(secondary_effect)
		. += "\n\n### Вторичное излучение\n[secondary_effect.get_description()]"

/obj/machinery/xenoartifact/proc/touch(mob/living/user)
	if(!istype(user) || !COOLDOWN_FINISHED(src, touch_cooldown))
		return
	COOLDOWN_START(src, touch_cooldown, 3 SECONDS)
	var/mob/living/carbon/carbon = user
	if(!istype(carbon) || !istype(carbon.get_item_by_slot(ITEM_SLOT_GLOVES), /obj/item/clothing/gloves/latex))
		trigger_effects(XENO_TRIGGER_TOUCH)
	for(var/datum/xenoartifact_effect/effect in list(first_effect, secondary_effect))
		if(effect.activated && effect.release_method == XENO_EFFECT_TOUCH)
			effect.do_effect_touch(user)
	log_combat(user, src, "коснулся артефакта")

/obj/machinery/xenoartifact/Bumped(atom/movable/bumper)
	. = ..()
	if(isliving(bumper))
		touch(bumper)
	else if(isitem(bumper))
		var/obj/item/item = bumper
		if(item.throwforce >= 10)
			trigger_effects(XENO_TRIGGER_FORCE)

/obj/machinery/xenoartifact/take_damage(damage_amount, damage_type, damage_flag, sound_effect, attack_dir, armour_penetration)
	. = ..()
	if(QDELETED(src) || !.)
		return
	switch(damage_flag)
		if(FIRE)
			trigger_effects(XENO_TRIGGER_HEAT)
		if(ENERGY, LASER)
			trigger_effects(XENO_TRIGGER_ENERGY)
		else
			trigger_effects(XENO_TRIGGER_FORCE)

/obj/machinery/xenoartifact/proc/on_reagent(datum/source, datum/reagent/reagent, amount)
	SIGNAL_HANDLER
	if(amount < 1)
		return
	if(istype(reagent, /datum/reagent/water) || istype(reagent, /datum/reagent/hydrogen))
		trigger_effects(XENO_TRIGGER_WATER)
	else if(istype(reagent, /datum/reagent/toxin/acid))
		trigger_effects(XENO_TRIGGER_ACID)
	else if(is_type_in_list(reagent, GLOB.xenoarch_volatile_reagents))
		trigger_effects(XENO_TRIGGER_VOLATILE)
	else if(istype(reagent, /datum/reagent/toxin))
		trigger_effects(XENO_TRIGGER_TOXIN)

/obj/machinery/xenoartifact/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(istype(tool, /obj/item/reagent_containers))
		// Реальное нанесение реагентов идёт через expose_reagents и не требует выплёскивать всю ёмкость.
		for(var/datum/reagent/reagent as anything in tool.reagents.reagent_list)
			if(reagent.volume >= 1)
				on_reagent(src, reagent, reagent.volume)
		return ITEM_INTERACT_SUCCESS
	if(tool.get_temperature() > 700)
		trigger_effects(XENO_TRIGGER_HEAT)
	if(istype(tool, /obj/item/melee/energy))
		trigger_effects(XENO_TRIGGER_ENERGY)
		return ITEM_INTERACT_SUCCESS
	if(istype(tool, /obj/item/xenoarch/handheld_scanner))
		to_chat(user, span_notice("Ручной сканер не охватывает устройство. Нужны площадка и анализатор артефактов."))
		return ITEM_INTERACT_SUCCESS
	return ..()

/obj/machinery/xenoartifact/process(seconds_per_tick)
	var/turf/location = get_turf(src)
	var/datum/gas_mixture/air = location?.return_air()
	if(!air)
		return
	trigger_effects(XENO_TRIGGER_COLD, air.temperature < 225)
	trigger_effects(XENO_TRIGGER_HEAT, air.temperature > 375)
	trigger_effects(XENO_TRIGGER_PLASMA, air.moles[/datum/gas/plasma] >= 10)
	trigger_effects(XENO_TRIGGER_OXY, air.moles[/datum/gas/oxygen] >= 10)
	trigger_effects(XENO_TRIGGER_CO2, air.moles[/datum/gas/carbon_dioxide] >= 10)
	trigger_effects(XENO_TRIGGER_NITRO, air.moles[/datum/gas/nitrogen] >= 10)
