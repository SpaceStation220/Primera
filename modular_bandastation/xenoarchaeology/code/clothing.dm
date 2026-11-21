/// Герметичный комплект для полевых раскопок; защита от артефактов использует штатную биоброню.
/obj/item/clothing/head/helmet/space/xenoarch
	name = "excavation voidsuit helmet"
	desc = "Шлем ксеноархеолога для работы в разреженной атмосфере. Экранирование ослабляет восприимчивость к эффектам артефактов."
	icon = 'modular_bandastation/xenoarchaeology/icons/sierra/clothing/heads.dmi'
	worn_icon = 'modular_bandastation/xenoarchaeology/icons/sierra/clothing/heads_worn.dmi'
	icon_state = "rig0-excavation"
	worn_icon_state = "excavation-helm"
	inhand_icon_state = "excavation_helm"
	lefthand_file = 'modular_bandastation/xenoarchaeology/icons/sierra/clothing/lefthand.dmi'
	righthand_file = 'modular_bandastation/xenoarchaeology/icons/sierra/clothing/righthand.dmi'
	visor_dirt = null

/obj/item/clothing/suit/space/xenoarch
	name = "excavation voidsuit"
	desc = "Герметичный скафандр для ксеноархеологических раскопок со штатным терморегулятором. Экранирование ослабляет восприимчивость к эффектам артефактов."
	icon = 'modular_bandastation/xenoarchaeology/icons/sierra/clothing/suits.dmi'
	worn_icon = 'modular_bandastation/xenoarchaeology/icons/sierra/clothing/suits_worn.dmi'
	icon_state = "rig-excavation"
	inhand_icon_state = "excavation_voidsuit"
	lefthand_file = 'modular_bandastation/xenoarchaeology/icons/sierra/clothing/lefthand.dmi'
	righthand_file = 'modular_bandastation/xenoarchaeology/icons/sierra/clothing/righthand.dmi'
	allowed = list(
		/obj/item/flashlight,
		/obj/item/gps,
		/obj/item/tank/internals,
		/obj/item/xenoarch/core_sampler,
		/obj/item/xenoarch/handheld_scanner,
		/obj/item/xenoarch/measuring_tape,
		/obj/item/xenoarch/stabilizer,
	)

/// Лабораторный комплект сохраняет ограничения обычной биозащиты: он не герметичен.
/obj/item/clothing/head/bio_hood/xenoarch
	name = "anomaly hood"
	desc = "Защитный капюшон для работы с аномальными материалами и биологическим загрязнением. Не заменяет космический шлем."
	icon = 'modular_bandastation/xenoarchaeology/icons/sierra/clothing/heads.dmi'
	worn_icon = 'modular_bandastation/xenoarchaeology/icons/sierra/clothing/heads_worn.dmi'
	icon_state = "bio_anom_hood"
	inhand_icon_state = "bio_anom_hood"
	lefthand_file = 'modular_bandastation/xenoarchaeology/icons/sierra/clothing/lefthand.dmi'
	righthand_file = 'modular_bandastation/xenoarchaeology/icons/sierra/clothing/righthand.dmi'
	dirt_state = null

/obj/item/clothing/suit/bio_suit/xenoarch
	name = "anomaly suit"
	desc = "Биозащитный костюм для лабораторной работы с артефактами. Ослабляет восприимчивость к их эффектам, но не защищает от разгерметизации."
	icon = 'modular_bandastation/xenoarchaeology/icons/sierra/clothing/suits.dmi'
	worn_icon = 'modular_bandastation/xenoarchaeology/icons/sierra/clothing/suits_worn.dmi'
	icon_state = "bio_anom"
	inhand_icon_state = "bio_anom"
	lefthand_file = 'modular_bandastation/xenoarchaeology/icons/sierra/clothing/lefthand.dmi'
	righthand_file = 'modular_bandastation/xenoarchaeology/icons/sierra/clothing/righthand.dmi'
	supports_variations_flags = NONE
	bodyshapes_with_variations = NONE

/datum/supply_pack/science/xenoarch_clothing
	name = "Защитная одежда ксеноархеологов"
	desc = "Два комплекта: герметичный скафандр со шлемом для раскопок и лабораторный биозащитный костюм с капюшоном. Дыхательные баллоны, маски, перчатки и очки заказываются отдельно."
	cost = CARGO_CRATE_VALUE * 10
	contains = list(
		/obj/item/clothing/head/helmet/space/xenoarch,
		/obj/item/clothing/suit/space/xenoarch,
		/obj/item/clothing/head/bio_hood/xenoarch,
		/obj/item/clothing/suit/bio_suit/xenoarch,
	)
	crate_name = "защитная одежда ксеноархеологов"
