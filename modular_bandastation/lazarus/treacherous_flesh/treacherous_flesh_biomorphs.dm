// AI EDIT START - Adapt the Lazarus event to the native Primera APIs and regression harness
/** Flesh creatures use native basic-mob AI and keep their player through splitting. */
/mob/living/basic/flesh_biomorph
	name = "биоморф"
	icon = 'modular_bandastation/lazarus/icons/treacherous_flesh.dmi'
	faction = list("treacherous_flesh")
	mob_biotypes = MOB_ORGANIC
	status_flags = CANPUSH
	physiology = list(STAMINA = 0)
	initial_language_holder = /datum/language_holder/treacherous_flesh
	see_in_dark = 8
	attack_sound = 'sound/items/weapons/bite.ogg'
	attack_verb_continuous = "кусает"
	attack_verb_simple = "кусает"
	ai_controller = /datum/ai_controller/basic_controller/simple/simple_hostile_obstacles
	/// Healing per original two-second life cycle while on flesh.
	var/weeds_heal_amount = 5
	/// Child type created when the body dies without being gibbed.
	var/split_to
	/// Identifier retained by the player-controlled child when splitting.
	var/code_name

/mob/living/basic/flesh_biomorph/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NOFIRE, INNATE_TRAIT)
	GLOB.lazarus_biomorphs += src
	code_name = "[pick("Альфа", "Бета", "Гамма", "Сигма", "Дельта", "Омега")]-[rand(100, 999)]"
	name = "[initial(name)] ([code_name])"
	real_name = name

/mob/living/basic/flesh_biomorph/Destroy()
	GLOB.lazarus_biomorphs -= src
	return ..()

/mob/living/basic/flesh_biomorph/add_tts_component()
	AddComponent(/datum/component/tts_component, /datum/tts_seed/silero/anubarak)

/mob/living/basic/flesh_biomorph/Life(seconds_per_tick = SSMOBS_DT)
	. = ..()
	if(stat == DEAD || !((locate(/obj/structure/alien/weeds/meaty) in loc) || (locate(/obj/structure/alien/weeds/node/meaty) in loc)))
		return
	heal_damage_type(weeds_heal_amount * seconds_per_tick / 4, BRUTE)
	heal_damage_type(weeds_heal_amount * seconds_per_tick / 4, BURN)

/mob/living/basic/flesh_biomorph/death(gibbed)
	. = ..()
	if(!. || gibbed)
		return
	if(split_to)
		var/mob/living/basic/flesh_biomorph/child
		for(var/index in 1 to rand(2, 3))
			child = new split_to(get_turf(src))
		if(mind)
			child.code_name = code_name
			child.name = "[initial(child.name)] ([code_name])"
			child.real_name = child.name
			mind.transfer_to(child, force_key_move = TRUE)
	gib()

/mob/living/basic/flesh_biomorph/say(message, bubble_type, list/spans, sanitize = TRUE, datum/language/language, ignore_spam, forced, filterproof, message_range, datum/saymode/saymode, list/message_mods)
	if(get_selected_language() == /datum/language/treacherous_flesh)
		return lazarus_hivemind(src, message)
	return ..()

/mob/living/basic/flesh_biomorph/lesser/small
	name = "Маленький биоморф"
	desc = "Искривлённая конечность с извивающимися щупальцами."
	icon_state = "small"
	icon_living = "small"
	maxHealth = 20
	health = 20
	obj_damage = 10
	melee_damage_lower = 5
	melee_damage_upper = 5
	pass_flags = PASSTABLE|PASSGRILLE|PASSMOB
	density = FALSE
	mob_size = MOB_SIZE_TINY
	weeds_heal_amount = 3
	speed = 0.5

/mob/living/basic/flesh_biomorph/lesser/small/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_VENTCRAWLER_ALWAYS, INNATE_TRAIT)
	var/datum/action/cooldown/mob_cooldown/sneak/lazarus/hide = new(src)
	hide.Grant(src)

/mob/living/basic/flesh_biomorph/lesser/small/CanPassThrough(atom/blocker, movement_dir, blocker_opinion)
	. = ..()
	if(istype(blocker, /obj/structure/flora))
		return TRUE
	if(HAS_TRAIT(src, TRAIT_SNEAK) && istype(blocker, /obj/machinery/door/airlock))
		var/obj/machinery/door/airlock/airlock = blocker
		if(!airlock.locked)
			return TRUE

/** Hiding also changes draw order, allowing the smallest body to crawl under doors. */
/datum/action/cooldown/mob_cooldown/sneak/lazarus
	name = "Спрятаться"
	desc = "Скрыться под предметами и пролезать под незаболтированными шлюзами."

/datum/action/cooldown/mob_cooldown/sneak/lazarus/Activate(atom/target)
	. = ..()
	owner.layer = HAS_TRAIT(owner, TRAIT_SNEAK) ? ABOVE_OPEN_TURF_LAYER : initial(owner.layer)

/datum/action/cooldown/mob_cooldown/sneak/lazarus/Remove(mob/living/remove_from)
	if(remove_from)
		remove_from.layer = initial(remove_from.layer)
	return ..()

/mob/living/basic/flesh_biomorph/lesser/medium
	name = "Средний биоморф"
	desc = "Кусок плоти с множеством извивающихся щупалец."
	icon_state = "medium"
	icon_living = "medium"
	maxHealth = 50
	health = 50
	obj_damage = 30
	melee_damage_lower = 12
	melee_damage_upper = 12
	pass_flags = PASSTABLE
	density = FALSE
	mob_size = MOB_SIZE_SMALL
	split_to = /mob/living/basic/flesh_biomorph/lesser/small
	weeds_heal_amount = 5
	speed = 0.8

/mob/living/basic/flesh_biomorph/lesser/medium/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_VENTCRAWLER_ALWAYS, INNATE_TRAIT)
	GRANT_ACTION(/datum/action/cooldown/biomorph/plant_weeds)

/mob/living/basic/flesh_biomorph/lesser/medium/CanPassThrough(atom/blocker, movement_dir, blocker_opinion)
	. = ..()
	if(istype(blocker, /obj/structure/flora))
		return TRUE

/mob/living/basic/flesh_biomorph/lesser/large
	name = "Крупный биоморф"
	desc = "Гора живой плоти с множеством щупалец."
	icon_state = "large"
	icon_living = "large"
	maxHealth = 90
	health = 90
	obj_damage = 50
	melee_damage_lower = 22
	melee_damage_upper = 22
	mob_size = MOB_SIZE_HUMAN
	split_to = /mob/living/basic/flesh_biomorph/lesser/medium
	weeds_heal_amount = 8

/mob/living/basic/flesh_biomorph/lesser/large/Initialize(mapload)
	. = ..()
	GRANT_ACTION(/datum/action/cooldown/biomorph/plant_weeds)
	GRANT_ACTION(/datum/action/cooldown/biomorph/build_structure)

/** Player-driven construction uses native cooldowns and do_after ownership checks. */
/datum/action/cooldown/biomorph
	button_icon = 'modular_bandastation/lazarus/icons/lazarus_actions.dmi'
	background_icon = 'modular_bandastation/lazarus/icons/lazarus_actions.dmi'
	background_icon_state = "bg_flesh"
	check_flags = AB_CHECK_CONSCIOUS|AB_CHECK_OPEN_TURF

/datum/action/cooldown/biomorph/plant_weeds
	name = "Распространить плоть"
	desc = "Установить глазной отросток для распространения плоти и лечения."
	button_icon_state = "weednode"
	cooldown_time = 30 SECONDS

/datum/action/cooldown/biomorph/plant_weeds/Activate(atom/target)
	var/turf/location = get_turf(owner)
	if(!isopenturf(location) || isspaceturf(location) || (locate(/obj/structure/alien/weeds/node) in location))
		return FALSE
	StartCooldown()
	if(!do_after(owner, 2 SECONDS, target = location) || QDELETED(owner) || owner.loc != location || (locate(/obj/structure/alien/weeds/node) in location))
		ResetCooldown()
		return FALSE
	new /obj/structure/alien/weeds/node/meaty(location)
	StartCooldown()
	return TRUE

/datum/action/cooldown/biomorph/build_structure
	name = "Создать структуру"
	desc = "Вырастить стену или дверь из плоти."
	button_icon = 'modular_bandastation/lazarus/icons/meaty_wall.dmi'
	button_icon_state = "resin_wall-0"
	cooldown_time = 10 SECONDS

/** Grows the selected structure after rechecking the builder, location and native cooldown. */
/datum/action/cooldown/biomorph/build_structure/Activate(atom/target)
	var/mob/living/builder = owner
	var/turf/location = get_turf(builder)
	var/choice = tgui_input_list(builder, "Что вырастить?", name, list("Мясистая стена", "Мясистая дверь"))
	if(QDELETED(builder) || builder != owner || HAS_TRAIT(builder, TRAIT_INCAPACITATED) || !isturf(builder.loc) || builder.loc != location || !choice || !IsAvailable())
		return FALSE
	if(isspaceturf(location) || (locate(/obj/structure/alien/resin) in location) || (locate(/obj/structure/alien/resin/door/meaty) in location))
		return FALSE
	StartCooldown()
	if(!do_after(builder, 3 SECONDS, target = location) || QDELETED(builder) || builder != owner || builder.loc != location || (locate(/obj/structure/alien/resin) in location) || (locate(/obj/structure/alien/resin/door/meaty) in location))
		ResetCooldown()
		return FALSE
	switch(choice)
		if("Мясистая стена")
			new /obj/structure/alien/resin/wall/meaty(location)
		if("Мясистая дверь")
			new /obj/structure/alien/resin/door/meaty(location)
	StartCooldown()
	return TRUE
// AI EDIT END
