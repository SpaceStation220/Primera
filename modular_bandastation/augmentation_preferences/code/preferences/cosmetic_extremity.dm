/// Whether this species has supported limb sprites for the requested zone.
/datum/species/proc/can_customize_cosmetic_extremities(body_zone)
	var/static/list/supported_species = list(/datum/species/human, /datum/species/human/felinid, /datum/species/human/cerulean, /datum/species/ipc)
	return (type in supported_species) && (isnull(body_zone) || bodypart_overrides[body_zone])

/// Whether the editor can customize the requested zone, or any zone when omitted.
/datum/preferences/proc/can_customize_cosmetic_extremities(body_zone)
	var/datum/species/species = GLOB.species_prototypes[read_preference(/datum/preference/choiced/species)]
	return species?.can_customize_cosmetic_extremities(body_zone)

/// The appearance of one hand or foot on a supported native limb.
/datum/preference/choiced/cosmetic_extremity
	abstract_type = /datum/preference/choiced/cosmetic_extremity
	savefile_identifier = PREFERENCE_CHARACTER
	category = PREFERENCE_CATEGORY_SECONDARY_FEATURES
	priority = PREFERENCE_PRORITY_LATE_BODY_TYPE
	can_randomize = FALSE
	/// The full limb whose hand or foot is drawn with this style.
	var/body_zone

/datum/preference/choiced/cosmetic_extremity/init_possible_values()
	return list(
		SPRITE_ACCESSORY_NONE = "По умолчанию",
		"Bishop" = "Bishop",
		"Cybersun" = "Cybersun",
		"Etamin" = "Etamin",
		"Hephaestus" = "Hephaestus",
		"Morpheus" = "Morpheus",
		"Shellguard" = "Shellguard",
		"Ward-Takahashi" = "Ward-Takahashi",
		"Xion" = "Xion",
		"Zeng-Hu" = "Zeng-Hu",
	)

/datum/preference/choiced/cosmetic_extremity/create_default_value()
	return SPRITE_ACCESSORY_NONE

/datum/preference/choiced/cosmetic_extremity/compile_constant_data()
	var/list/data = ..()
	data[CHOICED_PREFERENCE_DISPLAY_NAMES] = get_choices()
	return data

/datum/preference/choiced/cosmetic_extremity/has_relevant_feature(datum/preferences/preferences)
	return preferences.can_customize_cosmetic_extremities(body_zone)

/datum/preference/choiced/cosmetic_extremity/apply_to_human(mob/living/carbon/human/target, value)
	var/obj/item/bodypart/limb = target.get_bodypart(body_zone)
	if(limb)
		var/valid_style = value != SPRITE_ACCESSORY_NONE && (value in get_choices())
		limb.cosmetic_extremity_style = valid_style && target.dna.species.can_customize_cosmetic_extremities(body_zone) ? value : null

/datum/preference/choiced/cosmetic_extremity/left_hand
	savefile_key = "cosmetic_left_hand"
	body_zone = BODY_ZONE_L_ARM

/datum/preference/choiced/cosmetic_extremity/right_hand
	savefile_key = "cosmetic_right_hand"
	body_zone = BODY_ZONE_R_ARM

/datum/preference/choiced/cosmetic_extremity/left_foot
	savefile_key = "cosmetic_left_foot"
	body_zone = BODY_ZONE_L_LEG

/datum/preference/choiced/cosmetic_extremity/right_foot
	savefile_key = "cosmetic_right_foot"
	body_zone = BODY_ZONE_R_LEG
