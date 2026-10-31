/// Радар создаёт персональный участок раскопок на природном грунте добывающего сектора.
/obj/item/xenoarch/radar
	name = "archaeological radar"
	desc = "Радар осадочных слоёв. Alt-клик ищет новый участок; активация в руке показывает направление; применение к грунту извлекает образцы."
	icon_state = "recoverer"
	slot_flags = ITEM_SLOT_BELT
	custom_materials = list(/datum/material/iron = HALF_SHEET_MATERIAL_AMOUNT, /datum/material/glass = HALF_SHEET_MATERIAL_AMOUNT)
	/// Ограниченное число случайных проб исключает обход всей карты.
	var/search_attempts = 50
	/// Одно действие на радар; общий профиль дополнительно проверяется после ожидания.
	var/busy = FALSE
	COOLDOWN_DECLARE(scan_cooldown)

/// Только естественные проходимые участки; ни базы руин, ни лава, ни пропасти не подходят.
/obj/item/xenoarch/radar/proc/valid_ground(turf/ground)
	if(!isopenturf(ground) || ground.density || !is_mining_level(ground.z))
		return FALSE
	if(!istype(get_area(ground), /area/lavaland) && !istype(get_area(ground), /area/icemoon))
		return FALSE
	return istype(ground, /turf/open/misc/asteroid)

/obj/item/xenoarch/radar/proc/can_scan(mob/living/user)
	return !QDELETED(src) && !QDELETED(user) && user.mind && user.is_holding(src) && user.can_perform_action(src, NEED_DEXTERITY|NEED_HANDS) && valid_ground(get_turf(user))

/obj/item/xenoarch/radar/click_alt(mob/living/user)
	find_site(user)
	return CLICK_ACTION_SUCCESS

/// В отличие от исходника, профиль не хранит ссылку на turf и не переживает mind.
/obj/item/xenoarch/radar/proc/find_site(mob/living/user)
	if(busy || !COOLDOWN_FINISHED(src, scan_cooldown) || !can_scan(user))
		return FALSE
	busy = TRUE
	var/datum/mind/owner = user.mind
	balloon_alert(user, "ищу участок...")
	var/success = do_after(user, 15 SECONDS, target = user, extra_checks = CALLBACK(src, PROC_REF(can_scan), user))
	if(QDELETED(src))
		return FALSE
	busy = FALSE
	if(!success || !can_scan(user) || user.mind != owner)
		return FALSE
	COOLDOWN_START(src, scan_cooldown, 2 SECONDS)
	for(var/attempt in 1 to search_attempts)
		var/angle = rand(0, 359)
		var/radius = rand(24, 52)
		var/turf/candidate = locate(clamp(user.x + round(radius * cos(angle)), 1, world.maxx), clamp(user.y + round(radius * sin(angle)), 1, world.maxy), user.z)
		if(!valid_ground(candidate))
			continue
		owner.xenoarch_site = list(candidate.x, candidate.y, candidate.z, 1)
		balloon_alert(user, "участок найден")
		return TRUE
	balloon_alert(user, "участок не найден")
	return FALSE

/obj/item/xenoarch/radar/attack_self(mob/living/user, list/modifiers)
	if(!can_scan(user) || !COOLDOWN_FINISHED(src, scan_cooldown))
		return
	COOLDOWN_START(src, scan_cooldown, 2 SECONDS)
	var/list/site = user.mind.xenoarch_site
	if(!site || site[3] != user.z)
		balloon_alert(user, "сначала найдите участок!")
		return
	var/turf/target = locate(site[1], site[2], site[3])
	var/distance = get_dist(user, target)
	if(distance <= 4)
		balloon_alert(user, "участок рядом!")
		return
	var/static/list/directions = list("[NORTH]" = "север", "[SOUTH]" = "юг", "[EAST]" = "восток", "[WEST]" = "запад", "[NORTHEAST]" = "северо-восток", "[NORTHWEST]" = "северо-запад", "[SOUTHEAST]" = "юго-восток", "[SOUTHWEST]" = "юго-запад")
	to_chat(user, span_notice("Сигнал участка: [directions["[get_dir(user, target)]"]], расстояние [distance] м."))
	if(user.hud_used)
		var/atom/movable/screen/multitool_arrow/arrow = user.hud_used.add_screen_object(/atom/movable/screen/multitool_arrow, "xenoarch_radar_arrow", HUD_GROUP_INFO, update_screen = TRUE)
		arrow.color = distance <= 10 ? COLOR_GREEN : distance <= 15 ? COLOR_YELLOW : distance <= 24 ? COLOR_ORANGE : COLOR_RED
		arrow.transform = matrix(dir2angle(get_dir(user, target)), MATRIX_ROTATE)
		QDEL_IN(arrow, 1.5 SECONDS)

/obj/item/xenoarch/radar/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!isturf(interacting_with))
		return ..()
	dig_site(user, interacting_with)
	return ITEM_INTERACT_SUCCESS

/// Сравнение самого списка блокирует вторую выдачу, если другой радар уже израсходовал участок.
/obj/item/xenoarch/radar/proc/dig_site(mob/living/user, turf/ground)
	if(busy || !can_scan(user) || !valid_ground(ground) || !user.Adjacent(ground))
		return FALSE
	var/datum/mind/owner = user.mind
	var/list/site = owner.xenoarch_site
	if(!site)
		balloon_alert(user, "сначала найдите участок!")
		return FALSE
	busy = TRUE
	var/speed = owner.get_skill_modifier(/datum/skill/xenoarchaeology, SKILL_SPEED_MODIFIER)
	var/success = do_after(user, 5 SECONDS * speed, target = ground, extra_checks = CALLBACK(src, PROC_REF(can_scan), user))
	if(QDELETED(src))
		return FALSE
	busy = FALSE
	if(!success || !can_scan(user) || user.mind != owner || owner.xenoarch_site != site || !user.Adjacent(ground) || !valid_ground(ground))
		return FALSE
	if(site[3] != ground.z || abs(site[1] - ground.x) > site[4] || abs(site[2] - ground.y) > site[4])
		balloon_alert(user, "здесь ничего нет")
		return FALSE
	owner.xenoarch_site = null
	var/amount = 1 + prob(50) + prob(owner.get_skill_modifier(/datum/skill/xenoarchaeology, SKILL_PROBS_MODIFIER))
	if(SSmapping.level_trait(ground.z, ZTRAIT_LAVA_RUINS))
		amount++
	for(var/index in 1 to amount)
		new /obj/item/xenoarch/strange_rock(ground)
	owner.adjust_experience(/datum/skill/xenoarchaeology, amount * 25)
	balloon_alert(user, "образцы извлечены")
	return TRUE
