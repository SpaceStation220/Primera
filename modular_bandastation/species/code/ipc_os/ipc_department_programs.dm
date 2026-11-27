/// Installed factory programs use the existing White Wall lifecycle and occupy no storage.
/datum/ipc_os_program/factory
	builtin = TRUE
	installed = TRUE
	ready = TRUE
	var/list/hud_traits

/datum/ipc_os_program/factory/start()
	if(!..())
		return FALSE
	if(hud_traits)
		os.host.add_traits(hud_traits, REF(src))
	return TRUE

/datum/ipc_os_program/factory/stop()
	if(running && os.host && hud_traits)
		os.host.remove_traits(hud_traits, REF(src))
	return ..()

/datum/ipc_os_program/factory/proc/command(list/params)
	return FALSE

/datum/ipc_os_program/factory/gps
	id = "factory_gps"
	name = "GPS"
	description = "Штатная система позиционирования."
	icon = "location-dot"
	builtin_department = "cargo"
	var/obj/item/gps/device

/datum/ipc_os_program/factory/gps/start()
	if(!..())
		return FALSE
	device = new(os.core)
	var/datum/component/gps/item/gps = device.GetComponent(/datum/component/gps/item)
	gps.state = GLOB.deep_inventory_state
	return TRUE

/datum/ipc_os_program/factory/gps/stop()
	if(device)
		var/datum/component/gps/item/gps = device.GetComponent(/datum/component/gps/item)
		SStgui.close_uis(gps)
		QDEL_NULL(device)
	return ..()

/datum/ipc_os_program/factory/gps/command(list/params)
	var/datum/component/gps/item/gps = device?.GetComponent(/datum/component/gps/item)
	if(gps)
		gps.ui_interact(os.host)
	return !!gps

/datum/ipc_os_program/factory/mining
	id = "factory_mining"
	name = "Улучшенный сканер руды"
	description = "Автоматически сканирует окружающую породу, как улучшенный шахтёрский сканер."
	icon = "gem"
	builtin_department = "cargo"
	var/obj/item/t_scanner/adv_mining_scanner/device

/datum/ipc_os_program/factory/mining/start()
	if(!..())
		return FALSE
	device = new(os.core)
	device.toggle_on()
	return TRUE

/datum/ipc_os_program/factory/mining/stop()
	QDEL_NULL(device)
	return ..()

/datum/ipc_os_program/factory/botany
	id = "factory_botany"
	name = "Ботанический сканер"
	description = "Осмотрите гидропонный лоток, чтобы получить данные штатного анализатора растений."
	icon = "seedling"
	builtin_department = "service"
	var/obj/item/plant_analyzer/ipc_os/device

/datum/ipc_os_program/factory/botany/start()
	if(!..())
		return FALSE
	device = new(os.core)
	RegisterSignal(os.host, COMSIG_MOB_EXAMINATE, PROC_REF(on_examine))
	return TRUE

/datum/ipc_os_program/factory/botany/stop()
	if(running && os.host)
		UnregisterSignal(os.host, COMSIG_MOB_EXAMINATE)
	if(device)
		SStgui.close_uis(device)
		QDEL_NULL(device)
	return ..()

/datum/ipc_os_program/factory/botany/proc/on_examine(mob/source, atom/target)
	SIGNAL_HANDLER
	if(running && istype(target, /obj/machinery/hydroponics) && (target in view(9, os.host)))
		INVOKE_ASYNC(src, PROC_REF(analyze), target, activation_id)

/datum/ipc_os_program/factory/botany/proc/analyze(atom/target, activation)
	if(running && activation_id == activation && os?.can_use(os.host) && !QDELETED(target) && (target in view(9, os.host)))
		device?.analyze(os.host, target)

/obj/item/plant_analyzer/ipc_os/ui_state(mob/user)
	return GLOB.deep_inventory_state

/datum/ipc_os_program/factory/cleaning
	id = "factory_cleaning"
	name = "Уборка пола"
	description = "Очищает и смачивает пол при движении, замедляя корпус. Расход: 4% батареи за 15 секунд."
	icon = "broom"
	builtin_department = "service"
	var/datum/looping_sound/wash/wash_audio
	var/charge_elapsed = 0

/datum/ipc_os_program/factory/cleaning/start()
	if(!..())
		return FALSE
	wash_audio = new(os.host)
	wash_audio.start()
	os.host.add_movespeed_modifier(/datum/movespeed_modifier/ipc_cleaning)
	animate(os.host, pixel_w = os.host.base_pixel_w + 1, time = 0.3 SECONDS, loop = -1)
	animate(pixel_w = os.host.base_pixel_w - 1, time = 0.3 SECONDS)
	RegisterSignal(os.host, COMSIG_MOVABLE_MOVED, PROC_REF(clean))
	RegisterSignal(os.host, COMSIG_LIVING_POST_UPDATE_TRANSFORM, PROC_REF(refresh_shake))
	clean()
	return TRUE

/datum/ipc_os_program/factory/cleaning/stop()
	if(os.host && running)
		os.host.remove_movespeed_modifier(/datum/movespeed_modifier/ipc_cleaning)
		animate(os.host, pixel_w = os.host.base_pixel_w, time = 0.1 SECONDS)
	if(running && os.host)
		UnregisterSignal(os.host, list(COMSIG_MOVABLE_MOVED, COMSIG_LIVING_POST_UPDATE_TRANSFORM))
	QDEL_NULL(wash_audio)
	charge_elapsed = 0
	return ..()

/datum/ipc_os_program/factory/cleaning/proc/clean()
	SIGNAL_HANDLER
	if(!running || !os.is_operational() || !isturf(os.host.loc))
		return
	var/turf/open/floor = get_turf(os.host)
	if(!istype(floor, /turf/open/floor))
		return
	floor.wash(CLEAN_SCRUB)
	floor.MakeSlippery(TURF_WET_WATER, 10 SECONDS, 10 SECONDS)
	new /obj/effect/temp_visual/ipc_cleaning(get_turf(os.host))

/obj/effect/temp_visual/ipc_cleaning
	icon = 'icons/effects/effects.dmi'
	icon_state = "bubbles"
	duration = 0.3 SECONDS

/datum/movespeed_modifier/ipc_cleaning
	multiplicative_slowdown = 1

/// Native tackling physics remain on one component even when retrieval gloves are worn.
/datum/component/tackler
	var/datum/ipc_os_program/factory/tackle/ipc_program

/datum/ipc_os_program/factory/tackle
	id = "factory_tackle"
	name = "Протокол задержания"
	description = "Штатный таран: режим броска, пустая рука и правый щелчок по цели. Ускоряет надевание наручников."
	icon = "person-running"
	builtin_department = "security"
	hud_traits = list(TRAIT_FAST_CUFFING)
	passive = TRUE
	var/datum/component/tackler/tackler

/datum/ipc_os_program/factory/tackle/start()
	if(!..())
		return FALSE
	tackler = os.host.GetComponent(/datum/component/tackler)
	if(!tackler)
		tackler = os.host.AddComponent(/datum/component/tackler, stamina_cost = /obj/item/clothing/gloves/tackler::tackle_stam_cost, base_knockdown = /obj/item/clothing/gloves/tackler::base_knockdown, range = /obj/item/clothing/gloves/tackler::tackle_range, speed = /obj/item/clothing/gloves/tackler::tackle_speed, skill_mod = /obj/item/clothing/gloves/tackler::skill_mod, min_distance = /obj/item/clothing/gloves/tackler::min_distance)
	tackler.ipc_program = src
	return TRUE

/datum/ipc_os_program/factory/tackle/stop()
	if(tackler)
		tackler.ipc_program = null
		var/obj/item/clothing/gloves/tackler/gloves = os.host?.gloves
		if(!istype(gloves) || gloves.tackler != tackler)
			qdel(tackler)
		tackler = null
	return ..()

/datum/ipc_os_program/factory/shield
	id = "factory_shield"
	name = "Силовой щит"
	description = "Встроенный энергощит. Потребляет заряд, пока включён, и автоматически отключается при недостатке энергии."
	icon = "shield-halved"
	builtin_department = "security"
	var/elapsed = 0
	var/obj/item/shield/ipc_integrated/emitter

/datum/ipc_os_program/factory/shield/start()
	if(!os.is_operational() || os.host.get_active_held_item() || os.host.nutrition < os.host.ipc_charge_capacity() * 0.02 || !..())
		return FALSE
	emitter = new(os.host)
	if(IS_RIGHT_INDEX(os.host.active_hand_index))
		emitter.icon_state = "ipc_shield_right"
	ADD_TRAIT(emitter, TRAIT_NODROP, REF(src))
	if(!os.host.put_in_active_hand(emitter))
		stop()
		return FALSE
	playsound(os.host, 'sound/items/weapons/saberon.ogg', 35, TRUE)
	return TRUE

/datum/ipc_os_program/factory/shield/stop()
	if(emitter && os?.host)
		playsound(os.host, 'sound/items/weapons/saberoff.ogg', 35, TRUE)
	QDEL_NULL(emitter)
	elapsed = 0
	return ..()

/datum/ipc_os_program/factory/shield/tick(seconds_per_tick)
	elapsed += seconds_per_tick
	while(elapsed >= 20)
		var/obj/item/organ/heart/ipc/battery = os.working_battery()
		var/cost = os.host.ipc_charge_capacity() * 0.02
		if(!battery || os.host.nutrition < cost)
			stop()
			return
		battery.adjust_charge(-cost)
		elapsed -= 20
		if(os.host.nutrition < cost)
			stop()
			return

/obj/item/shield/ipc_integrated
	name = "встроенный силовой щит"
	icon = 'modular_bandastation/species/icons/ipc/integrated_shield.dmi'
	icon_state = "ipc_shield"
	inhand_icon_state = "ipc_shield"
	lefthand_file = 'modular_bandastation/species/icons/ipc/factory_tools_left.dmi'
	righthand_file = 'modular_bandastation/species/icons/ipc/factory_tools_right.dmi'
	slot_flags = NONE
	block_chance = 35
	breakable_by_damage = FALSE
	item_flags = NONE
	resistance_flags = INDESTRUCTIBLE
	custom_materials = null


/datum/ipc_os_program/factory/medhud
	id = "factory_medhud"
	name = "ChemiMed"
	description = "Медицинский HUD и анализ реагентов."
	icon = "heart-pulse"
	builtin_department = "medical"
	hud_traits = list(TRAIT_MEDICAL_HUD, TRAIT_REAGENT_SCANNER)

/datum/ipc_os_program/factory/sechud
	id = "factory_sechud"
	name = "Security HUD"
	description = "Встроенный охранный HUD."
	icon = "user-shield"
	builtin_department = "security"
	hud_traits = list(TRAIT_SECURITY_HUD)

/datum/ipc_os_program/factory/diagnostic
	id = "factory_diagnostic"
	name = "DioSCI"
	description = "Анализ реагентов и диагностика синтетиков."
	icon = "microchip"
	builtin_department = "science"
	hud_traits = list(TRAIT_DIAGNOSTIC_HUD, TRAIT_REAGENT_SCANNER)

/datum/ipc_os_program/factory/mesogase
	id = "factory_mesogase"
	name = "MesoGase"
	description = "Включает мезонное зрение. Осмотр видимой цели в пределах пяти тайлов показывает состав газа."
	icon = "glasses"
	builtin_department = "engineering"
	hud_traits = list(TRAIT_MESON_VISION)

/datum/ipc_os_program/factory/mesogase/start()
	if(!..())
		return FALSE
	RegisterSignal(os.host, COMSIG_MOB_EXAMINATE, PROC_REF(on_examine))
	return TRUE

/datum/ipc_os_program/factory/mesogase/stop()
	if(running && os.host)
		UnregisterSignal(os.host, COMSIG_MOB_EXAMINATE)
	return ..()

/datum/ipc_os_program/factory/mesogase/proc/on_examine(mob/source, atom/target)
	SIGNAL_HANDLER
	if(running && os.can_use(source) && target != source && (target in view(5, source)))
		atmos_scan(source, target, silent = TRUE)

/datum/ipc_os_program/factory/cleaning/proc/refresh_shake()
	SIGNAL_HANDLER
	if(running && os.host)
		addtimer(CALLBACK(src, PROC_REF(resume_shake)), UPDATE_TRANSFORM_ANIMATION_TIME, TIMER_UNIQUE|TIMER_OVERRIDE)

/datum/ipc_os_program/factory/cleaning/proc/resume_shake()
	if(running && os.is_operational())
		animate(os.host, pixel_w = os.host.base_pixel_w + 1, time = 0.3 SECONDS, loop = -1)
		animate(pixel_w = os.host.base_pixel_w - 1, time = 0.3 SECONDS)

/datum/ipc_os_program/factory/cleaning/tick(seconds_per_tick)
	charge_elapsed += seconds_per_tick
	while(charge_elapsed >= 15)
		charge_elapsed -= 15
		var/obj/item/organ/heart/ipc/battery = os.working_battery()
		var/cost = os.host.ipc_charge_capacity() * 0.04
		if(!battery || os.host.nutrition < cost)
			stop()
			return
		battery.adjust_charge(-cost)
