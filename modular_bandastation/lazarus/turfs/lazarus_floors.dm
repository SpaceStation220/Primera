#define SMOOTH_GROUP_LAZARUS_SNOW S_TURF(220)

/// Paradise's colored tiles use states absent from the native floor atlas.
/turf/open/floor/iron/lazarus
	icon = 'modular_bandastation/lazarus/icons/lazarus_floors.dmi'

/turf/open/floor/iron/lazarus/Initialize(mapload)
	base_icon_state = icon_state
	return ..()

/// Dirt beneath the colony. Cold exposure is handled by the area's Lazarus temperature.
/turf/open/misc/asteroid/lazarus
	name = "земля"
	desc = "Почва, почти полностью состоящая из песка. Используйте лопату для добычи песка."
	icon = 'modular_bandastation/lazarus/icons/lazarus_natural_floors.dmi'
	damaged_dmi = 'modular_bandastation/lazarus/icons/lazarus_natural_floors.dmi'
	icon_state = "dirt_0"
	base_icon_state = "dirt_0"
	baseturfs = /turf/open/misc/asteroid/lazarus
	turf_type = /turf/open/misc/asteroid/lazarus
	initial_gas_mix = OPENTURF_DEFAULT_ATMOS
	planetary_atmos = FALSE
	has_floor_variance = FALSE

/turf/open/misc/asteroid/lazarus/Initialize(mapload)
	. = ..()
	if(prob(floor_variance))
		icon_state = "dirt_[rand(1, 4)]"

/turf/open/misc/asteroid/lazarus/broken_states()
	return list("dirt_dug")

/turf/open/misc/asteroid/lazarus/dirt
	baseturfs = /turf/open/misc/asteroid/lazarus/dirt

/// Deep snow is shoveled away rather than dug for sand.
/turf/open/misc/asteroid/lazarus/snow
	name = "снег"
	desc = "Большой сугроб. Замедляет вас при передвижении. Используйте лопату для расчистки снега."
	icon = 'modular_bandastation/lazarus/icons/lazarus_snow.dmi'
	icon_state = "snow-0"
	base_icon_state = "snow"
	smoothing_flags = SMOOTH_BITMASK
	smoothing_groups = SMOOTH_GROUP_TURF_OPEN + SMOOTH_GROUP_LAZARUS_SNOW
	canSmoothWith = SMOOTH_GROUP_LAZARUS_SNOW
	layer = EDGED_TURF_LAYER
	footstep = "lazarus_snow"
	barefootstep = "lazarus_snow"
	clawfootstep = "lazarus_snow"
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	baseturfs = /turf/open/misc/asteroid/lazarus/dirt
	transform = TRANSLATE_MATRIX(-9, -9)
	slowdown = 1
	floor_variance = 0

/turf/open/misc/asteroid/lazarus/snow/getDug()
	ChangeTurf(/turf/open/misc/asteroid/lazarus/dirt, flags = CHANGETURF_INHERIT_AIR)
	return TRUE

/// The frozen lake retains normal breathable air; the event cold uses its own heat reserve.
/turf/open/misc/ice/lazarus
	baseturfs = /turf/open/misc/ice/lazarus
	initial_gas_mix = OPENTURF_DEFAULT_ATMOS
	planetary_atmos = FALSE
	temperature = T20C
	can_make_hole = FALSE
