/datum/ipc_os_program/factory/jaws
	id = "factory_jaws"
	name = "Челюсти Хранителя"
	description = "Встроенные медицинские клешни для фиксации пациента, стимуляции и прижигания лёгких. Для выпуска нужны две свободные руки."
	icon = "hand-holding-medical"
	builtin_department = "medical"
	var/mode = "stabilize"
	var/obj/item/ipc_guardian_jaw/left_jaw
	var/obj/item/ipc_guardian_jaw/right_jaw
	var/mob/living/carbon/patient
	var/session_id = 0

/datum/ipc_os_program/factory/jaws/start()
	var/mob/living/carbon/human/user = os.host
	var/left_index = user?.get_empty_held_index_for_side(LEFT_HANDS)
	var/right_index = user?.get_empty_held_index_for_side(RIGHT_HANDS)
	if(!left_index || !right_index)
		if(user)
			to_chat(user, span_warning("Освободите обе руки, чтобы выпустить клешни."))
		return FALSE
	if(!..())
		return FALSE
	left_jaw = new(user)
	left_jaw.program = src
	right_jaw = new(user)
	right_jaw.icon_state = "ipc_jaws_r"
	right_jaw.program = src
	ADD_TRAIT(left_jaw, TRAIT_NODROP, REF(src))
	ADD_TRAIT(right_jaw, TRAIT_NODROP, REF(src))
	if(!user.put_in_hand(left_jaw, left_index) || !user.put_in_hand(right_jaw, right_index))
		stop()
		return FALSE
	RegisterSignal(user, COMSIG_CARBON_POST_REMOVE_LIMB, PROC_REF(on_limb_lost))
	playsound(user, /obj/item/organ/cyberimp/arm/power_cord/ipc::extend_sound, 50, TRUE)
	return TRUE

/datum/ipc_os_program/factory/jaws/stop()
	release_patient()
	if(running && os.host)
		UnregisterSignal(os.host, COMSIG_CARBON_POST_REMOVE_LIMB)
		playsound(os.host, /obj/item/organ/cyberimp/arm/power_cord/ipc::retract_sound, 50, TRUE)
	QDEL_NULL(left_jaw)
	QDEL_NULL(right_jaw)
	return ..()

/datum/ipc_os_program/factory/jaws/tick(seconds_per_tick)
	if(!hands_ready(os.host))
		stop()

/datum/ipc_os_program/factory/jaws/proc/hands_ready(mob/living/carbon/human/user)
	return !QDELETED(left_jaw) && !QDELETED(right_jaw) && user.is_holding(left_jaw) && user.is_holding(right_jaw)

/datum/ipc_os_program/factory/jaws/proc/on_limb_lost(datum/source, obj/item/bodypart/lost_limb)
	SIGNAL_HANDLER
	if(lost_limb.body_zone in list(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM))
		stop()

/datum/ipc_os_program/factory/jaws/command(list/params)
	var/selection = params["operation"]
	if(selection == "release")
		return release_patient()
	if(patient || !(selection in list("stabilize", "restore")))
		return FALSE
	mode = selection
	return TRUE

/datum/ipc_os_program/factory/jaws/proc/eligible_patient(mob/living/carbon/target, selection)
	if(QDELETED(target) || target.stat == DEAD)
		return FALSE
	if(selection == "stabilize")
		return target.stat >= SOFT_CRIT && (target.get_brute_loss() > 0 || target.get_oxy_loss() > 0)
	return target.stat < SOFT_CRIT && target.get_brute_loss() > 0

/datum/ipc_os_program/factory/jaws/proc/valid_contact(mob/living/carbon/human/user, mob/living/carbon/target, token)
	return token == session_id && patient == target && !QDELETED(target) && target.stat != DEAD && running && available() && os.can_use(user) && hands_ready(user) && user.pulling == target && user.grab_state == GRAB_AGGRESSIVE && user.can_perform_action(target, FORBID_TELEKINESIS_REACH)

/datum/ipc_os_program/factory/jaws/proc/try_treat(mob/living/carbon/human/user, mob/living/carbon/target, obj/item/ipc_guardian_jaw/jaw)
	if(patient || !running || !available() || !os.can_use(user) || !hands_ready(user) || !(jaw in list(left_jaw, right_jaw)) || target == user || !user.can_perform_action(target, FORBID_TELEKINESIS_REACH))
		return FALSE
	var/selection = mode
	var/cost = user.ipc_charge_capacity() * (selection == "stabilize" ? 0.04 : 0.08)
	if(!eligible_patient(target, selection))
		to_chat(user, span_warning(selection == "stabilize" ? "Для стабилизации нужен пациент в критическом состоянии с травмами или удушьем." : "Для восстановления нужен пациент с травмами вне критического состояния."))
		return FALSE
	if(user.nutrition < cost || HAS_TRAIT(user, TRAIT_IPC_JAWS_HEARTBEAT) || HAS_TRAIT(target, TRAIT_IPC_JAWS_HEARTBEAT) || (user.pulling != target && !user.start_pulling(target, GRAB_PASSIVE, supress_message = TRUE)))
		return FALSE
	user.setGrabState(GRAB_AGGRESSIVE)
	user.set_pull_offsets(target, GRAB_AGGRESSIVE)
	patient = target
	var/token = ++session_id
	RegisterSignal(user, COMSIG_ATOM_NO_LONGER_PULLING, PROC_REF(on_pull_end))
	RegisterSignals(patient, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING), PROC_REF(on_patient_lost))
	if(selection == "stabilize")
		ADD_TRAIT(patient, TRAIT_NOCRITDAMAGE, REF(src))
	ADD_TRAIT(user, TRAIT_IPC_JAWS_HEARTBEAT, REF(src))
	ADD_TRAIT(patient, TRAIT_IPC_JAWS_HEARTBEAT, REF(src))
	user.visible_message(span_notice("[user] фиксирует [patient] медицинскими клешнями."), span_notice("Вы фиксируете пациента клешнями."))
	to_chat(patient, span_notice("Чтобы освободиться, попробуйте отойти или нажмите Resist."))
	user.do_attack_animation(patient, used_item = jaw)
	playsound(user, 'modular_bandastation/species/sound/ipc/jaws_engage.mp3', 55, FALSE)
	for(var/mob/living/listener as anything in list(user, patient))
		if(!HAS_TRAIT(listener, TRAIT_DEAF))
			SEND_SOUND(listener, sound('modular_bandastation/species/sound/ipc/jaws_heartbeat.mp3', repeat = TRUE, channel = CHANNEL_HEARTBEAT, volume = 55))
	INVOKE_ASYNC(src, PROC_REF(treat), user, target, selection, token)
	return TRUE

/datum/ipc_os_program/factory/jaws/proc/treat(mob/living/carbon/human/user, mob/living/carbon/target, selection, token)
	var/stabilizing = selection == "stabilize"
	var/duration = stabilizing ? 4 SECONDS : 6 SECONDS
	var/cost_fraction = stabilizing ? 0.04 : 0.08
	var/contact_key = "[REF(src)]:[token]"
	var/datum/callback/contact_check = CALLBACK(src, PROC_REF(valid_contact), user, target, token)
	if(do_after(user, 3 SECONDS, target = target, timed_action_flags = IGNORE_SLOWDOWNS, interaction_key = contact_key, ipc_fixed_duration = TRUE, extra_checks = contact_check))
		while(valid_contact(user, target, token))
			if(!do_after(user, duration, target = target, timed_action_flags = IGNORE_SLOWDOWNS, interaction_key = contact_key, ipc_fixed_duration = TRUE, extra_checks = contact_check) || !valid_contact(user, target, token))
				break
			if(!eligible_patient(target, selection))
				continue
			var/obj/item/organ/heart/ipc/battery = os.working_battery()
			var/cost = user.ipc_charge_capacity() * cost_fraction
			if(!battery || user.nutrition < cost)
				break
			battery.adjust_charge(-cost)
			if(stabilizing)
				target.adjust_oxy_loss(-6, updating_health = FALSE)
			target.heal_overall_damage(brute = stabilizing ? 6 : 7, updating_health = FALSE)
			target.updatehealth()
	if(token == session_id)
		release_patient()

/datum/ipc_os_program/factory/jaws/proc/on_pull_end(datum/source, atom/movable/old_target)
	SIGNAL_HANDLER
	if(old_target == patient)
		release_patient()

/datum/ipc_os_program/factory/jaws/proc/on_patient_lost(datum/source)
	SIGNAL_HANDLER
	release_patient()

/datum/ipc_os_program/factory/jaws/proc/release_patient()
	if(!patient)
		return FALSE
	var/mob/living/carbon/old_patient = patient
	var/mob/living/carbon/human/user = os?.host
	patient = null
	session_id++
	UnregisterSignal(old_patient, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING))
	REMOVE_TRAIT(old_patient, TRAIT_NOCRITDAMAGE, REF(src))
	if(user)
		UnregisterSignal(user, COMSIG_ATOM_NO_LONGER_PULLING)
		if(user.pulling == old_patient)
			user.stop_pulling()
	for(var/mob/living/listener as anything in list(user, old_patient))
		if(QDELETED(listener))
			continue
		REMOVE_TRAIT(listener, TRAIT_IPC_JAWS_HEARTBEAT, REF(src))
		SEND_SOUND(listener, sound(null, channel = CHANNEL_HEARTBEAT))
	if(os)
		SStgui.update_uis(os)
	return TRUE

/// Medical restraint gives the patient an immediate release through the ordinary Resist control.
/proc/ipc_resist_guardian_jaws(mob/living/target)
	var/mob/living/carbon/human/operator = target.pulledby
	if(!istype(operator) || target.stat == DEAD)
		return FALSE
	var/datum/ipc_os_program/factory/jaws/jaws = operator.get_ipc_os()?.programs["factory_jaws"]
	if(jaws?.patient != target)
		return FALSE
	return jaws.release_patient()

/obj/item/ipc_guardian_jaw
	name = "клешня Хранителя"
	desc = "Медицинская клешня спроектирована для фиксации пациента, стимуляции лёгких и прижигания лёгочных тканей."
	icon = 'modular_bandastation/species/icons/ipc/factory_tools.dmi'
	icon_state = "ipc_jaws_l"
	inhand_icon_state = "ipc_jaws"
	lefthand_file = 'modular_bandastation/species/icons/ipc/factory_tools_left.dmi'
	righthand_file = 'modular_bandastation/species/icons/ipc/factory_tools_right.dmi'
	item_flags = ABSTRACT | NOBLUDGEON
	var/datum/ipc_os_program/factory/jaws/program

/obj/item/ipc_guardian_jaw/Destroy()
	program = null
	return ..()

/obj/item/ipc_guardian_jaw/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!iscarbon(interacting_with) || !ishuman(user))
		return ITEM_INTERACT_BLOCKING
	return program?.try_treat(user, interacting_with, src) ? ITEM_INTERACT_SUCCESS : ITEM_INTERACT_BLOCKING
