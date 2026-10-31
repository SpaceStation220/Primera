/obj/item/storage/bag/xenoarch
	inhand_icon_state = "satchel"
	lefthand_file = 'icons/mob/inhands/equipment/backpack_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/backpack_righthand.dmi'
	name = "archaeological sample bag"
	desc = "Сумка для 25 археологических образцов. Поддерживает быстрый сбор и опустошение."
	icon = 'modular_bandastation/xenoarchaeology/icons/base/xenoarch_items.dmi'
	w_class = WEIGHT_CLASS_NORMAL
	icon_state = "satchel"
	worn_icon_state = "satchel"
	storage_type = /datum/storage/bag/xenoarch
	custom_materials = /obj/item/xenoarch::custom_materials

/datum/storage/bag/xenoarch
	max_slots = 25
	max_total_storage = 100
	max_specific_storage = WEIGHT_CLASS_NORMAL
	numerical_stacking = FALSE

/datum/storage/bag/xenoarch/New(atom/parent, max_slots, max_specific_storage, max_total_storage, rustle_sound, remove_rustle_sound)
	. = ..()
	set_holdable(/obj/item/xenoarch/sample)

/obj/item/storage/bag/xenoarch/advanced
	name = "advanced archaeological sample bag"
	desc = "Вместительная сумка для 50 археологических образцов."
	icon_state = "adv_satchel"
	storage_type = /datum/storage/bag/xenoarch/advanced
	custom_materials = list(/datum/material/gold = SMALL_MATERIAL_AMOUNT * 2.5, /datum/material/uranium = SMALL_MATERIAL_AMOUNT * 5)

/datum/storage/bag/xenoarch/advanced
	max_slots = 50
	max_total_storage = 200

/obj/item/storage/belt/utility/xenoarch
	name = "archaeological toolbelt"
	desc = "Пояс для археологических инструментов, сканеров, GPS, бумаги и ручек."
	icon = 'modular_bandastation/xenoarchaeology/icons/base/xenoarch_items.dmi'
	icon_state = "xenoarch_belt"
	content_overlays = FALSE
	storage_type = /datum/storage/belt/xenoarch
	custom_materials = /obj/item/xenoarch::custom_materials

/datum/storage/belt/xenoarch
	max_slots = 15
	max_total_storage = 40

/datum/storage/belt/xenoarch/New(atom/parent, max_slots, max_specific_storage, max_total_storage, rustle_sound, remove_rustle_sound)
	. = ..()
	set_holdable(can_hold_list = list(/obj/item/xenoarch, /obj/item/mining_scanner, /obj/item/t_scanner, /obj/item/gps, /obj/item/pen, /obj/item/paper), cant_hold_list = /obj/item/xenoarch/sample)
