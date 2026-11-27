/datum/looping_sound/ipc_coffee
	mid_sounds = 'modular_bandastation/species/sound/ipc/ipc_coffee_machine_10s.ogg'
	mid_length = 10 SECONDS
	volume = 70
	use_sound_tokens = TRUE

/datum/ipc_os_program/factory/drinks
	id = "factory_drinks"
	name = "Синтезатор напитков"
	description = "Выберите напиток и возьмите пустую ёмкость в активную руку. Приготовление занимает 10 секунд и расходует 5% заряда при успехе."
	icon = "mug-hot"
	builtin_department = "service"
	var/selected_drink = "coffee"
	var/obj/item/reagent_containers/cup/vessel
	var/datum/looping_sound/ipc_coffee/audio

/datum/ipc_os_program/factory/drinks/stop()
	restore_vessel(vessel)
	return ..()

/datum/ipc_os_program/factory/drinks/proc/recipe(id)
	switch(id)
		if("cola")
			return /obj/item/reagent_containers/cup/soda_cans/cola
		if("beer")
			return /obj/item/reagent_containers/cup/glass/bottle/beer
		if("coffee")
			return /obj/item/reagent_containers/cup/glass/coffee
	return null

/datum/ipc_os_program/factory/drinks/command(list/params)
	if(vessel)
		return FALSE
	if(params["drink"])
		if(!recipe(params["drink"]))
			return FALSE
		selected_drink = params["drink"]
		return TRUE
	var/obj/item/reagent_containers/cup/held = os.host.get_active_held_item()
	if(!istype(held) || held.reagents?.total_volume || os.host.nutrition < os.host.ipc_charge_capacity() * 0.05 || !os.host.transferItemToLoc(held, os.core))
		os.error_message = "Нужны пустая ёмкость в активной руке и достаточный заряд."
		return FALSE
	vessel = held
	INVOKE_ASYNC(src, PROC_REF(brew), held, selected_drink, activation_id)
	return TRUE

/datum/ipc_os_program/factory/drinks/proc/valid_brew(obj/item/reagent_containers/cup/expected, activation)
	return running && activation_id == activation && os?.can_use(os.host) && !QDELETED(expected) && vessel == expected && expected.loc == os.core && !expected.reagents?.total_volume && os.host.nutrition >= os.host.ipc_charge_capacity() * 0.05

/datum/ipc_os_program/factory/drinks/proc/brew(obj/item/reagent_containers/cup/expected, drink, activation)
	if(!valid_brew(expected, activation))
		restore_vessel(expected)
		return
	audio = new(os.host)
	audio.start()
	animate(os.host, pixel_w = os.host.base_pixel_w + 1, pixel_z = os.host.base_pixel_z, time = 0.2 SECONDS, loop = -1)
	animate(pixel_w = os.host.base_pixel_w - 1, pixel_z = os.host.base_pixel_z, time = 0.2 SECONDS)
	if(do_after(os.host, 10 SECONDS, os.core, timed_action_flags = IGNORE_SLOWDOWNS|IGNORE_HELD_ITEM, extra_checks = CALLBACK(src, PROC_REF(valid_brew), expected, activation), ipc_fixed_duration = TRUE) && valid_brew(expected, activation))
		var/product_type = recipe(drink)
		var/obj/item/product = new product_type(os.host.drop_location())
		var/obj/item/organ/heart/ipc/battery = os.working_battery()
		battery.adjust_charge(-os.host.ipc_charge_capacity() * 0.05)
		qdel(expected)
		os.host.put_in_hands(product)
		restore_vessel(expected)
	else if(vessel == expected)
		restore_vessel(expected)

/datum/ipc_os_program/factory/drinks/proc/restore_vessel(obj/item/reagent_containers/cup/expected)
	if(!expected || vessel != expected)
		return
	vessel = null
	QDEL_NULL(audio)
	if(os.host)
		animate(os.host, pixel_w = os.host.base_pixel_w, pixel_z = os.host.base_pixel_z, time = 0.2 SECONDS)
	if(!QDELETED(expected))
		expected.forceMove(os.host ? os.host.drop_location() : get_turf(os.core))
		os.host?.put_in_hands(expected)
