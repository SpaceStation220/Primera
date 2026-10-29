/** Replenishing scrapings used by the colony's Lazarus chemistry. */
/obj/effect/decal/cleanable/fungus
	name = "космический грибок"
	desc = "Грибковый нарост. Выглядит отвратительно."
	icon = /obj/effect/decal/cleanable/food/flour::icon
	icon_state = "flour"
	color = "#D5820B"
	is_mopped = FALSE
	/// Scraped colonies need time to regrow before another harvest.
	var/harvested = FALSE
	/// Cancel regrowth when the fungus is destroyed.
	var/regrowth_timer

/obj/effect/decal/cleanable/fungus/Initialize(mapload)
	. = ..()
	if(. == INITIALIZE_HINT_QDEL)
		return
	if(iswallturf(loc))
		SET_PLANE_IMPLICIT(src, GAME_PLANE)
		layer = CLEANABLE_OBJECT_LAYER
	create_reagents(10)
	reagents.add_reagent(/datum/reagent/fungus, 10)

/** The original colony intentionally grows fungus on both normal and reinforced walls. */
/obj/effect/decal/cleanable/fungus/NeverShouldHaveComeHere(turf/here_turf)
	return !iswallturf(here_turf) && ..()

/obj/effect/decal/cleanable/fungus/Destroy()
	if(regrowth_timer)
		deltimer(regrowth_timer)
		regrowth_timer = null
	return ..()

/obj/effect/decal/cleanable/fungus/examine(mob/user)
	. = ..()
	. += span_notice(harvested ? "После сбора наросту нужно время, чтобы восстановиться." : "Грибок можно соскрести в химический стакан.")

/obj/effect/decal/cleanable/fungus/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/reagent_containers/cup) || istype(tool, /obj/item/rag))
		return NONE
	if(harvested || user.incapacitated || !user.Adjacent(src) || !user.is_holding(tool) || !reagents.trans_to(tool, reagents.total_volume, transferred_by = user))
		return ITEM_INTERACT_BLOCKING
	harvested = TRUE
	alpha = 128
	regrowth_timer = addtimer(CALLBACK(src, PROC_REF(recreate)), rand(5 MINUTES, 10 MINUTES), TIMER_STOPPABLE)
	return ITEM_INTERACT_SUCCESS

/** Refill once after regrowth, preserving the existing holder and its capacity. */
/obj/effect/decal/cleanable/fungus/proc/recreate()
	if(!harvested)
		return
	if(regrowth_timer)
		deltimer(regrowth_timer)
		regrowth_timer = null
	reagents.clear_reagents()
	reagents.add_reagent(/datum/reagent/fungus, 10)
	harvested = FALSE
	alpha = 255

/obj/effect/spawner/random/fungus
	name = "fungus 100% chance"
	icon_state = "fungus"
	color = "#D5820B"
	loot = list(/obj/effect/decal/cleanable/fungus)

/obj/effect/spawner/random/fungus/maybe
	name = "fungus 15% chance"
	spawn_loot_chance = 15

/obj/effect/spawner/random/fungus/frequent
	name = "fungus 50% chance"
	spawn_loot_chance = 50

/obj/effect/spawner/random/fungus/probably
	name = "fungus 85% chance"
	spawn_loot_chance = 85

/** Raw fungus is a risky chemical ingredient rather than edible mushrooms. */
/datum/reagent/fungus
	name = "Space fungus"
	description = "Соскоб неизвестного грибка, растущего на стенах колонии."
	color = "#C87D28"
	taste_description = "плесень"

/datum/reagent/fungus/expose_mob(mob/living/exposed_mob, methods = TOUCH, reac_volume, show_message = TRUE, touch_protection = 0)
	. = ..()
	if(!(methods & INGEST))
		return
	var/outcome = rand(1, 10)
	if(outcome == 1)
		exposed_mob.reagents?.add_reagent(/datum/reagent/toxin, rand(1, 5))
	else if(outcome <= 5)
		exposed_mob.ForceContractDisease(new /datum/disease/food_poisoning)
	if(show_message)
		to_chat(exposed_mob, span_warning("Отвратительный вкус!"))

/** Non-contagious food poisoning; rest and chicken soup remain useful survival resources. */
/datum/disease/food_poisoning
	name = "Пищевое отравление"
	desc = "Тошнота, боль в животе и рвота."
	max_stages = 3
	stage_prob = 2.5
	spread_text = "Не заразно"
	spread_flags = DISEASE_SPREAD_SPECIAL
	cure_text = "Сон или куриный суп"
	agent = "Salmonella"
	cures = list(/datum/reagent/consumable/nutriment/soup/chicken_noodle_soup)
	cure_chance = 5
	viable_mobtypes = list(/mob/living/carbon/human)
	severity = DISEASE_SEVERITY_MINOR
	disease_flags = CURABLE
	required_organ = ORGAN_SLOT_STOMACH

/datum/disease/food_poisoning/stage_act(seconds_per_tick)
	. = ..()
	if(!.)
		return
	var/sleep_cure_chance = 16.5
	if(stage == 2)
		sleep_cure_chance = 29.9
	else if(stage == 3)
		sleep_cure_chance = 24.9
	if((affected_mob.IsSleeping() && SPT_PROB(sleep_cure_chance, seconds_per_tick)) || (stage >= 2 && SPT_PROB(0.05, seconds_per_tick)))
		to_chat(affected_mob, span_notice("Вам стало лучше."))
		cure()
		return FALSE
	if(SPT_PROB(2.5, seconds_per_tick))
		to_chat(affected_mob, span_warning("Вас тошнит, и живот неприятно ноет."))
	if(stage >= 2 && SPT_PROB(5, seconds_per_tick))
		affected_mob.emote("groan")
	if(stage == 3 && SPT_PROB(2.5, seconds_per_tick))
		if(affected_mob.nutrition > 10)
			affected_mob.vomit(lost_nutrition = rand(3, 5))
		else
			affected_mob.Stun(rand(4 SECONDS, 8 SECONDS))
			affected_mob.Knockdown(rand(4 SECONDS, 8 SECONDS))
