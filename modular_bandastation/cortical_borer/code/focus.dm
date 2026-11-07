/// An earned upgrade. The parasite owns these; none owns or retains the current host.
/datum/cortical_borer_focus
	/// Stable identifier supplied by the UI; arbitrary typepaths are never accepted.
	var/id
	/// Player-facing description and fractional purchase cost.
	var/name
	var/desc
	var/cost

/// Apply reversible host effects on entry or on purchase.
/datum/cortical_borer_focus/proc/apply_host(mob/living/basic/cortical_borer/borer)
	return

/// Undo only this upgrade's contribution, before the host reference is cleared.
/datum/cortical_borer_focus/proc/remove_host(mob/living/basic/cortical_borer/borer)
	return

/// Continuous effects use seconds, independently of the mob subsystem frequency.
/datum/cortical_borer_focus/proc/on_life(mob/living/basic/cortical_borer/borer, seconds_per_tick)
	return

/// Improve brain recovery, stamina recovery and hunger; reduce incoming brain damage through the organ's signal.
/datum/cortical_borer_focus/head
	id = "head"
	name = "Голова"
	desc = "Защита и восстановление мозга, снижение голода, ускоренное восстановление выносливости."
	cost = 4.5
	/// Weak because an organ can be removed or deleted independently of the upgrade.
	var/datum/weakref/brain_ref
	/// Snapshot of the coefficient actually applied to the current host.
	var/hunger_multiplier = 1
	var/stamina_multiplier = 1
	var/brain_protection = 0.15

/datum/cortical_borer_focus/head/apply_host(mob/living/basic/cortical_borer/borer)
	hunger_multiplier = borer.catatonic_bonus ? 0.5 : 0.75
	stamina_multiplier = borer.catatonic_bonus ? 0.75 : 0.875
	brain_protection = borer.catatonic_bonus ? 0.3 : 0.15
	MODIFY_PHYSIOLOGY(borer.host, PHYS_COEFF_HUNGER_MOD, hunger_multiplier)
	borer.host.stamina_regen_time *= stamina_multiplier
	var/obj/item/organ/brain/brain = borer.host.get_organ_slot(ORGAN_SLOT_BRAIN)
	if(brain)
		brain_ref = WEAKREF(brain)
		RegisterSignal(brain, COMSIG_ORGAN_ADJUST_DAMAGE, PROC_REF(protect_brain))

/datum/cortical_borer_focus/head/remove_host(mob/living/basic/cortical_borer/borer)
	MODIFY_PHYSIOLOGY(borer.host, PHYS_COEFF_HUNGER_MOD, 1 / hunger_multiplier)
	borer.host.stamina_regen_time /= stamina_multiplier
	var/obj/item/organ/brain/brain = brain_ref?.resolve()
	if(brain)
		UnregisterSignal(brain, COMSIG_ORGAN_ADJUST_DAMAGE)
	brain_ref = null

/datum/cortical_borer_focus/head/on_life(mob/living/basic/cortical_borer/borer, seconds_per_tick)
	if(!borer.controlling)
		borer.host.adjust_organ_loss(ORGAN_SLOT_BRAIN, -0.5 * seconds_per_tick)

/// Positive damage triggers one negative adjustment; healing cannot recurse.
/datum/cortical_borer_focus/head/proc/protect_brain(obj/item/organ/brain/brain, amount)
	SIGNAL_HANDLER
	if(amount > 0)
		brain.apply_organ_damage(-amount * brain_protection)

/datum/cortical_borer_focus/head/Destroy()
	brain_ref = null
	return ..()

/// Improve physical resilience and protect the heart.
/datum/cortical_borer_focus/torso
	id = "torso"
	name = "Тело"
	desc = "Снижение физического урона и предотвращение сердечных приступов."
	cost = 7.5
	/// Snapshot used for symmetric removal.
	var/damage_multiplier = 1

/datum/cortical_borer_focus/torso/apply_host(mob/living/basic/cortical_borer/borer)
	damage_multiplier = borer.catatonic_bonus ? 0.8 : 0.9
	MODIFY_PHYSIOLOGY(borer.host, BRUTE, damage_multiplier)
	ADD_TRAIT(borer.host, TRAIT_STABLEHEART, REF(src))

/datum/cortical_borer_focus/torso/remove_host(mob/living/basic/cortical_borer/borer)
	MODIFY_PHYSIOLOGY(borer.host, BRUTE, 1 / damage_multiplier)
	REMOVE_TRAIT(borer.host, TRAIT_STABLEHEART, REF(src))

/datum/cortical_borer_focus/torso/on_life(mob/living/basic/cortical_borer/borer, seconds_per_tick)
	borer.host.set_heartattack(FALSE)

/// Improve tool use and the current arms without modifying a shared species datum.
/datum/cortical_borer_focus/hands
	id = "hands"
	name = "Руки"
	desc = "Быстрее работать инструментами, +5 к урону кулаками текущих рук."
	cost = 2.5
	/// Retain weak references so amputated arms can be restored without keeping them alive.
	var/list/datum/weakref/modified_arms = list()

/datum/cortical_borer_focus/hands/apply_host(mob/living/basic/cortical_borer/borer)
	borer.host.add_actionspeed_modifier(/datum/actionspeed_modifier/cortical_borer)
	for(var/obj/item/bodypart/arm/arm in borer.host.bodyparts)
		arm.unarmed_damage_low += 5
		arm.unarmed_damage_high += 5
		modified_arms += WEAKREF(arm)

/datum/cortical_borer_focus/hands/remove_host(mob/living/basic/cortical_borer/borer)
	borer.host.remove_actionspeed_modifier(/datum/actionspeed_modifier/cortical_borer)
	for(var/datum/weakref/arm_ref as anything in modified_arms)
		var/obj/item/bodypart/arm/arm = arm_ref.resolve()
		if(arm)
			arm.unarmed_damage_low -= 5
			arm.unarmed_damage_high -= 5
	modified_arms.Cut()

/datum/cortical_borer_focus/hands/Destroy()
	modified_arms = null
	return ..()

/// Tool speed is an action modifier rather than a mutation of host action state.
/datum/actionspeed_modifier/cortical_borer
	multiplicative_slowdown = -0.5

/// Improve ground movement with stronger bonuses on a host unoccupied at entry.
/datum/cortical_borer_focus/legs
	id = "legs"
	name = "Ноги"
	desc = "Ускорение передвижения носителя."
	cost = 5
	/// The modifier actually installed; removal must not depend on the current SSD state.
	var/modifier_type

/datum/cortical_borer_focus/legs/apply_host(mob/living/basic/cortical_borer/borer)
	modifier_type = borer.catatonic_bonus ? /datum/movespeed_modifier/cortical_borer : /datum/movespeed_modifier/cortical_borer/lesser
	borer.host.add_movespeed_modifier(modifier_type)

/datum/cortical_borer_focus/legs/remove_host(mob/living/basic/cortical_borer/borer)
	borer.host.remove_movespeed_modifier(modifier_type)
	modifier_type = null

/// Ground-only movement boost.
/datum/movespeed_modifier/cortical_borer
	multiplicative_slowdown = -0.25
	movetypes = GROUND
	blacklisted_movetypes = FLYING | FLOATING

/// Lesser boost for occupied hosts.
/datum/movespeed_modifier/cortical_borer/lesser
	multiplicative_slowdown = -0.125

/// The targeted action and torment read this learned focus directly.
/datum/cortical_borer_focus/sting
	id = "sting"
	name = "Жало"
	desc = "Подавление длится на 5 секунд дольше; агония стоит на 15 ресурса меньше."
	cost = 2.5

/// Reproduction reads this focus before debiting resource.
/datum/cortical_borer_focus/reproductive
	id = "reproductive"
	name = "Размножение"
	desc = "Личинка стоит 30 ресурса; 15% шанс дополнительных личинок."
	cost = 5

/// Size is recalculated from earned rank, never scaled cumulatively.
/datum/cortical_borer_focus/abdomen
	id = "abdomen"
	name = "Брюшко"
	desc = "Размер борера уменьшается на 20%."
	cost = 4.5

/// Improve accumulation and shorten infestation; both derive from this learned datum.
/datum/cortical_borer_focus/secretion
	id = "secretion"
	name = "Секреция"
	desc = "Накопление ресурса быстрее на 0.25 в секунду; заражение занимает 2.5 секунды."
	cost = 7.5
