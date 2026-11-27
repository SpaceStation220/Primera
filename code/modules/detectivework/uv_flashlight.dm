/// UV reaches floor items, held items and visible clothing. A carried lamp can also shine from a pocket.
/obj/item/proc/get_forensic_uv_turf(emitting = FALSE)
	if(isturf(loc))
		return loc
	var/mob/holder = loc
	if(!istype(holder) || !isturf(holder.loc))
		return null
	var/slot = holder.get_slot_by_item(src)
	if(slot == ITEM_SLOT_HANDS || (emitting && (slot & ITEM_SLOT_POCKETS)))
		return holder.loc
	if(slot && iscarbon(holder) && !HAS_TRAIT(src, TRAIT_NO_WORN_ICON))
		var/mob/living/carbon/wearer = holder
		if(src in wearer.get_visible_items())
			return holder.loc
	return null

/obj/item/flashlight/forensic_uv
	name = "forensic UV flashlight"
	desc = "A handheld ultraviolet lamp. Treat washed blood with fluorescein spray to reveal it under this light for a forensic scan."
	icon = 'icons/obj/devices/forensic_uv.dmi'
	icon_state = "uv"
	inhand_icon_state = "electronic"
	worn_icon_state = "electronic"
	light_system = OVERLAY_LIGHT
	light_range = 5
	light_color = LIGHT_COLOR_PURPLE
	/// Visible turf -> intensity. Each lamp owns its own registrations.
	var/list/turf/lit_turfs = list()
	/// A held lamp follows the movement of its holder.
	var/static/list/holder_connections = list(
		COMSIG_MOVABLE_MOVED = PROC_REF(refresh_field),
		COMSIG_CARBON_ITEM_COVERAGE_CHANGED = PROC_REF(refresh_field),
	)

/obj/item/flashlight/forensic_uv/Initialize(mapload)
	. = ..()
	RegisterSignal(src, COMSIG_ATOM_UPDATE_LIGHT_ON, PROC_REF(on_light_changed))
	if(light_on)
		on_light_changed()

/obj/item/flashlight/forensic_uv/Destroy()
	clear_field()
	return ..()

/obj/item/flashlight/forensic_uv/update_icon_state()
	. = ..()
	// The handheld electronics sprite is shared by both states of this lamp.
	inhand_icon_state = initial(inhand_icon_state)

/obj/item/flashlight/forensic_uv/proc/on_light_changed()
	SIGNAL_HANDLER
	if(!light_on)
		clear_field()
		return
	RegisterSignals(src, list(COMSIG_MOVABLE_MOVED, COMSIG_ITEM_POST_EQUIPPED, COMSIG_ITEM_POST_UNEQUIP), PROC_REF(refresh_field))
	AddElement(/datum/element/connect_loc, holder_connections)
	refresh_field()

/// Release movement and visibility subscriptions even if the lamp is destroyed while lit.
/obj/item/flashlight/forensic_uv/proc/clear_field()
	RemoveElement(/datum/element/connect_loc, holder_connections)
	UnregisterSignal(src, list(COMSIG_MOVABLE_MOVED, COMSIG_ITEM_POST_EQUIPPED, COMSIG_ITEM_POST_UNEQUIP))
	for(var/turf/tile as anything in lit_turfs)
		UnregisterSignal(tile, list(COMSIG_TURF_CHECK_UV, COMSIG_TURF_DIRECTIONAL_OPACITY_CHANGED))
		SEND_SIGNAL(tile, COMSIG_TURF_UV_CHANGED)
	lit_turfs.Cut()

/// Reconcile the line of sight on movement or an opacity change, including opening a stationary door.
/obj/item/flashlight/forensic_uv/proc/refresh_field()
	SIGNAL_HANDLER
	// Centre-to-edge alpha follows the circular light mask, with a faint trace on the fifth tile.
	var/static/list/radial_alpha = list(255, 245, 232, 118, 16, 4)
	var/turf/origin = get_forensic_uv_turf(emitting = TRUE)
	var/list/visible = list()
	if(origin && light_on)
		var/radius = length(radial_alpha) - 1
		for(var/turf/tile in dview(radius, origin))
			var/distance = get_dist_euclidean(origin, tile)
			if(distance > radius)
				continue
			var/ring = round(distance)
			var/inner_alpha = radial_alpha[ring + 1]
			var/outer_alpha = radial_alpha[min(ring + 2, length(radial_alpha))]
			visible[tile] = round(LERP(inner_alpha, outer_alpha, distance - ring))
	var/list/previous = lit_turfs
	lit_turfs = visible
	for(var/turf/tile as anything in previous - visible)
		UnregisterSignal(tile, list(COMSIG_TURF_CHECK_UV, COMSIG_TURF_DIRECTIONAL_OPACITY_CHANGED))
		SEND_SIGNAL(tile, COMSIG_TURF_UV_CHANGED)
	for(var/turf/tile, intensity in visible)
		if(!previous[tile])
			RegisterSignal(tile, COMSIG_TURF_DIRECTIONAL_OPACITY_CHANGED, PROC_REF(refresh_field))
			RegisterSignal(tile, COMSIG_TURF_CHECK_UV, PROC_REF(illuminate))
		if(previous[tile] != intensity)
			SEND_SIGNAL(tile, COMSIG_TURF_UV_CHANGED)

/obj/item/flashlight/forensic_uv/proc/illuminate(turf/source, list/intensities)
	SIGNAL_HANDLER
	intensities += lit_turfs[source]

/// Strength of the brightest forensic lamp reaching this turf.
/turf/proc/get_forensic_uv_intensity()
	var/list/intensities = list(0)
	SEND_SIGNAL(src, COMSIG_TURF_CHECK_UV, intensities)
	return max(intensities)

/// Visible light reduces fluorescence to one third of its dark-room contrast at full brightness.
/turf/proc/get_forensic_uv_alpha(intensity)
	var/ambient = 1
	if(lighting_object)
		ambient = get_static_lumcount()
		var/list/lights = collect_dynamic_lightsources()
		for(var/datum/component/overlay_lighting/light, contribution in lights)
			if(!istype(light.parent, /obj/item/flashlight/forensic_uv))
				ambient += contribution
	return round(intensity * (1 - 2 / 3 * CLAMP01(ambient)))
