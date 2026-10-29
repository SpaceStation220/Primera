/// Active parasites and unclaimed eggs both prevent duplicate infections.
/proc/lazarus_host_infested(mob/living/carbon/human/host)
	if(!QDELETED(host.treacherous_flesh))
		return host.treacherous_flesh
	var/obj/effect/mob_spawn/ghost_role/treacherous_flesh/egg = locate() in host
	return !QDELETED(egg)

/// Keeps infection markers private and independent of the ordinary antagonist HUD.
/proc/lazarus_update_infection_marker(mob/living/carbon/human/host)
	if(QDELETED(host))
		return
	if(!lazarus_host_infested(host))
		host.remove_alt_appearance("lazarus_infested")
		return
	var/icon_state = host.treacherous_flesh ? "active_hud" : "infested_hud"
	var/datum/atom_hud/alternate_appearance/basic/treacherous_flesh/marker = host.alternate_appearances?["lazarus_infested"]
	if(marker)
		marker.image.icon_state = icon_state
		return
	var/image/indicator = image('modular_bandastation/lazarus/icons/treacherous_flesh.dmi', host, icon_state)
	indicator.pixel_y = 16
	indicator.appearance_flags = RESET_COLOR|RESET_ALPHA
	host.add_alt_appearance(/datum/atom_hud/alternate_appearance/basic/treacherous_flesh, "lazarus_infested", indicator, NONE)

/datum/atom_hud/alternate_appearance/basic/treacherous_flesh/mobShouldSee(mob/viewer)
	return istype(viewer, /mob/living/treacherous_flesh) || istype(viewer, /mob/living/basic/flesh_biomorph) || viewer.mind?.has_antag_datum(/datum/antagonist/treacherous_flesh) || (isobserver(viewer) && (viewer.client?.holder || SSticker.current_state >= GAME_STATE_FINISHED))

/// Non-airborne incubation preserves the original six-stage growth and chemical cure.
/datum/disease/treacherous_flesh
	name = "Инкубация биоассимилятора"
	max_stages = 6
	spread_text = "Не заразный"
	spread_flags = DISEASE_SPREAD_NON_CONTAGIOUS
	disease_flags = CURABLE|CAN_CARRY
	cure_text = "Lazarus Reagent"
	cures = list(/datum/reagent/medicine/lazarus_reagent)
	cure_chance = 25
	agent = "Клетки коварной плоти"
	viable_mobtypes = list(/mob/living/carbon/human)
	severity = DISEASE_SEVERITY_BIOHAZARD
	form = "Infestation"
	bypasses_immunity = TRUE
	visibility_flags = HIDDEN_SCANNER|HIDDEN_PANDEMIC
	/// The source's discovery threshold is 80% of six stages, rounded up.
	var/discovered = FALSE

/datum/disease/treacherous_flesh/update_stage(new_stage)
	. = ..()
	if(stage >= 5 && !discovered)
		discovered = TRUE
		visibility_flags = NONE
		affected_mob?.med_hud_set_status()

/datum/disease/treacherous_flesh/stage_act(seconds_per_tick)
	if(!..() || stage != max_stages || !SPT_PROB(4, seconds_per_tick))
		return
	var/mob/living/carbon/human/host = affected_mob
	if(!istype(host) || host.stat == DEAD || !host.client || lazarus_host_infested(host))
		return
	var/obj/effect/mob_spawn/ghost_role/treacherous_flesh/egg = new(host, host)
	notify_ghosts("Зародыш коварной плоти появился внутри организма [host].", source = egg, click_interact = TRUE)
	cure()

/// An actual infectious reagent so existing food, medicine and fluid transfer paths work.
/datum/reagent/treacherous_flesh
	name = "Клетки коварной плоти"
	description = "Опасные клетки паразита, способные ассимилировать живого органического носителя."
	color = "#2c0d0d"
	taste_description = "flesh"

/datum/reagent/treacherous_flesh/expose_mob(mob/living/exposed_mob, methods = TOUCH, reac_volume, show_message = TRUE, touch_protection = 0)
	. = ..()
	if(!ishuman(exposed_mob) || exposed_mob.stat == DEAD || reac_volume <= 0 || !(exposed_mob.mob_biotypes & MOB_ORGANIC))
		return
	var/mob/living/carbon/human/host = exposed_mob
	if(lazarus_host_infested(host) || (locate(/datum/disease/treacherous_flesh) in host.diseases))
		return
	host.ForceContractDisease(new /datum/disease/treacherous_flesh, make_copy = FALSE, del_on_fail = TRUE)

/// Called by the native pickup signal after the carrier actually obtains an item.
/mob/living/treacherous_flesh/proc/contaminate_item(mob/living/carbon/human/source, obj/item/picked_up)
	SIGNAL_HANDLER
	if(!infecting || source != host || !(istype(picked_up, /obj/item/food) || istype(picked_up, /obj/item/reagent_containers)) || !picked_up.reagents)
		return
	var/datum/reagents/reagents = picked_up.reagents
	var/needed = 1 - reagents.get_reagent_amount(/datum/reagent/treacherous_flesh)
	if(needed <= 0)
		return
	var/space = reagents.maximum_volume - reagents.total_volume
	if(space < needed)
		reagents.remove_all(needed - space)
	reagents.add_reagent(/datum/reagent/treacherous_flesh, needed)

/// A successful real operation spreads infection to its patient, including limb operations.
/mob/living/treacherous_flesh/proc/contaminate_patient(mob/living/carbon/human/source, datum/surgery_operation/operation, atom/movable/operating_on, obj/item/tool)
	SIGNAL_HANDLER
	if(!infecting || source != host)
		return
	var/mob/living/carbon/human/patient = operating_on
	if(isbodypart(operating_on))
		var/obj/item/bodypart/limb = operating_on
		patient = limb.owner
	if(!istype(patient) || patient.stat == DEAD || !(patient.mob_biotypes & MOB_ORGANIC) || lazarus_host_infested(patient) || (locate(/datum/disease/treacherous_flesh) in patient.diseases))
		return
	patient.ForceContractDisease(new /datum/disease/treacherous_flesh, make_copy = FALSE, del_on_fail = TRUE)
