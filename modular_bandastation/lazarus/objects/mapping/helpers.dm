// AI EDIT START - Adapt the Lazarus event to the native Primera APIs and regression harness
/** Generates the source forest once, leaving real dirt/snow and harvestable vegetation. */
/turf/open/misc/asteroid/lazarus/forest
	name = "forest turf"
	icon = 'modular_bandastation/lazarus/icons/mapping.dmi'
	icon_state = "forest"
	/// Percentage of generated tiles that expose dirt.
	var/dirt_chance = 15
	/// Weighted vegetation; "nothing" deliberately leaves an empty tile.
	var/list/forest_contents = list(
		"nothing" = 150,
		/obj/structure/flora/lazarus_tree = 120,
		/obj/structure/flora/grass/green = 30,
		/obj/structure/flora/grass/brown = 30,
		/obj/structure/flora/grass/both = 30,
		/obj/structure/flora/bush = 20,
		/obj/structure/flora/rock/style_random = 10,
		/obj/structure/flora/rock/pile/style_random = 10,
		/obj/structure/flora/lazarus/berry = 1,
	)

/turf/open/misc/asteroid/lazarus/forest/Initialize(mapload)
	. = ..()
	var/spawn_type = pick_weight(forest_contents)
	if(ispath(spawn_type))
		new spawn_type(src)
	ChangeTurf(prob(dirt_chance) ? /turf/open/misc/asteroid/lazarus/dirt : /turf/open/misc/asteroid/lazarus/snow, flags = CHANGETURF_INHERIT_AIR)

/turf/open/misc/asteroid/lazarus/forest/edge
	name = "forest edge turf"
	icon_state = "forest_edge"
	dirt_chance = 3
	forest_contents = list(
		"nothing" = 400,
		/obj/structure/flora/lazarus_tree = 40,
		/obj/structure/flora/grass/green = 150,
		/obj/structure/flora/grass/brown = 150,
		/obj/structure/flora/grass/both = 150,
		/obj/structure/flora/bush = 120,
		/obj/structure/flora/rock/style_random = 20,
		/obj/structure/flora/rock/pile/style_random = 20,
		/obj/structure/flora/lazarus/berry = 10,
		/obj/structure/flora/lazarus/comfrey = 5,
		/obj/structure/flora/lazarus/aloe = 5,
	)

/obj/effect/baseturf_helper/lazarus
	name = "lazarus baseturf editor"
	baseturf = /turf/open/misc/asteroid/lazarus/dirt

/** Reuses the native late window lookup, with the source's three destruction outcomes. */
/obj/effect/mapping_helpers/destroyed_window
	parent_type = /obj/effect/mapping_helpers/damaged_window
	name = "destroyed window helper"
	icon = 'modular_bandastation/lazarus/icons/mapping.dmi'
	icon_state = "destroyed_window"

/obj/effect/mapping_helpers/destroyed_window/LateInitialize()
	var/obj/structure/window/target = locate() in loc
	if(target)
		payload(target)
	else
		log_mapping("[src] failed to find a window at [AREACOORD(src)].")
	qdel(src)

/obj/effect/mapping_helpers/destroyed_window/intact_grill/payload(obj/structure/window/target)
	target.deconstruct(FALSE)

/obj/effect/mapping_helpers/destroyed_window/broken_grill/payload(obj/structure/window/target)
	target.deconstruct(FALSE)
	var/obj/structure/grille/grille = locate() in loc
	if(grille)
		grille.take_damage(grille.get_integrity())
	else
		log_mapping("[src] failed to find a grille at [AREACOORD(src)].")

/obj/effect/mapping_helpers/destroyed_window/destroyed_grill/payload(obj/structure/window/target)
	target.deconstruct(FALSE)
	var/obj/structure/grille/grille = locate() in loc
	if(grille)
		grille.deconstruct(FALSE)
	else
		log_mapping("[src] failed to find a grille at [AREACOORD(src)].")

/** Damage is applied after all mapped machines have initialized. */
/obj/effect/mapping_helpers/machinery
	late = TRUE

/obj/effect/mapping_helpers/machinery/LateInitialize()
	var/found = FALSE
	for(var/obj/machinery/machine in loc)
		found = TRUE
		payload(machine)
	if(!found)
		log_mapping("[src] failed to find machinery at [AREACOORD(src)].")
	qdel(src)

/** Override to apply this helper's effect after mapped machinery has initialized. */
/obj/effect/mapping_helpers/machinery/proc/payload(obj/machinery/machine)
	return

/obj/effect/mapping_helpers/machinery/damaged
	name = "damaged machinery helper"
	icon_state = "broken_machine"

/obj/effect/mapping_helpers/machinery/damaged/payload(obj/machinery/machine)
	machine.take_damage(max(0, machine.get_integrity() - max(1, machine.max_integrity * machine.integrity_failure)))

/obj/effect/mapping_helpers/machinery/destroyed
	name = "destroyed machinery helper"
	icon_state = "broken_machine"

/obj/effect/mapping_helpers/machinery/destroyed/payload(obj/machinery/machine)
	machine.take_damage(machine.get_integrity())

/** Only the rust variant is custom; broken-floor markers use the native helper. */
/obj/effect/mapping_helpers/lazarus_rust
	late = TRUE
	/// Source probability of weathered walls.
	var/spawn_probability = 75

/obj/effect/mapping_helpers/lazarus_rust/LateInitialize()
	var/turf/closed/wall/wall = get_turf(src)
	if(istype(wall) && prob(spawn_probability))
		wall.rust_turf()
	qdel(src)

/obj/effect/spawner/random/lazarus_dirt
	name = "dirt 50% chance"
	spawn_loot_chance = 50
	loot = list(/obj/effect/decal/cleanable/dirt/lazarus)

/** The source also places weathering on walls, like native wall graffiti. */
/obj/effect/decal/cleanable/dirt/lazarus/NeverShouldHaveComeHere(turf/here_turf)
	return isgroundlessturf(here_turf) && !GET_TURF_BELOW(here_turf)

/obj/effect/decal/cleanable/dirt/lazarus/Initialize(mapload)
	. = ..()
	if(. == INITIALIZE_HINT_QDEL)
		return
	if(isclosedturf(loc) && loc.density)
		SET_PLANE_IMPLICIT(src, GAME_PLANE)
		layer = CLEANABLE_OBJECT_LAYER

/obj/effect/spawner/random/lazarus_cobweb
	name = "cobweb 50% chance"
	spawn_loot_chance = 50
	loot = list(/obj/effect/decal/cleanable/cobweb)

/obj/effect/spawner/random/lazarus_cobweb/rare
	spawn_loot_chance = 9

/obj/effect/spawner/random/lazarus_cobweb/right
	loot = list(/obj/effect/decal/cleanable/cobweb/cobweb2)

/obj/effect/spawner/random/lazarus_cobweb/right/rare
	spawn_loot_chance = 9

/** The source pistol uses 10 mm magazines, unlike the native Makarov. */
/obj/item/gun/ballistic/automatic/pistol/lazarus_stechkin
	name = "stechkin pistol"
	accepted_magazine_type = /obj/item/ammo_box/magazine/m10mm

/obj/item/storage/box/lazarus_stechkin
	name = "FK-69 Stechkin kit"
	desc = "A box containing a 10 mm pistol and two spare magazines."

/obj/item/storage/box/lazarus_stechkin/PopulateContents()
	new /obj/item/gun/ballistic/automatic/pistol/lazarus_stechkin(src)
	new /obj/item/ammo_box/magazine/m10mm(src)
	new /obj/item/ammo_box/magazine/m10mm(src)

/obj/item/storage/box/lazarus_iv_bags
	name = "IV bags"
	desc = "A box containing seven empty IV bags."

/obj/item/storage/box/lazarus_iv_bags/PopulateContents()
	for(var/index in 1 to 7)
		new /obj/item/reagent_containers/blood(src)

/** Source bronze ashtray, retaining its sixteen-item capacity and cigarette extinguishing. */
/obj/item/lazarus_ashtray
	name = "bronze ashtray"
	desc = "Massive bronze ashtray."
	icon = 'modular_bandastation/lazarus/icons/ashtray.dmi'
	icon_state = "ashtray_br"
	max_integrity = 16
	throwforce = 10

/obj/item/lazarus_ashtray/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/cigbutt) && !istype(tool, /obj/item/cigarette) && !istype(tool, /obj/item/match))
		return NONE
	if(length(contents) >= 16)
		balloon_alert(user, "ashtray full!")
		return ITEM_INTERACT_BLOCKING
	if(!user.transferItemToLoc(tool, src))
		return ITEM_INTERACT_BLOCKING
	if(istype(tool, /obj/item/cigarette))
		var/obj/item/cigarette/cigarette = tool
		if(cigarette.lit)
			var/obj/item/butt = new cigarette.type_butt(src)
			cigarette.transfer_fingerprints_to(butt)
			qdel(cigarette)
	else
		tool.extinguish()
	add_fingerprint(user)
	update_appearance()
	return ITEM_INTERACT_SUCCESS

/obj/item/lazarus_ashtray/update_icon_state()
	. = ..()
	icon_state = length(contents) >= 16 ? "ashtray_full_br" : length(contents) > 8 ? "ashtray_half_br" : "ashtray_br"

/obj/item/lazarus_ashtray/attack_self(mob/user)
	empty_tray()

/** Drops the stored butts and matches before emptying, throwing or recycling the tray. */
/obj/item/lazarus_ashtray/proc/empty_tray()
	for(var/obj/item/item in contents)
		item.forceMove(drop_location())
	update_appearance()

/obj/item/lazarus_ashtray/throw_impact(atom/hit_atom, datum/thrownthing/throwingdatum)
	empty_tray()
	return ..()

/obj/item/lazarus_ashtray/wrench_act(mob/living/user, obj/item/tool)
	if(!tool.use_tool(src, user, volume = 50))
		return TRUE
	empty_tray()
	new /obj/item/stack/sheet/iron(drop_location())
	deconstruct()
	return TRUE

/** Event wood keeps the source's one-plank yield instead of the native ten-plank tree logs. */
/obj/item/grown/log/tree/lazarus
	plank_count = 1

/** Native flora harvesting, scoped to Lazarus so ordinary station trees retain their rules. */
/obj/structure/flora/lazarus_tree
	name = "pine tree"
	desc = "A coniferous pine tree."
	icon = 'icons/obj/fluff/flora/pinetrees.dmi'
	icon_state = "pine_1"
	density = TRUE
	max_integrity = 400
	pixel_x = -16
	layer = FLY_LAYER
	plane = ABOVE_GAME_PLANE
	can_uproot = FALSE
	harvest_time = 8 SECONDS
	harvest_amount_low = 1
	harvest_amount_high = 4
	harvest_verb = "chop down"
	delete_on_harvest = TRUE
	flora_flags = FLORA_WOODEN

/obj/structure/flora/lazarus_tree/Initialize(mapload)
	. = ..()
	icon_state = "pine_[rand(1, 3)]"
	AddComponent(/datum/component/seethrough, SEE_THROUGH_MAP_DEFAULT_TWO_TALL)

/obj/structure/flora/lazarus_tree/can_harvest(mob/user, obj/item/harvesting_item)
	return !harvested && (istype(harvesting_item, /obj/item/hatchet) || istype(harvesting_item, /obj/item/fireaxe))

/obj/structure/flora/lazarus_tree/get_potential_products()
	return list(/obj/item/grown/log/tree/lazarus = 1)

/obj/structure/flora/lazarus_tree/play_attack_sound(damage_amount, damage_type = BRUTE, damage_flag = 0)
	if(damage_type == BRUTE)
		playsound(src, 'modular_bandastation/lazarus/sound/wood_chop.ogg', 80, TRUE)
	else
		return ..()

/obj/structure/flora/lazarus_tree/harvest(mob/living/user, product_amount_multiplier = 1)
	. = ..(user, 1)
	if(!.)
		return
	if(user)
		// The source grants one batch when chopped and another when the tree is removed.
		for(var/index in 1 to rand(1, 4))
			. += new /obj/item/grown/log/tree/lazarus(get_turf(src))
	playsound(src, 'modular_bandastation/lazarus/sound/falling_tree.ogg', 50, TRUE)

/obj/structure/flora/lazarus_tree/great
	name = "вековая сосна"
	transform = matrix(1.5, 0, 0, 0, 1.5, 0)

/** Critical source APCs carried 25 times the standard battery capacity. */
/obj/item/stock_parts/power_store/battery/lazarus_critical
	maxcharge = STANDARD_BATTERY_CHARGE * 25
// AI EDIT END
