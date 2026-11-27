/**
 * Tracks directional pathing blocker presence on turfs so LinkBlockedWithAccess can skip empty source-turf scans.
 */
/datum/element/directional_path_blocker
	element_flags = ELEMENT_DETACH_ON_HOST_DESTROY

/datum/element/directional_path_blocker/Attach(datum/target)
	. = ..()
	if(!ismovable(target))
		return ELEMENT_INCOMPATIBLE
	RegisterSignal(target, COMSIG_MOVABLE_MOVED, PROC_REF(on_target_move))
	var/atom/movable/movable_target = target
	if(isturf(movable_target.loc))
		var/turf/turf_loc = movable_target.loc
		turf_loc.directional_blocker_count++

/datum/element/directional_path_blocker/Detach(datum/target)
	. = ..()
	UnregisterSignal(target, COMSIG_MOVABLE_MOVED)
	var/atom/movable/movable_target = target
	if(isturf(movable_target.loc))
		var/turf/turf_loc = movable_target.loc
		if(turf_loc.directional_blocker_count > 0)
			turf_loc.directional_blocker_count--

/// Updates directional blocker counts on the old and new turfs when the tracked atom moves.
/datum/element/directional_path_blocker/proc/on_target_move(atom/movable/source, atom/old_loc)
	SIGNAL_HANDLER
	if(isturf(old_loc))
		var/turf/old_turf = old_loc
		if(old_turf.directional_blocker_count > 0)
			old_turf.directional_blocker_count--
	if(isturf(source.loc))
		var/turf/new_turf = source.loc
		new_turf.directional_blocker_count++
