// AI EDIT START - Adapt the Lazarus event to the native Primera APIs and regression harness
#define GEOTHERMAL_GEN_OUTPUT 300
#define GEOTHERMAL_GEN_BROKEN 1
#define GEOTHERMAL_GEN_CABLES 2
#define GEOTHERMAL_GEN_WRENCH 3
#define GEOTHERMAL_GEN_SCREWDRIVER 4
#define GEOTHERMAL_GEN_ACTIVE 5

/** A fixed, repairable 300 W supply for the colony's small power grids. */
/obj/machinery/power/geothermal_generator
	name = "геотермальный генератор"
	desc = "Стационарный электрогенератор, вырабатывающий электроэнергию благодаря подземным источникам тепла. Время от времени нуждается в ремонте."
	icon = 'modular_bandastation/lazarus/icons/geothermal.dmi'
	icon_state = "geoterm_broken"
	density = TRUE
	anchored = TRUE
	opacity = TRUE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	/// Current step of the four-tool repair sequence.
	var/gen_state = GEOTHERMAL_GEN_BROKEN
	/// Scheduled mechanical failure; cancelled on sabotage or deletion.
	var/break_timer

/obj/machinery/power/geothermal_generator/Initialize(mapload)
	. = ..()
	connect_to_network()
	update_appearance(UPDATE_ICON_STATE)

/obj/machinery/power/geothermal_generator/Destroy()
	if(break_timer)
		deltimer(break_timer)
		break_timer = null
	return ..()

/obj/machinery/power/geothermal_generator/examine(mob/user)
	. = ..()
	switch(gen_state)
		if(GEOTHERMAL_GEN_BROKEN)
			. += span_notice("Генератор сломан. Откройте крышку отвёрткой.")
		if(GEOTHERMAL_GEN_CABLES)
			. += span_notice("Крышка открыта. Замените повреждённые провода кусачками.")
		if(GEOTHERMAL_GEN_WRENCH)
			. += span_notice("Из-под крышки валит пар. Отрегулируйте подачу гаечным ключом.")
		if(GEOTHERMAL_GEN_SCREWDRIVER)
			. += span_notice("Механизм исправен. Закройте крышку отвёрткой.")
		if(GEOTHERMAL_GEN_ACTIVE)
			. += span_notice("Генератор работает, вырабатывая [GEOTHERMAL_GEN_OUTPUT] W.")
			. += span_warning("В боевом режиме генератор можно саботировать монтировкой.")

/obj/machinery/power/geothermal_generator/update_icon_state()
	switch(gen_state)
		if(GEOTHERMAL_GEN_BROKEN)
			icon_state = "geoterm_broken"
		if(GEOTHERMAL_GEN_CABLES)
			icon_state = "geoterm_1"
		if(GEOTHERMAL_GEN_WRENCH)
			icon_state = "geoterm_2"
		if(GEOTHERMAL_GEN_SCREWDRIVER)
			icon_state = "geoterm_3"
		if(GEOTHERMAL_GEN_ACTIVE)
			icon_state = "geoterm_active"
	return ..()

/obj/machinery/power/geothermal_generator/process(seconds_per_tick)
	if(gen_state != GEOTHERMAL_GEN_ACTIVE)
		return
	if(QDELETED(powernet))
		break_gen()
		return
	add_avail(power_to_energy(GEOTHERMAL_GEN_OUTPUT))

/obj/machinery/power/geothermal_generator/screwdriver_act(mob/living/user, obj/item/tool)
	if(user.combat_mode)
		return NONE
	if(gen_state == GEOTHERMAL_GEN_BROKEN)
		return repair_step(user, tool, GEOTHERMAL_GEN_BROKEN, GEOTHERMAL_GEN_CABLES)
	if(gen_state == GEOTHERMAL_GEN_SCREWDRIVER)
		return repair_step(user, tool, GEOTHERMAL_GEN_SCREWDRIVER, GEOTHERMAL_GEN_ACTIVE)
	return ITEM_INTERACT_BLOCKING

/obj/machinery/power/geothermal_generator/wirecutter_act(mob/living/user, obj/item/tool)
	if(user.combat_mode)
		return NONE
	return repair_step(user, tool, GEOTHERMAL_GEN_CABLES, GEOTHERMAL_GEN_WRENCH)

/obj/machinery/power/geothermal_generator/wrench_act(mob/living/user, obj/item/tool)
	if(user.combat_mode)
		return NONE
	return repair_step(user, tool, GEOTHERMAL_GEN_WRENCH, GEOTHERMAL_GEN_SCREWDRIVER)

/** All repair steps share the same timed use and revalidate their starting state. */
/obj/machinery/power/geothermal_generator/proc/repair_step(mob/living/user, obj/item/tool, expected_state, next_state)
	if(gen_state != expected_state || !tool.tool_start_check(user, 0))
		return ITEM_INTERACT_BLOCKING
	balloon_alert(user, "ремонт генератора...")
	if(!tool.use_tool(src, user, 8 SECONDS, volume = 50))
		return ITEM_INTERACT_BLOCKING
	if(QDELETED(src) || QDELETED(user) || QDELETED(tool) || gen_state != expected_state || user.incapacitated || user.combat_mode || !user.Adjacent(src) || !user.is_holding(tool))
		return ITEM_INTERACT_BLOCKING
	gen_state = next_state
	update_appearance(UPDATE_ICON_STATE)
	if(gen_state == GEOTHERMAL_GEN_ACTIVE)
		break_timer = addtimer(CALLBACK(src, PROC_REF(break_gen)), rand(40 MINUTES, 60 MINUTES), TIMER_STOPPABLE)
	balloon_alert(user, "готово")
	return ITEM_INTERACT_SUCCESS

/obj/machinery/power/geothermal_generator/crowbar_act(mob/living/user, obj/item/tool)
	if(!user.combat_mode)
		return NONE
	if(gen_state != GEOTHERMAL_GEN_ACTIVE || !tool.tool_start_check(user, 0))
		return ITEM_INTERACT_BLOCKING
	balloon_alert(user, "саботаж генератора...")
	if(!tool.use_tool(src, user, 8 SECONDS, volume = 50))
		return ITEM_INTERACT_BLOCKING
	if(QDELETED(src) || QDELETED(user) || QDELETED(tool) || gen_state != GEOTHERMAL_GEN_ACTIVE || user.incapacitated || !user.combat_mode || !user.Adjacent(src) || !user.is_holding(tool))
		return ITEM_INTERACT_BLOCKING
	log_combat(user, src, "sabotaged")
	break_gen()
	return ITEM_INTERACT_SUCCESS

/** A disconnected, sabotaged or worn generator always restarts at the first repair. */
/obj/machinery/power/geothermal_generator/proc/break_gen()
	if(break_timer)
		deltimer(break_timer)
		break_timer = null
	gen_state = GEOTHERMAL_GEN_BROKEN
	update_appearance(UPDATE_ICON_STATE)

#undef GEOTHERMAL_GEN_OUTPUT
#undef GEOTHERMAL_GEN_BROKEN
#undef GEOTHERMAL_GEN_CABLES
#undef GEOTHERMAL_GEN_WRENCH
#undef GEOTHERMAL_GEN_SCREWDRIVER
#undef GEOTHERMAL_GEN_ACTIVE
// AI EDIT END
