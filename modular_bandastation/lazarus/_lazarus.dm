// AI EDIT START - Adapt the Lazarus event to the native Primera APIs and regression harness
/** Optional survival-horror map, adapted from ThaumicNik's IceEvent. */
/datum/modpack/lazarus
	name = "Эвент «Проект Лазарь»"
	desc = "Ледяная колония, выживание и Коварная плоть."
	author = "ThaumicNik; адаптация для PrimeDream"

/datum/modpack/lazarus/initialize()
	var/datum/map_config/selected_map = SSmapping.current_map
	if(selected_map?.defaulted && config.defaultmap && !config.defaultmap.defaulted)
		selected_map = config.defaultmap
	if(selected_map?.map_name == LAZARUS_MAP_NAME)
		GLOB.wood_recipes += new /datum/stack_recipe("деревянный потолок", /obj/item/lazarus_wooden_ceiling, 40, 1, 20, crafting_flags = NONE, category = CAT_STRUCTURE)
	var/list/snow_steps = list(list('modular_bandastation/lazarus/sound/snowstep1.ogg', 'modular_bandastation/lazarus/sound/snowstep2.ogg', 'modular_bandastation/lazarus/sound/snowstep3.ogg', 'modular_bandastation/lazarus/sound/snowstep4.ogg'), 50, 1)
	GLOB.footstep["lazarus_snow"] = snow_steps
	GLOB.barefootstep["lazarus_snow"] = snow_steps
	GLOB.clawfootstep["lazarus_snow"] = snow_steps
	RegisterSignal(SSdcs, COMSIG_GLOB_JOB_AFTER_SPAWN, PROC_REF(on_job_spawn))

/** Apply event equipment and cryosleep only to colonists on the event map. */
/datum/modpack/lazarus/proc/on_job_spawn(datum/source, datum/job/job, mob/living/spawned, client/player_client)
	SIGNAL_HANDLER
	if(!ishuman(spawned) || !istype(get_area(spawned), /area/lazarus))
		return
	var/mob/living/carbon/human/colonist = spawned
	for(var/obj/item/modular_computer/pda/pda in colonist.get_all_contents())
		qdel(pda)
	for(var/obj/item/storage/box/survival/box in colonist.get_all_contents())
		qdel(box)
	colonist.AddComponent(/datum/component/lazarus_frostbite)
	if(locate(/obj/machinery/cryopod) in get_turf(colonist))
		colonist.Sleeping(10 SECONDS)
		colonist.set_eye_blur_if_lower(12 SECONDS)
		colonist.adjust_drowsiness(25 SECONDS)
// AI EDIT END
