/// Местные модели заменяют внешние эксклюзивные модули NovaSector.
/obj/vehicle/sealed/mecha/reticence/loaded/xenoarch
	wreckage = /obj/structure/mecha_wreckage/reticence/xenoarch
	name = "Фантом"
	desc = "Древний Reticence, покрытый пылью. Сервоприводы повреждены, батарея почти выработала ресурс."

/obj/vehicle/sealed/mecha/reticence/loaded/xenoarch/Initialize(mapload)
	. = ..()
	update_integrity(max_integrity * 0.5)
	QDEL_NULL(cell)
	cell = new /obj/item/stock_parts/power_store/cell/xenoarch(src)

/obj/vehicle/sealed/mecha/odysseus/xenoarch
	icon = 'modular_bandastation/xenoarchaeology/icons/artifacts/mecha.dmi'
	icon_state = "medivac"
	base_icon_state = "medivac"
	wreckage = /obj/structure/mecha_wreckage/odysseus/xenoarch
	name = "Медэвак"
	desc = "Старинный медицинский экзокостюм. Его ещё можно вернуть в строй."

/obj/vehicle/sealed/mecha/odysseus/xenoarch/Initialize(mapload)
	. = ..()
	update_integrity(max_integrity * 0.5)
	QDEL_NULL(cell)
	cell = new /obj/item/stock_parts/power_store/cell/xenoarch(src)

/obj/vehicle/sealed/mecha/savannah_ivanov/xenoarch
	icon = 'modular_bandastation/xenoarchaeology/icons/artifacts/coop_mech.dmi'
	wreckage = /obj/structure/mecha_wreckage/savannah_ivanov/xenoarch
	name = "Красное воскресенье"
	desc = "Ранний тяжёлый двухместный экзокостюм. Толстая броня сохранилась лучше медлительных приводов."
	movedelay = 6
	max_integrity = 562.5

/obj/vehicle/sealed/mecha/savannah_ivanov/xenoarch/Initialize(mapload)
	. = ..()
	update_integrity(max_integrity * 0.5)
	QDEL_NULL(cell)
	cell = new /obj/item/stock_parts/power_store/cell/xenoarch(src)

/obj/vehicle/sealed/mecha/durand/xenoarch
	icon = 'modular_bandastation/xenoarchaeology/icons/artifacts/mecha.dmi'
	icon_state = "peacemaker"
	base_icon_state = "peacemaker"
	wreckage = /obj/structure/mecha_wreckage/durand/xenoarch
	name = "Миротворец-07"
	desc = "Забытый прототип экзокостюма подавления беспорядков. Корпус потерял прочность за годы в породе."
	movedelay = 3
	max_integrity = 300
	force = 5
	equip_by_category = list(MECHA_L_ARM = /obj/item/mecha_parts/mecha_equipment/weapon/energy/disabler, MECHA_R_ARM = /obj/item/mecha_parts/mecha_equipment/weapon/energy/disabler)

/obj/vehicle/sealed/mecha/durand/xenoarch/Initialize(mapload)
	. = ..()
	update_integrity(max_integrity * 0.5)
	QDEL_NULL(cell)
	cell = new /obj/item/stock_parts/power_store/cell/xenoarch(src)

/obj/item/stock_parts/power_store/cell/xenoarch
	name = "ancient depleted power cell"
	desc = "Старинная батарея, почти утратившая ёмкость за долгие годы в породе."
	icon_state = "bscell"
	maxcharge = STANDARD_CELL_CHARGE * 0.3

/obj/structure/mecha_wreckage/reticence/xenoarch
	icon = 'modular_bandastation/xenoarchaeology/icons/artifacts/mecha.dmi'
	icon_state = "phantom-broken"

/obj/structure/mecha_wreckage/odysseus/xenoarch
	icon = 'modular_bandastation/xenoarchaeology/icons/artifacts/mecha.dmi'
	icon_state = "medivac-broken"

/obj/structure/mecha_wreckage/savannah_ivanov/xenoarch
	icon = 'modular_bandastation/xenoarchaeology/icons/artifacts/coop_mech.dmi'
	icon_state = "savannah_ivanov-broken"

/obj/structure/mecha_wreckage/durand/xenoarch
	icon = 'modular_bandastation/xenoarchaeology/icons/artifacts/mecha.dmi'
	icon_state = "peacemaker-broken"
