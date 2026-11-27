/// Keep all DNA in a mixed sample if at least one of its DNA-bearing types stains the surface.
/datum/forensics/proc/get_residue_dna(surface_flag)
	var/list/sample = list()
	var/has_stain = FALSE
	for(var/key, value in blood_DNA)
		var/datum/blood_type/blood = value
		if(!istype(blood))
			blood = get_blood_type(value)
		if(!(blood?.blood_flags & BLOOD_ADD_DNA))
			continue
		sample[key] = blood.name
		has_stain ||= (blood.blood_flags & surface_flag)
	return has_stain ? sample : null

/// Forensic record on the washed surface. Nothing here is exposed to blood transfer or consumption.
/datum/component/blood_residue
	dupe_mode = COMPONENT_DUPE_UNIQUE
	/// Partial profile -> distinct blood types consistent with that reading.
	var/list/samples
	/// Positions lost during washing stay the same for all deposits on this surface until sterilization.
	var/profile_mask = ""
	/// Whether fluorescein has been applied since this residue was deposited.
	var/treated = FALSE
	/// Latest shape per decal type on this tile, retaining footprint directions separately from pools.
	var/list/shapes = list()
	/// Actual overlays added to the parent during this exposure.
	var/list/displayed = list()
	/// Turf whose illumination changes we listen for; null inside containers.
	var/turf/exposed_turf
	/// Strength of the strongest UV source on the surface, before visible-light washout.
	var/uv_intensity = 0
	/// Alpha currently shown on the surface.
	var/glow_alpha = 0
	/// Pixel intersection cached for the item's current sprite, including directional and animated frames.
	var/icon/item_mask
	/// Icon and state used to build item_mask.
	var/mask_source_icon
	var/mask_source_state
	/// The equipped sprite depends on the hand, slot and body shape of the wearer.
	var/icon/equipped_mask
	var/equipped_source_icon
	var/equipped_source_state

/datum/component/blood_residue/Initialize()
	if(!isitem(parent) && !isturf(parent))
		return COMPONENT_INCOMPATIBLE

/datum/component/blood_residue/RegisterWithParent()
	RegisterSignal(parent, COMSIG_ATOM_EXPOSE_REAGENT, PROC_REF(on_reagent))
	RegisterSignal(parent, COMSIG_COMPONENT_CLEAN_ACT, PROC_REF(on_wash))
	RegisterSignal(parent, COMSIG_DETECTIVE_SCANNED, PROC_REF(on_scan))
	if(isitem(parent))
		RegisterSignals(parent, list(COMSIG_MOVABLE_MOVED, COMSIG_ITEM_POST_EQUIPPED, COMSIG_ITEM_POST_UNEQUIP), PROC_REF(on_move))
		RegisterSignal(parent, COMSIG_ATOM_UPDATED_ICON, PROC_REF(on_item_icon_updated))
		RegisterSignal(parent, COMSIG_ITEM_GET_SEPARATE_WORN_OVERLAYS, PROC_REF(on_equipped_overlays))
		var/static/list/holder_connections = list(
			COMSIG_MOVABLE_MOVED = PROC_REF(on_move),
			COMSIG_CARBON_ITEM_COVERAGE_CHANGED = PROC_REF(on_move),
			COMSIG_MOB_EQUIPPED_ITEM = PROC_REF(on_move),
			COMSIG_MOB_UNEQUIPPED_ITEM = PROC_REF(on_move),
		)
		AddComponent(/datum/component/connect_loc_behalf, parent, holder_connections)
	on_move()

/datum/component/blood_residue/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_ATOM_EXPOSE_REAGENT)
	UnregisterSignal(parent, list(COMSIG_COMPONENT_CLEAN_ACT, COMSIG_DETECTIVE_SCANNED, COMSIG_MOVABLE_MOVED, COMSIG_ITEM_POST_EQUIPPED, COMSIG_ITEM_POST_UNEQUIP, COMSIG_ATOM_UPDATED_ICON, COMSIG_ITEM_GET_SEPARATE_WORN_OVERLAYS))
	if(uv_intensity)
		STOP_PROCESSING(SSobj, src)
	if(exposed_turf)
		UnregisterSignal(exposed_turf, COMSIG_TURF_UV_CHANGED)
		exposed_turf = null
	hide()
	if(glow_alpha && isitem(parent))
		var/obj/item/item = parent
		item.update_slot_icon()
	return ..()

/// Merge freshly washed blood without retaining the original decal, reagents, or diseases.
/datum/component/blood_residue/proc/record(list/dna, shape_key, mutable_appearance/shape)
	for(var/profile, blood_type in dna)
		var/partial = partial_profile(profile)
		LAZYORASSOCLIST(samples, partial, blood_type)
	treated = FALSE
	if(shape)
		var/mutable_appearance/previous = shapes[shape_key]
		if(previous && ispath(shape_key, /obj/effect/decal/cleanable/blood/footprints))
			shape.overlays |= previous.overlays
		shapes[shape_key] = shape
	refresh_exposure(force = TRUE)

/// Keep one character from each pair. A single-character identifier cannot be partially disclosed.
/datum/component/blood_residue/proc/partial_profile(profile)
	var/profile_length = length_char(profile)
	if(profile_length < 2)
		return "?"
	while(length(profile_mask) < profile_length)
		profile_mask += pick("x?", "?x")
	var/partial = ""
	for(var/index in 1 to profile_length)
		partial += profile_mask[index] == "?" ? "?" : copytext_char(profile, index, index + 1)
	return partial

/datum/component/blood_residue/proc/on_reagent(datum/source, datum/reagent/reagent, volume, methods)
	SIGNAL_HANDLER
	if(!treated && istype(reagent, /datum/reagent/fluorescein) && volume > 0 && (methods & (TOUCH | VAPOR)))
		treated = TRUE
		refresh_exposure()

/datum/component/blood_residue/proc/on_move()
	SIGNAL_HANDLER
	var/turf/new_turf = parent
	if(isitem(parent))
		var/obj/item/item = parent
		new_turf = item.get_forensic_uv_turf()
	if(new_turf == exposed_turf)
		return
	if(exposed_turf)
		UnregisterSignal(exposed_turf, COMSIG_TURF_UV_CHANGED)
	exposed_turf = new_turf
	if(exposed_turf)
		RegisterSignal(exposed_turf, COMSIG_TURF_UV_CHANGED, PROC_REF(refresh_exposure))
	refresh_exposure(force = TRUE)

/datum/component/blood_residue/proc/refresh_exposure(datum/source, force = FALSE)
	SIGNAL_HANDLER
	var/strongest = 0
	if(treated && exposed_turf && length(samples))
		strongest = exposed_turf.get_forensic_uv_intensity()
	if(strongest && !uv_intensity)
		START_PROCESSING(SSobj, src)
	else if(!strongest && uv_intensity)
		STOP_PROCESSING(SSobj, src)
	uv_intensity = strongest
	update_glow(force)

/datum/component/blood_residue/proc/on_item_icon_updated(obj/item/source)
	SIGNAL_HANDLER
	if(uv_intensity && (source.icon != mask_source_icon || source.icon_state != mask_source_state))
		update_glow(force = TRUE)

/datum/component/blood_residue/process(seconds_per_tick)
	// Station lights and mobile lights can change independently of either the UV source or the evidence.
	update_glow()

/// Bright visible light leaves one third of the dark-room contrast. UV lamps do not wash out one another.
/datum/component/blood_residue/proc/update_glow(force = FALSE)
	var/new_alpha = 0
	if(uv_intensity)
		new_alpha = exposed_turf.get_forensic_uv_alpha(uv_intensity)
	var/obj/item/item = isitem(parent) ? parent : null
	var/sprite_changed = item && (item.icon != mask_source_icon || item.icon_state != mask_source_state)
	if(new_alpha == glow_alpha && !force && !sprite_changed)
		return
	hide()
	glow_alpha = new_alpha
	if(item && ismob(item.loc))
		item.update_slot_icon()
	if(!glow_alpha)
		return
	var/atom/surface = parent
	if(item)
		if(sprite_changed)
			mask_source_icon = item.icon
			mask_source_state = item.icon_state
			item_mask = make_mask(item.icon, item.icon_state)
		if(!item_mask)
			return
		displayed += stain_appearance(item_mask)
	else
		for(var/key in shapes)
			var/mutable_appearance/shape = shapes[key]
			shape.alpha = glow_alpha
			displayed += shape
	surface.add_overlay(displayed)

/datum/component/blood_residue/proc/on_equipped_overlays(obj/item/source, list/overlays, mutable_appearance/standing, mutable_appearance/draw_target)
	SIGNAL_HANDLER
	if(!glow_alpha)
		return
	if(draw_target.icon != equipped_source_icon || draw_target.icon_state != equipped_source_state)
		equipped_source_icon = draw_target.icon
		equipped_source_state = draw_target.icon_state
		equipped_mask = make_mask(draw_target.icon, draw_target.icon_state)
	if(equipped_mask)
		overlays += stain_appearance(equipped_mask)

/// Both visible colour and emission use the same silhouette.
/datum/component/blood_residue/proc/stain_appearance(icon/mask)
	var/mutable_appearance/stain = mutable_appearance(mask, "", appearance_flags = RESET_COLOR)
	stain.color = /datum/reagent/fluorescein::color
	stain.alpha = glow_alpha
	stain.overlays += emissive_appearance(mask, "", parent, effect_type = EMISSIVE_NO_BLOOM)
	return stain

/// Clip the blood pattern to the floor, in-hand or equipped sprite selected by the renderer.
/datum/component/blood_residue/proc/make_mask(sprite_icon, sprite_state)
	if(!sprite_icon)
		return null
	var/icon/mask = icon(sprite_icon, sprite_state)
	if(!mask.Width() || !mask.Height())
		return null
	// Preserve the alpha of every frame and direction, replacing the item's RGB with the blood pattern.
	mask.MapColors(0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,1, 1,1,1,0)
	var/icon/pattern = icon('icons/effects/blood.dmi', "itemblood")
	pattern.Scale(mask.Width(), mask.Height())
	mask.Blend(pattern, ICON_MULTIPLY)
	return mask

/// Remove exactly the overlays belonging to the residue, leaving fresh blood intact.
/datum/component/blood_residue/proc/hide()
	if(!length(displayed))
		return
	var/atom/surface = parent
	surface.cut_overlay(displayed)
	displayed.Cut()

/datum/component/blood_residue/proc/on_wash(datum/source, clean_types)
	SIGNAL_HANDLER
	if(clean_types & CLEAN_TYPE_BLOOD_RESIDUE)
		qdel(src)
		return COMPONENT_CLEANED

/datum/component/blood_residue/proc/on_scan(datum/source, mob/user, datum/detective_scanner_log/log_entry)
	SIGNAL_HANDLER
	if(!length(displayed))
		return
	var/list/readings = list()
	for(var/partial, types in samples)
		readings[partial] = jointext(types, " / ")
	log_entry.add_data_entry(DETSCAN_CATEGORY_BLOOD, readings)
