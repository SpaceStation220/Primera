// AI EDIT START - Adapt the Lazarus event to native area and floor contracts
#define SMOOTH_GROUP_LAZARUS_SNOW S_TURF(220)

/** Paradise's colored tiles use states absent from the native floor atlas. */
/turf/open/floor/iron/lazarus
	icon = 'modular_bandastation/lazarus/icons/lazarus_floors.dmi'

/turf/open/floor/iron/lazarus/Initialize(mapload)
	base_icon_state = icon_state
	return ..()

/turf/open/floor/iron/lazarus/blue
	icon_state = "blue"
	base_icon_state = "blue"

/turf/open/floor/iron/lazarus/bluecorner
	icon_state = "bluecorner"
	base_icon_state = "bluecorner"

/turf/open/floor/iron/lazarus/bluefull
	icon_state = "bluefull"
	base_icon_state = "bluefull"

/turf/open/floor/iron/lazarus/bot
	icon_state = "bot"
	base_icon_state = "bot"

/turf/open/floor/iron/lazarus/brown
	icon_state = "brown"
	base_icon_state = "brown"

/turf/open/floor/iron/lazarus/browncorner
	icon_state = "browncorner"
	base_icon_state = "browncorner"

/turf/open/floor/iron/lazarus/brownfull
	icon_state = "brownfull"
	base_icon_state = "brownfull"

/turf/open/floor/iron/lazarus/cafeteria
	icon_state = "cafeteria"
	base_icon_state = "cafeteria"

/turf/open/floor/iron/lazarus/dark_diagonal
	icon_state = "dark_diagonal"
	base_icon_state = "dark_diagonal"

/turf/open/floor/iron/lazarus/dark_small
	icon_state = "dark_small"
	base_icon_state = "dark_small"

/turf/open/floor/iron/lazarus/darkblue
	icon_state = "darkblue"
	base_icon_state = "darkblue"

/turf/open/floor/iron/lazarus/darkbluecorners
	icon_state = "darkbluecorners"
	base_icon_state = "darkbluecorners"

/turf/open/floor/iron/lazarus/darkbluefull
	icon_state = "darkbluefull"
	base_icon_state = "darkbluefull"

/turf/open/floor/iron/lazarus/darkbrown
	icon_state = "darkbrown"
	base_icon_state = "darkbrown"

/turf/open/floor/iron/lazarus/darkbrowncorners
	icon_state = "darkbrowncorners"
	base_icon_state = "darkbrowncorners"

/turf/open/floor/iron/lazarus/darkfull
	icon_state = "darkfull"
	base_icon_state = "darkfull"

/turf/open/floor/iron/lazarus/darkgreen
	icon_state = "darkgreen"
	base_icon_state = "darkgreen"

/turf/open/floor/iron/lazarus/darkneutral
	icon_state = "darkneutral"
	base_icon_state = "darkneutral"

/turf/open/floor/iron/lazarus/darkneutralcorner
	icon_state = "darkneutralcorner"
	base_icon_state = "darkneutralcorner"

/turf/open/floor/iron/lazarus/darkpurple
	icon_state = "darkpurple"
	base_icon_state = "darkpurple"

/turf/open/floor/iron/lazarus/darkpurplecorners
	icon_state = "darkpurplecorners"
	base_icon_state = "darkpurplecorners"

/turf/open/floor/iron/lazarus/darkred
	icon_state = "darkred"
	base_icon_state = "darkred"

/turf/open/floor/iron/lazarus/darkredcorners
	icon_state = "darkredcorners"
	base_icon_state = "darkredcorners"

/turf/open/floor/iron/lazarus/darkyellow
	icon_state = "darkyellow"
	base_icon_state = "darkyellow"

/turf/open/floor/iron/lazarus/darkyellowcorners
	icon_state = "darkyellowcorners"
	base_icon_state = "darkyellowcorners"

/turf/open/floor/iron/lazarus/green
	icon_state = "green"
	base_icon_state = "green"

/turf/open/floor/iron/lazarus/greencorner
	icon_state = "greencorner"
	base_icon_state = "greencorner"

/turf/open/floor/iron/lazarus/greenfull
	icon_state = "greenfull"
	base_icon_state = "greenfull"

/turf/open/floor/iron/lazarus/navybluealt
	icon_state = "navybluealt"
	base_icon_state = "navybluealt"

/turf/open/floor/iron/lazarus/navybluecornersalt
	icon_state = "navybluecornersalt"
	base_icon_state = "navybluecornersalt"

/turf/open/floor/iron/lazarus/neutral
	icon_state = "neutral"
	base_icon_state = "neutral"

/turf/open/floor/iron/lazarus/neutralcorner
	icon_state = "neutralcorner"
	base_icon_state = "neutralcorner"

/turf/open/floor/iron/lazarus/neutralfull
	icon_state = "neutralfull"
	base_icon_state = "neutralfull"

/turf/open/floor/iron/lazarus/red
	icon_state = "red"
	base_icon_state = "red"

/turf/open/floor/iron/lazarus/redcorner
	icon_state = "redcorner"
	base_icon_state = "redcorner"

/turf/open/floor/iron/lazarus/redfull
	icon_state = "redfull"
	base_icon_state = "redfull"

/turf/open/floor/iron/lazarus/vault
	icon_state = "vault"
	base_icon_state = "vault"

/turf/open/floor/iron/lazarus/white
	icon_state = "white"
	base_icon_state = "white"

/turf/open/floor/iron/lazarus/whiteblue
	icon_state = "whiteblue"
	base_icon_state = "whiteblue"

/turf/open/floor/iron/lazarus/whitebluecorner
	icon_state = "whitebluecorner"
	base_icon_state = "whitebluecorner"

/turf/open/floor/iron/lazarus/whitebluefull
	icon_state = "whitebluefull"
	base_icon_state = "whitebluefull"

/turf/open/floor/iron/lazarus/whitegreen
	icon_state = "whitegreen"
	base_icon_state = "whitegreen"

/turf/open/floor/iron/lazarus/whitegreenfull
	icon_state = "whitegreenfull"
	base_icon_state = "whitegreenfull"

/turf/open/floor/iron/lazarus/whiteyellow
	icon_state = "whiteyellow"
	base_icon_state = "whiteyellow"

/turf/open/floor/iron/lazarus/whiteyellowcorner
	icon_state = "whiteyellowcorner"
	base_icon_state = "whiteyellowcorner"

/turf/open/floor/iron/lazarus/whiteyellowfull
	icon_state = "whiteyellowfull"
	base_icon_state = "whiteyellowfull"

/turf/open/floor/iron/lazarus/yellow
	icon_state = "yellow"
	base_icon_state = "yellow"

/turf/open/floor/iron/lazarus/yellowcorner
	icon_state = "yellowcorner"
	base_icon_state = "yellowcorner"

/turf/open/floor/iron/lazarus/yellowfull
	icon_state = "yellowfull"
	base_icon_state = "yellowfull"


/** Dirt beneath the colony. Cold exposure is handled by the area's Lazarus temperature. */
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

/turf/open/misc/asteroid/lazarus/dirt/dug
	icon_state = "dirt_dug"
	base_icon_state = "dirt_dug"

/** Deep snow is shoveled away rather than dug for sand. */
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

/** The frozen lake retains normal breathable air; the event cold uses its own heat reserve. */
/turf/open/misc/ice/lazarus
	baseturfs = /turf/open/misc/ice/lazarus
	initial_gas_mix = OPENTURF_DEFAULT_ATMOS
	planetary_atmos = FALSE
	temperature = T20C
	can_make_hole = FALSE
// AI EDIT END
