/// Молоток с фиксированной толщиной снимаемого слоя породы.
/obj/item/xenoarch/hammer
	inhand_icon_state = "clawhammer"
	worn_icon_state = "clawhammer"
	lefthand_file = 'icons/mob/inhands/weapons/hammers_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/weapons/hammers_righthand.dmi'
	name = "archaeological hammer (1 cm)"
	desc = "Молоток для раскопок. Снимает слой породы толщиной 1 см. Излишне глубокий удар уничтожит находку."
	icon_state = "hammer1"
	slot_flags = ITEM_SLOT_BELT
	/// Толщина слоя, снимаемого одним ударом, в сантиметрах.
	var/dig_amount = 1
	/// Продолжительность одного удара.
	var/dig_speed = 0.5 SECONDS

/obj/item/xenoarch/hammer/cm2
	name = "archaeological hammer (2 cm)"
	desc = "Молоток для раскопок. Снимает слой породы толщиной 2 см. Излишне глубокий удар уничтожит находку."
	icon_state = "hammer2"
	dig_amount = 2
	dig_speed = 1 SECONDS

/obj/item/xenoarch/hammer/cm3
	name = "archaeological hammer (3 cm)"
	desc = "Молоток для раскопок. Снимает слой породы толщиной 3 см. Излишне глубокий удар уничтожит находку."
	icon_state = "hammer3"
	dig_amount = 3
	dig_speed = 1.5 SECONDS

/obj/item/xenoarch/hammer/cm4
	name = "archaeological hammer (4 cm)"
	desc = "Молоток для раскопок. Снимает слой породы толщиной 4 см. Излишне глубокий удар уничтожит находку."
	icon_state = "hammer4"
	dig_amount = 4
	dig_speed = 2 SECONDS

/obj/item/xenoarch/hammer/cm5
	name = "archaeological hammer (5 cm)"
	desc = "Молоток для раскопок. Снимает слой породы толщиной 5 см. Излишне глубокий удар уничтожит находку."
	icon_state = "hammer5"
	dig_amount = 5
	dig_speed = 2.5 SECONDS

/obj/item/xenoarch/hammer/cm6
	name = "archaeological hammer (6 cm)"
	desc = "Молоток для раскопок. Снимает слой породы толщиной 6 см. Излишне глубокий удар уничтожит находку."
	icon_state = "hammer6"
	dig_amount = 6
	dig_speed = 3 SECONDS

/obj/item/xenoarch/hammer/cm10
	name = "archaeological hammer (10 cm)"
	desc = "Молоток для раскопок. Снимает слой породы толщиной 10 см. Излишне глубокий удар уничтожит находку."
	icon_state = "hammer10"
	dig_amount = 10
	dig_speed = 5 SECONDS

/// Кисточка для точной раскопки и удаления осадочной оболочки находок.
/obj/item/xenoarch/brush
	inhand_icon_state = "pen"
	worn_icon_state = "pen"
	lefthand_file = 'icons/mob/inhands/items_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items_righthand.dmi'
	name = "archaeological brush"
	desc = "Кисточка для раскопок. Снимает по 1 см породы, извлекает достигнутую находку и очищает предметы от осадочной оболочки."
	icon_state = "brush"
	slot_flags = ITEM_SLOT_BELT
	/// Время снятия одного сантиметра породы.
	var/dig_speed = 3 SECONDS

/// Измеритель отмечает уже снятую глубину, доступную при осмотре образца.
/obj/item/xenoarch/measuring_tape
	name = "archaeological measuring tape"
	desc = "Голографический измеритель глубины раскопки. Примените к камню, затем осматривайте образец для чтения текущей глубины."
	icon_state = "tape"
	slot_flags = ITEM_SLOT_BELT

/// Сканер определяет максимальную глубину и ширину безопасного интервала.
/obj/item/xenoarch/handheld_scanner
	name = "archaeological handheld scanner"
	desc = "Сканер археологических образцов. Показывает максимальную глубину и безопасный интервал; их разность — граница, после которой следует работать кисточкой."
	icon_state = "scanner"
	slot_flags = ITEM_SLOT_BELT
	/// Продолжительность сканирования.
	var/scanning_speed = 2 SECONDS
	/// Показывает точную глубину вместо безопасного интервала.
	var/advanced = FALSE

/obj/item/xenoarch/hammer/advanced
	name = "advanced archaeological hammer"
	desc = "Регулируемый археологический молоток. Активируйте в руке, чтобы выбрать слой от 1 до 30 см."
	icon_state = "adv_hammer"
	dig_speed = 0.5
	custom_materials = list(/datum/material/uranium = SMALL_MATERIAL_AMOUNT * 4, /datum/material/iron = SMALL_MATERIAL_AMOUNT * 2, /datum/material/gold = SMALL_MATERIAL_AMOUNT * 2, /datum/material/glass = SMALL_MATERIAL_AMOUNT)

/// Настройка проверяется и после диалога: предмет всё ещё должен быть в руках.
/obj/item/xenoarch/hammer/advanced/attack_self(mob/user, list/modifiers)
	var/depth = tgui_input_number(user, "Толщина снимаемого слоя, см", "Археологический молоток", dig_amount, 30, 1)
	if(QDELETED(src) || QDELETED(user) || !user.is_holding(src) || !user.can_perform_action(src, NEED_DEXTERITY|NEED_HANDS))
		return
	set_depth(depth)

/// Отдельная проверка не позволяет отрицательной или дробной глубине попасть в раскопку.
/obj/item/xenoarch/hammer/advanced/proc/set_depth(depth)
	if(!isnum(depth) || depth < 1 || depth > 30 || depth != round(depth))
		return FALSE
	dig_amount = depth
	dig_speed = depth * 0.5
	return TRUE

/obj/item/xenoarch/hammer/advanced/examine(mob/user)
	. = ..()
	. += span_notice("Толщина снимаемого слоя: [dig_amount] см.")

/obj/item/xenoarch/brush/advanced
	name = "advanced archaeological brush"
	desc = "Улучшенная археологическая кисточка. Снимает по 1 см породы за полсекунды."
	icon_state = "adv_brush"
	dig_speed = 0.5 SECONDS
	custom_materials = /obj/item/xenoarch/hammer/advanced::custom_materials

/obj/item/xenoarch/handheld_scanner/advanced
	name = "advanced archaeological scanner"
	desc = "Улучшенный сканер показывает точную глубину находки."
	icon_state = "adv_scanner"
	advanced = TRUE
	scanning_speed = 1 SECONDS
	custom_materials = /obj/item/xenoarch/hammer/advanced::custom_materials
