/// Переносная камера на батарее. Штатный occupant владеет единственной находкой.
/obj/machinery/xenoarch_container
	name = "контейнер аномальных артефактов"
	desc = "Переносная камера подавления. Перетащите внутрь незакреплённый аномальный артефакт. Открывается нажатием руки при научном доступе. При разряде батареи или ЭМИ камера аварийно открывается."
	icon = 'modular_bandastation/xenoarchaeology/icons/sierra/anomaly_cage.dmi'
	icon_state = "anomaly_container"
	anchored = FALSE
	density = TRUE
	state_open = TRUE
	use_power = NO_POWER_USE
	interaction_flags_machine = INTERACT_MACHINE_ALLOW_SILICON | INTERACT_MACHINE_OPEN | INTERACT_MACHINE_OFFLINE
	req_access = list(ACCESS_RESEARCH)
	circuit = /obj/item/circuitboard/machine/xenoarch/container
	/// Джоули в секунду; заряд расходуется только при подавлении артефакта.
	var/power_draw = 100 WATTS
	/// Снимок внешнего вида не удерживает ссылку на артефакт.
	var/mutable_appearance/contained_appearance

/obj/machinery/xenoarch_container/Destroy()
	open_machine()
	contained_appearance = null
	return ..()

/obj/machinery/xenoarch_container/get_cell()
	return locate(/obj/item/stock_parts/power_store/cell) in contents

/obj/machinery/xenoarch_container/can_be_occupant(atom/movable/target)
	if(!istype(target, /obj/machinery/xenoartifact) || QDELETED(target))
		return FALSE
	var/obj/machinery/xenoartifact/artifact = target
	return artifact.random_effects && !artifact.anchored && !artifact.lab_owner?.resolve() && !artifact.has_buckled_mobs()

/obj/machinery/xenoarch_container/close_machine(atom/movable/target, density_to_set = TRUE)
	var/obj/item/stock_parts/power_store/cell/cell = get_cell()
	if(!state_open || occupant || panel_open || (machine_stat & BROKEN) || !cell?.charge || !isturf(target?.loc) || !Adjacent(target) || !can_be_occupant(target))
		return FALSE
	..()
	if(occupant != target || target.loc != src)
		return FALSE
	var/obj/machinery/xenoartifact/artifact = target
	artifact.set_containment(TRUE)
	update_appearance()
	return TRUE

/obj/machinery/xenoarch_container/mouse_drop_receive(atom/dropped, mob/living/user, params)
	if(!istype(user) || !can_interact(user) || !allowed(user) || !user.can_perform_action(dropped, NEED_DEXTERITY|NEED_HANDS|FORBID_TELEKINESIS_REACH) || !can_be_occupant(dropped))
		return
	if(!state_open || occupant || panel_open)
		return
	balloon_alert(user, "помещаем артефакт...")
	if(!do_after(user, 3 SECONDS, target = dropped))
		return
	if(!can_interact(user) || !allowed(user) || !user.can_perform_action(dropped, NEED_DEXTERITY|NEED_HANDS|FORBID_TELEKINESIS_REACH))
		return
	if(close_machine(dropped))
		add_fingerprint(user)
		playsound(src, 'sound/machines/closet/closet_close.ogg', 40, TRUE)

/obj/machinery/xenoarch_container/Exited(atom/movable/gone, direction)
	if(istype(gone, /obj/machinery/xenoartifact))
		var/obj/machinery/xenoartifact/artifact = gone
		artifact.set_containment(FALSE)
	. = ..()
	if(!occupant)
		state_open = TRUE
	update_appearance()

/obj/machinery/xenoarch_container/interact(mob/user)
	if(!allowed(user))
		balloon_alert(user, "нет научного доступа!")
		return
	if(panel_open)
		var/obj/item/stock_parts/power_store/cell/cell = get_cell()
		if(cell)
			component_parts -= cell
			cell.forceMove(drop_location())
			user.put_in_hands(cell)
		return
	if(occupant)
		open_machine()
		playsound(src, 'sound/machines/closet/closet_open.ogg', 40, TRUE)
	else
		balloon_alert(user, "перетащите артефакт внутрь")

/obj/machinery/xenoarch_container/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/stock_parts/power_store/cell))
		return ..()
	if(!allowed(user) || !panel_open || occupant || get_cell())
		return ITEM_INTERACT_BLOCKING
	if(!user.transferItemToLoc(tool, src))
		return ITEM_INTERACT_BLOCKING
	component_parts += tool
	update_appearance()
	return ITEM_INTERACT_SUCCESS

/obj/machinery/xenoarch_container/screwdriver_act(mob/living/user, obj/item/tool)
	if(occupant || !allowed(user))
		return ITEM_INTERACT_BLOCKING
	return default_deconstruction_screwdriver(user, tool)

/obj/machinery/xenoarch_container/crowbar_act(mob/living/user, obj/item/tool)
	return default_deconstruction_crowbar(user, tool)

/obj/machinery/xenoarch_container/process(seconds_per_tick)
	if(!occupant)
		return
	var/obj/item/stock_parts/power_store/cell/cell = get_cell()
	var/power_used = cell?.use(power_draw * seconds_per_tick, force = TRUE)
	if(QDELETED(src))
		return
	if((machine_stat & BROKEN) || !power_used || cell.charge <= 0)
		balloon_alert_to_viewers("аварийное открытие!")
		open_machine()

/obj/machinery/xenoarch_container/emp_act(severity)
	. = ..()
	if(. & EMP_PROTECT_SELF)
		return
	var/obj/item/stock_parts/power_store/cell/cell = get_cell()
	cell?.emp_act(severity)
	if(QDELETED(src))
		return
	open_machine()

/obj/machinery/xenoarch_container/update_overlays()
	. = ..()
	if(contained_appearance)
		underlays -= contained_appearance
		contained_appearance = null
	if(occupant)
		contained_appearance = new /mutable_appearance(occupant)
		contained_appearance.layer = FLOAT_LAYER
		contained_appearance.plane = FLOAT_PLANE
		underlays += contained_appearance
		. += mutable_appearance(icon, "anomaly_container_lights")
	if(panel_open)
		. += mutable_appearance(icon, "anomaly_container_panel")

/obj/machinery/xenoarch_container/examine(mob/user)
	. = ..()
	var/obj/item/stock_parts/power_store/cell/cell = get_cell()
	. += span_notice("Камера [occupant ? "закрыта: излучение подавлено" : "пуста"]. Батарея: [cell ? "[round(cell.percent())]%" : "отсутствует"].")
	. += span_notice("Для замены батареи откройте пустой контейнер отвёрткой и нажмите рукой. Вставьте заряженную батарею и закройте панель.")

/obj/item/circuitboard/machine/xenoarch/container
	name = "anomalous artifact container"
	build_path = /obj/machinery/xenoarch_container
	needs_anchored = FALSE
	req_components = list(/obj/item/stock_parts/power_store/cell = 1, /datum/stock_part/capacitor = 2, /obj/item/stack/sheet/plasteel = 2, /obj/item/stack/sheet/glass = 2)
	def_components = list(/obj/item/stock_parts/power_store/cell = /obj/item/stock_parts/power_store/cell/high)
