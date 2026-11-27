/atom
	/// Exclusive ownership is local to this physical target, never a global silicon privilege.
	var/datum/weakref/ipc_neural_pilot

/datum/ipc_os_program/cyberlink
	var/datum/ipc_cyberlink_pilot/pilot

/datum/ipc_os_program/cyberlink/proc/pilot_kind(atom/target)
	if(istype(target, /obj/vehicle/sealed/mecha))
		var/obj/vehicle/sealed/mecha/mech = target
		if(mech.mech_type & EXOSUIT_MODULE_COMBAT)
			return "combat"
		if(mech.mech_type & (EXOSUIT_MODULE_WORKING | EXOSUIT_MODULE_MEDICAL))
			return "civilian"
	if(istype(target, /mob/living/basic/bot/secbot))
		return "secbot"
	if(istype(target, /mob/living/basic/bot))
		return "bot"
	return null

/datum/ipc_os_program/cyberlink/proc/pilot_ready(atom/movable/target, datum/ipc_cyberlink_pilot/own_session)
	if(QDELETED(target) || !pilot_kind(target) || !os.is_operational())
		return FALSE
	var/turf/body_turf = get_turf(os.host)
	var/turf/target_turf = get_turf(target)
	if(!body_turf || !target_turf || body_turf.z != target_turf.z)
		return FALSE
	var/datum/ipc_cyberlink_pilot/reservation = target.ipc_neural_pilot?.resolve()
	if(reservation && reservation != own_session)
		return FALSE
	if(istype(target, /obj/vehicle/sealed/mecha))
		var/obj/vehicle/sealed/mecha/mech = target
		if(!mech.cell || mech.cell.charge <= 0 || mech.completely_disabled || (mech.dna_lock && mech.dna_lock != os.host.dna.unique_enzymes))
			return FALSE
		if(own_session)
			return length(mech.occupants) == 1 && (own_session.controlled in mech.occupants) && own_session.controlled.loc == mech
		return !length(mech.occupants)
	var/mob/living/basic/bot/bot = target
	if(bot.stat == DEAD || !(bot.bot_mode_flags & BOT_MODE_ON) || !(bot.bot_mode_flags & BOT_MODE_REMOTE_ENABLED) || (bot.bot_access_flags & BOT_COVER_EMAGGED) || bot.paicard || !bot.ai_controller)
		return FALSE
	var/mob/living/basic/bot/secbot/security_bot = bot
	if(istype(security_bot) && !istype(security_bot.weapon, /obj/item/melee/baton/security))
		return FALSE
	if(own_session)
		return bot.mind == own_session.source_mind && bot.ai_controller == own_session.bot_ai && own_session.bot_ai.forced_off && (!istype(security_bot) || (security_bot.weapon == own_session.baton && own_session.baton.loc == bot && own_session.baton.cell == own_session.adapter))
	return !bot.client && !bot.mind

/datum/ipc_os_program/cyberlink/proc/pilot_targets()
	var/list/targets = list()
	if(!running || !available() || !os.can_use(os.host) || pilot)
		return targets
	for(var/atom/movable/target as anything in (GLOB.mechas_list + GLOB.bots_list))
		if(pilot_ready(target))
			targets += target
	return targets

/datum/ipc_os_program/cyberlink/proc/request_bot_pilot(mob/user, target_ref)
	if(!os.can_use(user))
		return FALSE
	for(var/mob/living/basic/bot/bot as anything in GLOB.bots_list)
		if(REF(bot) != target_ref)
			continue
		if(pilot_ready(bot) && begin_routing(user, bot, pilot_kind(bot) == "secbot" || !slot_access(bot), pilot_bot = TRUE))
			return TRUE
		break
	link_message = "Не удалось вселиться. Проверьте питание бота, права удалённого доступа и состояние текущей связи."
	return TRUE

/datum/ipc_os_program/cyberlink/proc/pilot_start(atom/movable/target, show_routing_result = FALSE)
	if(camera_session || pilot || !os.can_use(os.host) || !os.host.mind || !(target in pilot_targets()))
		return FALSE
	var/datum/ipc_cyberlink_pilot/session = new(src, target)
	session.show_routing_result = show_routing_result
	if(!session.start())
		qdel(session)
		return FALSE
	ensure_link_processing()
	return TRUE

/// The physical body and its installed core remain the owner throughout every native mind transfer.
/datum/ipc_cyberlink_pilot
	var/datum/ipc_os_program/cyberlink/program
	var/mob/living/carbon/human/body
	var/obj/item/organ/brain/core
	var/atom/movable/target
	var/mob/living/controlled
	var/datum/mind/source_mind
	var/datum/weakref/original_character
	var/owner_client
	var/turf/body_origin
	var/transferring = FALSE
	var/show_routing_result = FALSE
	var/handoff_deadline = 0
	var/ending = FALSE
	var/penalized = FALSE
	var/elapsed = 0
	var/next_sparks
	var/datum/action/innate/ipc_neural_return/return_action
	var/datum/ai_controller/bot_ai
	var/ai_was_forced_off
	var/ai_off_revision
	var/had_arrest_component = FALSE
	var/obj/item/melee/baton/security/baton
	var/obj/item/stock_parts/power_store/cell/original_cell
	var/original_active
	var/obj/item/stock_parts/power_store/cell/ipc_neural/adapter

/datum/ipc_cyberlink_pilot/New(datum/ipc_os_program/cyberlink/program, atom/movable/target)
	. = ..()
	src.program = program
	src.target = target
	body = program.os.host
	core = program.os.core
	if(istype(target, /obj/vehicle/sealed/mecha))
		controlled = new /mob/living/ipc_neural_proxy(target)
	else
		controlled = target

/datum/ipc_cyberlink_pilot/proc/start()
	if(program.camera_session || program.pilot || !program.running || !program.available() || program.os.control_session || !program.os.can_use(body) || !body.mind || !(target in program.pilot_targets()))
		return FALSE
	source_mind = body.mind
	original_character = source_mind.original_character
	owner_client = GET_CLIENT(body)
	body_origin = get_turf(body)
	program.pilot = src
	target.ipc_neural_pilot = WEAKREF(src)
	transferring = TRUE
	body.add_traits(list(TRAIT_IMMOBILIZED, TRAIT_HANDS_BLOCKED, TRAIT_IPC_REMOTE_PILOT_BODY), REF(src))
	RegisterSignals(body, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING, COMSIG_ATOM_EMP_ACT, COMSIG_MOVABLE_MOVED, COMSIG_MOB_MIND_TRANSFERRED_INTO), PROC_REF(invalidated))
	RegisterSignals(core, list(COMSIG_QDELETING, COMSIG_ATOM_EMP_ACT), PROC_REF(invalidated))
	RegisterSignal(source_mind, COMSIG_MIND_TRANSFERRED, PROC_REF(mind_changed))
	RegisterSignal(source_mind, COMSIG_QDELETING, PROC_REF(invalidated))
	RegisterSignal(target, COMSIG_QDELETING, PROC_REF(invalidated))
	if(istype(target, /obj/vehicle/sealed/mecha))
		var/obj/vehicle/sealed/mecha/mech = target
		ADD_TRAIT(controlled, TRAIT_GODMODE, REF(src))
		if(HAS_TRAIT(body, TRAIT_PACIFISM))
			ADD_TRAIT(controlled, TRAIT_PACIFISM, REF(src))
		controlled.remote_control = mech
		if(!mech.add_occupant(controlled))
			end()
			return FALSE
		RegisterSignal(mech, COMSIG_ATOM_INTEGRITY_CHANGED, PROC_REF(integrity_changed))
		RegisterSignal(mech, COMSIG_ATOM_DESTRUCTION, PROC_REF(destroyed))
	else
		var/mob/living/basic/bot/bot = target
		RegisterSignal(bot, COMSIG_ATOM_EMP_ACT, PROC_REF(invalidated))
		bot_ai = bot.ai_controller
		ai_was_forced_off = bot_ai.forced_off
		bot_ai.force_ai_off()
		ai_off_revision = bot_ai.forced_off_revision
		bot_ai.clear_blackboard_key(BB_CURRENT_TARGET)
		var/mob/living/basic/bot/secbot/security_bot = bot
		if(istype(security_bot))
			var/datum/component/arrest = security_bot.GetComponent(/datum/component/stun_n_cuff)
			if(!istype(security_bot, /mob/living/basic/bot/secbot/ed209))
				had_arrest_component = !!arrest
				qdel(arrest)
			baton = security_bot.weapon
			original_cell = baton.cell
			original_active = baton.active
			adapter = new(baton)
			adapter.link = src
			adapter.maxcharge = baton.cell_hit_cost
			adapter.charge = adapter.maxcharge
			baton.cell = adapter
			baton.active = TRUE
			baton.set_light_on(TRUE)
			baton.update_appearance()
			RegisterSignals(baton, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING), PROC_REF(invalidated))
			RegisterSignal(bot, COMSIG_MOB_CLICKON, PROC_REF(bot_click))
		RegisterSignal(bot, COMSIG_LIVING_DEATH, PROC_REF(destroyed))
		next_sparks = world.time + rand(6,10) SECONDS
	RegisterSignal(controlled, COMSIG_MOB_LOGOUT, PROC_REF(controlled_logout))
	RegisterSignal(controlled, COMSIG_MOVABLE_MOVED, PROC_REF(controlled_moved))
	if(controlled != target)
		RegisterSignal(controlled, COMSIG_QDELETING, PROC_REF(invalidated))
		RegisterSignal(target, COMSIG_MOVABLE_MOVED, PROC_REF(controlled_moved))
	// Client Login may yield while the native mob transfer updates its HUD.
	handoff_deadline = world.time + 5 SECONDS
	var/client/pilot_client = owner_client
	if(istype(pilot_client))
		addtimer(CALLBACK(src, PROC_REF(transfer_client)), 0)
	else
		source_mind.transfer_to(controlled)
		source_mind.original_character = original_character
		finish_handoff()
	return !ending

/datum/ipc_cyberlink_pilot/proc/transfer_client()
	var/client/pilot_client = owner_client
	if(ending || QDELETED(pilot_client) || pilot_client.mob != body || body.mind != source_mind || !program.os.is_operational())
		end()
		return
	source_mind.key = pilot_client.key
	source_mind.transfer_to(controlled, force_key_move = TRUE)
	if(!ending && source_mind?.current == controlled)
		source_mind.original_character = original_character

/datum/ipc_cyberlink_pilot/proc/finish_handoff()
	transferring = FALSE
	return_action = new(src)
	return_action.Grant(controlled)
	controlled.reset_perspective(target)
	controlled.update_mouse_pointer()
	var/instructions = bot_instructions()
	if(instructions)
		to_chat(controlled, span_notice(instructions))
	if(show_routing_result)
		program.routing_window.result = "success"
		if(controlled.client)
			program.routing_window.ui_interact(controlled)
	SEND_SOUND(controlled, sound('modular_bandastation/species/sound/ipc/cyberlink_success.mp3', volume = 60))
	log_game("[key_name(controlled)] established a ChromieKnight pilot channel to [target] at [AREACOORD(target)].")

/datum/ipc_cyberlink_pilot/proc/bot_instructions()
	if(istype(target, /mob/living/basic/bot/secbot/ed209))
		return "ЛКМ — выстрел из дизейблера. ПКМ вблизи — удар дубинкой."
	if(istype(target, /mob/living/basic/bot/secbot))
		return "ЛКМ по цели вблизи — удар дубинкой."
	if(istype(target, /mob/living/basic/bot/cleanbot))
		return "ЛКМ по соседнему полу или пятну — уборка. Пена доступна на панели действий."
	if(istype(target, /mob/living/basic/bot/medbot))
		return "ЛКМ по раненому рядом — лечение."
	if(istype(target, /mob/living/basic/bot/repairbot))
		return "ЛКМ по соседнему повреждённому полу или конструкции — ремонт."
	if(istype(target, /mob/living/basic/bot))
		return "Используйте ЛКМ по цели и действия на панели бота."

/datum/ipc_cyberlink_pilot/proc/controlled_logout()
	SIGNAL_HANDLER
	if(!transferring)
		end()

/datum/ipc_cyberlink_pilot/proc/valid()
	return !ending && !transferring && !QDELETED(body) && !QDELETED(core) && !QDELETED(target) && !QDELETED(controlled) && program?.running && program.available() && program.os.host == body && program.os.core == core && core.owner == body && !program.os.control_session && program.os.is_operational() && !body.incapacitated && get_turf(body) == body_origin && source_mind?.current == controlled && GET_CLIENT(controlled) == owner_client && owner_client && program.pilot_ready(target, src)

/datum/ipc_cyberlink_pilot/proc/periodic_cost()
	var/kind = program.pilot_kind(target)
	if(kind == "bot" || kind == "secbot")
		return kind == "bot" ? 1 : 1.5
	var/civilian = kind == "civilian"
	var/distance = get_dist(get_turf(body), get_turf(target))
	if(distance <= 8)
		return civilian ? 1 : 1.5
	if(distance <= 20)
		return civilian ? 1.5 : 2.5
	if(distance <= 40)
		return civilian ? 2.5 : 4
	return civilian ? 4 : 6

/datum/ipc_cyberlink_pilot/proc/tick(seconds_per_tick)
	if(transferring)
		var/client/pilot_client = owner_client
		if(istype(pilot_client) && pilot_client.mob == controlled && controlled.client == pilot_client && source_mind?.current == controlled)
			finish_handoff()
		else if(world.time >= handoff_deadline)
			end()
		return
	if(!valid())
		end()
		return
	elapsed += seconds_per_tick
	while(elapsed >= 10)
		elapsed -= 10
		if(!program.spend_charge(periodic_cost()))
			end()
			return
		if(ending)
			return
	if(adapter)
		adapter.charge = body.nutrition >= program.charge_cost(2) ? adapter.maxcharge : 0
		if(world.time >= next_sparks)
			do_sparks(3, TRUE, target)
			next_sparks = world.time + rand(6,10) SECONDS

/datum/ipc_cyberlink_pilot/proc/integrity_changed(datum/source, old_value, new_value)
	SIGNAL_HANDLER
	if(!ending && !QDELETED(body) && old_value > new_value)
		body.adjust_coretemperature((old_value - new_value) * 0.75)
		// Native mech destruction ejects occupants before the generic destruction signal.
		if(new_value <= 0)
			destroyed(source)

/datum/ipc_cyberlink_pilot/proc/destroyed(datum/source)
	SIGNAL_HANDLER
	if(ending || penalized)
		return
	penalized = TRUE
	if(!QDELETED(body))
		var/kind = program.pilot_kind(target)
		if(kind == "combat")
			var/turf/target_turf = get_turf(target)
			var/turf/body_turf = get_turf(body)
			if(target_turf && body_turf && target_turf != body_turf && target_turf.z == body_turf.z)
				target_turf.Beam(body_turf, icon_state = "lichbeam", time = 2 SECONDS)
		body.adjust_coretemperature(kind == "combat" ? 60 : kind == "civilian" ? 35 : 15)
		body.apply_damage(kind == "combat" ? 40 : kind == "civilian" ? 25 : 10, BURN)
	end()

/datum/ipc_cyberlink_pilot/proc/invalidated(datum/source)
	SIGNAL_HANDLER
	if(!transferring)
		end()

/datum/ipc_cyberlink_pilot/proc/controlled_moved()
	SIGNAL_HANDLER
	if(!transferring && !valid())
		// A containing mech is still updating its contents' spatial cells during Moved.
		addtimer(CALLBACK(src, PROC_REF(check_position)), 0)

/datum/ipc_cyberlink_pilot/proc/check_position()
	if(!valid())
		end()

/datum/ipc_cyberlink_pilot/proc/mind_changed()
	SIGNAL_HANDLER
	if(!transferring)
		end()

/datum/ipc_cyberlink_pilot/proc/bot_click(mob/source, atom/clicked, list/modifiers)
	SIGNAL_HANDLER
	if(modifiers[SHIFT_CLICK] || modifiers[CTRL_CLICK] || modifiers[ALT_CLICK] || modifiers[MIDDLE_CLICK])
		return NONE
	if(!valid())
		return NONE
	if(istype(controlled, /mob/living/basic/bot/secbot/ed209) && !modifiers[RIGHT_CLICK])
		INVOKE_ASYNC(src, PROC_REF(fire_disabler), clicked, modifiers)
	else if(isliving(clicked) && clicked != controlled && controlled.Adjacent(clicked))
		INVOKE_ASYNC(src, PROC_REF(stun_target), clicked)
	return COMSIG_MOB_CANCEL_CLICKON

/datum/ipc_cyberlink_pilot/proc/fire_disabler(atom/clicked, list/modifiers)
	if(!valid() || QDELETED(clicked) || clicked == controlled || controlled.incapacitated || HAS_TRAIT(body, TRAIT_PACIFISM) || HAS_TRAIT(controlled, TRAIT_PACIFISM) || !(clicked in view(controlled)) || clicked.IsObscured())
		return FALSE
	controlled.RangedAttack(clicked, modifiers)
	return TRUE

/datum/ipc_cyberlink_pilot/proc/stun_target(mob/living/victim)
	if(!valid() || !baton || victim == controlled || !controlled.Adjacent(victim) || controlled.incapacitated || controlled.next_move > world.time || HAS_TRAIT(controlled, TRAIT_PACIFISM) || HAS_TRAIT(body, TRAIT_PACIFISM) || body.nutrition < program.charge_cost(2))
		return FALSE
	adapter.charge = adapter.maxcharge
	if(!baton.active)
		baton.active = TRUE
		baton.set_light_on(TRUE)
		baton.update_appearance()
	baton.melee_attack_chain(controlled, victim, list(RIGHT_CLICK = FALSE))
	return TRUE

/// Idempotent teardown does not reverse an unrelated external mind transfer.
/datum/ipc_cyberlink_pilot/proc/end()
	if(ending)
		return
	ending = TRUE
	transferring = TRUE
	QDEL_NULL(return_action)
	for(var/datum/source in list(body, core, target, controlled, baton))
		if(source)
			UnregisterSignal(source, list(COMSIG_LIVING_DEATH, COMSIG_MOB_LOGOUT, COMSIG_QDELETING, COMSIG_ATOM_EMP_ACT, COMSIG_MOVABLE_MOVED, COMSIG_ATOM_INTEGRITY_CHANGED, COMSIG_ATOM_DESTRUCTION, COMSIG_MOB_CLICKON, COMSIG_MOB_MIND_TRANSFERRED_INTO))
	if(source_mind)
		UnregisterSignal(source_mind, list(COMSIG_MIND_TRANSFERRED, COMSIG_QDELETING))
	if(!QDELETED(source_mind) && source_mind.current == controlled)
		if(!QDELETED(body) && (!body.mind || body.mind == source_mind))
			source_mind.transfer_to(body, force_key_move = !!controlled.client)
			source_mind.original_character = original_character
		else if(!QDELETED(controlled))
			controlled.ghostize(can_reenter_corpse = FALSE)
	if(!QDELETED(body))
		body.remove_traits(list(TRAIT_IMMOBILIZED, TRAIT_HANDS_BLOCKED, TRAIT_IPC_REMOTE_PILOT_BODY), REF(src))
		if(!body.client && !body.player_logged && body.stat != DEAD)
			body.add_overlay(GLOB.ssd_indicator_overlay)
	if(target?.ipc_neural_pilot?.resolve() == src)
		target.ipc_neural_pilot = null
	if(istype(target, /obj/vehicle/sealed/mecha))
		var/obj/vehicle/sealed/mecha/mech = target
		if(controlled in mech.occupants)
			mech.remove_occupant(controlled)
		controlled.remote_control = null
		if(controlled.mind)
			controlled.ghostize(can_reenter_corpse = FALSE)
		qdel(controlled)
	else if(istype(target, /mob/living/basic/bot))
		var/mob/living/basic/bot/secbot/bot = target
		if(!QDELETED(baton) && baton.cell == adapter)
			baton.cell = original_cell
			baton.active = original_active
			baton.set_light_on(original_active)
			baton.update_appearance()
		QDEL_NULL(adapter)
		if(!QDELETED(bot))
			if(istype(bot) && had_arrest_component && !bot.GetComponent(/datum/component/stun_n_cuff))
				bot.add_arrest_component()
		if(!QDELETED(target) && !QDELETED(bot_ai) && !ai_was_forced_off && bot_ai.forced_off_revision == ai_off_revision)
			bot_ai.clear_forced_off()
	if(program?.pilot == src)
		program.pilot = null
	if(!QDELING(src))
		qdel(src)

/datum/ipc_cyberlink_pilot/Destroy()
	if(!ending)
		end()
	program = null
	body = null
	core = null
	target = null
	controlled = null
	source_mind = null
	original_character = null
	owner_client = null
	body_origin = null
	bot_ai = null
	baton = null
	original_cell = null
	return ..()

/mob/living/ipc_neural_proxy
	name = "нейронный канал"
	density = FALSE
	invisibility = INVISIBILITY_ABSTRACT
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/mob/living/ipc_neural_proxy/Life(seconds_per_tick = SSMOBS_DT)
	return

/mob/living/ipc_neural_proxy/Move()
	return FALSE

/datum/action/innate/ipc_neural_return
	name = "ChromieКnight 4.4"
	desc = "Открыть состояние связи и вернуться в свой корпус."
	button_icon = /datum/action/innate/ipc_os::button_icon
	button_icon_state = /datum/action/innate/ipc_os::button_icon_state
	var/datum/ipc_cyberlink_pilot/link

/datum/action/innate/ipc_neural_return/New(datum/ipc_cyberlink_pilot/link)
	. = ..()
	src.link = link

/datum/action/innate/ipc_neural_return/Activate()
	if(link?.valid() && owner == link.controlled)
		link.program.ui_interact(owner)

/datum/action/innate/ipc_neural_return/Destroy()
	link = null
	return ..()

/// A temporary cell adapter lets the real baton apply armor, cooldown and stamina effects unchanged.
/obj/item/stock_parts/power_store/cell/ipc_neural
	maxcharge = STANDARD_CELL_CHARGE
	charge = STANDARD_CELL_CHARGE
	var/datum/ipc_cyberlink_pilot/link

/obj/item/stock_parts/power_store/cell/ipc_neural/use(used, force = FALSE)
	if(!link?.valid() || used != link.baton.cell_hit_cost || !link.program.spend_charge(2))
		return 0
	return used

/obj/item/stock_parts/power_store/cell/ipc_neural/Destroy()
	link = null
	return ..()
