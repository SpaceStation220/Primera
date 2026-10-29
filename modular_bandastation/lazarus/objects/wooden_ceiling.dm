/** A one-use roof kit for an airtight player-built room in the Lazarus wilderness. */
/obj/item/lazarus_wooden_ceiling
	name = "деревянный потолок"
	icon_state = "ceiling"
	icon = 'modular_bandastation/lazarus/icons/wooden_ceiling.dmi'
	desc = "Стройматериалы для крыши, способной выдержать бурю. Хижина должна быть огорожена герметичными стенами и закрытой дверью."
	w_class = WEIGHT_CLASS_BULKY

/obj/item/lazarus_wooden_ceiling/attack_self(mob/living/user)
	if(user.incapacitated || !user.is_holding(src) || !istype(get_area(user), /area/lazarus/outdoors))
		return
	if(!find_roof_turfs(user))
		to_chat(user, span_warning("Крышу можно установить только над замкнутым помещением площадью до 300 клеток в лесу."))
		return
	balloon_alert(user, "строительство крыши...")
	if(!do_after(user, 8 SECONDS, target = user))
		return
	if(QDELETED(src) || QDELETED(user) || user.incapacitated || !user.is_holding(src))
		return
	var/list/turfs = find_roof_turfs(user)
	if(!length(turfs))
		return
	var/area/lazarus/shelter/shelter = new
	shelter.setup("Укрытие")
	var/list/affected_areas = list()
	set_turfs_to_area(turfs, shelter, affected_areas)
	shelter.reg_in_areas_in_z()
	if(shelter.static_lighting)
		shelter.create_area_lighting_objects()
	SEND_GLOBAL_SIGNAL(COMSIG_AREA_CREATED, shelter, affected_areas, user)
	for(var/area_name in affected_areas)
		var/area/old_area = affected_areas[area_name]
		for(var/obj/machinery/door/firedoor/firedoor as anything in old_area.firedoors)
			firedoor.CalculateAffectingAreas()
	user.log_message("built a wooden roof at [AREACOORD(user)]", LOG_GAME)
	to_chat(user, span_notice("Крыша готова. Теперь эта хижина защищает от метели."))
	qdel(src)

/** Restrict native room detection to this event's outdoor areas, including enclosing walls. */
/obj/item/lazarus_wooden_ceiling/proc/find_roof_turfs(mob/user)
	var/turf/origin = get_turf(user)
	if(!isopenturf(origin) || !istype(origin.loc, /area/lazarus/outdoors))
		return
	var/list/turfs = detect_room(origin, max_size = 600)
	if(!length(turfs) || length(turfs) > 300)
		return
	for(var/turf/room_turf as anything in turfs)
		if(!istype(room_turf.loc, /area/lazarus/outdoors))
			return
	return turfs
