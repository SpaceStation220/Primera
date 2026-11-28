/// Ископаемые Sierra используют местный цикл очистки осадочных оболочек.
/obj/item/xenoarch_fossil
	name = "fossilised bone"
	desc = "Окаменевшая кость давно исчезнувшего существа. Приложите её к ископаемому черепу, чтобы начать сборку экспоната."
	icon = 'modular_bandastation/xenoarchaeology/icons/sierra/xenoarchaeology_finds.dmi'
	icon_state = "bone"
	w_class = WEIGHT_CLASS_SMALL
	inhand_icon_state = "Gibtonite ore"
	lefthand_file = 'icons/mob/inhands/items_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items_righthand.dmi'

/obj/item/xenoarch_fossil/skull
	name = "fossilised skull"
	desc = "Ископаемый череп. Приложите к нему кость, затем добавьте оставшиеся кости в каркас скелета."
	icon_state = "skull"

/obj/item/xenoarch_fossil/skull/horned
	name = "horned fossilised skull"
	icon_state = "hskull"

/obj/item/xenoarch_fossil/skull/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(tool.type != /obj/item/xenoarch_fossil)
		return ..()
	if(!user.can_perform_action(src, NEED_DEXTERITY|NEED_HANDS|FORBID_TELEKINESIS_REACH) || !(loc == user || isturf(loc)) || !user.is_holding(tool))
		return ITEM_INTERACT_BLOCKING
	var/obj/structure/xenoarch_skeleton/display = new(get_turf(src))
	if(!user.transferItemToLoc(tool, display))
		qdel(display)
		return ITEM_INTERACT_BLOCKING
	if(loc == user)
		if(!user.transferItemToLoc(src, display))
			display.dump_contents()
			qdel(display)
			return ITEM_INTERACT_BLOCKING
	else
		forceMove(display)
	display.update_appearance()
	return ITEM_INTERACT_SUCCESS

/obj/item/xenoarch_fossil/shell
	name = "fossilised shell"
	desc = "Каменный отпечаток панциря древнего беспозвоночного. Самостоятельная палеонтологическая находка."
	icon_state = "shell"

/obj/item/xenoarch_fossil/plant
	name = "fossilised plant"
	desc = "Отпечаток древнего растения в камне. Семян и живой ткани в нём не осталось."
	icon_state = "plant1"

/obj/item/xenoarch_fossil/plant/Initialize(mapload)
	. = ..()
	icon_state = "plant[rand(1, 4)]"

/obj/structure/xenoarch_skeleton
	name = "ископаемый скелет"
	desc = "Палеонтологический экспонат. Для сборки нужны череп и шесть ископаемых костей. Подпишите табличку ручкой; гаечным ключом можно закрепить экспонат."
	icon = 'modular_bandastation/xenoarchaeology/icons/sierra/xenoarchaeology_finds.dmi'
	icon_state = "uskel"
	anchored = FALSE
	density = TRUE
	max_integrity = 100
	/// Хранится текст подписи, а не имя предмета: локализация сохраняется.
	var/plaque = "Неизвестный древний вид"

/obj/structure/xenoarch_skeleton/proc/bone_count()
	var/amount = 0
	for(var/obj/item/xenoarch_fossil/fossil in contents)
		if(fossil.type == /obj/item/xenoarch_fossil)
			amount++
	return amount

/obj/structure/xenoarch_skeleton/proc/is_complete()
	return bone_count() == 6 && (locate(/obj/item/xenoarch_fossil/skull) in contents)

/obj/structure/xenoarch_skeleton/update_icon_state()
	. = ..()
	icon_state = is_complete() ? "skel" : "uskel"

/obj/structure/xenoarch_skeleton/Exited(atom/movable/gone, direction)
	. = ..()
	update_appearance()

/obj/structure/xenoarch_skeleton/examine(mob/user)
	. = ..()
	. += span_notice("Кости: [bone_count()]/6. [is_complete() ? "Скелет собран." : "Скелет ещё не собран."]")
	if(locate(/obj/item/xenoarch_fossil/skull/horned) in contents)
		. += span_notice("Скелет увенчан рогатым черепом.")
	. += span_notice("Табличка: «[html_encode(plaque)]».")

/obj/structure/xenoarch_skeleton/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(tool.type == /obj/item/xenoarch_fossil)
		if(!user.can_perform_action(src, NEED_DEXTERITY|NEED_HANDS|FORBID_TELEKINESIS_REACH) || bone_count() >= 6 || !user.transferItemToLoc(tool, src))
			return ITEM_INTERACT_BLOCKING
		update_appearance()
		return ITEM_INTERACT_SUCCESS
	if(istype(tool, /obj/item/pen))
		if(!user.is_holding(tool) || !user.can_perform_action(src, NEED_DEXTERITY|NEED_HANDS|FORBID_TELEKINESIS_REACH))
			return ITEM_INTERACT_BLOCKING
		var/new_plaque = tgui_input_text(user, "Название древнего вида или подпись экспоната", "Табличка экспоната", plaque, max_length = 64)
		if(isnull(new_plaque) || QDELETED(src) || QDELETED(tool) || QDELETED(user) || !user.is_holding(tool) || !user.can_perform_action(src, NEED_DEXTERITY|NEED_HANDS|FORBID_TELEKINESIS_REACH))
			return ITEM_INTERACT_BLOCKING
		plaque = trim(copytext_char(new_plaque, 1, 65))
		return ITEM_INTERACT_SUCCESS
	return ..()

/obj/structure/xenoarch_skeleton/wrench_act(mob/living/user, obj/item/tool)
	return default_unfasten_wrench(user, tool)

/obj/structure/xenoarch_skeleton/handle_deconstruct(disassembled = TRUE)
	dump_contents()
	return ..()

/obj/structure/xenoarch_skeleton/dump_contents()
	for(var/atom/movable/part as anything in contents)
		part.forceMove(get_turf(src))

/obj/effect/spawner/random/xenoarch/fossil
	loot = list(/obj/item/xenoarch_fossil = 9, /obj/item/xenoarch_fossil/skull = 3, /obj/item/xenoarch_fossil/skull/horned = 2, /obj/item/xenoarch_fossil/shell = 2, /obj/item/xenoarch_fossil/plant = 2)
