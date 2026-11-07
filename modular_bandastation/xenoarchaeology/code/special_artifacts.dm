/// Кристалл реагирует на перемещение рядом через штатный proximity monitor.
/obj/machinery/xenoartifact/bluespace_crystal
	name = "огромный блюспейс-кристалл"
	desc = "В глубине кристалла мерцают пространственные искажения."
	icon_state = "artifact_13"
	artifact_style = 13
	max_integrity = 200
	random_effects = FALSE
	var/anomaly_type

/obj/machinery/xenoartifact/bluespace_crystal/Initialize(mapload)
	. = ..()
	first_effect = new /datum/xenoartifact_effect/tesla(src)
	first_effect.trigger = XENO_TRIGGER_PROXY
	anomaly_type = pick_weight(list(/obj/effect/anomaly/flux = 1, /obj/effect/anomaly/grav/high = 1, /obj/effect/anomaly/ectoplasm = 1, /obj/effect/anomaly/bioscrambler = 1, /obj/effect/anomaly/pyro = 1, /obj/effect/anomaly/bhole = 1, /obj/effect/anomaly/bluespace = 6))
	new /datum/proximity_monitor(src, 3)
	update_proximity()

/obj/machinery/xenoartifact/bluespace_crystal/HasProximity(atom/movable/nearby)
	addtimer(CALLBACK(src, PROC_REF(update_proximity)), 0, TIMER_UNIQUE)

/obj/machinery/xenoartifact/bluespace_crystal/OnProximityExit(atom/movable/nearby)
	addtimer(CALLBACK(src, PROC_REF(update_proximity)), 0, TIMER_UNIQUE)

/obj/machinery/xenoartifact/bluespace_crystal/proc/update_proximity()
	var/nearby = FALSE
	for(var/mob/living/creature in range(3, src))
		nearby = TRUE
		break
	trigger_effects(XENO_TRIGGER_PROXY, nearby)

/obj/machinery/xenoartifact/bluespace_crystal/atom_destruction(damage_flag)
	new /obj/item/stack/sheet/bluespace_crystal(drop_location(), rand(1, 50))
	var/obj/effect/anomaly/anomaly = new anomaly_type(drop_location())
	anomaly.lifespan = 3 MINUTES
	for(var/mob/living/creature in range(7, src))
		var/weakness = get_xenoartifact_susceptibility(creature)
		if(weakness)
			do_teleport(creature, get_turf(creature), 20 * weakness)
	return ..()

/obj/machinery/xenoartifact/bluespace_crystal/take_damage(damage_amount, damage_type, damage_flag, sound_effect, attack_dir, armour_penetration)
	. = ..()
	if(. && !QDELETED(src))
		var/power = max(1, round(. / 10))
		tesla_zap(src, power, 50000 * power)
		empulse(src, power, 2 * power)

/obj/machinery/xenoartifact/bluespace_crystal/analysis_description()
	return "Необычно крупный блюспейс-кристалл. Реагирует на движение электрическими разрядами. Разрушение высвободит пространственную аномалию."

/// Мощность передаётся в powernet в ваттах; подсистема сети сама учитывает длительность тика.
/obj/machinery/power/xenoarch_crystal
	name = "энергетический кристалл"
	desc = "Псевдоорганическая кристаллическая решётка. Закрепите над узлом кабеля, обмотайте двумя отрезками провода и коснитесь для включения."
	icon = 'modular_bandastation/xenoarchaeology/icons/artifacts/artifacts.dmi'
	icon_state = "artifact_11"
	anchored = FALSE
	density = TRUE
	var/wired = FALSE
	var/enabled = FALSE
	var/working = FALSE
	var/crystal_style = 11

/obj/machinery/power/xenoarch_crystal/Initialize(mapload)
	. = ..()
	crystal_style = rand(11, 13)
	update_appearance()

/obj/machinery/power/xenoarch_crystal/update_icon_state()
	. = ..()
	icon_state = "artifact_[crystal_style][enabled && wired && anchored ? "_active" : ""]"

/obj/machinery/power/xenoarch_crystal/update_overlays()
	. = ..()
	var/static/crystal_wires
	if(isnull(crystal_wires))
		crystal_wires = iconstate2appearance('modular_bandastation/xenoarchaeology/icons/artifacts/artifacts.dmi', "crystal_overlay")
	if(wired)
		. += crystal_wires

/obj/machinery/power/xenoarch_crystal/should_have_node()
	return TRUE

/obj/machinery/power/xenoarch_crystal/wrench_act(mob/living/user, obj/item/tool)
	if(default_unfasten_wrench(user, tool))
		if(anchored)
			connect_to_network()
		else
			enabled = FALSE
			disconnect_from_network()
		update_appearance()
		return ITEM_INTERACT_SUCCESS

/obj/machinery/power/xenoarch_crystal/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/stack/cable_coil))
		return ..()
	var/obj/item/stack/cable_coil/cable = tool
	if(wired || working || cable.amount < 2)
		return ITEM_INTERACT_BLOCKING
	working = TRUE
	var/success = do_after(user, 2 SECONDS, target = src)
	if(QDELETED(src))
		return ITEM_INTERACT_BLOCKING
	working = FALSE
	if(!success || wired || QDELETED(user) || QDELETED(cable) || !user.is_holding(cable) || !user.can_perform_action(src, NEED_DEXTERITY|NEED_HANDS|FORBID_TELEKINESIS_REACH) || !cable.use(2))
		return ITEM_INTERACT_BLOCKING
	wired = TRUE
	update_appearance()
	return ITEM_INTERACT_SUCCESS

/obj/machinery/power/xenoarch_crystal/wirecutter_act(mob/living/user, obj/item/tool)
	if(!wired || working)
		return ITEM_INTERACT_BLOCKING
	working = TRUE
	var/success = tool.use_tool(src, user, 2 SECONDS, volume = 50)
	if(QDELETED(src))
		return ITEM_INTERACT_BLOCKING
	working = FALSE
	if(!success || !wired || QDELETED(user) || QDELETED(tool) || !user.is_holding(tool) || !user.can_perform_action(src, NEED_DEXTERITY|NEED_HANDS|FORBID_TELEKINESIS_REACH))
		return ITEM_INTERACT_BLOCKING
	wired = FALSE
	enabled = FALSE
	new /obj/item/stack/cable_coil(drop_location(), 2)
	update_appearance()
	return ITEM_INTERACT_SUCCESS

/obj/machinery/power/xenoarch_crystal/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(. || !wired || !anchored || !user.can_perform_action(src, NEED_HANDS|FORBID_TELEKINESIS_REACH))
		return
	connect_to_network()
	enabled = !enabled
	update_appearance()
	balloon_alert(user, enabled ? "кристалл включён" : "кристалл выключен")

/obj/machinery/power/xenoarch_crystal/process(seconds_per_tick)
	if(enabled && wired && anchored)
		add_avail(250 KILO WATTS)

/obj/machinery/power/xenoarch_crystal/bullet_act(obj/projectile/projectile, def_zone, piercing_hit = FALSE)
	if(istype(projectile, /obj/projectile/energy) || istype(projectile, /obj/projectile/beam))
		projectile.reflect(src)
		return BULLET_ACT_FORCE_PIERCE
	return ..()

/obj/machinery/power/xenoarch_crystal/atom_destruction(damage_flag)
	new /obj/item/stack/sheet/bluespace_crystal(drop_location(), rand(1, 3))
	for(var/index in 1 to rand(1, 10))
		new /obj/item/shard(drop_location())
	return ..()

/obj/machinery/xenoartifact/cloner
	name = "таинственная капсула"
	desc = "Капсула с вязкой жидкостью. При наличии питания выращивает неизвестный организм."
	icon = 'modular_bandastation/xenoarchaeology/icons/artifacts/artifacts_64x32.dmi'
	icon_state = "autocloner_off"
	random_effects = FALSE
	use_power = IDLE_POWER_USE
	idle_power_usage = 1000
	active_power_usage = 2000
	var/spawn_type
	var/growth = 0
	var/growth_duration

/obj/machinery/xenoartifact/cloner/Initialize(mapload)
	. = ..()
	growth_duration = rand(120, 360)
	if(prob(33))
		spawn_type = pick(/mob/living/basic/bear, /mob/living/basic/carp, /mob/living/basic/snake, /mob/living/basic/goose, /mob/living/basic/mining/goliath, /mob/living/basic/mining/watcher, /mob/living/basic/mimic)
	else
		spawn_type = pick(/mob/living/basic/axolotl, /mob/living/basic/crab, /mob/living/basic/bat, /mob/living/basic/pet/cat, /mob/living/basic/pet/dog/pug, /mob/living/basic/pet/fox, /mob/living/basic/pet/penguin, /mob/living/basic/chicken, /mob/living/basic/cow, /mob/living/basic/goat, /mob/living/carbon/human/species/monkey)

/obj/machinery/xenoartifact/cloner/process(seconds_per_tick)
	if(!is_operational)
		growth = max(0, growth - seconds_per_tick)
		return
	var/was_growing = growth > growth_duration * 0.75
	growth += seconds_per_tick
	update_use_power(growth > growth_duration * 0.75 ? ACTIVE_POWER_USE : IDLE_POWER_USE)
	if(growth >= growth_duration)
		growth -= growth_duration
		new spawn_type(drop_location())
		playsound(src, 'sound/machines/ping.ogg', 50, FALSE)
	if(was_growing != (growth > growth_duration * 0.75))
		update_appearance()

/obj/machinery/xenoartifact/cloner/on_set_is_operational(old_value)
	. = ..()
	update_appearance()

/obj/machinery/xenoartifact/cloner/update_icon_state()
	. = ..()
	icon_state = !is_operational ? "autocloner_off" : growth > growth_duration * 0.75 ? "autocloner_process" : "autocloner_on"

/obj/machinery/xenoartifact/cloner/analysis_description()
	return "Автоматическая клонирующая капсула. Использует органические наномашины и протоплазменную среду. Выращивает один и тот же вид каждые 2–6 минут; при потере питания рост обращается вспять. Организм может быть враждебным."

/obj/machinery/xenoartifact/replicator
	name = "инопланетный репликатор"
	desc = "Устройство с непонятными органами управления. Принимает один предмет как сырьё для выбранного преобразования."
	random_effects = FALSE
	icon_state = "replicator"
	use_power = IDLE_POWER_USE
	idle_power_usage = 100
	active_power_usage = 1000
	interaction_flags_machine = parent_type::interaction_flags_machine | INTERACT_MACHINE_OFFLINE
	var/obj/item/feedstock
	/// Названия кнопок связаны с локальными генераторами наград.
	var/list/recipes = list()
	var/selected_recipe = 0
	var/progress = 0
	var/duration = 5

/obj/machinery/xenoartifact/replicator/Initialize(mapload)
	. = ..()
	var/list/possible = list(/obj/effect/spawner/random/animalhide, /obj/effect/spawner/random/bedsheet/any, /obj/effect/spawner/random/bureaucracy/pen, /obj/effect/spawner/random/bureaucracy/stamp, /obj/effect/spawner/random/engineering/tool, /obj/effect/spawner/random/engineering/material_rare, /obj/effect/spawner/random/entertainment/musical_instrument, /obj/effect/spawner/random/medical/minor_healing, /obj/effect/spawner/random/medical/surgery_tool, /obj/effect/spawner/random/trash/garbage)
	for(var/index in 1 to rand(3, 8))
		var/label = "[index]. [pick("Жёлтая", "Фиолетовая", "Зелёная", "Синяя", "Красная")] [pick("круглая", "квадратная", "ромбовидная", "треугольная")] кнопка"
		recipes[label] = pick_n_take(possible)

/obj/machinery/xenoartifact/replicator/Destroy()
	feedstock = null
	return ..()

/obj/machinery/xenoartifact/replicator/Exited(atom/movable/gone, direction)
	. = ..()
	if(gone == feedstock)
		feedstock = null
		selected_recipe = 0
		progress = 0
		update_use_power(IDLE_POWER_USE)
		update_appearance()

/obj/machinery/xenoartifact/replicator/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(feedstock || tool.item_flags & (ABSTRACT|DROPDEL) || tool.resistance_flags & INDESTRUCTIBLE || istype(tool, /obj/item/storage) || length(tool.contents))
		return ITEM_INTERACT_BLOCKING
	if(user.transferItemToLoc(tool, src))
		feedstock = tool
		return ITEM_INTERACT_SUCCESS
	return ITEM_INTERACT_BLOCKING

/obj/machinery/xenoartifact/replicator/proc/select_recipe(index)
	if(!is_operational || selected_recipe || QDELETED(feedstock) || feedstock.loc != src || !isnum(index) || index != round(index) || index < 1 || index > length(recipes))
		return FALSE
	selected_recipe = index
	progress = 0
	update_use_power(ACTIVE_POWER_USE)
	update_appearance()
	return TRUE

/obj/machinery/xenoartifact/replicator/process(seconds_per_tick)
	if(!is_operational || !selected_recipe || QDELETED(feedstock) || feedstock.loc != src)
		return
	progress += seconds_per_tick
	if(progress < duration)
		return
	var/recipe = recipes[recipes[selected_recipe]]
	var/obj/item/consumed = feedstock
	feedstock = null
	selected_recipe = 0
	progress = 0
	qdel(consumed)
	new recipe(drop_location())
	update_use_power(IDLE_POWER_USE)
	update_appearance()

/obj/machinery/xenoartifact/replicator/on_set_is_operational(old_value)
	. = ..()
	update_appearance()

/obj/machinery/xenoartifact/replicator/update_icon_state()
	. = ..()
	icon_state = selected_recipe && is_operational ? "replicator_active" : "replicator"

/obj/machinery/xenoartifact/replicator/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "XenoartifactReplicator", name)
		ui.open()

/obj/machinery/xenoartifact/replicator/ui_data(mob/user)
	return list("recipes" = assoc_to_keys(recipes), "hasFeedstock" = !QDELETED(feedstock), "active" = !!selected_recipe, "operational" = is_operational, "progress" = progress / duration)

/obj/machinery/xenoartifact/replicator/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(action == "recipe")
		if(!istext(params["index"]))
			return FALSE
		return select_recipe(text2num(params["index"]))
	if(action == "eject")
		feedstock?.forceMove(drop_location())
		return TRUE

/obj/machinery/xenoartifact/replicator/analysis_description()
	return "Автоматический синтезатор. Преобразует одно вложенное сырьё в предмет, определяемый выбранным органом управления. Кнопки требуют экспериментальной проверки."
