// AI EDIT START - Adapt the Lazarus event to the native Primera APIs and regression harness
/** Timid wildlife uses the native fleeing AI and keeps the original event's hunting yields. */
/mob/living/basic/lazarus_prey
	abstract_type = /mob/living/basic/lazarus_prey
	melee_damage_lower = 0
	melee_damage_upper = 0
	minimum_survivable_temperature = 0
	faction = list("lazarus_wildlife")
	ai_controller = /datum/ai_controller/basic_controller/simple/simple_fearful
	/// Detection range passed to the native target finder.
	var/threat_range = 8
	/// Native movement-loop delay; rabbits move twice as quickly as deer.
	var/flee_delay = 0.4 SECONDS
	/// Whether the infested animal has already begun its irreversible transformation.
	var/biomorphing = FALSE
	/// Hidden infestation revealed when a human is targeted.
	var/infested = FALSE
	/// Delayed burst, cancelled if the carcass is destroyed or butchered first.
	var/biomorph_timer

/mob/living/basic/lazarus_prey/Initialize(mapload)
	. = ..()
	ai_controller.set_blackboard_key(BB_TARGETING_STRATEGY, /datum/targeting_strategy/basic/lazarus_prey)
	ai_controller.set_blackboard_key(BB_VISION_RANGE, threat_range)
	ai_controller.set_blackboard_key(BB_BASIC_MOB_FLEE_DISTANCE, 12)
	ai_controller.movement_delay = flee_delay
	RegisterSignal(src, COMSIG_AI_BLACKBOARD_KEY_SET(BB_CURRENT_TARGET), PROC_REF(on_threat_acquired))

/** Target selection limited to the colony wildlife's original detection radius. */
/datum/targeting_strategy/basic/lazarus_prey

/** The shared fearful tree scans nine tiles; colony wildlife has shorter detection ranges. */
/datum/targeting_strategy/basic/lazarus_prey/is_valid_target(mob/living/living_mob, atom/the_target, vision_range, datum/ai_controller/controller = null)
	var/detection_range = living_mob.ai_controller?.blackboard[BB_VISION_RANGE]
	if(!isnum(detection_range))
		return FALSE
	return ..(living_mob, the_target, min(vision_range || detection_range, detection_range), controller)

/mob/living/basic/lazarus_prey/Destroy()
	if(biomorph_timer)
		deltimer(biomorph_timer)
		biomorph_timer = null
	return ..()

/mob/living/basic/lazarus_prey/CanPassThrough(atom/blocker, movement_dir, blocker_opinion)
	. = ..()
	if(istype(blocker, /obj/structure/flora))
		return TRUE

/mob/living/basic/lazarus_prey/deer
	name = "лесной олень"
	desc = "Крупный лесной олень. Пугливый, но безвредный."
	icon = 'modular_bandastation/lazarus/icons/winter_mob.dmi'
	icon_state = "reindeer"
	icon_living = "reindeer"
	icon_dead = "reindeer-dead"
	butcher_results = list(/obj/item/food/meat/slab = 12, /obj/item/stack/sheet/leather = 10)
	response_help_continuous = "pets"
	response_help_simple = "pet"
	response_disarm_continuous = "gently pushes aside"
	response_disarm_simple = "gently push aside"
	response_harm_continuous = "kicks"
	response_harm_simple = "kick"
	maxHealth = 50
	health = 50
	mob_biotypes = MOB_ORGANIC | MOB_BEAST
	mob_size = MOB_SIZE_HUMAN

/mob/living/basic/lazarus_prey/bunny
	name = "кролик"
	desc = "Жирный кролик в зимней шубке. Самое то для перекуса, правда, догнать тяжело..."
	icon = 'modular_bandastation/lazarus/icons/animal.dmi'
	icon_state = "m_bunny"
	icon_living = "m_bunny"
	icon_dead = "bunny_dead"
	butcher_results = list(/obj/item/food/meat/slab = 5, /obj/item/stack/sheet/leather = 3)
	response_help_continuous = "pets"
	response_help_simple = "pet"
	response_disarm_continuous = "gently pushes aside"
	response_disarm_simple = "gently push aside"
	response_harm_continuous = "kicks"
	response_harm_simple = "kick"
	flee_delay = 0.2 SECONDS
	maxHealth = 20
	health = 20
	density = FALSE
	pass_flags = PASSTABLE | PASSGRILLE | PASSMOB
	mob_biotypes = MOB_ORGANIC | MOB_BEAST
	mob_size = MOB_SIZE_TINY

/mob/living/basic/lazarus_prey/proc/on_threat_acquired(datum/source, key)
	SIGNAL_HANDLER
	var/atom/threat = ai_controller.blackboard[key]
	if(!infested || biomorphing || stat == DEAD || !ishuman(threat))
		return
	var/mob/living/carbon/human/human = threat
	if(human.has_faction("treacherous_flesh"))
		return
	INVOKE_ASYNC(src, PROC_REF(start_biomorphing))

/** Begin one five-second burst; repeated AI targeting cannot schedule duplicates. */
/mob/living/basic/lazarus_prey/proc/start_biomorphing()
	if(biomorphing || stat == DEAD)
		return
	biomorphing = TRUE
	visible_message(span_danger("[src] падает замертво и начинает неестественно расширяться! О БОЖЕ!"))
	death(FALSE)
	do_jitter_animation(1000)
	playsound(src, 'sound/effects/wounds/crack1.ogg', 75, TRUE)
	playsound(src, 'sound/machines/steam_hiss.ogg', 75, TRUE)
	biomorph_timer = addtimer(CALLBACK(src, PROC_REF(end_biomorphing)), 5 SECONDS, TIMER_STOPPABLE)
	var/matrix/expanded = matrix(transform)
	expanded.Scale(1.8, 1.2)
	animate(src, time = 5 SECONDS, transform = expanded, easing = SINE_EASING)

/** Spawn before gibbing: native gib() deletes its source and may clear its location. */
/mob/living/basic/lazarus_prey/proc/end_biomorphing()
	biomorph_timer = null
	var/turf/spawn_turf = get_turf(src)
	if(!biomorphing || !spawn_turf)
		return
	visible_message(span_danger("Туша разрывается на куски, и из неё появляется отвратительный ком плоти!"))
	playsound(src, 'modular_bandastation/lazarus/sound/biomorph_burst.ogg', 75, TRUE)
	new /mob/living/basic/flesh_biomorph/lesser/medium(spawn_turf)
	gib()

/mob/living/basic/lazarus_prey/deer/infested
	desc = "Крупный лесной олень. Пугливый, но безвредный. Поверхность его тела неестественно колышется."
	threat_range = 4
	infested = TRUE

/mob/living/basic/lazarus_prey/bunny/infested
	desc = "Жирный кролик в зимней шубке. Поверхность его тела неестественно колышется."
	threat_range = 4
	infested = TRUE
// AI EDIT END
