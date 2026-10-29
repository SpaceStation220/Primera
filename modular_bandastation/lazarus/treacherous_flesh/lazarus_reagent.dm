/// The donor's infection cure and dangerous reanimation fluid.
/datum/reagent/medicine/lazarus_reagent
	name = "Lazarus Reagent"
	description = "Биолюминесцентная зелёная жидкость, будто движущаяся сама по себе."
	color = "#A0E85E"
	metabolization_rate = 0.2
	taste_description = "life"
	chemical_flags = REAGENT_CAN_BE_SYNTHESIZED

/datum/reagent/medicine/lazarus_reagent/on_mob_life(mob/living/carbon/affected_mob, seconds_per_tick, metabolization_ratio)
	. = ..()
	if(SPT_PROB(10, seconds_per_tick))
		affected_mob.adjust_brute_loss(2 * metabolization_ratio)
		affected_mob.adjust_tox_loss(2 * metabolization_ratio)
		return UPDATE_MOB_HEALTH

/datum/reagent/medicine/lazarus_reagent/expose_mob(mob/living/exposed_mob, methods = TOUCH, reac_volume, show_message = TRUE, touch_protection = 0)
	. = ..()
	if(reac_volume < 1 || exposed_mob.stat != DEAD)
		return
	if(isanimal_or_basicmob(exposed_mob) && (methods & TOUCH))
		if(!exposed_mob.compare_sentience_type(SENTIENCE_ORGANIC))
			return
		if(exposed_mob.revive(HEAL_ALL))
			exposed_mob.AddComponent(/datum/component/lazarus_no_repeat_loot)
			exposed_mob.visible_message(span_warning("[exposed_mob] восстаёт из мёртвых!"))
		return
	if(!iscarbon(exposed_mob) || !((methods & INGEST) || ((methods & TOUCH) && prob(25))))
		return
	if(HAS_TRAIT(exposed_mob, TRAIT_SUICIDED) || HAS_TRAIT(exposed_mob, TRAIT_HUSK) || exposed_mob.has_status_effect(/datum/status_effect/lazarus_revival))
		return
	if(exposed_mob.get_brute_loss() + exposed_mob.get_fire_loss() >= 150)
		if(exposed_mob.mind?.has_antag_datum(/datum/antagonist/changeling) || exposed_mob.get_organ_by_type(/obj/item/organ/zombie_infection) || (!exposed_mob.key && !exposed_mob.get_ghost(ghosts_with_clients = TRUE)))
			return
		exposed_mob.gib()
		return
	exposed_mob.apply_status_effect(/datum/status_effect/lazarus_revival)

/// Reserves one revival attempt and revalidates the corpse after the five-second delay.
/datum/status_effect/lazarus_revival
	id = "lazarus_revival"
	duration = 5 SECONDS
	status_type = STATUS_EFFECT_UNIQUE
	alert_type = null

/datum/status_effect/lazarus_revival/on_apply()
	owner.notify_revival("Реагент Лазаря пытается оживить ваше тело. Вернитесь в него!")
	owner.do_jitter_animation(5 SECONDS)
	return TRUE

/datum/status_effect/lazarus_revival/on_remove()
	if(QDELING(owner) || owner.stat != DEAD || !owner.key || HAS_TRAIT(owner, TRAIT_SUICIDED) || HAS_TRAIT(owner, TRAIT_HUSK))
		return
	if(owner.get_brute_loss() + owner.get_fire_loss() >= 150)
		return
	owner.set_oxy_loss(0)
	owner.adjust_brute_loss(rand(0, 15))
	owner.adjust_fire_loss(rand(0, 15))
	owner.adjust_tox_loss(rand(0, 15))
	// Modern bodies use organ damage instead of the removed clone-damage pool.
	owner.adjust_organ_loss(ORGAN_SLOT_LIVER, 25)
	owner.revive()

/// Reanimated creatures cannot provide a fresh set of death drops each time.
/datum/component/lazarus_no_repeat_loot
	dupe_mode = COMPONENT_DUPE_UNIQUE

/datum/component/lazarus_no_repeat_loot/Initialize()
	if(!isliving(parent))
		return COMPONENT_INCOMPATIBLE
	var/mob/living/revived = parent
	if(istype(revived, /mob/living/simple_animal))
		var/mob/living/simple_animal/animal = revived
		animal.loot = list()
	RegisterSignal(parent, COMSIG_LIVING_DROP_LOOT, PROC_REF(block_loot))

/datum/component/lazarus_no_repeat_loot/proc/block_loot(datum/source, list/loot, gibbed)
	SIGNAL_HANDLER
	return COMPONENT_NO_LOOT_DROP

/datum/chemical_reaction/medicine/lazarus_reagent
	results = list(/datum/reagent/medicine/lazarus_reagent = 3)
	required_reagents = list(/datum/reagent/medicine/omnizine = 1, /datum/reagent/water/holywater = 1, /datum/reagent/toxin/mutagen = 1)
	reaction_flags = REACTION_INSTANT

/datum/chemical_reaction/medicine/lazarus_reagent/pre_reaction_other_checks(datum/reagents/holder)
	return istype(get_area(holder.my_atom), /area/lazarus) && ..()

/// The donor recipe matches Strange Reagent; select the event product only on its map.
/datum/chemical_reaction/medicine/strange_reagent/pre_reaction_other_checks(datum/reagents/holder)
	return !istype(get_area(holder.my_atom), /area/lazarus) && ..()
