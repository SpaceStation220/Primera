GLOBAL_LIST_EMPTY(monkey_recyclers)

/obj/machinery/monkey_recycler
	name = "monkey recycler"
	desc = "Машина для переработки низших форм в кубики соответствующего вида."
	icon = 'icons/obj/machines/kitchen.dmi'
	icon_state = "grinder"
	base_icon_state = "grinder"
	layer = BELOW_OBJ_LAYER
	interaction_flags_mouse_drop = NEED_DEXTERITY
	density = TRUE
	circuit = /obj/item/circuitboard/machine/monkey_recycler

	/// Recycled material in cube equivalents, keyed by the type of cube it can produce.
	var/list/stored_matter = list()
	var/cube_production = 0.2

/obj/machinery/monkey_recycler/Initialize(mapload)
	. = ..()
	if (mapload)
		GLOB.monkey_recyclers += src
	add_overlay("grinder_monkey")

/obj/machinery/monkey_recycler/Destroy()
	GLOB.monkey_recyclers -= src
	return ..()

/obj/machinery/monkey_recycler/RefreshParts() //Ranges from 0.2 to 0.8 per monkey recycled
	. = ..()
	cube_production = 0
	for(var/datum/stock_part/servo/servo in component_parts)
		cube_production += servo.tier * 0.1
	for(var/datum/stock_part/matter_bin/matter_bin in component_parts)
		cube_production += matter_bin.tier * 0.1

/obj/machinery/monkey_recycler/examine(mob/user)
	. = ..()
	if(in_range(user, src) || isobserver(user))
		. += span_notice("На дисплее состояния отображается: Производит <b>[cube_production]</b> [declension_ru(cube_production,"кубик","кубика","кубиков")] за каждое переработанное существо.")

/obj/machinery/monkey_recycler/wrench_act(mob/living/user, obj/item/tool)
	. = ..()
	if(default_unfasten_wrench(user, tool))
		power_change()
	return ITEM_INTERACT_SUCCESS

/obj/machinery/monkey_recycler/screwdriver_act(mob/living/user, obj/item/tool)
	return default_deconstruction_screwdriver(user, tool)

/obj/machinery/monkey_recycler/crowbar_act(mob/living/user, obj/item/tool)
	return default_pry_open(user, tool, close_after_pry = TRUE, deconstruct_on_fail = TRUE)

/obj/machinery/monkey_recycler/update_icon_state()
	. = ..()
	icon_state = panel_open ? "[base_icon_state]_open" : base_icon_state

/obj/machinery/monkey_recycler/mouse_drop_receive(mob/living/target, mob/living/user, params)
	if(!istype(target))
		return
	if(ismonkey(target))
		stuff_monkey_in(target, user)

/obj/machinery/monkey_recycler/proc/stuff_monkey_in(mob/living/carbon/human/target, mob/living/user)
	if(!ismonkey(target))
		return
	if(!IS_UNCONSCIOUS_OR_CRIT(target))
		to_chat(user, span_warning("Существо слишком сильно сопротивляется, чтобы поместить его в утилизатор."))
		return
	if(target.buckled || target.has_buckled_mobs())
		to_chat(user, span_warning("Тело существа к чему-то пристёгнуто."))
		return
	var/datum/species/monkey/lesser_species = target.dna.species
	var/obj/item/food/monkeycube/cube_type = lesser_species.recycled_cube_type
	qdel(target)
	to_chat(user, span_notice("Вы помещаете существо в машину."))
	playsound(src.loc, 'sound/machines/juicer.ogg', 50, TRUE)
	var/offset = prob(50) ? -2 : 2
	animate(src, pixel_x = pixel_x + offset, time = 0.2, loop = 200) //start shaking
	use_energy(active_power_usage)
	var/stock = round(stored_matter[cube_type] + cube_production, 0.1)
	stored_matter[cube_type] = stock
	addtimer(VARSET_CALLBACK(src, pixel_x, base_pixel_x))
	to_chat(user, span_notice("Запас материала для «[initial(cube_type.name)]»: [stock]."))

/obj/machinery/monkey_recycler/interact(mob/user)
	var/printed = FALSE
	for(var/obj/item/food/monkeycube/cube_type as anything in stored_matter)
		var/ready = floor(stored_matter[cube_type])
		if(!ready)
			continue
		stored_matter[cube_type] -= ready
		for(var/i in 1 to ready)
			new cube_type(drop_location())
		printed = TRUE
	if(printed)
		to_chat(user, span_notice("Машина громко шипит и выдаёт кубы из переработанного материала."))
		playsound(src.loc, 'sound/machines/hiss.ogg', 50, TRUE)
	else
		to_chat(user, span_danger("Для изготовления куба нужна хотя бы одна единица материала одного вида."))

/obj/machinery/monkey_recycler/multitool_act(mob/living/user, obj/item/multitool/I)
	. = ..()
	if(istype(I))
		I.set_buffer(src)
		balloon_alert(user, "сохранено в буфер multitool")
		return TRUE
