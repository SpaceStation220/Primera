/// Порода с археологическим образцом вместо руды; не нарушает тип mineral_type.
/turf/closed/mineral/xenoarchaeology
	name = "порода с посторонним включением"
	desc = "В толще породы виднеется необычное включение. После добычи его можно исследовать археологическими инструментами."
	mineral_amt = 1
	scan_icon = 'modular_bandastation/xenoarchaeology/icons/base/ore_visuals.dmi'
	scan_state = "rock_strange"
	turf_type = /turf/open/misc/asteroid/basalt/lava_land_surface
	baseturfs = /turf/open/misc/asteroid/basalt/lava_land_surface
	initial_gas_mix = LAVALAND_DEFAULT_ATMOS
	defer_change = TRUE

/// Обычная жила не должна подменять включение и его метку сканера.
/turf/closed/mineral/xenoarchaeology/change_ore(ore_type, random)
	return

/turf/closed/mineral/xenoarchaeology/gets_drilled(mob/user, exp_multiplier = 0)
	if(mineral_amt > 0)
		mineral_amt = 0
		if(contains_artifact)
			new /obj/item/xenoarch/strange_rock/boulder(src)
		else
			new /obj/item/xenoarch/strange_rock(src)
	return ..()

/// Сидерит сохраняет свою текстуру, прочность и грунт после добычи.
/turf/closed/mineral/xenoarchaeology/red_rock
	icon = /turf/closed/mineral/random/volcanic/red_rock::icon
	icon_state = /turf/closed/mineral/random/volcanic/red_rock::icon_state
	color = /turf/closed/mineral/random/volcanic/red_rock::color
	turf_type = /turf/closed/mineral/random/volcanic/red_rock::turf_type
	baseturfs = /turf/closed/mineral/random/volcanic/red_rock::baseturfs
	tool_mine_speed = /turf/closed/mineral/random/volcanic/red_rock::tool_mine_speed
	hand_mine_speed = /turf/closed/mineral/random/volcanic/red_rock::hand_mine_speed

/// Сланец сохраняет свою текстуру, прочность и грунт после добычи.
/turf/closed/mineral/xenoarchaeology/shale
	icon = /turf/closed/mineral/random/volcanic/shale::icon
	icon_state = /turf/closed/mineral/random/volcanic/shale::icon_state
	color = /turf/closed/mineral/random/volcanic/shale::color
	turf_type = /turf/closed/mineral/random/volcanic/shale::turf_type
	baseturfs = /turf/closed/mineral/random/volcanic/shale::baseturfs
	tool_mine_speed = /turf/closed/mineral/random/volcanic/shale::tool_mine_speed
	hand_mine_speed = /turf/closed/mineral/random/volcanic/shale::hand_mine_speed

/// Образцы на поверхности ледяной луны сохраняют её атмосферу и снежный грунт.
/turf/closed/mineral/xenoarchaeology/ice
	icon = MAP_SWITCH('modular_bandastation/aesthetics/walls/icons/rocks/contrastless_rocks.dmi', 'modular_bandastation/aesthetics/walls/icons/rocks/mapping_rocks.dmi')
	icon_state = MAP_SWITCH("smoothrocks-0", "mountainrock")
	color = MAP_SWITCH(COLOR_WHITE, null)
	turf_type = /turf/open/misc/asteroid/snow/icemoon
	baseturfs = /turf/open/misc/asteroid/snow/icemoon
	initial_gas_mix = ICEMOON_DEFAULT_ATMOS
	weak_turf = TRUE

/// Подземный вариант оставляет лёд, а не поверхностный снег.
/turf/closed/mineral/xenoarchaeology/ice/underground
	icon = /turf/closed/mineral/snowmountain/cavern/icemoon::icon
	icon_state = /turf/closed/mineral/snowmountain/cavern/icemoon::icon_state
	color = /turf/closed/mineral/snowmountain/cavern/icemoon::color
	turf_type = /turf/open/misc/asteroid/snow/ice/icemoon
	baseturfs = /turf/open/misc/asteroid/snow/ice/icemoon
	weak_turf = FALSE
