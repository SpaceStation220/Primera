/// Generation follows the personality core; a replacement chassis cannot rewrite it.
/obj/item/organ/brain/ipc
	var/ipc_generation = "II"
	/// Null means no roundstart profession has been captured, including an unassigned spawn.
	var/datum/job/ipc_starting_job
	var/ipc_job_captured = FALSE
	/// Once a personality has left a chassis, preview preferences cannot rewrite it.
	var/engram_transplanted = FALSE
	var/ipc_department

/obj/item/organ/brain/ipc/on_physical_mob_remove(mob/living/carbon/organ_owner, special, movement_flags)
	if(ipc_generation == "III")
		engram_transplanted = TRUE
	return ..()

/datum/ipc_os/proc/generation()
	var/obj/item/organ/brain/ipc/positronic = core
	return istype(positronic) ? positronic.ipc_generation : "II"

/datum/ipc_os/proc/capture_generation_job(datum/job/job)
	var/obj/item/organ/brain/ipc/positronic = core
	if(!istype(positronic) || positronic.ipc_job_captured || !job)
		return
	positronic.ipc_job_captured = TRUE
	positronic.ipc_starting_job = job.type
	for(var/department in job.departments_list)
		switch(department)
			if(/datum/job_department/medical)
				positronic.ipc_department = "medical"
			if(/datum/job_department/engineering)
				positronic.ipc_department = "engineering"
			if(/datum/job_department/security)
				positronic.ipc_department = "security"
			if(/datum/job_department/science)
				positronic.ipc_department = "science"
			if(/datum/job_department/service)
				positronic.ipc_department = "service"
			if(/datum/job_department/cargo)
				positronic.ipc_department = "cargo"
		if(positronic.ipc_department)
			break

/datum/preference/choiced/ipc/generation
	savefile_key = FEATURE_IPC_GENERATION
	feature_key = FEATURE_IPC_GENERATION
	priority = PREFERENCE_PRIORITY_BODYPARTS

/datum/preference/choiced/ipc/generation/init_possible_values()
	return list("I", "II", "III", "IV")

/datum/preference/choiced/ipc/generation/create_default_value()
	return "II"

/datum/preference/choiced/ipc/generation/compile_constant_data()
	var/list/data = ..()
	data[CHOICED_PREFERENCE_DISPLAY_NAMES] = list(
		"I" = "I — Профессиональная специализация",
		"II" = "II — Универсальные КПБ",
		"III" = "III «Гуманность» — Оцифрованные органики",
		"IV" = "IV «Киберлинк» — Флагманы с высокой вычислительной способностью",
	)
	return data

/datum/preference/choiced/ipc/generation/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	. = ..()
	if(!is_species(target, /datum/species/ipc))
		return
	var/obj/item/organ/brain/ipc/positronic = target.get_organ_slot(ORGAN_SLOT_BRAIN)
	// Character preferences configure a new personality, never a transplanted round participant.
	if(istype(positronic) && !positronic.ipc_job_captured && !positronic.engram_transplanted && !target.mind?.active)
		var/datum/ipc_os_program/humanity/archive = positronic.operating_system?.programs["humanity"]
		if(value != "III")
			archive?.detach()
		positronic.ipc_generation = value
		if(value == "III" && archive)
			archive.configure(preferences)
			archive.attach(target)

/// Physical generation effects follow the installed personality core, including while its software is off.
/mob/living/carbon/human/proc/is_ipc_generation(generation)
	if(!dna || !is_species(src, /datum/species/ipc))
		return FALSE
	var/obj/item/organ/brain/ipc/core = get_organ_slot(ORGAN_SLOT_BRAIN)
	return istype(core) && core.ipc_generation == generation

/datum/species/ipc/proc/on_generation_item_attack(mob/living/carbon/human/source, mob/living/target, mob/living/user, list/modifiers, list/attack_modifiers)
	SIGNAL_HANDLER
	if(source.is_ipc_generation("IV"))
		MODIFY_ATTACK_FORCE_MULTIPLIER(attack_modifiers, 0.85)

/datum/species/ipc/proc/on_generation_object_attack(mob/living/carbon/human/source, atom/target, list/modifiers, list/attack_modifiers)
	SIGNAL_HANDLER
	if(source.is_ipc_generation("IV"))
		MODIFY_ATTACK_FORCE_MULTIPLIER(attack_modifiers, 0.85)
