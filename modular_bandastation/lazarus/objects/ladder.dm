// AI EDIT START - Adapt the Lazarus event to the native Primera APIs and regression harness
GLOBAL_LIST_EMPTY(ladder_teleporters)

/** Links colony floors by the IDs embedded in the original event map. */
/obj/structure/ladder_teleporter
	name = "лестница"
	desc = "Лестница, ведущая куда-то..."
	icon = 'modular_bandastation/lazarus/icons/ladder.dmi'
	icon_state = "both"
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	anchored = TRUE
	density = TRUE
	/// ID of the destination ladder.
	var/target_id
	/// Mapper-assigned ID used by the other end.
	var/ladder_id

/obj/structure/ladder_teleporter/Initialize(mapload)
	. = ..()
	GLOB.ladder_teleporters += src

/obj/structure/ladder_teleporter/Destroy()
	GLOB.ladder_teleporters -= src
	return ..()

/obj/structure/ladder_teleporter/singularity_act()
	return

/obj/structure/ladder_teleporter/singularity_pull(atom/singularity, current_size)
	return

/** Resolve on use so that deleting a destination cannot leave a stale hard reference. */
/obj/structure/ladder_teleporter/proc/find_destination()
	if(isnull(target_id))
		return
	for(var/obj/structure/ladder_teleporter/ladder as anything in GLOB.ladder_teleporters)
		if(ladder != src && ladder.ladder_id == target_id && !QDELETED(ladder))
			return ladder

/obj/structure/ladder_teleporter/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(. || user.incapacitated || !user.Adjacent(src) || !isturf(user.loc) || user.buckled)
		return
	var/obj/structure/ladder_teleporter/destination = find_destination()
	if(!destination)
		balloon_alert(user, "никуда не ведёт!")
		return
	var/atom/movable/pulled = user.pulling
	user.visible_message(span_notice("[user] начинает спускаться по лестнице."), span_notice("Вы начинаете передвигаться по лестнице."))
	if(!do_after(user, 2 SECONDS, target = src, interaction_key = DOAFTER_SOURCE_CLIMBING_LADDER))
		return
	if(QDELETED(src) || QDELETED(user) || QDELETED(destination) || destination != find_destination() || user.incapacitated || !user.Adjacent(src) || !isturf(user.loc) || user.buckled || user.pulling != pulled)
		return
	var/turf/target_turf = get_turf(destination)
	if(isnull(target_turf))
		return
	user.zMove(target = target_turf, z_move_flags = ZMOVE_CHECK_PULLEDBY | ZMOVE_INCLUDE_PULLED)
	user.visible_message(span_notice("[user] заканчивает передвигаться по лестнице."), span_notice("Вы закончили передвигаться по лестнице."))

/obj/structure/ladder_teleporter/attack_ghost(mob/dead/observer/user)
	var/obj/structure/ladder_teleporter/destination = find_destination()
	if(destination)
		user.forceMove(get_turf(destination))
// AI EDIT END
