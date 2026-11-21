/// Батарея владеет копией эффекта и не зависит от жизни исходного артефакта.
/obj/item/xenoarch/particle_battery
	name = "exotic particle battery"
	desc = "Батарея экзотических частиц. Заряжается в сборщике, применяется через излучатель."
	icon = 'modular_bandastation/xenoarchaeology/icons/artifacts/machinery.dmi'
	icon_state = "particles_battery0"
	custom_materials = list(/datum/material/iron = HALF_SHEET_MATERIAL_AMOUNT, /datum/material/plasma = HALF_SHEET_MATERIAL_AMOUNT, /datum/material/bluespace = SMALL_MATERIAL_AMOUNT)
	var/datum/xenoartifact_effect/battery_effect
	var/capacity = 200
	var/stored_charge = 0
	var/source_signature

/obj/item/xenoarch/particle_battery/Destroy()
	QDEL_NULL(battery_effect)
	return ..()

/obj/item/xenoarch/particle_battery/examine(mob/user)
	. = ..()
	. += span_notice("Заряд: [round(stored_charge, 0.1)]/[capacity].")

/obj/item/xenoarch/particle_battery/proc/get_charge_level()
	return round(clamp(stored_charge / max(1, capacity) * 100, 0, 100), 25)

/// Обновляем батарею и её гнездо только при переходе между ступенями индикатора.
/obj/item/xenoarch/particle_battery/proc/set_charge(amount)
	var/previous_level = get_charge_level()
	stored_charge = clamp(amount, 0, capacity)
	if(previous_level != get_charge_level())
		update_appearance()
		if(istype(loc, /obj/item/xenoarch/particle_utilizer))
			loc.update_appearance()

/obj/item/xenoarch/particle_battery/update_icon_state()
	. = ..()
	icon_state = "particles_battery[get_charge_level()]"

/// Излучатель управляет временем и расходом батареи, эффект обрабатывается ровно один раз SSobj.
/obj/item/xenoarch/particle_utilizer
	name = "exotic particle utilizer"
	desc = "Излучатель эффектов батареи. Перед включением убедитесь, что известны свойства излучения."
	icon = 'modular_bandastation/xenoarchaeology/icons/artifacts/machinery.dmi'
	icon_state = "utilizer"
	custom_materials = list(/datum/material/iron = HALF_SHEET_MATERIAL_AMOUNT, /datum/material/plasma = HALF_SHEET_MATERIAL_AMOUNT)
	var/active = FALSE
	var/duration = 5
	/// Ноль означает непрерывное излучение.
	var/stop_at = 0
	COOLDOWN_DECLARE(emission_cooldown)

/obj/item/xenoarch/particle_utilizer/Destroy()
	stop_emission()
	return ..()

/obj/item/xenoarch/particle_utilizer/proc/get_battery()
	return locate(/obj/item/xenoarch/particle_battery) in contents

/obj/item/xenoarch/particle_utilizer/Entered(atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	. = ..()
	if(istype(arrived, /obj/item/xenoarch/particle_battery))
		update_appearance()

/obj/item/xenoarch/particle_utilizer/Exited(atom/movable/gone, direction)
	if(istype(gone, /obj/item/xenoarch/particle_battery))
		var/obj/item/xenoarch/particle_battery/battery = gone
		battery.battery_effect?.turn_effect_off()
		stop_emission()
	return ..()

/obj/item/xenoarch/particle_utilizer/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/xenoarch/particle_battery))
		return ..()
	if(get_battery() || !user.transferItemToLoc(tool, src))
		return ITEM_INTERACT_BLOCKING
	balloon_alert(user, "батарея установлена")
	return ITEM_INTERACT_SUCCESS

/obj/item/xenoarch/particle_utilizer/proc/start_emission(timed = FALSE)
	var/obj/item/xenoarch/particle_battery/battery = get_battery()
	if(active || !COOLDOWN_FINISHED(src, emission_cooldown) || !battery?.battery_effect || battery.stored_charge <= 0)
		return FALSE
	active = TRUE
	stop_at = timed ? world.time + duration SECONDS : 0
	if(!battery.battery_effect.activated)
		battery.battery_effect.ToggleActivate(FALSE)
	START_PROCESSING(SSobj, src)
	update_appearance()
	return TRUE

/obj/item/xenoarch/particle_utilizer/proc/stop_emission()
	if(active)
		COOLDOWN_START(src, emission_cooldown, 5 SECONDS)
	active = FALSE
	stop_at = 0
	var/obj/item/xenoarch/particle_battery/battery = get_battery()
	battery?.battery_effect?.turn_effect_off()
	STOP_PROCESSING(SSobj, src)
	update_appearance()

/obj/item/xenoarch/particle_utilizer/update_icon_state()
	. = ..()
	var/obj/item/xenoarch/particle_battery/battery = get_battery()
	icon_state = battery ? "utilizer[battery.get_charge_level()]_[active ? "on" : "off"]" : "utilizer"

/obj/item/xenoarch/particle_utilizer/process(seconds_per_tick)
	var/obj/item/xenoarch/particle_battery/battery = get_battery()
	if(!active || !battery?.battery_effect || battery.stored_charge <= 0 || (stop_at && world.time >= stop_at))
		stop_emission()
		return
	battery.set_charge(battery.stored_charge - 0.5 * seconds_per_tick)
	if(isliving(loc) && battery.battery_effect.release_method == XENO_EFFECT_TOUCH)
		battery.battery_effect.do_effect_touch(loc)
	if(!battery.stored_charge)
		stop_emission()

/obj/item/xenoarch/particle_utilizer/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!isliving(interacting_with))
		return ..()
	var/obj/item/xenoarch/particle_battery/battery = get_battery()
	if(!active || !battery?.battery_effect || battery.stored_charge < 20 || !user.is_holding(src) || !user.can_perform_action(interacting_with, NEED_DEXTERITY|NEED_HANDS|FORBID_TELEKINESIS_REACH))
		return ITEM_INTERACT_BLOCKING
	if(battery.battery_effect.release_method != XENO_EFFECT_TOUCH)
		return ITEM_INTERACT_BLOCKING
	battery.battery_effect.do_effect_touch(interacting_with)
	battery.set_charge(battery.stored_charge - 20)
	log_combat(user, interacting_with, "применил излучатель", src, "эффект: [battery.battery_effect.log_name]")
	return ITEM_INTERACT_SUCCESS

/obj/item/xenoarch/particle_utilizer/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "XenoartifactUtilizer", declent_ru(NOMINATIVE))
		ui.open()

/obj/item/xenoarch/particle_utilizer/ui_data(mob/user)
	var/obj/item/xenoarch/particle_battery/battery = get_battery()
	return list("active" = active, "duration" = duration, "remaining" = stop_at ? max(0, (stop_at - world.time) / 10) : null, "hasBattery" = !!battery, "charge" = battery?.stored_charge || 0, "capacity" = battery?.capacity || 200, "ready" = COOLDOWN_FINISHED(src, emission_cooldown))

/obj/item/xenoarch/particle_utilizer/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	switch(action)
		if("start", "timed")
			if(start_emission(action == "timed"))
				log_combat(ui.user, src, "включил излучатель частиц")
				return TRUE
		if("stop")
			stop_emission()
			return TRUE
		if("eject")
			stop_emission()
			var/obj/item/xenoarch/particle_battery/battery = get_battery()
			battery?.forceMove(drop_location())
			return TRUE
		if("duration")
			if(!istext(params["value"]))
				return FALSE
			var/seconds = text2num(params["value"])
			if(!active && isnum(seconds) && seconds >= 1 && seconds <= 200)
				duration = round(seconds)
				return TRUE
