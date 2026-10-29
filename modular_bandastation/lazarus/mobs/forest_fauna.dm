/** Timid wildlife uses the native fleeing AI and keeps the original event's hunting yields. */
/mob/living/simple_animal/hostile/prey
	melee_damage_lower = 0
	melee_damage_upper = 0
	vision_range = 8
	retreat_distance = 12
	minimum_distance = 12
	minbodytemp = 0
	environment_smash = ENVIRONMENT_SMASH_NONE
	/// Whether the infested animal has already begun its irreversible transformation.
	var/biomorphing = FALSE
	/// Hidden infestation revealed when a human is targeted.
	var/infested = FALSE
	/// Delayed burst, cancelled if the carcass is destroyed or butchered first.
	var/biomorph_timer

/mob/living/simple_animal/hostile/prey/Destroy()
	if(biomorph_timer)
		deltimer(biomorph_timer)
		biomorph_timer = null
	return ..()

/mob/living/simple_animal/hostile/prey/CanPassThrough(atom/blocker, movement_dir, blocker_opinion)
	if(istype(blocker, /obj/structure/flora))
		return TRUE
	return ..()

/mob/living/simple_animal/hostile/prey/deer
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
	move_to_delay = 4
	maxHealth = 50
	health = 50
	mob_biotypes = MOB_ORGANIC | MOB_BEAST
	mob_size = MOB_SIZE_HUMAN

/mob/living/simple_animal/hostile/prey/bunny
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
	move_to_delay = 2
	maxHealth = 20
	health = 20
	density = FALSE
	pass_flags = PASSTABLE | PASSGRILLE | PASSMOB
	mob_biotypes = MOB_ORGANIC | MOB_BEAST
	mob_size = MOB_SIZE_TINY

/mob/living/simple_animal/hostile/prey/GiveTarget(new_target)
	. = ..()
	if(!infested || biomorphing || stat == DEAD || !ishuman(target))
		return
	var/mob/living/carbon/human/human = target
	if("treacherous_flesh" in human.faction)
		return
	start_biomorphing()

/** Begin one five-second burst; repeated AI targeting cannot schedule duplicates. */
/mob/living/simple_animal/hostile/prey/proc/start_biomorphing()
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
/mob/living/simple_animal/hostile/prey/proc/end_biomorphing()
	biomorph_timer = null
	var/turf/spawn_turf = get_turf(src)
	if(!biomorphing || !spawn_turf)
		return
	visible_message(span_danger("Туша разрывается на куски, и из неё появляется отвратительный ком плоти!"))
	playsound(src, 'modular_bandastation/lazarus/sound/biomorph_burst.ogg', 75, TRUE)
	new /mob/living/basic/flesh_biomorph/lesser/medium(spawn_turf)
	gib()

/mob/living/simple_animal/hostile/prey/deer/infested
	desc = "Крупный лесной олень. Пугливый, но безвредный. Поверхность его тела неестественно колышется."
	vision_range = 4
	infested = TRUE

/mob/living/simple_animal/hostile/prey/bunny/infested
	desc = "Жирный кролик в зимней шубке. Поверхность его тела неестественно колышется."
	vision_range = 4
	infested = TRUE
