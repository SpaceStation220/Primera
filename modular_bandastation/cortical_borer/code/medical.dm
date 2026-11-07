/// Normal diagnosis only exposes a parasite that is actively controlling the body.
/mob/living/basic/cortical_borer/proc/on_healthscan(datum/source, list/render_list, scanpower, mob/user, mode, tochat)
	SIGNAL_HANDLER
	if(controlling)
		render_list += "<span class='alert'>Обнаружены отклонения в работе мозга, характерные для контроля мозговым червём.</span><br>"

/// Extraction fits the new limb surgery framework instead of copying Paradise's old steps.
/datum/surgery_operation/limb/remove_cortical_borer
	name = "Извлечение мозгового червя"
	desc = "Извлечь мозгового червя из головы пациента."
	implements = list(TOOL_HEMOSTAT = 1)
	time = 5 SECONDS
	required_bodytype = BODYTYPE_ORGANIC
	all_surgery_states_required = SURGERY_SKIN_OPEN | SURGERY_ORGANS_CUT | SURGERY_BONE_SAWED

/datum/surgery_operation/limb/remove_cortical_borer/get_default_radial_image()
	return image(/obj/item/hemostat)

/datum/surgery_operation/limb/remove_cortical_borer/state_check(obj/item/bodypart/limb)
	if(limb.body_zone != BODY_ZONE_HEAD || !iscarbon(limb.owner))
		return FALSE
	var/mob/living/carbon/patient = limb.owner
	return !!patient.get_cortical_borer()

/datum/surgery_operation/limb/remove_cortical_borer/on_success(obj/item/bodypart/limb, mob/living/surgeon, obj/item/tool, list/operation_args)
	var/mob/living/carbon/patient = limb.owner
	var/mob/living/basic/cortical_borer/borer = patient?.get_cortical_borer()
	if(!borer)
		return
	log_combat(surgeon, patient, "surgically removed a cortical borer")
	borer.leave_host()
	patient.visible_message(span_notice("[surgeon] извлекает мозгового червя из головы [patient]!"))
