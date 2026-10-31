#define GRAVITY_PULL 0
#define GRAVITY_REPEL 1
#define GRAVITY_MAYHEM 2

/datum/xenoartifact_effect/gravity
	log_name = "Гравитация"
	/// Are we pulling? Repelling? Or is it anarchy mode?
	var/grav_type

/datum/xenoartifact_effect/gravity/New()
	. = ..()
	trigger = XENO_TRIGGER_TOUCH
	release_method = XENO_EFFECT_PULSE
	type_name = XENO_EFFECT_BLUESPACE
	grav_type = pick(GRAVITY_PULL, GRAVITY_REPEL, GRAVITY_MAYHEM)
	maximum_charges = rand(4,10)
	activation_pulse_cost = maximum_charges

/datum/xenoartifact_effect/gravity/do_effect_pulse(seconds_per_tick)
	. = ..()
	if(!.)
		return
	var/turf/curr_turf = get_turf(holder)
	switch(grav_type)
		if (GRAVITY_MAYHEM)
			for(var/atom/movable/to_throw in range(range, curr_turf))
				mayhem_throw(to_throw, 1)
		if (GRAVITY_REPEL)
			for(var/atom/movable/to_throw in range(range, curr_turf))
				repel(to_throw, curr_turf)
		if (GRAVITY_PULL)
			for(var/atom/movable/to_throw in range(range, curr_turf))
				grav_pull(to_throw, curr_turf)

/**
 * Throws stuff away
 *
 * Arguments:
 * * to_repel - what to throw
 * * our_turf - from which turf
 */
/datum/xenoartifact_effect/gravity/proc/repel(atom/to_repel, turf/our_turf)
	var/protection = get_xenoartifact_susceptibility(to_repel)
	if(ishuman(to_repel) && !get_xenoartifact_susceptibility(to_repel))
		return
	var/obj/test_anchored = to_repel
	if (istype(test_anchored))
		if(test_anchored.anchored)
			return
	var/turfs_to_step = 0
	turfs_to_step = round(protection * 16 / 2) // 8 turfs max range with no protection
	while(turfs_to_step > 0)
		step_away(to_repel, our_turf)
		turfs_to_step--

/**
 * Pulls stuff closer to the turf
 *
 * Arguments:
 * * to_pull - what to pull
 * * our_turf - to which turf
 */
/datum/xenoartifact_effect/gravity/proc/grav_pull(atom/to_pull, turf/our_turf)
	var/protection = get_xenoartifact_susceptibility(to_pull)
	if(ishuman(to_pull) && !get_xenoartifact_susceptibility(to_pull))
		return
	if (istype(to_pull, /obj))
		var/obj/test_anchored = to_pull
		if(test_anchored.anchored)
			return
	var/turfs_to_step = 0
	turfs_to_step = round(protection * 16 / 2) // 8 turfs max range with no protection
	while(turfs_to_step > 0)
		step_towards(to_pull, our_turf)
		turfs_to_step--

/**
 * Throws stuff randomly
 *
 * Arguments:
 * * to_throw - what to throw
 * * amplifier - amplifier to throw power
 */
/datum/xenoartifact_effect/gravity/proc/mayhem_throw(atom/to_throw, amplifier)
	var/protection = get_xenoartifact_susceptibility(to_throw)
	if(!protection)
		return
	var/obj/test_anchored = to_throw
	if (istype(test_anchored))
		if(test_anchored.anchored)
			return
	var/throw_power = maximum_charges * 2
	var/atom/movable/throw_atom = to_throw
	var/turf/target_turf = pick(orange(get_turf(holder), range * 2 * protection))
	if(!QDELETED(throw_atom))
		throw_atom.throw_at(target_turf, 10 * protection * amplifier, throw_power * protection * amplifier/2)

/datum/xenoartifact_effect/gravity/do_effect_destroy()
	var/turf/curr_turf = get_turf(holder)
	for(var/atom/movable/to_throw in range(range, curr_turf))
		mayhem_throw(to_throw, 2)

#undef GRAVITY_PULL
#undef GRAVITY_REPEL
#undef GRAVITY_MAYHEM
