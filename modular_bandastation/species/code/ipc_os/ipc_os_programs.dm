#define IPC_OS_DEFRAG_INTERVAL_SECONDS 15

/// Apply efficiency only to ordinary microbattery drain, never to separately priced abilities.
/datum/ipc_os/proc/power_multiplier()
	if(!is_operational())
		return 1
	var/datum/ipc_os_program/power_save = programs["power_save"]
	var/datum/ipc_os_program/defrag = programs["defrag"]
	return (power_save.running ? 0.7 : 1) * (defrag.running ? 1.2 : 1)

/// An incoming valid new infection makes exactly one roll, after its transmission finishes.
/datum/ipc_os/proc/blocks_virus()
	var/datum/ipc_os_program/firewall = programs["firewall"]
	return is_operational() && firewall.installed && prob(50)

/datum/ipc_os_program/defrag
	/// Completed running time only; repeated toggles cannot create healing intervals.
	var/heal_elapsed = 0

/datum/ipc_os_program/defrag/stop()
	. = ..()
	heal_elapsed = 0

/datum/ipc_os_program/defrag/tick(seconds_per_tick)
	if(!os.working_battery())
		stop()
		return
	heal_elapsed += seconds_per_tick
	while(heal_elapsed >= IPC_OS_DEFRAG_INTERVAL_SECONDS)
		heal_elapsed -= IPC_OS_DEFRAG_INTERVAL_SECONDS
		os.host.heal_overall_damage(brute = 2, required_bodytype = BODYTYPE_ROBOTIC)

/datum/ipc_os_program/signal_boost
	/// Native signaling hardware is owned by this program, not accessible as loot.
	var/obj/item/assembly/signaler/internal/signaler
	/// Settings survive stopping, while the radio subscription does not.
	var/frequency = FREQ_SIGNALER
	/// Existing signaler protocol code.
	var/code = DEFAULT_SIGNALER_CODE
	COOLDOWN_DECLARE(send_cooldown)

/datum/ipc_os_program/signal_boost/start()
	if(!..())
		return FALSE
	signaler = new(os.host)
	signaler.set_frequency(frequency)
	signaler.code = code
	return TRUE

#undef IPC_OS_DEFRAG_INTERVAL_SECONDS

/datum/ipc_os_program/signal_boost/stop()
	QDEL_NULL(signaler)
	return ..()

/// Validate settings and send through the actual SSradio signaler implementation.
/datum/ipc_os_program/signal_boost/proc/command(action, list/params)
	if(!running || !signaler || !os.can_use(usr))
		return FALSE
	switch(action)
		if("signal_freq")
			var/value = text2num("[params["value"]]")
			if(isnull(value))
				return FALSE
			frequency = sanitize_frequency(round(value), TRUE)
			signaler.set_frequency(frequency)
		if("signal_code")
			var/value = text2num("[params["value"]]")
			if(isnull(value))
				return FALSE
			code = clamp(round(value), 1, 100)
			signaler.code = code
		if("signal_send")
			if(!COOLDOWN_FINISHED(src, send_cooldown))
				return FALSE
			COOLDOWN_START(src, send_cooldown, 1 SECONDS)
			INVOKE_ASYNC(signaler, TYPE_PROC_REF(/obj/item/assembly/signaler, signal))
	return TRUE
