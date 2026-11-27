#define IPC_CALIBRATION_DURATION (20 MINUTES)

/// Calibration belongs to the machine and expires independently of the technician.
/obj/machinery
	var/ipc_calibration_mode
	var/ipc_calibration_until = 0

/obj/machinery/proc/ipc_supports_calibration()
	SHOULD_BE_PURE(TRUE)
	return istype(src, /obj/machinery/autolathe) || istype(src, /obj/machinery/rnd/production) || istype(src, /obj/machinery/mecha_part_fabricator)

/obj/machinery/proc/ipc_apply_calibration(mode)
	if(!ipc_supports_calibration() || !is_operational || !(mode in list("economy", "fast")))
		return FALSE
	ipc_calibration_mode = mode
	ipc_calibration_until = world.time + IPC_CALIBRATION_DURATION
	addtimer(CALLBACK(src, PROC_REF(ipc_expire_calibration)), IPC_CALIBRATION_DURATION, TIMER_UNIQUE | TIMER_OVERRIDE)
	update_static_data_for_all_viewers()
	return TRUE

/obj/machinery/proc/ipc_expire_calibration()
	ipc_calibration_mode = null
	ipc_calibration_until = 0
	update_static_data_for_all_viewers()

/obj/machinery/proc/ipc_calibrated_cost(datum/design/design, coefficient)
	SHOULD_BE_PURE(TRUE)
	if(world.time < ipc_calibration_until && ipc_calibration_mode == "economy" && !design.fixed_cost_efficiency && !ispath(design.build_path, /obj/item/stack))
		return coefficient * 0.85
	return coefficient

/obj/machinery/proc/ipc_calibrated_time(duration)
	SHOULD_BE_PURE(TRUE)
	return world.time < ipc_calibration_until && ipc_calibration_mode == "fast" ? duration / 1.25 : duration

/datum/ipc_os_program/factory/calibration
	id = "factory_calibration"
	name = "Протоколы экспериментальной калибровки"
	description = "Кабель для техфабов, принтеров плат, автолатов и фабрикаторов экзокостюмов. Настройка занимает 10 секунд и расходует 10% батареи."
	icon = "plug"
	builtin_department = "science"
	passive = TRUE
	var/mode = "economy"
	var/obj/item/ipc_calibration_cable/cable
	var/calibrating = FALSE

/datum/ipc_os_program/factory/calibration/command(list/params)
	if(calibrating || !os.can_use(os.host))
		return FALSE
	var/selection = params["mode"]
	if(selection in list("economy", "fast"))
		mode = selection
		return TRUE
	if(params["operation"] != "cable")
		return FALSE
	if(cable)
		QDEL_NULL(cable)
		return TRUE
	var/mob/living/carbon/human/user = os.host
	if(!user.has_active_hand() || user.get_active_held_item())
		to_chat(user, span_warning("Освободите активную руку для кабеля."))
		return FALSE
	cable = new(user)
	cable.program = src
	cable.icon_state = "ipc_calibration_[user.held_index_to_dir(user.active_hand_index)]"
	ADD_TRAIT(cable, TRAIT_NODROP, REF(src))
	if(!user.put_in_active_hand(cable))
		QDEL_NULL(cable)
		return FALSE
	playsound(user, /obj/item/organ/cyberimp/arm/power_cord/ipc::extend_sound, 50, TRUE)
	return TRUE

/datum/ipc_os_program/factory/calibration/stop()
	calibrating = FALSE
	QDEL_NULL(cable)
	return ..()

/datum/ipc_os_program/factory/calibration/tick(seconds_per_tick)
	if(cable && !os.host.is_holding(cable))
		calibrating = FALSE
		QDEL_NULL(cable)

/datum/ipc_os_program/factory/calibration/proc/can_calibrate(mob/living/carbon/human/user, obj/machinery/machine, obj/item/ipc_calibration_cable/connector)
	var/cost = user.ipc_charge_capacity() * 0.10
	return running && available() && os.can_use(user) && !QDELETED(connector) && connector == cable && user.is_holding(connector) && !QDELETED(machine) && machine.ipc_supports_calibration() && machine.is_operational && user.can_perform_action(machine, FORBID_TELEKINESIS_REACH) && os.working_battery() && user.nutrition >= cost

/datum/ipc_os_program/factory/calibration/proc/try_calibrate(mob/living/carbon/human/user, obj/machinery/machine, obj/item/ipc_calibration_cable/connector)
	if(calibrating || !can_calibrate(user, machine, connector))
		to_chat(user, span_warning("Проверьте питание машины, кабель и заряд микробатареи."))
		return FALSE
	calibrating = TRUE
	INVOKE_ASYNC(src, PROC_REF(calibrate), user, machine, connector)
	return TRUE

/datum/ipc_os_program/factory/calibration/proc/calibrate(mob/living/carbon/human/user, obj/machinery/machine, obj/item/ipc_calibration_cable/connector)
	var/selection = mode
	if(do_after(user, 10 SECONDS, target = machine, timed_action_flags = IGNORE_SLOWDOWNS, ipc_fixed_duration = TRUE, extra_checks = CALLBACK(src, PROC_REF(can_calibrate), user, machine, connector)) && can_calibrate(user, machine, connector))
		var/obj/item/organ/heart/ipc/battery = os.working_battery()
		battery.adjust_charge(-user.ipc_charge_capacity() * 0.10)
		machine.ipc_apply_calibration(selection)
		var/label = selection == "economy" ? "Экономичная работа" : "Ускоренная работа"
		to_chat(user, span_notice("[machine]: режим «[label]» установлен на 20 минут."))
		log_game("[key_name(user)] calibrated [machine] at [AREACOORD(machine)] ([selection]).")
	if(cable == connector)
		calibrating = FALSE
	if(os)
		SStgui.update_uis(os)

/obj/item/ipc_calibration_cable
	name = "калибровочный кабель"
	desc = "Выдвижной разъём для экспериментальной калибровки фабрикаторов."
	icon = 'modular_bandastation/species/icons/ipc/factory_tools.dmi'
	icon_state = "ipc_calibration_l"
	inhand_icon_state = "ipc_calibration"
	lefthand_file = 'modular_bandastation/species/icons/ipc/factory_tools_left.dmi'
	righthand_file = 'modular_bandastation/species/icons/ipc/factory_tools_right.dmi'
	item_flags = ABSTRACT | NOBLUDGEON
	var/datum/ipc_os_program/factory/calibration/program

/obj/item/ipc_calibration_cable/Destroy()
	program = null
	return ..()

/obj/item/ipc_calibration_cable/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!ismachinery(interacting_with) || !ishuman(user))
		return ITEM_INTERACT_BLOCKING
	var/obj/machinery/machine = interacting_with
	if(!machine.ipc_supports_calibration())
		to_chat(user, span_warning("Эта машина не поддерживает калибровку."))
		return ITEM_INTERACT_BLOCKING
	return program?.try_calibrate(user, machine, src) ? ITEM_INTERACT_SUCCESS : ITEM_INTERACT_BLOCKING

#undef IPC_CALIBRATION_DURATION
