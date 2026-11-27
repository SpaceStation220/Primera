/**
 * Fits the selected worn uniform state to the native-size Worme.
 * Indices map output pixels to source pixels in BYOND coordinates, starting at the bottom left.
 * The side views have a separate sleeve and trouser fit so the hem and feet keep their alignment.
 */
/proc/get_worme_uniform_icon(source_icon, state, skirt)
	if(!source_icon || isnull(state))
		return null

	var/static/list/fitted_states = list()
	var/cache_key = "[REF(source_icon)]-[state]-[skirt]"
	if(fitted_states[cache_key])
		return fitted_states[cache_key]
	if(!(state in icon_states(source_icon)))
		return null

	var/icon/source = icon(source_icon, state)
	if(source.Width() != ICON_SIZE_X || source.Height() != ICON_SIZE_Y)
		return null

	var/static/list/directions = list(SOUTH, NORTH, EAST, WEST)
	var/static/list/frontal_rows = list(-2, -1, 0, 1, 2, 3, 4, 6, 7, 9, 10, 11, 12, 13, 14, 15, 16, 17, 19, 20, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33)
	var/static/list/profile_rows = list(-2, -1, 0, 1, 2, 3, 4, 5, 7, 8, 9, 10, 12, 13, 14, 14, 15, 16, 18, 20, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33)
	var/static/list/frontal_columns = list(-1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 15, 16, 17, 19, 20, 21, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34)
	var/static/list/side_torso_columns = list(
		"[EAST]" = list(2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34),
		"[WEST]" = list(-1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 23, 24, 25, 26, 27, 28, 29, 30, 31),
	)
	var/static/list/side_shoulder_columns = list(
		"[EAST]" = list(2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 13, 14, 15, 16, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33),
		"[WEST]" = list(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 17, 18, 19, 20, 21, 23, 24, 25, 26, 27, 28, 29, 30, 31),
	)
	var/static/list/side_trouser_columns = list(
		"[EAST]" = list(2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34),
		"[WEST]" = list(-1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31),
	)

	var/icon/fitted = icon()
	for(var/direction in directions)
		var/side_view = direction & (EAST | WEST)
		var/icon/original_direction = icon(source_icon, state, direction)
		var/icon/vertical_fit = icon(original_direction)
		vertical_fit.DrawBox(null, 1, 1, ICON_SIZE_X, ICON_SIZE_Y)
		remap_uniform_strips(original_direction, vertical_fit, side_view ? profile_rows : frontal_rows, FALSE, 1, ICON_SIZE_X)

		var/icon/directional_fit = icon(original_direction)
		directional_fit.DrawBox(null, 1, 1, ICON_SIZE_X, ICON_SIZE_Y)
		if(side_view)
			var/list/torso_columns = side_torso_columns["[direction]"]
			remap_uniform_strips(vertical_fit, directional_fit, skirt ? torso_columns : side_trouser_columns["[direction]"], TRUE, 1, 11)
			remap_uniform_strips(vertical_fit, directional_fit, torso_columns, TRUE, 12, 13)
			remap_uniform_strips(vertical_fit, directional_fit, side_shoulder_columns["[direction]"], TRUE, 14, ICON_SIZE_Y)
		else
			remap_uniform_strips(vertical_fit, directional_fit, frontal_columns, TRUE, 1, ICON_SIZE_Y)
		fitted.Insert(directional_fit, state, direction)

	var/finished_icon = fcopy_rsc(fitted)
	fitted_states[cache_key] = finished_icon
	return finished_icon

/// Copy adjacent pixels as strips so every frame keeps its timing without a per-pixel DM loop.
/proc/remap_uniform_strips(icon/source, icon/destination, list/pixel_map, by_column, band_start, band_end)
	var/position = 1
	while(position <= length(pixel_map))
		var/source_start = pixel_map[position]
		var/span = 1
		while(position + span <= length(pixel_map) && pixel_map[position + span] == source_start + span)
			span++

		var/icon/strip = icon(source)
		var/source_end = source_start + span - 1
		if(by_column)
			strip.Crop(source_start, band_start, source_end, band_end)
			destination.Blend(strip, ICON_OVERLAY, position, band_start)
		else
			strip.Crop(band_start, source_start, band_end, source_end)
			destination.Blend(strip, ICON_OVERLAY, band_start, position)
		position += span
/// Fits a resolved uniform state to the native proportions of its wearer's chest.
/proc/get_lesser_form_uniform_icon(source_icon, state, skirt, limb_id)
	if(limb_id == SPECIES_WORME)
		return get_worme_uniform_icon(source_icon, state, skirt)

	// Landmarks run from the top and left of the sprite, starting at zero.
	var/static/list/fits = list(
		"wolpin" = list(
			"south" = list(10, 15, 17, 20, 23),
			"north" = list(9, 15, 17, 19, 23),
			"front" = list(8, 11, 15, 16, 19, 22),
			"side" = list(9, 12, 15, 18),
			"trousers" = list(12, 13, 16, 18),
		),
		"stok" = list(
			"south" = list(12, 16, 18, 20, 23),
			"front" = list(10, 12, 15, 16, 19, 20),
			"side" = list(11, 13, 16, 19),
			"trousers" = list(12, 14, 16, 18),
		),
		"neara" = list(
			"south" = list(12, 16, 18, 20, 23),
			"front" = list(10, 11, 15, 16, 19, 20),
			"side" = list(11, 13, 16, 19),
			"trousers" = list(12, 14, 16, 18),
		),
		"farwa" = list(
			"south" = list(12, 16, 18, 20, 23),
			"front" = list(10, 11, 15, 16, 19, 20),
			"side" = list(10, 12, 15, 18),
			"trousers" = list(11, 13, 15, 17),
		),
	)
	var/list/fit = fits[limb_id]
	if(!fit || !source_icon || isnull(state))
		return null

	var/static/list/fitted_states = list()
	var/cache_key = "[REF(source_icon)]-[state]-[skirt]-[limb_id]"
	if(fitted_states[cache_key])
		return fitted_states[cache_key]
	if(!(state in icon_states(source_icon)))
		return null

	var/icon/source = icon(source_icon, state)
	if(source.Width() != ICON_SIZE_X || source.Height() != ICON_SIZE_Y)
		return null

	// Collar, sleeve, waist, crotch, and hem. Side views use a narrower fit below the crotch.
	var/static/list/source_rows = list(10, 16, 20, 23, 28)
	var/static/list/source_front = list(7, 11, 15, 16, 20, 23)
	var/static/list/source_side = list(11, 13, 16, 19)
	var/static/list/source_trousers = list(12, 13, 15, 17)
	var/list/frontal_columns = map_lesser_uniform_axis(source_front, fit["front"], ICON_SIZE_X)
	var/list/east_columns = map_lesser_uniform_axis(source_side, fit["side"], ICON_SIZE_X)
	var/list/east_trousers = skirt ? east_columns : map_lesser_uniform_axis(source_trousers, fit["trousers"], ICON_SIZE_X)
	var/icon/fitted = icon()
	for(var/direction in GLOB.cardinals)
		var/list/anchors = fit[dir2text(direction)] || fit["south"]
		var/list/rows = mirror_lesser_uniform_axis(map_lesser_uniform_axis(source_rows, anchors, ICON_SIZE_Y))
		var/icon/original_direction = icon(source_icon, state, direction)
		var/icon/vertical_fit = icon(original_direction)
		vertical_fit.DrawBox(null, 1, 1, ICON_SIZE_X, ICON_SIZE_Y)
		remap_uniform_strips(original_direction, vertical_fit, rows, FALSE, 1, ICON_SIZE_X)

		var/icon/directional_fit = icon(original_direction)
		directional_fit.DrawBox(null, 1, 1, ICON_SIZE_X, ICON_SIZE_Y)
		if(direction & (EAST | WEST))
			var/list/torso_columns = direction == EAST ? east_columns : mirror_lesser_uniform_axis(east_columns)
			var/list/trouser_columns = direction == EAST ? east_trousers : mirror_lesser_uniform_axis(east_trousers)
			var/trouser_height = ICON_SIZE_Y - anchors[4]
			remap_uniform_strips(vertical_fit, directional_fit, trouser_columns, TRUE, 1, trouser_height)
			remap_uniform_strips(vertical_fit, directional_fit, torso_columns, TRUE, trouser_height + 1, ICON_SIZE_Y)
		else
			remap_uniform_strips(vertical_fit, directional_fit, frontal_columns, TRUE, 1, ICON_SIZE_Y)
		fitted.Insert(directional_fit, state, direction)

	var/finished_icon = fcopy_rsc(fitted)
	fitted_states[cache_key] = finished_icon
	return finished_icon

/// Interpolates the source pixel for each destination coordinate between the supplied landmarks.
/proc/map_lesser_uniform_axis(list/source, list/target, size)
	var/list/pixels = new(size)
	var/segment = 1
	for(var/destination in 0 to size - 1)
		while(segment < length(target) && destination >= target[segment + 1])
			segment++
		var/source_position = source[segment] + destination - target[segment]
		if(destination >= target[segment] && segment < length(target))
			var/fraction = (destination - target[segment]) / (target[segment + 1] - target[segment])
			source_position = source[segment] + fraction * (source[segment + 1] - source[segment])
		pixels[destination + 1] = round(source_position + 0.5) + 1
	return pixels

/// Reflects an axis map for a mirrored profile or to convert top-down rows to BYOND coordinates.
/proc/mirror_lesser_uniform_axis(list/pixels)
	var/size = length(pixels)
	var/list/mirrored = new(size)
	for(var/coordinate in 1 to size)
		mirrored[coordinate] = size + 1 - pixels[size + 1 - coordinate]
	return mirrored
