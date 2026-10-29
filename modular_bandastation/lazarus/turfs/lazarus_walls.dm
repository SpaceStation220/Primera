#define SMOOTH_GROUP_LAZARUS_ICE_WALL S_TURF(221)

/// Glacial walls preserve the source's weldable, unmineable barrier.
/turf/closed/wall/lazarus_ice
	name = "ледяная стена"
	desc = "Стена из застывших во льду камней. Кирка против неё бесполезна, но сварочник может помочь."
	icon = 'modular_bandastation/lazarus/icons/ice_wall.dmi'
	icon_state = "ice_wall-0"
	base_icon_state = "ice_wall"
	sheet_type = null
	explosive_resistance = 3
	smoothing_groups = SMOOTH_GROUP_CLOSED_TURFS + SMOOTH_GROUP_LAZARUS_ICE_WALL
	canSmoothWith = SMOOTH_GROUP_LAZARUS_ICE_WALL
	baseturfs = /turf/open/misc/asteroid/lazarus/dirt

/turf/closed/indestructible/lazarus_ice
	name = "ледяная стена"
	desc = "Стена из застывших во льду камней. Эта выглядит очень крепко."
	icon = 'modular_bandastation/lazarus/icons/ice_wall.dmi'
	icon_state = "ice_wall-0"
	base_icon_state = "ice_wall"
	smoothing_flags = SMOOTH_BITMASK
	smoothing_groups = SMOOTH_GROUP_CLOSED_TURFS + SMOOTH_GROUP_LAZARUS_ICE_WALL
	canSmoothWith = SMOOTH_GROUP_LAZARUS_ICE_WALL
	baseturfs = /turf/open/misc/asteroid/lazarus/dirt

/turf/closed/mineral/random/lazarus
	turf_type = /turf/open/misc/asteroid/lazarus
	baseturfs = /turf/open/misc/asteroid/lazarus
	initial_gas_mix = OPENTURF_DEFAULT_ATMOS

/turf/open/chasm/lazarus
	icon = 'modular_bandastation/lazarus/icons/lazarus_chasms.dmi'
	light_range = 3
	light_power = 0.8
	light_color = "#A91515"
	initial_gas_mix = OPENTURF_DEFAULT_ATMOS
