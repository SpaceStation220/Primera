// AI EDIT START - Validate apartment keys across timed interactions
/// A physical key that only operates the apartment door assigned when it is created.
/obj/item/key/appartment
	name = "Ключ для квартиры"
	desc = "Квартирный ключ, которому не назначена дверь."
	/// The assigned door may be dismantled without retaining it through its keys.
	var/datum/weakref/linked_airlock

/obj/item/key/appartment/Initialize(mapload, obj/machinery/door/airlock/door)
	. = ..()
	if(!istype(door) || QDELETED(door))
		return
	linked_airlock = WEAKREF(door)
	name = "Ключ от [door.name]"
	desc = "Этим ключом можно поднимать и опускать болты двери [door.name]."

/obj/item/key/appartment/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	var/obj/machinery/door/airlock/airlock = linked_airlock?.resolve()
	if(interacting_with != airlock || !can_use_key(user, airlock))
		return ITEM_INTERACT_BLOCKING

	if(!do_after(user, 5 SECONDS, target = airlock))
		return ITEM_INTERACT_BLOCKING
	if(!can_use_key(user, airlock) || airlock.operating)
		return ITEM_INTERACT_BLOCKING
	if(airlock.locked)
		airlock.unbolt()
	else
		if(!airlock.density && !airlock.close())
			return ITEM_INTERACT_BLOCKING
		// Closing animates asynchronously, so ownership and reach must still hold afterwards.
		if(!can_use_key(user, airlock) || !airlock.density || airlock.operating)
			return ITEM_INTERACT_BLOCKING
		airlock.bolt()

	return ITEM_INTERACT_SUCCESS

/// Revalidate the same permission boundary before and after either yielding operation.
/obj/item/key/appartment/proc/can_use_key(mob/living/user, obj/machinery/door/airlock/door)
	if(QDELETED(src) || QDELETED(user) || QDELETED(door) || !iscarbon(user))
		return FALSE
	return linked_airlock?.resolve() == door && user.is_holding(src) && user.can_perform_action(door, NEED_DEXTERITY|FORBID_TELEKINESIS_REACH)
// AI EDIT END
