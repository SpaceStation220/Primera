/// Only the copied prototype has unlimited power; native shuttle maps retain their settings.
/area/shuttle/stationtrauma_space
	name = "Корабль"
	requires_power = FALSE
	ambientsounds = list(null)
	ambient_buzz = null

/obj/machinery/power/apc/check_access_list(list/access_list)
	return ..() || has_ship_engineering_access(access_list, ACCESS_ENGINE_EQUIP)

/obj/machinery/airalarm/check_access_list(list/access_list)
	return ..() || has_ship_engineering_access(access_list, ACCESS_ATMOS_EQUIP)

/// Recognize ship engineers on standard equipment and preserve access configured for special equipment.
/obj/machinery/proc/has_ship_engineering_access(list/access_list, default_access)
	return length(access_list) && ((ACCESS_EXPEDITION_ENGINEER in access_list) || (ACCESS_ENGINEERING in access_list)) \
		&& istype(get_area(src), /area/shuttle/stationtrauma_space) \
		&& length(req_access) == 1 && req_access[1] == default_access && !length(req_one_access)

/** Mapped expedition area: Открытый космос. */
/area/space/stationtrauma_space_home
	name = "Открытый космос"

/** Mapped expedition area: stationtrauma space site. */
/area/stationtrauma_space_site
	requires_power = FALSE
	default_gravity = STANDARD_GRAVITY
	ambientsounds = list(null)

/** Mapped expedition area: Астероидное поле. */
/area/stationtrauma_space_site/asteroid
	name = "Астероидное поле"
	default_gravity = ZERO_GRAVITY
/** Mapped expedition area: Экспедиционная база. */
/area/stationtrauma_space_site/planet
	name = "Экспедиционная база"

/** Mapped expedition area: Дрейфующая грузовая платформа. */
/area/stationtrauma_space_site/cargo
	name = "Дрейфующая грузовая платформа"
	default_gravity = ZERO_GRAVITY

/** Powered interiors of the Epsilon Eridani trade outposts. */
/area/stationtrauma_trade_outpost
	name = "Торговый аванпост"
	default_gravity = STANDARD_GRAVITY

/area/stationtrauma_trade_outpost/industrial
	name = "Торговый узел концерна Sable"

/area/stationtrauma_trade_outpost/medical
	name = "Торговый узел «Зелёная Экспансия»"

/area/stationtrauma_trade_outpost/agricultural
	name = "Торговый узел Ol Corp"

/area/stationtrauma_trade_outpost/research
	name = "Торговый узел верфей Зувийена"

/area/stationtrauma_trade_outpost/security
	name = "Торговый узел WitherVit"

/area/stationtrauma_trade_outpost/service
	name = "Торговый узел Donk Co."

/area/stationtrauma_trade_outpost/corporate
	name = "Торговый узел NanoTrasen"

/area/stationtrauma_trade_outpost/interdyne
	name = "Торговый узел Interdyne Pharmaceutics"
