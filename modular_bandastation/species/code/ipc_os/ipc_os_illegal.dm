#define IPC_OS_OVERCLOCK_HEAT_PER_SECOND 12
#define IPC_OS_GHOST_DRAIN_PER_SECOND (NUTRITION_LEVEL_FULL * 0.04 / 10)

/// Return software only for a compatible chassis with its actual existing core.
/mob/living/carbon/human/proc/get_ipc_os()
	if(!is_species(src, /datum/species/ipc))
		return null
	var/obj/item/organ/brain/ipc/core = get_organ_slot(ORGAN_SLOT_BRAIN)
	return istype(core) ? core.operating_system : null

/mob/living/carbon/human/emag_act(mob/user, obj/item/card/emag/emag_card)
	var/datum/ipc_os/os = get_ipc_os()
	if(!os)
		return ..()
	if(istype(emag_card, /obj/item/card/emag/doorjack) || !os.unlock(TRUE))
		return FALSE
	to_chat(src, span_warning("Positronic OS: Black Wall разблокирован. Доступно 32 GB."))
	return TRUE

/// A consumed software carrier, never an implant or an organ.
/obj/item/ipc_os_upgrade
	name = "IPC illegal software update"
	desc = "Открывает в NET программы VirusKit, ID_Spoof v3 и GhostMode. Не увеличивает память."
	icon = 'icons/obj/devices/floppy_disks.dmi'
	icon_state = "datadisk3"
	item_flags = NOBLUDGEON

/obj/item/ipc_os_upgrade/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!ishuman(interacting_with) || !user.can_perform_action(interacting_with, FORBID_TELEKINESIS_REACH))
		return NONE
	var/mob/living/carbon/human/ipc = interacting_with
	var/datum/ipc_os/os = ipc.get_ipc_os()
	if(!os || !os.unlock())
		balloon_alert(user, "обновление недоступно")
		return ITEM_INTERACT_BLOCKING
	to_chat(ipc, span_warning("Positronic OS: открыт ограниченный каталог Black Wall. Память не изменена."))
	qdel(src)
	return ITEM_INTERACT_SUCCESS

/// Bank-account credits plus the existing market's delivery fee; no traitor TC conversion.
/datum/market_item/ipc_os_upgrade
	name = "Нелегальное обновление КПБ"
	desc = "Открывает VirusKit, ID_Spoof v3 и GhostMode. Установка программ выполняется отдельно в NET."
	category = "Equipment"
	item = /obj/item/ipc_os_upgrade
	price = 200
	stock = 3
	stock_max = 3
	availability_prob = 100

/datum/ipc_os_program/id_spoof
	ready = TRUE
	/// Cosmetic text, never written into an ID, mind or manifest.
	var/spoof_name = "Неизвестный"
	/// Optional visible title, without real job or access effects.
	var/spoof_job = "КПБ"
	/// Editing text does not renew the approved fifteen-minute activation.
	var/expires_at = 0

/datum/ipc_os_program/id_spoof/start()
	if(!..())
		return FALSE
	expires_at = world.time + 15 MINUTES
	RegisterSignal(os.host, COMSIG_HUMAN_GET_VISIBLE_NAME, PROC_REF(on_visible_name))
	os.host.update_visible_name()
	return TRUE

/datum/ipc_os_program/id_spoof/stop()
	if(running && os.host)
		UnregisterSignal(os.host, COMSIG_HUMAN_GET_VISIBLE_NAME)
		os.host.update_visible_name()
	expires_at = 0
	return ..()

/datum/ipc_os_program/id_spoof/tick(seconds_per_tick)
	if(world.time >= expires_at)
		stop()

/datum/ipc_os_program/id_spoof/proc/on_visible_name(datum/source, list/identity)
	SIGNAL_HANDLER
	identity[VISIBLE_NAME_FACE] = "[spoof_name][length(spoof_job) ? " ([spoof_job])" : ""]"
	identity[VISIBLE_NAME_FORCED] = TRUE

/datum/ipc_os_program/ghost_mode
	ready = TRUE

/datum/ipc_os_program/ghost_mode/start()
	if(!..())
		return FALSE
	os.host.AddElement(/datum/element/digitalcamo, REF(src))
	return TRUE

/datum/ipc_os_program/ghost_mode/stop()
	if(running && os.host)
		os.host.RemoveElement(/datum/element/digitalcamo, REF(src))
	return ..()

/datum/ipc_os_program/ghost_mode/tick(seconds_per_tick)
	var/obj/item/organ/heart/ipc/battery = os.working_battery()
	var/cost = IPC_OS_GHOST_DRAIN_PER_SECOND * seconds_per_tick
	if(!battery || os.host.nutrition < cost)
		stop()
		return
	battery.adjust_charge(-cost)

/// The modifier returns a raw delay adjustment because Primera scales ordinary TG modifiers.
/datum/movespeed_modifier/ipc_os_overclock
	variable = TRUE
	blacklisted_movetypes = FLYING|FLOATING

/datum/movespeed_modifier/ipc_os_overclock/get_rp_speed()
	return multiplicative_slowdown

/datum/ipc_os_program/overclock
	ready = TRUE
	/// Prevent recursion when updating our own modifier emits MOVESPEED_UPDATED.
	var/syncing_speed = FALSE

/datum/ipc_os_program/overclock/start()
	if(!..())
		return FALSE
	RegisterSignals(os.host, list(COMSIG_MOB_MOVESPEED_UPDATED, COMSIG_MOVE_INTENT_TOGGLED), PROC_REF(sync_speed))
	os.host.add_movespeed_modifier(/datum/movespeed_modifier/ipc_os_overclock)
	return TRUE

/datum/ipc_os_program/overclock/stop()
	if(running && os.host)
		UnregisterSignal(os.host, list(COMSIG_MOB_MOVESPEED_UPDATED, COMSIG_MOVE_INTENT_TOGGLED))
		os.host.remove_movespeed_modifier(/datum/movespeed_modifier/ipc_os_overclock)
	return ..()

/datum/ipc_os_program/overclock/proc/sync_speed()
	SIGNAL_HANDLER
	if(syncing_speed || !running)
		return
	var/datum/movespeed_modifier/ipc_os_overclock/modifier = os.host.has_movespeed_modifier(/datum/movespeed_modifier/ipc_os_overclock)
	if(!modifier)
		return
	syncing_speed = TRUE
	var/base_delay = os.host.cached_multiplicative_slowdown - modifier.get_rp_speed()
	var/adjustment = os.host.move_intent == MOVE_INTENT_RUN && !(os.host.movement_type & (FLYING|FLOATING)) ? -max(base_delay, 0) * 0.2 : 0
	os.host.add_or_update_variable_movespeed_modifier(/datum/movespeed_modifier/ipc_os_overclock, multiplicative_slowdown = adjustment)
	syncing_speed = FALSE

/datum/ipc_os_program/overclock/tick(seconds_per_tick)
	os.host.adjust_coretemperature(IPC_OS_OVERCLOCK_HEAT_PER_SECOND * seconds_per_tick)
	os.host.adjust_bodytemperature(IPC_OS_OVERCLOCK_HEAT_PER_SECOND * seconds_per_tick)

/datum/ipc_os_program/wall_breaker
	ready = TRUE

/datum/ipc_os_program/neural_crack
	ready = TRUE
	passive = TRUE
	/// A dedicated conscious-only action remains usable when stun blocks the desktop.
	var/datum/action/innate/ipc_os/neural_crack/crack_action

/datum/ipc_os_program/neural_crack/start()
	if(!..())
		return FALSE
	crack_action = new(os)
	crack_action.Grant(os.host)
	return TRUE

/datum/ipc_os_program/neural_crack/stop()
	QDEL_NULL(crack_action)
	return ..()

/// Charge brain damage only for a valid stun removal; no other crowd-control state is changed.
/datum/ipc_os/proc/neural_crack()
	var/datum/ipc_os_program/program = programs["neural_crack"]
	if(!is_operational() || IS_UNCONSCIOUS_OR_CRIT(host) || !program.installed || !host.IsStun() || core.damage + 15 > core.maxHealth)
		return FALSE
	host.remove_status_effect(/datum/status_effect/incapacitating/stun)
	core.apply_organ_damage(15)
	return TRUE

/datum/action/innate/ipc_os/neural_crack
	name = "NeuralCrack"
	desc = "Снять только stun за 15 урона позитронному мозгу."
	button_icon = 'icons/mob/actions/actions_spells.dmi'
	button_icon_state = "emp"

/datum/action/innate/ipc_os/neural_crack/IsAvailable(feedback = FALSE)
	return !action_disabled && owner == os?.host && os?.is_operational() && !IS_UNCONSCIOUS_OR_CRIT(owner) && os.host.IsStun()

/datum/action/innate/ipc_os/neural_crack/Activate()
	if(IsAvailable())
		os.neural_crack()

#undef IPC_OS_OVERCLOCK_HEAT_PER_SECOND
#undef IPC_OS_GHOST_DRAIN_PER_SECOND
