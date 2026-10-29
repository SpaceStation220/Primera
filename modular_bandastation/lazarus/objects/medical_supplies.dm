// AI EDIT START - Adapt the Lazarus event to the native Primera APIs and regression harness
/** Paradise's topical medicines, scoped to the event's supplies. */
/datum/reagent/medicine/lazarus_topical
	name = "Styptic Powder"
	description = "Кровоостанавливающий порошок для наружного применения. Вреден при проглатывании."
	color = "#FF9696"
	metabolization_rate = 1.5
	chemical_flags = REAGENT_CAN_BE_SYNTHESIZED | REAGENT_NO_RANDOM_RECIPE
	/// Brute damage healed per unit applied externally.
	var/heal_brute = 1
	/// Burn damage healed per unit applied externally.
	var/heal_burn = 0

/datum/reagent/medicine/lazarus_topical/expose_mob(mob/living/exposed_mob, methods = TOUCH, reac_volume, show_message = TRUE, touch_protection = 0)
	. = ..()
	if(!iscarbon(exposed_mob))
		return
	if(methods & (TOUCH | PATCH))
		exposed_mob.adjust_brute_loss(-reac_volume * heal_brute, required_bodytype = BODYTYPE_ORGANIC)
		exposed_mob.adjust_fire_loss(-reac_volume * heal_burn, required_bodytype = BODYTYPE_ORGANIC)
	if(methods & INGEST)
		exposed_mob.adjust_tox_loss(reac_volume * 0.5)

/datum/reagent/medicine/lazarus_topical/on_mob_life(mob/living/carbon/affected_mob, seconds_per_tick, metabolization_ratio)
	. = ..()
	if(volume > 1)
		var/healed = affected_mob.adjust_brute_loss(-heal_brute * seconds_per_tick * metabolization_ratio, FALSE, required_bodytype = BODYTYPE_ORGANIC)
		healed += affected_mob.adjust_fire_loss(-heal_burn * seconds_per_tick * metabolization_ratio, FALSE, required_bodytype = BODYTYPE_ORGANIC)
		if(healed)
			return UPDATE_MOB_HEALTH

/datum/reagent/medicine/lazarus_topical/silver_sulfadiazine
	name = "Silver Sulfadiazine"
	description = "Антибактериальное средство от ожогов для наружного применения."
	color = "#F0DC00"
	heal_brute = 0
	heal_burn = 1

/** Original ambient-temperature recipes keep the event's finite menders refillable. */
/datum/chemical_reaction/medicine/lazarus_styptic
	results = list(/datum/reagent/medicine/lazarus_topical = 4)
	required_reagents = list(/datum/reagent/aluminium = 1, /datum/reagent/hydrogen = 1, /datum/reagent/oxygen = 1, /datum/reagent/toxin/acid = 1)
	reaction_flags = REACTION_INSTANT

/datum/chemical_reaction/medicine/lazarus_silver_sulfadiazine
	results = list(/datum/reagent/medicine/lazarus_topical/silver_sulfadiazine = 5)
	required_reagents = list(/datum/reagent/ammonia = 1, /datum/reagent/silver = 1, /datum/reagent/sulfur = 1, /datum/reagent/oxygen = 1, /datum/reagent/chlorine = 1)
	reaction_flags = REACTION_INSTANT | REACTION_COMPETITIVE

/datum/chemical_reaction/medicine/lazarus_styptic/pre_reaction_other_checks(datum/reagents/holder)
	return istype(get_area(holder.my_atom), /area/lazarus) && ..()

/datum/chemical_reaction/medicine/lazarus_silver_sulfadiazine/pre_reaction_other_checks(datum/reagents/holder)
	return istype(get_area(holder.my_atom), /area/lazarus) && ..()

/datum/chemical_reaction/medicine/lenturi/pre_reaction_other_checks(datum/reagents/holder)
	return !istype(get_area(holder.my_atom), /area/lazarus) && ..()

/** Refillable auto-mender using native medigel containers and reagent transfer. */
/obj/item/reagent_containers/medigel/lazarus
	name = "автоматический перевязчик"
	desc = "Прибор для непрерывного нанесения лечебного состава на открытые раны. Alt+ЛКМ опустошает резервуар."
	volume = 200
	amount_per_transfer_from_this = 8
	has_variable_transfer_amount = FALSE
	/// Only one treatment may run per mender at a time.
	var/applying = FALSE
	/// Holder-change signals recur while a harmful reagent is removed.
	var/purging = FALSE

/obj/item/reagent_containers/medigel/lazarus/on_reagent_change(datum/reagents/holder, ...)
	if(!purging && !(obj_flags & EMAGGED))
		purging = TRUE
		for(var/datum/reagent/contained as anything in reagents.reagent_list.Copy())
			if(!istype(contained, /datum/reagent/medicine/lazarus_topical) && !istype(contained, /datum/reagent/medicine/c2/synthflesh))
				reagents.del_reagent(contained.type)
		purging = FALSE
	return ..()

/obj/item/reagent_containers/medigel/lazarus/emag_act(mob/user)
	if(obj_flags & EMAGGED)
		return FALSE
	obj_flags |= EMAGGED
	to_chat(user, span_warning("Вы отключили защиту перевязчика от вредных реагентов."))
	return TRUE

/obj/item/reagent_containers/medigel/lazarus/attack_self(mob/living/user)
	return interact_with_atom(user, user)

/obj/item/reagent_containers/medigel/lazarus/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!iscarbon(interacting_with))
		return NONE
	var/mob/living/carbon/patient = interacting_with
	if(applying || !reagents?.total_volume || user.incapacitated || !user.is_holding(src) || !user.Adjacent(patient))
		return ITEM_INTERACT_BLOCKING
	applying = TRUE
	user.visible_message(span_notice("[user] начинает обрабатывать [patient] перевязчиком."))
	while(reagents.total_volume && do_after(user, 1 SECONDS, patient))
		if(QDELETED(src) || QDELETED(user) || QDELETED(patient) || user.incapacitated || !user.is_holding(src) || !user.Adjacent(patient) || !patient.reagents || !reagents?.total_volume)
			break
		if(!(obj_flags & EMAGGED) && !patient.can_inject(user))
			break
		var/previous_health = patient.health
		var/amount = min(8, reagents.total_volume)
		log_combat(user, patient, "auto-mended", src, reagents.get_reagent_log_string())
		reagents.expose(patient, PATCH, amount / reagents.total_volume)
		reagents.trans_to(patient, amount * 0.5, transferred_by = user, methods = INJECT)
		reagents.remove_all(amount * 0.5)
		playsound(src, 'sound/effects/spray.ogg', 30, TRUE)
		if(patient.health == previous_health)
			break
	if(!QDELETED(src))
		applying = FALSE
	return ITEM_INTERACT_SUCCESS

/obj/item/reagent_containers/medigel/lazarus/click_alt(mob/living/user)
	if(user.incapacitated || !user.is_holding(src))
		return NONE
	if(tgui_alert(user, "Опустошить перевязчик?", name, list("Да", "Нет")) != "Да")
		return CLICK_ACTION_SUCCESS
	if(QDELETED(src) || QDELETED(user) || user.incapacitated || !user.is_holding(src))
		return CLICK_ACTION_SUCCESS
	reagents.expose(get_turf(user), TOUCH)
	reagents.clear_reagents()
	return CLICK_ACTION_SUCCESS

/obj/item/reagent_containers/medigel/lazarus/brute
	name = "травматологический перевязчик"
	icon_state = "brutegel"
	list_reagents = list(/datum/reagent/medicine/lazarus_topical = 200)

/obj/item/reagent_containers/medigel/lazarus/burn
	name = "противоожоговый перевязчик"
	icon_state = "burngel"
	list_reagents = list(/datum/reagent/medicine/lazarus_topical/silver_sulfadiazine = 200)

/obj/item/reagent_containers/cup/bottle/lazarus_oculine
	name = "флакон окулина"
	list_reagents = list(/datum/reagent/medicine/oculine = 30)

/obj/item/reagent_containers/cup/bottle/lazarus_reagent
	name = "флакон реагента «Лазарь»"
	list_reagents = list(/datum/reagent/medicine/lazarus_reagent = 30)

/obj/item/reagent_containers/cup/bowl/soup/lazarus_chicken
	name = "куриный суп"
	list_reagents = list(/datum/reagent/consumable/nutriment/soup/chicken_noodle_soup = 30)

/obj/item/reagent_containers/cup/soda_cans/lazarus_kvass
	name = "квас"
	list_reagents = list(/datum/reagent/consumable/kvass = 30)

/** A portable IPC kit retains the donor's welder and three cable coils. */
/obj/item/storage/medkit/lazarus_machine
	name = "набор для ремонта КПБ"
	desc = "Набор инструментов для экстренного ремонта синтетических колонистов."

/obj/item/storage/medkit/lazarus_machine/PopulateContents()
	new /obj/item/weldingtool/mini(src)
	for(var/i in 1 to 3)
		new /obj/item/stack/cable_coil(src)
	new /obj/item/healthanalyzer(src)

/** The original wilderness herbs can be mashed immediately, without a working kitchen. */
/obj/item/seeds/comfrey
	name = "семена окопника"
	spawn_blacklisted = TRUE
	species = "cabbage"
	plantname = "Окопник"
	product = /obj/item/food/grown/comfrey
	icon_state = "seed-cabbage"
	yield = 2
	maturation = 3
	growthstages = 1
	growing_icon = 'icons/obj/service/hydroponics/growing_vegetables.dmi'
	reagents_add = list(/datum/reagent/medicine/lazarus_topical = 0.1)

/obj/item/food/grown/comfrey
	seed = /obj/item/seeds/comfrey
	name = "лист окопника"
	desc = "Разомните в руке, чтобы получить лечебную припарку от ушибов."
	icon = 'modular_bandastation/lazarus/icons/harvest.dmi'
	icon_state = "tea_astra_leaves"
	color = "#378C61"
	bite_consumption_mod = 2
	tastes = list("окопник" = 1)

/obj/item/food/grown/comfrey/attack_self(mob/living/user)
	if(user.incapacitated || !user.is_holding(src))
		return
	var/obj/item/stack/medical/bruise_pack/lazarus_poultice/poultice = new(get_turf(user))
	poultice.heal_brute = seed.potency
	qdel(src)
	user.put_in_hands(poultice)

/obj/item/stack/medical/bruise_pack/lazarus_poultice
	name = "припарка из окопника"
	amount = 1
	max_amount = 1
	merge_type = /obj/item/stack/medical/bruise_pack/lazarus_poultice

/obj/item/seeds/aloe/lazarus
	product = /obj/item/food/grown/aloe/lazarus
	spawn_blacklisted = TRUE
	yield = 2
	reagents_add = list(/datum/reagent/medicine/lazarus_topical/silver_sulfadiazine = 0.1)

/obj/item/food/grown/aloe/lazarus
	seed = /obj/item/seeds/aloe/lazarus
	desc = "Разомните в руке, чтобы получить лечебную припарку от ожогов."
	icon = 'modular_bandastation/lazarus/icons/harvest.dmi'
	icon_state = "ambrosiavulgaris"
	color = "#4CC5C7"

/obj/item/food/grown/aloe/lazarus/attack_self(mob/living/user)
	if(user.incapacitated || !user.is_holding(src))
		return
	var/obj/item/stack/medical/ointment/lazarus_poultice/poultice = new(get_turf(user))
	poultice.heal_burn = seed.potency
	qdel(src)
	user.put_in_hands(poultice)

/obj/item/stack/medical/ointment/lazarus_poultice
	name = "припарка из алоэ"
	amount = 1
	max_amount = 1
	merge_type = /obj/item/stack/medical/ointment/lazarus_poultice
// AI EDIT END
