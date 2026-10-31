/// Ранцевый приёмник использует существующий индекс POI, который очищается при удалении породы.
/obj/item/xenoarch/wave_scanner
	inhand_icon_state = "explorerpack"
	lefthand_file = 'icons/mob/inhands/equipment/backpack_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/backpack_righthand.dmi'
	name = "archaeological wave scanner"
	desc = "Ранцевый волновой сканер. Показывает примерное расстояние до ближайшего крупного включения на текущем уровне."
	icon = 'modular_bandastation/xenoarchaeology/icons/artifacts/tools.dmi'
	worn_icon = 'modular_bandastation/xenoarchaeology/icons/artifacts/worn.dmi'
	icon_state = "wave_scanner"
	worn_icon_state = "wave_scanner"
	slot_flags = ITEM_SLOT_BACK
	w_class = WEIGHT_CLASS_BULKY
	actions_types = list(/datum/action/item_action/xenoarch_wave_scan)
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2, /datum/material/plasma = SHEET_MATERIAL_AMOUNT, /datum/material/glass = HALF_SHEET_MATERIAL_AMOUNT, /datum/material/bluespace = SMALL_MATERIAL_AMOUNT)
	COOLDOWN_DECLARE(scan_cooldown)

/obj/item/xenoarch/wave_scanner/ui_action_click(mob/user, datum/action/source)
	scan(user)

/obj/item/xenoarch/wave_scanner/attack_self(mob/user, list/modifiers)
	scan(user)

/obj/item/xenoarch/wave_scanner/proc/scan(mob/living/user)
	if(!istype(user) || loc != user || !user.can_perform_action(src, NEED_DEXTERITY|NEED_HANDS) || !COOLDOWN_FINISHED(src, scan_cooldown))
		return FALSE
	COOLDOWN_START(src, scan_cooldown, 2.5 SECONDS)
	var/nearest = INFINITY
	for(var/datum/point_of_interest/point as anything in SSpoints_of_interest.other_points_of_interest)
		var/turf/closed/mineral/xenoarchaeology/ore = point.target
		if(!istype(ore) || !ore.contains_artifact || ore.z != user.z)
			continue
		nearest = min(nearest, get_dist(user, ore))
	if(nearest == INFINITY)
		to_chat(user, span_notice("Обнаружено только фоновое излучение."))
	else
		to_chat(user, span_notice("Экзотическое излучение: источник примерно в [max(0, nearest * 2 + rand(-1, 1))] метрах."))
	playsound(src, 'sound/machines/terminal/terminal_alert.ogg', 25, FALSE)
	return TRUE

/datum/action/item_action/xenoarch_wave_scan
	name = "Поиск крупного артефакта"
	desc = "Измерить расстояние до ближайшего крупного археологического включения."
