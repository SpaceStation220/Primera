/// Meat uses the native weed lifecycle and node ownership, with the donor's sprites.
/obj/structure/alien/weeds/meaty
	name = "мясистая плоть"
	desc = "Живой ковёр плоти постоянно шевелится, наращивая новые слои."
	icon = 'modular_bandastation/lazarus/icons/meaty_weeds.dmi'
	icon_state = "weeds-0"
	base_icon_state = "weeds"

/obj/structure/alien/weeds/meaty/set_base_icon()
	pixel_x = 0
	pixel_y = 0
	update_appearance(UPDATE_OVERLAYS)
	return

/obj/structure/alien/weeds/meaty/update_overlays()
	. = ..()
	. += lazarus_wallweed_overlays(src)

/// Native expansion creates its own base type, so override only that factory step.
/obj/structure/alien/weeds/meaty/try_expand()
	lazarus_expand_weeds(src)

/obj/structure/alien/weeds/node/meaty
	name = "глазной отросток"
	desc = "Множество белых глаз смотрят прямо на вас."
	icon = 'modular_bandastation/lazarus/icons/meaty_weeds.dmi'
	icon_state = "weednode"
	base_icon_state = "weednode"
	smoothing_flags = NONE
	light_color = "#A91515"
	light_power = 0.8
	lon_range = 3

/obj/structure/alien/weeds/node/meaty/set_base_icon()
	pixel_x = 0
	pixel_y = 0
	update_appearance(UPDATE_OVERLAYS)
	return

/obj/structure/alien/weeds/node/meaty/update_overlays()
	. = ..()
	. += lazarus_wallweed_overlays(src)

/obj/structure/alien/weeds/node/meaty/try_expand()
	lazarus_expand_weeds(src)

/// Shares expansion between ordinary weeds and nodes without touching unrelated aliens.
/proc/lazarus_expand_weeds(obj/structure/alien/weeds/source)
	var/turf/location = get_turf(source)
	if(!source.parent_node || !location || is_type_in_list(location, source.blacklisted_turfs))
		return
	source.update_appearance(UPDATE_OVERLAYS)
	for(var/turf/destination as anything in location.get_atmos_adjacent_turfs())
		if(get_dist(source.parent_node, destination) > source.parent_node.node_range || is_type_in_list(destination, source.blacklisted_turfs) || (locate(/obj/structure/alien/weeds) in destination))
			continue
		var/obj/structure/alien/weeds/meaty/child = new(destination)
		child.parent_node = source.parent_node
		child.RegisterSignal(source.parent_node, COMSIG_QDELETING, TYPE_PROC_REF(/obj/structure/alien/weeds, after_parent_destroyed))

/// The donor wall sprites face away from each wall and are offset onto its tile.
/proc/lazarus_wallweed_overlays(obj/structure/alien/weeds/source)
	. = list()
	for(var/direction in GLOB.alldirs)
		var/turf/wall = get_step(source, direction)
		if(!iswallturf(wall))
			continue
		var/mutable_appearance/overgrowth = mutable_appearance(source.icon, "wallweed-[turn(direction, 180)]", BELOW_MOB_LAYER)
		overgrowth.pixel_x = (wall.x - source.x) * ICON_SIZE_X
		overgrowth.pixel_y = (wall.y - source.y) * ICON_SIZE_Y
		SET_PLANE_EXPLICIT(overgrowth, GAME_PLANE, source)
		. += overgrowth

/obj/structure/alien/resin/wall/meaty
	name = "мясистая стена"
	desc = "Огромный ком плоти образует прочную стену."
	icon = 'modular_bandastation/lazarus/icons/meaty_wall.dmi'

/// Mineral doors already provide safe opening, atmospheric updates and auto-closing.
/obj/structure/alien/resin/door/meaty
	parent_type = /obj/structure/mineral_door
	name = "мясистая дверь"
	desc = "Отвратительная арка, заросшая живой плотью."
	icon = 'modular_bandastation/lazarus/icons/meaty_door.dmi'
	icon_state = "resin"
	obj_flags = parent_type::obj_flags | NO_DEBRIS_AFTER_DECONSTRUCTION
	close_delay = 3 SECONDS
	sheetAmount = 0
	openSound = 'sound/effects/blob/attackblob.ogg'
	closeSound = 'sound/effects/blob/attackblob.ogg'

/obj/structure/alien/resin/door/meaty/TryToSwitchState(atom/user)
	if(!ismob(user) || isSwitchingStates)
		return
	var/mob/visitor = user
	if(!("treacherous_flesh" in visitor.faction))
		return
	SwitchState()
