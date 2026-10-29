// AI EDIT START - Adapt the Lazarus event to the native Primera APIs and regression harness
/mob/living/carbon/human
	/// The event reserve is distinct from native atmospheric body temperature.
	var/frostbite = FROSTBITE_WARM

/** Attach once when a human enters the colony, including admin-created humans. */
/area/lazarus/Entered(atom/movable/arrived, area/old_area)
	. = ..()
	if(ishuman(arrived))
		arrived.AddComponent(/datum/component/lazarus_frostbite)

/** Local cold mechanics driven by the existing living-life signal. */
/datum/component/lazarus_frostbite
	dupe_mode = COMPONENT_DUPE_UNIQUE

/datum/component/lazarus_frostbite/Initialize()
	if(!ishuman(parent))
		return COMPONENT_INCOMPATIBLE

/datum/component/lazarus_frostbite/RegisterWithParent()
	RegisterSignal(parent, COMSIG_LIVING_LIFE, PROC_REF(on_life))
	RegisterSignal(parent, COMSIG_LIVING_POST_FULLY_HEAL, PROC_REF(on_heal))
	RegisterSignal(parent, COMSIG_LIVING_HEALTHSCAN, PROC_REF(on_healthscan))

/datum/component/lazarus_frostbite/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_LIVING_LIFE, COMSIG_LIVING_POST_FULLY_HEAL, COMSIG_LIVING_HEALTHSCAN))
	var/mob/living/carbon/human/human = parent
	human.clear_alert("lazarus_frostbite")

/** Administrator and native full-heal paths also restore the event reserve. */
/datum/component/lazarus_frostbite/proc/on_heal(mob/living/carbon/human/human, heal_flags)
	SIGNAL_HANDLER
	if(heal_flags & HEAL_TEMP)
		human.frostbite = FROSTBITE_WARM

/** Existing medical analyzers display the event reserve on colony patients. */
/datum/component/lazarus_frostbite/proc/on_healthscan(mob/living/carbon/human/human, list/render_list)
	SIGNAL_HANDLER
	if(istype(get_area(human), /area/lazarus))
		render_list += "[span_info("Запас тепла: [round(human.frostbite)]/[FROSTBITE_WARM].")]<br>"

/datum/component/lazarus_frostbite/proc/on_life(mob/living/carbon/human/human, seconds_per_tick)
	SIGNAL_HANDLER
	if(!istype(get_area(human), /area/lazarus))
		human.clear_alert("lazarus_frostbite")
		return
	if(human.stat == DEAD)
		return
	human.handle_frostbite(seconds_per_tick)

/** Advance the donor's reserve at the same rate regardless of subsystem timing. */
/mob/living/carbon/human/proc/handle_frostbite(seconds_per_tick = 2)
	var/delta = get_frostbite_delta()
	if(HAS_TRAIT(src, TRAIT_GODMODE))
		frostbite = FROSTBITE_WARM
	else
		frostbite = clamp(frostbite + delta * seconds_per_tick / 2, 0, FROSTBITE_WARM)
	if(frostbite <= FROSTBITE_HYPOTHERMIA)
		adjust_stamina_loss(0.5 * seconds_per_tick / 2)
		adjust_fire_loss(seconds_per_tick / 2)
	else if(frostbite <= FROSTBITE_SEVERE)
		adjust_fire_loss(0.5 * seconds_per_tick / 2)
	var/atom/movable/screen/alert/temperature = throw_alert("lazarus_frostbite", /atom/movable/screen/alert/lazarus_frostbite)
	var/rate = delta >= 20 ? "veryhigh" : delta >= 0 ? "high" : delta >= -15 ? "normal" : delta >= -30 ? "low" : "verylow"
	var/reserve = frostbite >= FROSTBITE_CHILLED ? "warm" : frostbite >= FROSTBITE_MILD ? "chilled" : frostbite >= FROSTBITE_SEVERE ? "mild" : frostbite > FROSTBITE_HYPOTHERMIA ? "severe" : "hypothermia"
	temperature.icon_state = "[rate]_[reserve]"

/** Original event balance: clothing offsets the area cold, never generates heat. */
/mob/living/carbon/human/proc/get_frostbite_delta()
	var/area/lazarus/location = get_area(src)
	if(!istype(location))
		return 0
	return min(location.temperature + get_clothes_isolation(), 0) + FROSTBITE_REGENERATION + get_around_heat()

/** Insulation of the six equipment slots used by the original event. */
/mob/living/carbon/human/proc/get_clothes_isolation()
	var/insulation = 0
	for(var/obj/item/clothing/clothing in list(head, wear_suit, wear_mask, w_uniform, shoes, gloves))
		insulation += clothing.lazarus_isolation
	return insulation

/** Campfires, powered heaters, fire and the active local blizzard affect warmth. */
/mob/living/carbon/human/proc/get_around_heat()
	var/heat = on_fire ? FROSTBITE_BURNING_BONUS : 0
	for(var/obj/structure/bonfire/bonfire in range(5, src))
		if(bonfire.burning)
			heat += BONFIRE_HEAT
	for(var/obj/machinery/space_heater/heater in range(5, src))
		if(heater.on && heater.cell?.charge > 0 && heater.target_temperature > T0C)
			heat += SPACE_HEATER_HEAT
	var/datum/weather/lazarus_blizzard/blizzard = SSweather.get_weather_by_type(/datum/weather/lazarus_blizzard)
	if(blizzard && blizzard.stage == MAIN_STAGE && (z in blizzard.impacted_z_levels) && istype(get_area(src), /area/lazarus/outdoors))
		heat -= BLIZZARD_TEMPERATURE_EFFECT
	return heat

/** Native alert placement and cleanup also work after reconnecting or observing. */
/atom/movable/screen/alert/lazarus_frostbite
	name = "Запас тепла"
	desc = "Нажмите, чтобы оценить тепло, одежду и источники обогрева."
	icon = 'modular_bandastation/lazarus/icons/screen_frostbite.dmi'
	icon_state = "normal_warm"

/atom/movable/screen/alert/lazarus_frostbite/Click(location, control, params)
	if(!..())
		return
	if(usr != owner || !ishuman(owner))
		return
	var/mob/living/carbon/human/human = owner
	to_chat(human, span_notice("Запас тепла: [round(human.frostbite)] / [FROSTBITE_WARM]. Изменение за 2 секунды: [human.get_frostbite_delta()]. Защита одежды: [human.get_clothes_isolation()]. Обогрев и погода: [human.get_around_heat()]."))

/obj/item/clothing
	/// Insulation used exclusively by Lazarus cold mechanics.
	var/lazarus_isolation = 0

/obj/item/clothing/head
	lazarus_isolation = FB_ISOLATION_LOW
/obj/item/clothing/mask
	lazarus_isolation = FB_ISOLATION_LOW
/obj/item/clothing/under
	lazarus_isolation = FB_ISOLATION_LOW
/obj/item/clothing/shoes
	lazarus_isolation = FB_ISOLATION_LOW
/obj/item/clothing/gloves
	lazarus_isolation = FB_ISOLATION_LOW
/obj/item/clothing/suit
	lazarus_isolation = FB_ISOLATION_MEDIUM
/obj/item/clothing/head/ushanka
	lazarus_isolation = FB_ISOLATION_MEDIUM
/obj/item/clothing/head/hooded/winterhood
	lazarus_isolation = FB_ISOLATION_MEDIUM
/obj/item/clothing/suit/hooded/wintercoat
	lazarus_isolation = FB_ISOLATION_HIGH
/obj/item/clothing/shoes/winterboots
	lazarus_isolation = FB_ISOLATION_MEDIUM
/obj/item/clothing/shoes/workboots
	lazarus_isolation = FB_ISOLATION_MEDIUM
// AI EDIT END
