// AI EDIT START - Adapt the Lazarus event to the native Primera APIs and regression harness
/** Portable tests detect an active parasite, not the hidden incubation period. */
/obj/item/treacherous_flesh_tester
	name = "тестер коварной плоти"
	w_class = WEIGHT_CLASS_SMALL
	/// Message shown when the instrument detects a parasite.
	var/positive_message = "Тест положительный."
	/// Message shown when no active parasite is present.
	var/negative_message = "Тест отрицательный."
	/// Whether scanning consumes the instrument.
	var/single_use = FALSE
	/// Consumed only after a valid scan of a reachable human.
	var/used = FALSE

/obj/item/treacherous_flesh_tester/interact_with_atom(atom/target, mob/living/user, list/modifiers)
	if(!ishuman(target) || !user.Adjacent(target) || !user.can_perform_action(src, NEED_DEXTERITY))
		return NONE
	if(single_use && used)
		to_chat(user, span_notice("Тестер уже использован."))
		return ITEM_INTERACT_BLOCKING
	var/mob/living/carbon/human/patient = target
	user.visible_message(patient.treacherous_flesh ? span_boldwarning(positive_message) : span_notice(negative_message))
	if(single_use)
		used = TRUE
		icon_state = "lazarus_empty"
	return ITEM_INTERACT_SUCCESS

/obj/item/treacherous_flesh_tester/covid
	name = "одноразовый тестер на космо-ковид"
	desc = "Одноразовый тест неизвестного производителя."
	icon = 'modular_bandastation/lazarus/icons/testers.dmi'
	icon_state = "lazarus_hypo"
	single_use = TRUE
	positive_message = "Тестер показывает красную лампочку. Похоже, тест положительный."
	negative_message = "Тестер показывает зелёную лампочку. Похоже, тест отрицательный."

/obj/item/treacherous_flesh_tester/artifact
	name = "странный кристалл"
	desc = "Синеватый кристалл, реагирующий на заражённые ткани."
	icon = 'modular_bandastation/lazarus/icons/wizard.dmi'
	icon_state = "purified_soulstone"
	positive_message = "Кристалл выпускает синеватое свечение."
	negative_message = "Кристалл никак не реагирует."
// AI EDIT END
