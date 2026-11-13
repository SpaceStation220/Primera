/datum/xenoartifact_effect/heal
	log_name = "Исцеление"
	type_name = XENO_EFFECT_ORGANIC

/**
 * Heals target mob
 *
 * Arguments:
 * * receiver - mob to heal
 * * healing_power - how much to heal
 */
/datum/xenoartifact_effect/heal/proc/heal_target(mob/living/receiver, healing_power)
	if(ishuman(receiver))
		var/mob/living/carbon/human/human_mob = receiver
		var/weakness = get_xenoartifact_susceptibility(human_mob)
		human_mob.heal_overall_damage(healing_power * weakness, healing_power * weakness)
		return
	receiver.heal_overall_damage(healing_power, healing_power)

/datum/xenoartifact_effect/heal/do_effect_touch(mob/user)
	. = ..()
	if(!.)
		return
	to_chat(user, span_notice("Успокаивающая энергия наполняет вас силами."))
	heal_target(user, 25)

/datum/xenoartifact_effect/heal/do_effect_aura(seconds_per_tick)
	. = ..()
	if(!.)
		return
	var/turf/curr_turf = get_turf(holder)
	for(var/mob/living/receiver in range(range, curr_turf))
		to_chat(receiver, span_notice("Волна энергии наполняет вас силами."))
		heal_target(receiver, rand(1,3)/2 * seconds_per_tick)

/datum/xenoartifact_effect/heal/do_effect_pulse(seconds_per_tick)
	. = ..()
	if(!.)
		return
	var/used_power = .
	var/turf/curr_turf = get_turf(holder)
	for(var/mob/living/receiver in range(range, curr_turf))
		to_chat(receiver, span_notice("Волна энергии наполняет вас силами."))
		heal_target(receiver, 2.5 * used_power * seconds_per_tick)

/datum/xenoartifact_effect/heal/do_effect_destroy()
	var/turf/curr_turf = get_turf(holder)
	for(var/mob/living/receiver in range(7, curr_turf))
		to_chat(receiver, span_notice("Волна энергии залечивает ваши раны."))
		heal_target(receiver, 50)

/datum/xenoartifact_effect/roboheal
	log_name = "Ремонт кремниевых форм жизни"

/datum/xenoartifact_effect/roboheal/New()
	. = ..()
	type_name = pick(XENO_EFFECT_ELECTRO, XENO_EFFECT_PARTICLE)

/**
 * Heals silicons only
 *
 * Arguments:
 * * receiver - mob to heal
 * * healing_power - how much to heal
 */
/datum/xenoartifact_effect/roboheal/proc/heal_target(mob/living/receiver, healing_power)
	receiver.heal_overall_damage(healing_power, healing_power)

/datum/xenoartifact_effect/roboheal/do_effect_touch(mob/user)
	. = ..()
	if(!.)
		return
	if(!issilicon(user))
		return
	to_chat(user, span_notice("Система сообщает о самопроизвольном восстановлении повреждённых компонентов!"))
	heal_target(user, 25)

/datum/xenoartifact_effect/roboheal/do_effect_aura(seconds_per_tick)
	. = ..()
	if(!.)
		return
	var/turf/curr_turf = get_turf(holder)
	for(var/mob/living/silicon/receiver in range(range, curr_turf))
		to_chat(receiver, span_notice("СИСТЕМНОЕ ОПОВЕЩЕНИЕ: обнаружено восстанавливающее энергетическое поле!"))
		heal_target(receiver, 0.5 * seconds_per_tick)

/datum/xenoartifact_effect/roboheal/do_effect_pulse(seconds_per_tick)
	. = ..()
	if(!.)
		return
	var/used_power = .
	var/turf/curr_turf = get_turf(holder)
	for(var/mob/living/silicon/receiver in range(range, curr_turf))
		to_chat(receiver, span_notice("СИСТЕМНОЕ ОПОВЕЩЕНИЕ: импульс энергии устранил повреждения конструкции!"))
		heal_target(receiver, 2.5 * used_power * seconds_per_tick)

/datum/xenoartifact_effect/roboheal/do_effect_destroy()
	var/turf/curr_turf = get_turf(holder)
	for(var/mob/living/silicon/receiver in range(7, curr_turf))
		to_chat(receiver, span_notice("СИСТЕМНОЕ ОПОВЕЩЕНИЕ: импульс энергии устранил повреждения конструкции!"))
		heal_target(receiver, 50)

/datum/xenoartifact_effect/hurt
	log_name = "Повреждение органики"

/**
 * Deals damage to mobs via take_overall_damage
 *
 * Arguments:
 * * receiver - mob to damage
 * * damage_power - how much to damage
 */
/datum/xenoartifact_effect/hurt/proc/deal_damage(mob/living/receiver, damage_power)
	if(ishuman(receiver))
		var/mob/living/carbon/human/human_receiver = receiver
		var/weakness = get_xenoartifact_susceptibility(human_receiver)
		human_receiver.take_overall_damage(damage_power * weakness, damage_power * weakness)
		return
	receiver.take_overall_damage(damage_power, damage_power)

/datum/xenoartifact_effect/hurt/do_effect_touch(mob/user)
	. = ..()
	if(!.)
		return
	to_chat(user, span_warning("Вас поражает болезненный разряд энергии!"))
	deal_damage(user, 10)
	return TRUE

/datum/xenoartifact_effect/hurt/do_effect_aura(seconds_per_tick)
	. = ..()
	if(!.)
		return
	var/turf/curr_turf = get_turf(holder)
	for(var/mob/living/receiver in range(range, curr_turf))
		to_chat(receiver, span_warning("Нечто рядом излучает болезненную силу."))
		deal_damage(receiver, 0.5 * seconds_per_tick)

/datum/xenoartifact_effect/hurt/do_effect_pulse(seconds_per_tick)
	. = ..()
	if(!.)
		return
	var/used_power = .
	var/turf/curr_turf = get_turf(holder)
	for(var/mob/living/receiver in range(range, curr_turf))
		to_chat(receiver, span_notice("Волна энергии разрывает вашу плоть."))
		deal_damage(receiver, 2.5 * (used_power / 3) * seconds_per_tick)

/datum/xenoartifact_effect/hurt/do_effect_destroy()
	var/turf/curr_turf = get_turf(holder)
	for(var/mob/living/receiver in range(7, curr_turf))
		to_chat(receiver, span_warning("Вы чувствуете чудовищную боль."))
		deal_damage(receiver, 50)

/datum/xenoartifact_effect/robohurt
	log_name = "Повреждение кремниевых форм жизни"

/datum/xenoartifact_effect/robohurt/New()
	. = ..()
	type_name = pick(XENO_EFFECT_ELECTRO, XENO_EFFECT_PARTICLE)

/**
 * Deals damage to silicons only
 *
 * Arguments:
 * * receiver - mob to damage
 * * damage_power - how much to damage
 */
/datum/xenoartifact_effect/robohurt/proc/deal_damage(mob/living/receiver, damage_power)
	receiver.take_overall_damage(damage_power, damage_power)

/datum/xenoartifact_effect/robohurt/do_effect_touch(mob/user)
	. = ..()
	if(!.)
		return
	if(!issilicon(user))
		return
	to_chat(user, span_warning("Система сообщает о серьёзных повреждениях!"))
	deal_damage(user, 10)

/datum/xenoartifact_effect/robohurt/do_effect_aura(seconds_per_tick)
	. = ..()
	if(!.)
		return
	var/turf/curr_turf = get_turf(holder)
	for(var/mob/living/silicon/receiver in range(range, curr_turf))
		to_chat(receiver, span_warning("СИСТЕМНОЕ ОПОВЕЩЕНИЕ: обнаружено разрушительное энергетическое поле!"))
		deal_damage(receiver, 0.5 * seconds_per_tick)

/datum/xenoartifact_effect/robohurt/do_effect_pulse(seconds_per_tick)
	. = ..()
	if(!.)
		return
	var/used_power = .
	var/turf/curr_turf = get_turf(holder)
	for(var/mob/living/silicon/receiver in range(range, curr_turf))
		to_chat(receiver, span_warning("СИСТЕМНОЕ ОПОВЕЩЕНИЕ: импульс энергии повредил конструкцию!"))
		deal_damage(receiver, 0.25 * used_power * seconds_per_tick)

/datum/xenoartifact_effect/robohurt/do_effect_destroy()
	var/turf/curr_turf = get_turf(holder)
	for(var/mob/living/silicon/receiver in range(7, curr_turf))
		to_chat(receiver, span_warning("СИСТЕМНОЕ ОПОВЕЩЕНИЕ: импульс энергии нанёс критические повреждения!"))
		deal_damage(receiver, 50)
