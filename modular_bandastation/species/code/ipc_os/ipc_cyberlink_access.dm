/obj/machinery/door/airlock
	var/bolt_revision = 0
	var/shock_revision = 0

/// A lease authorizes only its owner and target; it never alters a door's ID requirements.
/datum/ipc_cyberlink_access
	var/datum/weakref/target_ref
	var/expires_at
	var/owns_bolts = FALSE
	var/owns_shock = FALSE
	var/original_bolts
	var/original_shock
	var/original_shock_deadline
	var/expected_bolt_revision
	var/expected_shock_revision
	var/bolt_restore_at

/datum/ipc_cyberlink_access/New(atom/movable/target)
	. = ..()
	target_ref = WEAKREF(target)
	expires_at = world.time + (istype(target, /obj/machinery/door) ? 10 SECONDS : istype(target, /obj/machinery/computer) ? 30 SECONDS : 50 SECONDS)

/datum/ipc_cyberlink_access/Destroy()
	restore(TRUE)
	target_ref = null
	return ..()

/datum/ipc_cyberlink_access/proc/active(atom/target)
	return world.time < expires_at && target_ref.resolve() == target

/datum/ipc_cyberlink_access/proc/restore(force = FALSE)
	var/obj/machinery/door/airlock/door = target_ref?.resolve()
	if(!istype(door))
		return
	if(owns_shock && (force || world.time >= expires_at))
		owns_shock = FALSE
		if(door.shock_revision == expected_shock_revision)
			var/remaining = original_shock > 0 ? max(0, ceil((original_shock_deadline - world.time) / (1 SECONDS))) : original_shock
			door.set_electrified(remaining)
	if(owns_bolts && (force || world.time >= bolt_restore_at))
		owns_bolts = FALSE
		if(door.bolt_revision == expected_bolt_revision)
			if(original_bolts)
				door.bolt()
			else
				door.unbolt()

/datum/ipc_cyberlink_access/proc/set_bolts(mob/user)
	var/obj/machinery/door/airlock/door = target_ref.resolve()
	if(!istype(door) || !active(door) || !door.hasPower() || door.wires.is_cut(WIRE_BOLTS))
		return FALSE
	if(!owns_bolts || door.bolt_revision != expected_bolt_revision)
		original_bolts = door.locked
	if(door.locked)
		door.unbolt()
	else
		door.bolt()
	expected_bolt_revision = door.bolt_revision
	bolt_restore_at = expires_at + (door.locked ? 8 SECONDS : 0)
	owns_bolts = TRUE
	log_combat(user, door, "toggled bolts through ChromieKnight")
	return TRUE

/datum/ipc_cyberlink_access/proc/set_shock(mob/user, enabled)
	var/obj/machinery/door/airlock/door = target_ref.resolve()
	if(!istype(door) || !active(door) || !door.hasPower() || door.wires.is_cut(WIRE_SHOCK))
		return FALSE
	var/desired = enabled ? MACHINE_ELECTRIFIED_PERMANENT : MACHINE_NOT_ELECTRIFIED
	if(door.secondsElectrified == desired)
		return FALSE
	if(!owns_shock || door.shock_revision != expected_shock_revision)
		original_shock = door.secondsElectrified
		original_shock_deadline = world.time + max(0, original_shock) SECONDS
	door.set_electrified(desired, user)
	expected_shock_revision = door.shock_revision
	owns_shock = TRUE
	return TRUE

/// The command list is a closed adapter boundary, not a forwarding API for arbitrary ui_act calls.
/datum/ipc_os_program/cyberlink/proc/machine_kind(atom/target)
	if(istype(target, /mob/living/basic/bot) && !istype(target, /mob/living/basic/bot/secbot))
		return "bot"
	if(istype(target, /obj/machinery/door/airlock))
		return "door"
	if(istype(target, /obj/machinery/power/apc))
		return "apc"
	if(istype(target, /obj/machinery/airalarm))
		return "alarm"
	if(istype(target, /obj/machinery) && !istype(target, /obj/machinery/camera))
		return "machine"
	return null

/datum/ipc_os_program/cyberlink/proc/machine_targets()
	var/list/targets = list()
	if(!running || !available() || !os.is_operational() || pilot)
		return targets
	for(var/atom/movable/target in view(4, os.host))
		if(machine_kind(target))
			targets += target
	var/turf/body_turf = get_turf(os.host)
	for(var/mob/living/basic/bot/bot as anything in GLOB.bots_list)
		var/turf/bot_turf = get_turf(bot)
		if(body_turf && bot_turf && body_turf.z == bot_turf.z && machine_kind(bot) && machine_operational(bot))
			targets |= bot
	return targets

/datum/ipc_os_program/cyberlink/proc/machine_operational(atom/movable/target)
	if(istype(target, /mob/living/basic/bot))
		var/mob/living/basic/bot/bot = target
		return bot.stat != DEAD && (bot.bot_mode_flags & BOT_MODE_REMOTE_ENABLED) && !(bot.bot_access_flags & BOT_COVER_EMAGGED) && !bot.paicard && !bot.client
	var/obj/machinery/machine = target
	if(QDELETED(target) || !machine_kind(target) || (machine.machine_stat & (BROKEN|MAINT)))
		return FALSE
	if(istype(target, /obj/machinery/door/airlock))
		var/obj/machinery/door/airlock/door = target
		return door.canAIControl(os.host) && !door.hackProof
	if(istype(target, /obj/machinery/power/apc))
		var/obj/machinery/power/apc/apc = target
		return !apc.aidisabled && !apc.malfai && !(apc.obj_flags & EMAGGED)
	if(machine_kind(target) == "machine")
		return !(machine.machine_stat & NOPOWER)
	var/obj/machinery/airalarm/alarm = target
	return !(alarm.machine_stat & NOPOWER) && !alarm.aidisabled && !alarm.shorted && alarm.buildstage == AIR_ALARM_BUILD_COMPLETE

/datum/ipc_os_program/cyberlink/proc/slot_access(atom/movable/target)
	var/obj/item/card/id/card = os.host?.wear_id?.GetID()
	return card && target.check_access(card)

/datum/ipc_os_program/cyberlink/proc/access_for(atom/target)
	for(var/datum/ipc_cyberlink_access/access as anything in accesses)
		if(access.active(target))
			return access
	return null

/datum/ipc_os_program/cyberlink/proc/machine_authorized(atom/movable/target)
	var/linked = target == linked_target?.resolve() && connection_body?.resolve() == os.host
	if(linked && machine_kind(target) == "bot" && has_memory(target))
		return TRUE
	return access_for(target) || ((target.check_access(null) || slot_access(target)) && (remote_enabled || linked))

/datum/ipc_os_program/cyberlink/proc/machine_commands(atom/movable/target)
	var/list/commands = list()
	if(!machine_operational(target) || !machine_authorized(target))
		return commands
	switch(machine_kind(target))
		if("bot")
			commands["power"] = "Питание"
			return commands
		if("door")
			commands["door_toggle"] = "Открыть / закрыть"
			if(access_for(target))
				commands["bolts"] = "Переключить болты"
				commands["shock"] = "Электрифицировать"
				commands["unshock"] = "Снять электризацию"
		if("apc")
			var/obj/machinery/power/apc/apc = target
			commands = list("charge" = "Заряд батареи", "cover" = "Замок крышки", "nightshift" = "Ночной свет")
			if(apc.failure_timer)
				commands["reboot"] = "Сброс отказа"
			else if(apc.is_operational)
				commands["breaker"] = "Автомат питания"
			var/list/channels = list("equipment" = "Оборудование", "lighting" = "Освещение", "environ" = "Жизнеобеспечение")
			var/list/states = list("0" = "выкл.", "2" = "вкл.", "3" = "авто")
			for(var/channel in channels)
				for(var/value in states)
					commands["[channel]_[value]"] = "[channels[channel]]: [states[value]]"
		if("alarm")
			var/obj/machinery/airalarm/alarm = target
			for(var/mode_path in GLOB.air_alarm_modes)
				var/datum/air_alarm_mode/mode = GLOB.air_alarm_modes[mode_path]
				if(!mode.emag || (alarm.obj_flags & EMAGGED))
					commands["mode:[mode_path]"] = mode.name
	return commands

/datum/ipc_os_program/cyberlink/proc/execute_machine(mob/user, atom/movable/target, command)
	if(!os.can_use(user) || !running || !(target in command_targets()) || !(command in machine_commands(target)))
		return FALSE
	var/relay_cost = is_relayed(target) ? charge_cost(0.5) : 0
	var/obj/item/organ/heart/ipc/relay_battery = os.working_battery()
	if(relay_cost && !spend_charge(0.5))
		return FALSE
	var/success = FALSE
	var/mob/living/carbon/human/body = os.host
	var/previous_ready = command_ready_at
	var/reserved_ready = world.time
	command_ready_at = reserved_ready
	switch(machine_kind(target))
		if("bot")
			var/mob/living/basic/bot/bot = target
			if(bot.bot_mode_flags & BOT_MODE_ON)
				bot.turn_off()
			else
				bot.turn_on()
			success = TRUE
		if("door")
			var/obj/machinery/door/airlock/door = target
			var/datum/ipc_cyberlink_access/access = access_for(door)
			switch(command)
				if("door_toggle")
					if(!door.welded && !door.locked && !door.operating)
						success = door.density ? door.open(opener = user) : door.close()
				if("bolts")
					success = access?.set_bolts(user)
				if("shock", "unshock")
					success = access?.set_shock(user, command == "shock")
		if("apc")
			var/obj/machinery/power/apc/apc = target
			success = TRUE
			switch(command)
				if("breaker")
					apc.toggle_breaker(user)
				if("charge")
					apc.chargemode = !apc.chargemode
					if(!apc.chargemode)
						apc.charging = APC_NOT_CHARGING
				if("cover")
					apc.coverlocked = !apc.coverlocked
				if("nightshift")
					apc.toggle_nightshift_lights(user)
				if("reboot")
					apc.reboot()
				else
					var/list/parts = splittext(command, "_")
					var/value = apc.setsubsystem(text2num(parts[2]))
					switch(parts[1])
						if("equipment")
							success = apc.equipment != value
							apc.equipment = value
						if("lighting")
							success = apc.lighting != value
							apc.lighting = value
						if("environ")
							success = apc.environ != value
							apc.environ = value
			apc.update_appearance()
			apc.update()
		if("alarm")
			var/obj/machinery/airalarm/alarm = target
			var/mode_path = text2path(copytext(command, 6))
			if(alarm.selected_mode != GLOB.air_alarm_modes[mode_path])
				alarm.select_mode(user, mode_path)
				success = alarm.selected_mode == GLOB.air_alarm_modes[mode_path]
	if(success)
		if(!QDELETED(body))
			body.adjust_coretemperature(25)
		log_game("[key_name(user)] used ChromieKnight command [command] on [target] at [AREACOORD(target)].")
	else if(command_ready_at == reserved_ready)
		command_ready_at = previous_ready
	if(!success && relay_cost && !QDELETED(relay_battery))
		relay_battery.adjust_charge(relay_cost)
	return success
