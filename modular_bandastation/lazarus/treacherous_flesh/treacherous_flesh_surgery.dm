// AI EDIT START - Adapt the Lazarus event to the native Primera APIs and regression harness
/** Search is available even on healthy patients, preserving the risk of a mistaken extraction. */
/datum/surgery_operation/limb/lazarus_check_anomalies
	name = "Поиск аномалий Лазаря"
	desc = "Извлечь паразита из грудной полости. На здоровом пациенте серьёзно повреждает ткани."
	implements = list(TOOL_HEMOSTAT = 1)
	time = 10 SECONDS
	required_bodytype = ~BODYTYPE_ROBOTIC
	all_surgery_states_required = SURGERY_SKIN_OPEN|SURGERY_ORGANS_CUT
	operation_flags = OPERATION_NOTABLE

/datum/surgery_operation/limb/lazarus_check_anomalies/get_default_radial_image()
	return image('modular_bandastation/lazarus/icons/treacherous_flesh.dmi', "spawner")

/datum/surgery_operation/limb/lazarus_check_anomalies/state_check(obj/item/bodypart/limb)
	if(limb.body_zone != BODY_ZONE_CHEST || !ishuman(limb.owner))
		return FALSE
	return istype(get_area(limb.owner), /area/lazarus) || lazarus_host_infested(limb.owner)

/datum/surgery_operation/limb/lazarus_check_anomalies/on_success(obj/item/bodypart/limb, mob/living/surgeon, obj/item/tool, list/operation_args)
	var/mob/living/carbon/human/patient = limb.owner
	if(!istype(patient) || !state_check(limb))
		return
	if(patient.treacherous_flesh)
		patient.visible_message(span_boldwarning("[surgeon] вытаскивает из тела [patient] нечто ужасное!"))
		patient.treacherous_flesh.burst_out()
		return
	var/obj/effect/mob_spawn/ghost_role/treacherous_flesh/egg = locate() in patient
	if(egg)
		qdel(egg)
		new /mob/living/basic/flesh_biomorph/lesser/small(get_turf(patient))
		patient.adjust_brute_loss(60)
	else
		patient.adjust_brute_loss(50)
		patient.adjust_tox_loss(25)
	patient.adjust_stamina_loss(100)
	patient.emote("scream")
// AI EDIT END
