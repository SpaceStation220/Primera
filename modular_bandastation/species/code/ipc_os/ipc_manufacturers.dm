GLOBAL_LIST_INIT(ipc_manufacturers, init_ipc_appearance_choices(/datum/ipc_manufacturer))

/// Mechanical identity is stored on the physical torso, independently of its sprite.
/obj/item/bodypart/chest/robot/ipc
	var/ipc_manufacturer
	var/list/ipc_food_queue = list()
	var/loading_food = FALSE

/// Intercept self-feeding before native mouth checks: the torso has a loading port, not a mouth.
/datum/species/ipc/proc/on_food_load_click(mob/living/carbon/human/human, atom/target, list/modifiers)
	SIGNAL_HANDLER
	if(target != human || modifiers[RIGHT_CLICK] || modifiers[SHIFT_CLICK] || modifiers[CTRL_CLICK] || modifiers[ALT_CLICK])
		return NONE
	var/obj/item/bodypart/chest/robot/ipc/torso = human.get_bodypart(BODY_ZONE_CHEST)
	var/obj/item/food/food = human.get_active_held_item()
	if(!istype(torso) || torso.ipc_manufacturer != /datum/ipc_manufacturer/zeng::name || !istype(food))
		return NONE
	if(!torso.loading_food)
		INVOKE_ASYNC(torso, TYPE_PROC_REF(/obj/item/bodypart/chest/robot/ipc, load_food_sequence), human, food)
	return COMSIG_MOB_CANCEL_CLICKON

/obj/item/bodypart/chest/robot/ipc/proc/load_food_sequence(mob/living/carbon/human/human, obj/item/food/food)
	if(loading_food || length(ipc_food_queue) >= 5 || human.incapacitated || !human.is_holding(food))
		return
	loading_food = TRUE
	for(var/bite in 1 to 3)
		if(owner != human || QDELETED(food) || !human.is_holding(food) || !do_after(human, 1 SECONDS, food, ipc_fixed_duration = TRUE))
			loading_food = FALSE
			return
		playsound(human, 'sound/items/eatfood.ogg', 35, TRUE)
	load_ipc_food(human, food)
	loading_food = FALSE

/obj/item/bodypart/chest/robot/ipc/Destroy()
	for(var/obj/item/food/food as anything in ipc_food_queue)
		food.forceMove(drop_location())
	ipc_food_queue = null
	return ..()

/// Each whole dish has its own minute of processing; the torso owns both food and progress.
/obj/item/bodypart/chest/robot/ipc/proc/load_ipc_food(mob/living/carbon/human/human, obj/item/food/food)
	if(ipc_manufacturer != /datum/ipc_manufacturer/zeng::name || owner != human || human.stat == DEAD || !istype(food) || !human.is_holding(food))
		return FALSE
	if(length(ipc_food_queue) >= 5)
		human.balloon_alert(human, "переработчик заполнен")
		return TRUE
	// Raw ingredients and empty/partly eaten items cannot be split into free battery charges.
	var/datum/component/edible/edible = food.GetComponent(/datum/component/edible)
	if(!edible || edible.bitecount || !food.reagents?.total_volume || (food.foodtypes & RAW) || istype(food, /obj/item/food/grown))
		return FALSE
	if(!human.transferItemToLoc(food, src))
		return TRUE
	ipc_food_queue[food] = 0
	human.balloon_alert(human, "блюдо загружено")
	return TRUE

/obj/item/bodypart/chest/robot/ipc/proc/process_ipc_food(mob/living/carbon/human/human, seconds_per_tick)
	if(owner != human || human.stat == DEAD || ipc_manufacturer != /datum/ipc_manufacturer/zeng::name)
		return
	var/obj/item/organ/heart/ipc/battery = human.get_organ_slot(ORGAN_SLOT_HEART)
	if(!istype(battery) || (battery.organ_flags & (ORGAN_FAILING|ORGAN_EMP)))
		return
	for(var/obj/item/food/food as anything in ipc_food_queue.Copy())
		if(QDELETED(food) || food.loc != src)
			ipc_food_queue -= food
			continue
		ipc_food_queue[food] += seconds_per_tick
		if(ipc_food_queue[food] < 60)
			continue
		ipc_food_queue -= food
		qdel(food)
		battery.adjust_charge(NUTRITION_LEVEL_FULL * 0.01)
		human.balloon_alert(human, "блюдо переработано")

/datum/ipc_manufacturer
	parent_type = /datum/sprite_accessory
	var/description
	var/memory = 0
	var/base_drain = 1
	var/capacity_multiplier = 1
	var/apc_rate = 1
	var/repair_efficiency = 1
	var/repair_materials = 1
	var/brute_multiplier = 1
	var/burn_multiplier = 1
	var/leg_multiplier = 1
	var/heat_multiplier = 1
	var/action_rate = 1
	var/movement_rate = 1

/datum/ipc_manufacturer/morpheus
	name = "Morpheus Cyberkinetics"
	description = "Сварка и провода восстанавливают на 10% больше повреждений. Базовый расход энергии немного повышен."
	repair_efficiency = 1.1
	base_drain = 1.04

/datum/ipc_manufacturer/etamin
	name = "Etamin Industry"
	description = "Действия на 3% быстрее, накопление тепла на 3% выше."
	action_rate = 1.03
	heat_multiplier = 1.03

/datum/ipc_manufacturer/bishop
	name = "Bishop Cybernetics"
	description = "Дополнительные 3 GB памяти ОС. Базовый расход энергии немного повышен."
	memory = 3
	base_drain = 1.02

/datum/ipc_manufacturer/hephaestus
	name = "Hephaestus Industries"
	description = "Получает на 4% меньше физического урона. Для ремонта требуется на 5% больше материалов."
	brute_multiplier = 0.96
	repair_materials = 1.05

/datum/ipc_manufacturer/ward
	name = "Ward-Takahashi"
	description = "Ёмкость микробатареи — 120 вместо обычных 100 единиц. Базовый расход энергии немного повышен."
	capacity_multiplier = 1.2
	base_drain = 1.02

/datum/ipc_manufacturer/xion
	name = "Xion Manufacturing Group"
	description = "Накопление тепла снижено на 10%. Корпус немного уязвимее к физическим повреждениям."
	heat_multiplier = 0.9
	brute_multiplier = 1.03

/datum/ipc_manufacturer/zeng
	name = "Zeng-Hu Pharmaceuticals"
	description = "Автоматически перерабатывает до пяти целых блюд: минута на каждое и небольшой заряд батареи. Напитки не принимаются. Ремонт расходует на 10% больше материалов."
	repair_materials = 1.1

/datum/ipc_manufacturer/shellguard
	name = "Shellguard Munitions"
	description = "Получает на 4% меньше урона от ожогов. Для ремонта требуется на 5% больше материалов."
	burn_multiplier = 0.96
	repair_materials = 1.05

/// Yang uses the Unbranded mechanics requested for this existing chassis.
/datum/ipc_manufacturer/yang
	name = "Yang Company"
	description = "Заряжается от ЛКП на 5% быстрее, но имеет на 3 GB меньше памяти ОС."
	apc_rate = 1.05
	memory = -3

/datum/ipc_manufacturer/cybersun
	name = "Cybersun Industries"
	description = "Передвижение на 5% быстрее и тихая ходьба. Ноги немного уязвимее к повреждениям."
	leg_multiplier = 1.03
	movement_rate = 1.05

/datum/ipc_manufacturer/con
	name = "CON"
	description = "Свободно сочетает внешность разных производителей. Брендовых бонусов и штрафов нет."

/mob/living/carbon/human/proc/get_ipc_manufacturer()
	RETURN_TYPE(/datum/ipc_manufacturer)
	if(!dna || !is_species(src, /datum/species/ipc))
		return null
	var/obj/item/bodypart/chest/robot/ipc/torso = get_bodypart(BODY_ZONE_CHEST)
	return istype(torso) ? GLOB.ipc_manufacturers[torso.ipc_manufacturer] : null

/mob/living/carbon/proc/ipc_charge_capacity()
	return NUTRITION_LEVEL_FULL

/mob/living/carbon/human/ipc_charge_capacity()
	var/datum/ipc_manufacturer/manufacturer = get_ipc_manufacturer()
	return NUTRITION_LEVEL_FULL * (manufacturer?.capacity_multiplier || 1)

/mob/living/carbon/proc/ipc_apc_charge_limit()
	return ipc_charge_capacity() * NUTRITION_LEVEL_WELL_FED / NUTRITION_LEVEL_FULL

/mob/proc/ipc_movement_rate()
	return 1

/mob/living/carbon/human/ipc_movement_rate()
	var/datum/ipc_manufacturer/manufacturer = get_ipc_manufacturer()
	var/rate = manufacturer?.movement_rate || 1
	if(move_intent == MOVE_INTENT_RUN && !(movement_type & (FLYING|FLOATING)) && mob_mood?.humanity)
		rate *= mob_mood.humanity.run_rate
	return rate

/mob/living/carbon/human/proc/ipc_heat_input(amount)
	if(amount <= 0)
		return amount
	var/datum/ipc_manufacturer/manufacturer = get_ipc_manufacturer()
	return amount * (manufacturer?.heat_multiplier || 1)

/mob/living/carbon/human/adjust_bodytemperature(amount, min_temp = 0, max_temp = INFINITY, use_insulation = FALSE, use_steps = FALSE, capped = TRUE, apply_ipc_heat = TRUE)
	return ..(apply_ipc_heat ? ipc_heat_input(amount) : amount, min_temp, max_temp, use_insulation, use_steps, capped)

/datum/species/ipc/proc/on_chassis_changed(mob/living/carbon/human/human)
	SIGNAL_HANDLER
	human.update_movespeed()
	human.set_nutrition(min(human.nutrition, human.ipc_charge_capacity()), forced = TRUE)
	var/obj/item/organ/heart/ipc/battery = human.get_organ_slot(ORGAN_SLOT_HEART)
	if(istype(battery))
		battery.update_charge_alert()


/proc/get_ipc_chassis_choices(manufacturer, head = FALSE)
	var/list/choices = list()
	for(var/model in GLOB.ipc_chassis)
		var/datum/ipc_chassis/chassis = GLOB.ipc_chassis[model]
		if(head ? !chassis.has_head : !chassis.has_body)
			continue
		if(manufacturer == /datum/ipc_manufacturer/con::name || chassis.manufacturer == manufacturer)
			choices += model
	return choices

/datum/preference/choiced/ipc/manufacturer
	savefile_key = FEATURE_IPC_MANUFACTURER
	feature_key = FEATURE_IPC_MANUFACTURER
	priority = PREFERENCE_PRIORITY_BODYPARTS

/datum/preference/choiced/ipc/manufacturer/init_possible_values()
	return assoc_to_keys(GLOB.ipc_manufacturers)

/datum/preference/choiced/ipc/manufacturer/create_default_value()
	return /datum/ipc_manufacturer/con::name

/datum/preference/choiced/ipc/manufacturer/compile_constant_data()
	var/list/data = ..()
	var/list/descriptions = list()
	for(var/brand in GLOB.ipc_manufacturers)
		var/datum/ipc_manufacturer/manufacturer = GLOB.ipc_manufacturers[brand]
		descriptions[brand] = manufacturer.description
	data["descriptions"] = descriptions
	return data

/datum/preference/choiced/ipc/manufacturer/deserialize(input, datum/preferences/preferences)
	if(input == "HEF")
		input = /datum/ipc_manufacturer/con::name
	return ..()

/datum/preference/choiced/ipc/manufacturer/post_write(value, datum/preferences/preferences)
	. = ..()
	if(!preferences)
		return
	for(var/preference in list(/datum/preference/choiced/ipc/chassis, /datum/preference/choiced/ipc/head, /datum/preference/choiced/ipc/screen))
		preferences.value_cache -= preference

/datum/preference/choiced/ipc/manufacturer/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	. = ..()
	if(!is_species(target, /datum/species/ipc))
		return
	var/obj/item/bodypart/chest/robot/ipc/torso = target.get_bodypart(BODY_ZONE_CHEST)
	var/obj/item/organ/brain/ipc/core = target.get_organ_slot(ORGAN_SLOT_BRAIN)
	if(istype(torso) && (!istype(core) || !core.ipc_job_captured) && !target.mind?.active)
		torso.ipc_manufacturer = value
		target.set_nutrition(min(target.nutrition, target.ipc_charge_capacity()), forced = TRUE)

/// Cosmetic preferences are restricted on the server as well as in the dropdown.
/datum/preference/choiced/ipc/proc/model_choices(datum/preferences/preferences)
	var/manufacturer = preferences?.read_preference(/datum/preference/choiced/ipc/manufacturer) || /datum/ipc_manufacturer/con::name
	return get_ipc_chassis_choices(manufacturer, type == /datum/preference/choiced/ipc/head)

/datum/preference/choiced/ipc/chassis/deserialize(input, datum/preferences/preferences)
	var/list/choices = model_choices(preferences)
	return sanitize_inlist(input, choices, choices[1])

/datum/preference/choiced/ipc/chassis/is_valid(value, datum/preferences/preferences)
	return ..() && (value in model_choices(preferences))

/datum/preference/choiced/ipc/chassis/create_informed_default_value(datum/preferences/preferences)
	var/list/choices = model_choices(preferences)
	return sanitize_inlist(create_default_value(), choices, choices[1])

/datum/preference/choiced/ipc/head/deserialize(input, datum/preferences/preferences)
	var/list/choices = model_choices(preferences)
	return sanitize_inlist(input, choices, choices[1])

/datum/preference/choiced/ipc/head/is_valid(value, datum/preferences/preferences)
	return ..() && (value in model_choices(preferences))

/datum/preference/choiced/ipc/head/create_informed_default_value(datum/preferences/preferences)
	var/list/choices = model_choices(preferences)
	return sanitize_inlist(create_default_value(), choices, choices[1])

/datum/preference/choiced/ipc/proc/compile_model_choices()
	var/list/choices_by_manufacturer = list()
	for(var/manufacturer in GLOB.ipc_manufacturers)
		choices_by_manufacturer[manufacturer] = get_ipc_chassis_choices(manufacturer, type == /datum/preference/choiced/ipc/head)
	return choices_by_manufacturer

/datum/preference/choiced/ipc/chassis/compile_constant_data()
	var/list/data = ..()
	data["choices_by_manufacturer"] = compile_model_choices()
	return data

/datum/preference/choiced/ipc/head/compile_constant_data()
	var/list/data = ..()
	data["choices_by_manufacturer"] = compile_model_choices()
	return data

/datum/preference/choiced/ipc/limb
	parent_type = /datum/preference/choiced/ipc/chassis
	abstract_type = /datum/preference/choiced/ipc/limb

/datum/preference/choiced/ipc/limb/has_relevant_feature(datum/preferences/preferences)
	return ..() && preferences.read_preference(/datum/preference/choiced/ipc/manufacturer) == /datum/ipc_manufacturer/con::name

/datum/preference/choiced/ipc/limb/left_arm
	savefile_key = "ipc_left_arm"
	feature_key = "ipc_left_arm"

/datum/preference/choiced/ipc/limb/right_arm
	savefile_key = "ipc_right_arm"
	feature_key = "ipc_right_arm"

/datum/preference/choiced/ipc/limb/left_leg
	savefile_key = "ipc_left_leg"
	feature_key = "ipc_left_leg"

/datum/preference/choiced/ipc/limb/right_leg
	savefile_key = "ipc_right_leg"
	feature_key = "ipc_right_leg"
