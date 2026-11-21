/// Ксеноархеология NovaSector с местными наградами и лабораторными интерфейсами TGUI.
/datum/modpack/xenoarchaeology
	name = "Ксеноархеология"
	desc = "Поиск, раскопки, автоматическая обработка и изучение древних артефактов."
	author = "Jake Park, NovaSector contributors, BandaStation contributors"

/// Общий тип археологических инструментов и образцов.
/obj/item/xenoarch
	abstract_type = /obj/item/xenoarch
	icon = 'modular_bandastation/xenoarchaeology/icons/base/xenoarch_items.dmi'
	icon_state = "tape"
	// NovaSector не содержит отдельных кадров в руках: используем штатную позу прибора.
	inhand_icon_state = "electronic"
	worn_icon_state = "electronic"
	lefthand_file = 'icons/mob/inhands/items/devices_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items/devices_righthand.dmi'
	w_class = WEIGHT_CLASS_SMALL
	custom_materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT * 2, /datum/material/glass = SMALL_MATERIAL_AMOUNT)
